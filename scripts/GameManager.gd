extends Node
@export var heartbeat_safe_volume_db: float = -8.0
@export var heartbeat_danger_volume_db: float = 8.0
@export var heartbeat_enemy_distance_threshold: float = 300.0
@export var heartbeat_update_interval: float = 0.1
@export var heartbeat_pitch_variation: bool = true
@export var heartbeat_safe_pitch: float = 0.8
@export var heartbeat_danger_pitch: float = 1.3
@export var heartbeat_smoothing: float = 0.15
var ambient_sound: AudioStreamPlayer
var heartbeat_sound: AudioStreamPlayer
var auto_sonar_timer: Timer
var player
var heartbeat_update_timer: float = 0.0
var quest_system: QuestSystem
var reward_system: RewardSystem
var medkit_system: MedkitSystem
var quest_ui: QuestUI
func _ready():
	RenderingServer.set_default_clear_color(Color.BLACK)
	heartbeat_update_interval = max(0.05, heartbeat_update_interval)
	setup_audio()
	start_audio()
	player = get_node_or_null("../Player")
	if player:
		player.player_died.connect(_on_player_died)
	auto_sonar_timer = Timer.new()
	auto_sonar_timer.one_shot = true
	add_child(auto_sonar_timer)
	auto_sonar_timer.timeout.connect(_on_auto_sonar_timeout)
	_schedule_next_auto_sonar()
	set_process(true)
	_update_heartbeat_volume()
	_setup_quest_systems()
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
	heartbeat_sound.volume_db = heartbeat_safe_volume_db
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
func _process(delta):
	if not heartbeat_sound:
		return
	if not player or not is_instance_valid(player):
		player = get_node_or_null("../Player")
	heartbeat_update_timer -= delta
	if heartbeat_update_timer <= 0.0:
		heartbeat_update_timer = heartbeat_update_interval
		_update_heartbeat_volume()
func _update_heartbeat_volume():
	if not heartbeat_sound:
		return
	var danger_factor = 0.0
	var health_danger = 0.0
	var enemy_danger = 0.0
	var corruption_danger = 0.0
	if player and is_instance_valid(player) and player is Node2D:
		var current_health = player.get("health")
		var max_health = player.get("MAX_HEALTH")
		if (typeof(current_health) == TYPE_INT or typeof(current_health) == TYPE_FLOAT) and (typeof(max_health) == TYPE_INT or typeof(max_health) == TYPE_FLOAT) and float(max_health) > 0.0:
			var health_ratio = clamp(float(current_health) / float(max_health), 0.0, 1.0)
			health_danger = pow(1.0 - health_ratio, 2.0)
		var corruption_active = player.get("corruption_active")
		if corruption_active:
			corruption_danger = 0.6
		var threshold = max(1.0, heartbeat_enemy_distance_threshold)
		var player_pos = (player as Node2D).global_position
		var enemy_distances = []
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not enemy or enemy == player or not is_instance_valid(enemy):
				continue
			if enemy is Node2D:
				var distance = (enemy as Node2D).global_position.distance_to(player_pos)
				if distance < threshold:
					enemy_distances.append(distance)
		if enemy_distances.size() > 0:
			enemy_distances.sort()
			var closest_distance = enemy_distances[0]
			var closest_proximity = 1.0 - clamp(closest_distance / threshold, 0.0, 1.0)
			enemy_danger = pow(closest_proximity, 1.5)
			if enemy_distances.size() > 1:
				var second_closest = enemy_distances[1] if enemy_distances.size() > 1 else threshold
				var multi_enemy_factor = min(0.3, enemy_distances.size() * 0.1)
				enemy_danger = min(1.0, enemy_danger + multi_enemy_factor)
	danger_factor = max(health_danger * 0.8, enemy_danger * 1.0)
	danger_factor = max(danger_factor, corruption_danger)
	danger_factor = clamp(danger_factor, 0.0, 1.0)
	var target_volume = lerp(heartbeat_safe_volume_db, heartbeat_danger_volume_db, danger_factor)
	heartbeat_sound.volume_db = lerp(heartbeat_sound.volume_db, target_volume, heartbeat_smoothing)
	if heartbeat_pitch_variation:
		var target_pitch = lerp(heartbeat_safe_pitch, heartbeat_danger_pitch, danger_factor)
		heartbeat_sound.pitch_scale = lerp(heartbeat_sound.pitch_scale, target_pitch, heartbeat_smoothing)
func _schedule_next_auto_sonar():
	auto_sonar_timer.wait_time = randf_range(25.0, 35.0)
	auto_sonar_timer.start()
func _setup_quest_systems():
	quest_system = preload("res://scripts/QuestSystem.gd").new()
	quest_system.name = "QuestSystem"
	get_tree().current_scene.add_child.call_deferred(quest_system)
	reward_system = preload("res://scripts/RewardSystem.gd").new()
	reward_system.name = "RewardSystem"
	get_tree().current_scene.add_child.call_deferred(reward_system)
	medkit_system = preload("res://scripts/MedkitSystem.gd").new()
	medkit_system.name = "MedkitSystem"
	get_tree().current_scene.add_child.call_deferred(medkit_system)
	quest_ui = preload("res://scripts/ui/QuestUI.gd").new()
	quest_ui.name = "QuestUI"
	quest_ui.set_quest_system_reference(quest_system)
	_setup_quest_ui_deferred.call_deferred()
func _setup_quest_ui_deferred():
	var ui_layer = get_tree().current_scene.get_node_or_null("CanvasLayer")
	if ui_layer:
		ui_layer.add_child(quest_ui)
	else:
		var canvas_layer = CanvasLayer.new()
		canvas_layer.name = "CanvasLayer"
		get_tree().current_scene.add_child(canvas_layer)
		canvas_layer.add_child(quest_ui)
	if quest_system:
		quest_system.quest_death_timer_expired.connect(_on_quest_death_timer_expired)
func get_quest_system() -> QuestSystem:
	return quest_system
func get_reward_system() -> RewardSystem:
	return reward_system
func get_medkit_system() -> MedkitSystem:
	return medkit_system
func get_quest_ui() -> QuestUI:
	return quest_ui
func _on_quest_death_timer_expired(quest):
	print("Death quest timer expired: ", quest.description)
