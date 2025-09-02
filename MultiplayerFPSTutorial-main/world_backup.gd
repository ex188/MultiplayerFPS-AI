extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD
@onready var health_bar = $CanvasLayer/HUD/HealthBar
@onready var ai_difficulty_slider = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AIDifficultySlider
@onready var ai_count_slider = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AICountSlider

const Player = preload("res://player.tscn")
const AIPlayer = preload("res://AIPlayer.tscn")
const PORT = 9999
var enet_peer = ENetMultiplayerPeer.new()

# AI Settings
var ai_players = []
var max_ai_players = 3
var ai_difficulty = 1.0
var ai_spawn_timer = 0.0
var ai_spawn_delay = 2.0  # Seconds between AI spawns

func _ready():
	# Connect AI slider signals to update labels
	if ai_difficulty_slider:
		ai_difficulty_slider.value_changed.connect(_on_ai_difficulty_changed)
	if ai_count_slider:
		ai_count_slider.value_changed.connect(_on_ai_count_changed)

func _on_ai_difficulty_changed(value: float):
	if ai_difficulty_slider:
		var label = get_node("CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AIDifficultyLabel")
		if label:
			label.text = "AI Difficulty: %.1f" % value

func _on_ai_count_changed(value: float):
	if ai_count_slider:
		var label = get_node("CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AICountLabel")
		if label:
			label.text = "AI Players: %d" % int(value)

func _unhandled_input(event):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()
	
	# Update AI settings from UI
	ai_difficulty = ai_difficulty_slider.value
	max_ai_players = int(ai_count_slider.value)
	
	print("Hosting with AI settings - Difficulty: ", ai_difficulty, " Count: ", max_ai_players)
	
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	add_player(multiplayer.get_unique_id())
	
	# Start spawning AI players
	_spawn_ai_players()

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()
	
	enet_peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = enet_peer

func add_player(peer_id):
	var player = Player.instantiate()
	player.name = str(peer_id)
	
	# Set spawn position for human players
	player.position = Vector3(0, 0, -5)  # Spawn slightly away from center
	
	add_child(player)
	if player.is_multiplayer_authority():
		player.health_changed.connect(update_health_bar)

func remove_player(peer_id):
	var player = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

func update_health_bar(health_value):
	health_bar.value = health_value

func _on_multiplayer_spawner_spawned(node):
	if node.is_multiplayer_authority():
		node.health_changed.connect(update_health_bar)

func _process(delta):
	# Only the server (host) manages AI players
	if not multiplayer.is_server():
		return
	
	# Update AI spawn timer
	ai_spawn_timer += delta
	
	# Spawn AI players if needed
	if ai_spawn_timer >= ai_spawn_delay and ai_players.size() < max_ai_players:
		_spawn_single_ai_player()
		ai_spawn_timer = 0.0

func _spawn_ai_players():
	print("Starting to spawn AI players. Max AI players: ", max_ai_players)
	# Spawn initial AI players
	for i in range(max_ai_players):
		print("Spawning AI player ", i + 1, " of ", max_ai_players)
		_spawn_single_ai_player()
		await get_tree().create_timer(1.0).timeout  # Stagger spawns

func _spawn_single_ai_player():
	print("Attempting to spawn AI player...")
	
	# Check if AIPlayer scene exists
	if not AIPlayer:
		print("ERROR: AIPlayer scene not found!")
		return
		
	var ai_player = AIPlayer.instantiate()
	if ai_player == null:
		print("ERROR: Failed to instantiate AIPlayer scene!")
		return
		
	ai_player.name = "AI_" + str(ai_players.size())
	ai_player.ai_id = ai_players.size()
	ai_player.set_difficulty(ai_difficulty)
	
	add_child(ai_player)
	ai_players.append(ai_player)
	
	print("Successfully spawned AI player: ", ai_player.name, " at position: ", ai_player.position)

func _remove_ai_player(ai_player):
	if ai_player in ai_players:
		ai_players.erase(ai_player)
		ai_player.queue_free()

func set_ai_difficulty(difficulty: float):
	ai_difficulty = clamp(difficulty, 0.5, 2.0)
	for ai in ai_players:
		ai.set_difficulty(ai_difficulty)

func set_max_ai_players(count: int):
	max_ai_players = clamp(count, 0, 8)
	
	# Remove excess AI players if needed
	while ai_players.size() > max_ai_players:
		var ai_to_remove = ai_players.pop_back()
		ai_to_remove.queue_free()

func upnp_setup():
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Discover Failed! Error %s" % discover_result)

	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
		"UPNP Invalid Gateway!")

	var map_result = upnp.add_port_mapping(PORT)
	assert(map_result == UPNP.UPNP_RESULT_SUCCESS, \
		"UPNP Port Mapping Failed! Error %s" % map_result)
	
	print("Success! Join Address: %s" % upnp.query_external_address())
