extends Node

var ambient_sound: AudioStreamPlayer
var heartbeat_sound: AudioStreamPlayer

func _ready():
	RenderingServer.set_default_clear_color(Color.BLACK)
	
	
	setup_audio()
	start_audio()  
	
	
	var player = get_node("../Player")
	if player:
		player.player_died.connect(_on_player_died)

func setup_audio():
	
	ambient_sound = AudioStreamPlayer.new()
	var ambient_stream = load("res://assets/sfx/haunted-house-ambience-337104.mp3")
	if ambient_stream is AudioStreamMP3:
		ambient_stream.loop = true  
	ambient_sound.stream = ambient_stream
	ambient_sound.volume_db = -23
	
	add_child(ambient_sound)
	
	
	heartbeat_sound = AudioStreamPlayer.new()
	var heartbeat_stream = load("res://assets/sfx/thudding-heartbeat-372487.mp3")
	if heartbeat_stream is AudioStreamMP3:
		heartbeat_stream.loop = true  
	heartbeat_sound.stream = heartbeat_stream
	heartbeat_sound.volume_db = 5
	
	add_child(heartbeat_sound)

func start_audio():
	
	ambient_sound.play()
	heartbeat_sound.play()
	print("Audio started playing")

func _on_player_died():
	
	
	var fade_audio_tween = create_tween()
	fade_audio_tween.tween_property(ambient_sound, "volume_db", -80, 1.0)
	fade_audio_tween.parallel().tween_property(heartbeat_sound, "volume_db", -80, 1.0)
	await fade_audio_tween.finished
	
	ambient_sound.stop()
	heartbeat_sound.stop()
	
	
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = get_viewport().size
	get_tree().root.add_child(fade)
	
	var tween = create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.5)
	await tween.finished
	
	get_tree().change_scene_to_file("res://scenes/ui/DeathScreen.tscn")

func _on_player_sonar_pulse(position: Vector2, range: float, direction: Vector2):
	var sonar_system = get_node("../SonarSystem")
	if sonar_system:
		sonar_system._on_sonar_pulse(position, range, direction)
