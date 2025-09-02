extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $Camera3D/Pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D
@onready var nav_agent = $NavigationAgent3D
@onready var ai_timer = $AITimer
@onready var name_label = $NameLabel
@onready var health_bar = $HealthBar3D

var health = 3
var ai_id = 0

const SPEED = 8.0  # Slightly slower than human players
const JUMP_VELOCITY = 10.0
const GRAVITY = 20.0

# AI Behavior variables
var target_player = null
var current_state = "patrol"
var last_known_player_position = Vector3.ZERO
var patrol_points = []
var current_patrol_index = 0
var ai_difficulty = 1.0  # 0.5 = easy, 1.0 = normal, 1.5 = hard

# AI timing variables
var shoot_cooldown = 0.0
var decision_timer = 0.0
var reaction_time = 0.5  # How fast AI reacts to player

# AI states
enum AIState {
	PATROL,
	CHASE,
	ATTACK,
	RETREAT,
	SEARCH
}

var ai_state = AIState.PATROL

func _enter_tree():
	set_multiplayer_authority(1)  # AI players are always server-authoritative

func _ready():
	print("=== AI Player _ready() called - ID: ", ai_id, " ===")
	
	# Check if nodes exist
	print("name_label exists: ", name_label != null)
	print("health_bar exists: ", health_bar != null)
	print("ai_timer exists: ", ai_timer != null)
	
	add_to_group("ai_player")
	add_to_group("player")  # So they can be targeted by other players
	
	# Ensure collision is enabled
	collision_layer = 2  # Same as human players
	collision_mask = 1   # Can collide with ground
	print("Set collision layer: ", collision_layer, " mask: ", collision_mask)
	
	# Make sure collision shape is enabled
	var collision_shape = $CollisionShape3D
	if collision_shape:
		collision_shape.disabled = false
		print("Collision shape enabled for AI ", ai_id)
	else:
		print("ERROR: No CollisionShape3D found for AI ", ai_id)
	
	# Force update collision settings
	await get_tree().process_frame
	collision_layer = 2
	collision_mask = 1
	print("Force updated collision for AI ", ai_id, " - layer: ", collision_layer, " mask: ", collision_mask)
	
	# Set up AI timer
	if ai_timer:
		ai_timer.wait_time = 0.1  # Update AI every 100ms
		ai_timer.timeout.connect(_update_ai)
		ai_timer.start()
		print("AI timer started")
	
	# Initialize patrol points around the map
	_setup_patrol_points()
	
	# Set random starting position
	position = _get_random_spawn_position()
	
	# For testing: spawn one AI near center but not on top of human player
	if ai_id == 0:
		position = Vector3(3, 1, 3)  # Spawn near center, slightly above ground
		print("AI Player 0 spawned at position: ", position)
	
	# Set name label
	if name_label:
		name_label.text = "AI Player " + str(ai_id + 1)
		print("Set name label: ", name_label.text)
	else:
		print("ERROR: name_label is null!")
	
	# Set up health bar
	if health_bar:
		health_bar.text = "HP: " + str(health) + "/3"
		_update_health_bar_color()
		print("Set health bar: ", health_bar.text)
	else:
		print("ERROR: health_bar is null!")
	
	# Ensure AI is on the ground
	await get_tree().process_frame  # Wait one frame for physics to initialize
	_ensure_on_ground()
	
	print("AI Player initialized at position: ", position)
	print("AI Player collision layer: ", collision_layer, " mask: ", collision_mask)
	print("=== AI Player _ready() finished ===")

func _ensure_on_ground():
	# Cast a ray downward to find the ground
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		position + Vector3(0, 10, 0),  # Start from above
		position + Vector3(0, -10, 0)  # End below
	)
	query.collision_mask = 1  # Only collide with layer 1 (ground)
	
	var result = space_state.intersect_ray(query)
	if result:
		position.y = result.position.y + 1.0  # Place 1 unit above ground
		print("AI Player positioned on ground at: ", position)

func _setup_patrol_points():
	# Define patrol points within the visible field area
	patrol_points = [
		Vector3(-6, 1, -6),   # Top-left
		Vector3(6, 1, -6),    # Top-right
		Vector3(6, 1, 6),     # Bottom-right
		Vector3(-6, 1, 6),    # Bottom-left
		Vector3(0, 1, 0),     # Center
		Vector3(-3, 1, -3),   # Inner positions
		Vector3(3, 1, -3),
		Vector3(3, 1, 3),
		Vector3(-3, 1, 3)
	]

func _get_random_spawn_position() -> Vector3:
	# Get a random spawn position within the visible field area
	var spawn_positions = [
		Vector3(-8, 1, -8),   # Top-left corner
		Vector3(8, 1, -8),    # Top-right corner
		Vector3(8, 1, 8),     # Bottom-right corner
		Vector3(-8, 1, 8),    # Bottom-left corner
		Vector3(0, 1, -6),    # Top center
		Vector3(0, 1, 6),     # Bottom center
		Vector3(-6, 1, 0),    # Left center
		Vector3(6, 1, 0),     # Right center
		Vector3(-4, 1, -4),   # Inner positions
		Vector3(4, 1, -4),
		Vector3(4, 1, 4),
		Vector3(-4, 1, 4)
	]
	
	# Find a position that's not too close to other players
	for pos in spawn_positions:
		var too_close = false
		for player in get_tree().get_nodes_in_group("player"):
			if player != self and player.position.distance_to(pos) < 5.0:
				too_close = true
				break
		if not too_close:
			return pos
	
	# If all positions are too close, return a random one anyway
	return spawn_positions[randi() % spawn_positions.size()]

