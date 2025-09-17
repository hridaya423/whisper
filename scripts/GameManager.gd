extends Node

var ambient_sound: AudioStreamPlayer
var heartbeat_sound: AudioStreamPlayer
var auto_sonar_timer: Timer
var player

func _ready():
	RenderingServer.set_default_clear_color(Color.BLACK)
	setup_audio()
	start_audio()
	player = get_node("../Player")
	if player:
		player.player_died.connect(_on_player_died)
	auto_sonar_timer = Timer.new()
	auto_sonar_timer.one_shot = true
	add_child(auto_sonar_timer)
	auto_sonar_timer.timeout.connect(_on_auto_sonar_timeout)
	_schedule_next_auto_sonar()

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

func _on_auto_sonar_timeout():
	if player:
		var pos: Vector2 = player.global_position
		var range: float = player.get("sonar_range") if player.get("sonar_range") != null else 150.0
		var dir: Vector2 = player.get("facing_direction") if player.get("facing_direction") != null else Vector2.RIGHT

		_on_player_sonar_pulse(pos, range, dir)

		var sonar_audio = player.get_node_or_null("SonarAudio")
		if sonar_audio:
			sonar_audio.play()

	_schedule_next_auto_sonar()


func _schedule_next_auto_sonar():
	auto_sonar_timer.wait_time = randf_range(25.0, 35.0)
	auto_sonar_timer.start()