func _update_ai():
	if not is_multiplayer_authority():
		return
	
	decision_timer += 0.1
	
	# Update shoot cooldown
	if shoot_cooldown > 0:
		shoot_cooldown -= 0.1
	
	# Find nearest target (player or other AI)
	_find_target_player()
	
	# Make AI decisions based on current state
	match ai_state:
		AIState.PATROL:
			_patrol_behavior()
		AIState.CHASE:
			_chase_behavior()
		AIState.ATTACK:
			_attack_behavior()
		AIState.RETREAT:
			_retreat_behavior()
		AIState.SEARCH:
			_search_behavior()
	
	# Update movement
	_update_movement()
	
	# Debug: Print AI state occasionally
	if decision_timer > 5.0:  # Every 5 seconds
		print("AI ", ai_id, " state: ", get_ai_state_string(), " at position: ", position)
		decision_timer = 0.0

func _find_target_player():
	var nearest_player = null
	var nearest_distance = 50.0  # Maximum detection range
	
	# Find all players (human and AI)
	for player in get_tree().get_nodes_in_group("player"):
		if player == self:
			continue  # Skip self
		
		var distance = position.distance_to(player.position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_player = player
	
	target_player = nearest_player

func _update_movement():
	# Simple direct movement without navigation
	var target_position = Vector3.ZERO
	
	match ai_state:
		AIState.PATROL:
			if patrol_points.size() > 0:
				target_position = patrol_points[current_patrol_index]
		AIState.CHASE, AIState.ATTACK:
			if target_player:
				target_position = target_player.position
		AIState.RETREAT:
			target_position = last_known_player_position
		AIState.SEARCH:
			target_position = last_known_player_position
		_:
			velocity.x = 0
			velocity.z = 0
			return
	
	# Calculate direction to target
	var direction = (target_position - position).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

func _patrol_behavior():
	if target_player and position.distance_to(target_player.position) < 15.0:
		# Player detected, switch to chase
		ai_state = AIState.CHASE
		last_known_player_position = target_player.position
		return
	
	# Move to next patrol point
	if patrol_points.size() > 0:
		var target_point = patrol_points[current_patrol_index]
		
		if position.distance_to(target_point) < 3.0:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _chase_behavior():
	if not target_player:
		ai_state = AIState.SEARCH
		return
	
	var distance_to_player = position.distance_to(target_player.position)
	
	# If player is too far, go back to patrol
	if distance_to_player > 20.0:
		ai_state = AIState.PATROL
		return
	
	# If close enough, switch to attack
	if distance_to_player < 8.0:
		ai_state = AIState.ATTACK
		return
	
	# Chase the player (movement handled in _update_movement)
	last_known_player_position = target_player.position

func _attack_behavior():
	if not target_player:
		ai_state = AIState.SEARCH
		return
	
	var distance_to_player = position.distance_to(target_player.position)
	
	# If player moved away, chase them
	if distance_to_player > 10.0:
		ai_state = AIState.CHASE
		return
	
	# If too close, retreat a bit
	if distance_to_player < 3.0:
		ai_state = AIState.RETREAT
		return
	
	# Look at the player
	_look_at_target(target_player.position)
	
	# Try to shoot
	if shoot_cooldown <= 0 and _can_see_player(target_player):
		print("AI ", ai_id, " in attack mode, can see target, attempting to shoot")
		_try_shoot()
	elif shoot_cooldown > 0:
		print("AI ", ai_id, " in attack mode but on cooldown: ", shoot_cooldown)
	elif not _can_see_player(target_player):
		print("AI ", ai_id, " in attack mode but cannot see target")

func _retreat_behavior():
	if not target_player:
		ai_state = AIState.SEARCH
		return
	
	var distance_to_player = position.distance_to(target_player.position)
	
	# If far enough, go back to attack
	if distance_to_player > 5.0:
		ai_state = AIState.ATTACK
		return
	
	# Move away from player (movement handled in _update_movement)
	# Set a retreat position
	var retreat_direction = (position - target_player.position).normalized()
	last_known_player_position = position + retreat_direction * 5.0

func _search_behavior():
	# Go to last known player position (movement handled in _update_movement)
	if position.distance_to(last_known_player_position) < 3.0:
		# Search around the area
		var search_positions = [
			last_known_player_position + Vector3(5, 0, 0),
			last_known_player_position + Vector3(-5, 0, 0),
			last_known_player_position + Vector3(0, 0, 5),
			last_known_player_position + Vector3(0, 0, -5)
		]
		last_known_player_position = search_positions[randi() % search_positions.size()]
	
	# If we find the player again, chase them
	if target_player and position.distance_to(target_player.position) < 15.0:
		ai_state = AIState.CHASE

func _look_at_target(target_pos: Vector3):
	var direction = (target_pos - position).normalized()
	var target_rotation = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

func _can_see_player(player) -> bool:
	# Simple line of sight check
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(position, player.position)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	return result.is_empty() or result.collider == player

func _try_shoot():
	if shoot_cooldown > 0:
		return
	
	# Add some randomness to AI shooting accuracy
	var accuracy = 0.6 * ai_difficulty  # Better AI = more accurate
	if randf() > accuracy:
		print("AI ", ai_id, " missed due to accuracy")
		return
	
	print("AI ", ai_id, " attempting to shoot at target!")
	
	# Simulate shooting
	play_shoot_effects.rpc()
	
	# Check if we hit the target using raycast
	if target_player:
		# Update raycast to point at target
		var direction = (target_player.position - position).normalized()
		raycast.target_position = direction * 100.0
		raycast.force_raycast_update()
		
		print("AI ", ai_id, " raycast direction: ", direction, " target: ", target_player.position)
		
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			print("AI ", ai_id, " raycast hit: ", hit_player)
			if hit_player == target_player:
				print("AI ", ai_id, " HIT TARGET! Dealing damage!")
				hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			else:
				print("AI ", ai_id, " hit something else: ", hit_player)
		else:
			print("AI ", ai_id, " raycast missed")
	
	# Add some randomness to shooting cooldown
	var base_cooldown = 1.5 / ai_difficulty  # Slightly slower shooting
	shoot_cooldown = base_cooldown + randf_range(-0.3, 0.3)
	print("AI ", ai_id, " shoot cooldown set to: ", shoot_cooldown)



# func _on_velocity_computed(safe_velocity):
# 	velocity = safe_velocity
# 	move_and_slide()

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		# Stop falling when on ground
		if velocity.y < 0:
			velocity.y = 0
	
	# Update animation based on movement
	if velocity.length() > 0.1:
		anim_player.play("move")
	else:
		anim_player.play("idle")
	
	# Apply movement
	move_and_slide()
	
	# Debug: Print position occasionally
	if randf() < 0.005:  # 0.5% chance per frame
		print("AI ", ai_id, " position: ", position, " velocity: ", velocity)

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer", "call_local")
func receive_damage():
	print("=== AI Player ", ai_id, " RECEIVED DAMAGE! ===")
	health -= 1
	print("AI Player ", ai_id, " took damage! Health: ", health)
	
	# Update health bar immediately (local)
	_update_health_display()
	
	if health <= 0:
		print("AI Player ", ai_id, " died! Respawning...")
		health = 3
		position = _get_random_spawn_position()
		ai_state = AIState.PATROL  # Reset AI state on respawn
		
		# Reset health bar
		_update_health_display()
	
	health_changed.emit(health)

# Local function to update health display immediately
func _update_health_display():
	if health_bar:
		health_bar.text = "HP: " + str(health) + "/3"
		_update_health_bar_color()
		print("Updated health bar to: ", health_bar.text)
	else:
		print("ERROR: health_bar is null when trying to update!")

func _update_health_bar_color():
	if not health_bar:
		return
	
	# Change health bar color based on health
	if health >= 3:
		health_bar.modulate = Color.GREEN
	elif health == 2:
		health_bar.modulate = Color.YELLOW
	elif health == 1:
		health_bar.modulate = Color.RED
	else:
		health_bar.modulate = Color.DARK_RED

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
		anim_player.play("idle")

# Public functions for external control
func set_difficulty(difficulty: float):
	ai_difficulty = clamp(difficulty, 0.5, 2.0)
	reaction_time = 0.5 / ai_difficulty  # Faster reaction for better AI

func get_ai_state_string() -> String:
	match ai_state:
		AIState.PATROL:
			return "Patrol"
		AIState.CHASE:
			return "Chase"
		AIState.ATTACK:
			return "Attack"
		AIState.RETREAT:
			return "Retreat"
		AIState.SEARCH:
			return "Search"
		_:
			return "Unknown"

# Test function to manually damage AI
func test_damage():
	print("Testing damage on AI ", ai_id)
	receive_damage()

# Test function to check if AI can be hit by raycast
func test_raycast_hit():
	print("Testing raycast hit on AI ", ai_id)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		Vector3(0, 2, 0),  # Start from above
		position  # End at AI position
	)
	query.collision_mask = 2  # Look for layer 2 (players)
	
	var result = space_state.intersect_ray(query)
	if result:
		print("Raycast hit: ", result.collider)
		if result.collider == self:
			print("SUCCESS: Raycast hit this AI player!")
		else:
			print("Raycast hit something else: ", result.collider)
	else:
		print("Raycast missed everything")

# Test function to force AI to shoot
func test_shoot():
	print("Testing AI ", ai_id, " shooting...")
	shoot_cooldown = 0  # Reset cooldown
	_try_shoot()
