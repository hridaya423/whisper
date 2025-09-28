extends Node
class_name QuestSystem
enum QuestType {
	KILL_ENEMIES,
	COLLECT_RUNES,
	SURVIVE_TIME,
	REACH_DISTANCE
}
enum PenaltyType {
	SONAR_RANGE_REDUCTION,
	MOVEMENT_SPEED_REDUCTION,
	SONAR_COOLDOWN_INCREASE,
	HEALTH_DRAIN,
	TIME_PRESSURE,
	VISION_REDUCTION,
	CORRUPTION_BUILDUP,
	ENEMY_ATTRACTION
}
const QuestData = preload("res://scripts/quests/QuestData.gd")
var available_quests: Array[QuestData] = []
var active_quests: Array[QuestData] = []
var completed_quests: Array[QuestData] = []
var quest_triggers_enabled: bool = false
var last_quest_level: int = 0
var min_quests_per_offer: int = 2
var max_quests_per_offer: int = 4
var max_active_quests: int = 3
var player: Node
var level_manager: Node
var enemy_spawner: Node
var rune_system: Node
var reward_system: Node
var survival_timer: float = 0.0
var initial_distance: float = 0.0
var enemies_killed_this_session: int = 0
var runes_collected_this_session: int = 0
var next_quest_level: int = 0
var dialogue_player: AudioStreamPlayer
var dialogue_played = false
var active_penalties: Dictionary = {}
var health_drain_timer: float = 0.0
var health_drain_interval: float = 8.0
var quest_offered_sound: AudioStreamPlayer
var quest_accepted_sound: AudioStreamPlayer
var quest_completed_sound: AudioStreamPlayer
var reward_received_sound: AudioStreamPlayer
var medkit_use_sound: AudioStreamPlayer
signal quest_offered(quests)
signal quest_accepted(quest)
signal quest_completed(quest)
signal quest_progress_updated(quest)
signal quest_failed(quest)
signal quest_death_timer_expired(quest)
signal quest_penalty_applied(penalty_type: PenaltyType, strength: float)
signal quest_penalty_removed(penalty_type: PenaltyType)
func _ready():
	_setup_references()
	_setup_audio()
	_setup_dialogue()
	_connect_signals()
	set_process(true)
	quest_triggers_enabled = false
func _setup_references():
	player = get_tree().get_first_node_in_group("player")
	level_manager = _find_node_by_name(get_tree().current_scene, "LevelManager")
	enemy_spawner = _find_node_by_name(get_tree().current_scene, "EnemySpawner")
	rune_system = _find_node_by_name(get_tree().current_scene, "RuneSystem")
	reward_system = _find_node_by_name(get_tree().current_scene, "RewardSystem")
	if not reward_system:
		pass
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
func _connect_signals():
	if level_manager and level_manager.has_signal("level_completed"):
		level_manager.level_completed.connect(_on_level_completed)
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_killed)
	if rune_system and rune_system.has_signal("rune_collected"):
		rune_system.rune_collected.connect(_on_rune_collected)
func _process(delta):
	_update_survival_quests(delta)
	_update_distance_quests()
	_update_quest_progress()
	_update_death_quest_timers(delta)
	_update_penalty_effects(delta)
func _update_survival_quests(delta: float):
	survival_timer += delta
	for quest in active_quests:
		if quest.type == QuestType.SURVIVE_TIME:
			var new_progress = int(survival_timer)
			if new_progress != quest.progress:
				quest.progress = new_progress
				_sync_completion_state(quest)
				quest_progress_updated.emit(quest)
				if quest.is_completed():
					_complete_quest(quest)
func _update_distance_quests():
	if not player:
		return
	var current_distance = abs(player.global_position.x)
	if initial_distance == 0.0:
		initial_distance = current_distance
	var distance_traveled = current_distance - initial_distance
	for quest in active_quests:
		if quest.type == QuestType.REACH_DISTANCE:
			var new_progress = int(distance_traveled)
			if new_progress != quest.progress:
				quest.progress = new_progress
				_sync_completion_state(quest)
				quest_progress_updated.emit(quest)
				if quest.is_completed():
					_complete_quest(quest)
func _sync_completion_state(quest: QuestData):
	if quest.progress >= quest.target and quest.status != QuestData.Status.COMPLETED:
		quest.status = QuestData.Status.COMPLETED
func _update_quest_progress():
	for quest in active_quests:
		match quest.type:
			QuestType.KILL_ENEMIES:
				if enemies_killed_this_session != quest.progress:
					quest.progress = min(enemies_killed_this_session, quest.target)
					quest_progress_updated.emit(quest)
					if quest.is_completed():
						_complete_quest(quest)
			QuestType.COLLECT_RUNES:
				if runes_collected_this_session != quest.progress:
					quest.progress = min(runes_collected_this_session, quest.target)
					quest_progress_updated.emit(quest)
					if quest.is_completed():
						_complete_quest(quest)
func _update_death_quest_timers(delta: float):
	for quest in active_quests.duplicate():
		if quest.is_death_quest:
			quest.update_time(delta)
			if quest.status == QuestData.Status.FAILED:
				_fail_death_quest(quest)
func _update_penalty_effects(delta: float):
	if active_penalties.has(PenaltyType.HEALTH_DRAIN):
		health_drain_timer += delta
		if health_drain_timer >= health_drain_interval:
			health_drain_timer = 0.0
			if player and player.has_method("take_damage"):
				player.take_damage()
func _fail_death_quest(quest: QuestData):
	if quest in active_quests:
		active_quests.erase(quest)
		quest.status = QuestData.Status.FAILED
		quest_failed.emit(quest)
		quest_death_timer_expired.emit(quest)
		_remove_quest_penalties(quest)
		if player and player.has_method("die"):
			player.die()
func _on_level_completed(level: int):
	if active_quests.size() == 0:
		_reset_quest_tracking()
	if not quest_triggers_enabled and level >= 1:
		quest_triggers_enabled = true
	if quest_triggers_enabled and _should_offer_quests(level):
		last_quest_level = level
		_offer_quests(level)
func _should_offer_quests(level: int) -> bool:
	if next_quest_level == 0:
		next_quest_level = 1
	if level >= next_quest_level and level != last_quest_level:
		var random_interval = randi_range(1, 2)
		next_quest_level = level + random_interval
		return true
	return false
func _reset_quest_tracking():
	enemies_killed_this_session = 0
	runes_collected_this_session = 0
	survival_timer = 0.0
	if player:
		initial_distance = abs(player.global_position.x)
func _on_enemy_killed():
	enemies_killed_this_session += 1
func _on_rune_collected(rune_type):
	runes_collected_this_session += 1
func _offer_quests(current_level: int):
	print_stack()
	available_quests.clear()
	var num_quests = randi_range(min_quests_per_offer, max_quests_per_offer)
	for i in range(num_quests):
		var quest = _generate_random_quest(current_level)
		if quest:
			available_quests.append(quest)
	if available_quests.size() > 0:
		_play_quest_offered_sound()
		_play_quest_dialogue()
		var quest_payload: Array = []
		for idx in range(available_quests.size()):
			var quest_item = available_quests[idx]
			quest_payload.append(quest_item)
		quest_offered.emit(quest_payload)
func _generate_random_quest(level: int) -> QuestData:
	var quest_types = [QuestType.KILL_ENEMIES, QuestType.COLLECT_RUNES, QuestType.SURVIVE_TIME, QuestType.REACH_DISTANCE]
	var quest_type = quest_types[randi() % quest_types.size()]
	var target = _calculate_quest_target(quest_type, level)
	var quest = QuestData.new(quest_type, target, "", 0, level)
	var penalty_multiplier = 1.0
	if randf() < 0.7:
		_add_random_penalty(quest, level)
		penalty_multiplier = 1.0 + quest.penalty_strength
	var death_quest_chance = 0.15 + (level * 0.05)
	if randf() < death_quest_chance and quest_type != QuestType.SURVIVE_TIME:
		_make_death_quest(quest, level)
		penalty_multiplier += 1.5
	var reward_data = _generate_quest_reward(level, penalty_multiplier)
	quest.reward_type = reward_data.type
	quest.reward_amount = reward_data.amount
	quest.description = _generate_quest_description(quest)
	return quest
func _calculate_quest_target(quest_type: QuestType, level: int) -> int:
	var base_difficulty = 1.0 + (level - 2) * 0.5
	match quest_type:
		QuestType.KILL_ENEMIES:
			return int(randi_range(8, 15) * base_difficulty)
		QuestType.COLLECT_RUNES:
			return int(randi_range(4, 8) * base_difficulty)
		QuestType.SURVIVE_TIME:
			return int(randi_range(90, 180) * base_difficulty)
		QuestType.REACH_DISTANCE:
			return int(randi_range(800, 1800) * base_difficulty)
		_:
			return 1
func _generate_quest_reward(level: int, penalty_multiplier: float = 1.0) -> Dictionary:
	var reward_types = ["medkit", "rune_duration", "attack_boost", "speed_boost", "sonar_boost"]
	var weights = [30, 25, 20, 15, 10]
	var total_weight = weights.reduce(func(a, b): return a + b, 0)
	var random_value = randi() % total_weight
	var cumulative_weight = 0
	var selected_type = "medkit"
	for i in range(reward_types.size()):
		cumulative_weight += weights[i]
		if random_value < cumulative_weight:
			selected_type = reward_types[i]
			break
	var amount = _calculate_reward_amount(selected_type, level, penalty_multiplier)
	return {"type": selected_type, "amount": amount}
func _calculate_reward_amount(reward_type: String, level: int, penalty_multiplier: float = 1.0) -> int:
	var level_bonus = 1.0 + (level - 2) * 0.2
	var total_multiplier = level_bonus * penalty_multiplier
	match reward_type:
		"medkit":
			return max(1, int(randi_range(1, 3) * penalty_multiplier))
		"rune_duration":
			return int(randi_range(10, 25) * total_multiplier)
		"attack_boost":
			return int(randi_range(30, 75) * total_multiplier)
		"speed_boost":
			return int(randi_range(30, 60) * total_multiplier)
		"sonar_boost":
			return int(randi_range(45, 80) * total_multiplier)
		_:
			return 1
func _add_random_penalty(quest: QuestData, level: int):
	var penalty_types = [
		PenaltyType.SONAR_RANGE_REDUCTION,
		PenaltyType.MOVEMENT_SPEED_REDUCTION,
		PenaltyType.SONAR_COOLDOWN_INCREASE,
		PenaltyType.HEALTH_DRAIN,
		PenaltyType.TIME_PRESSURE,
		PenaltyType.VISION_REDUCTION,
		PenaltyType.CORRUPTION_BUILDUP,
		PenaltyType.ENEMY_ATTRACTION
	]
	var penalty_type = penalty_types[randi() % penalty_types.size()]
	var base_strength = 0.25 + (level * 0.05)
	var strength = clamp(base_strength + randf_range(-0.1, 0.15), 0.2, 0.6)
	var penalty_description = _get_penalty_description(penalty_type, strength)
	quest.set_penalty(penalty_type, strength, penalty_description)
func _get_penalty_description(penalty: PenaltyType, strength: float) -> String:
	match penalty:
		PenaltyType.SONAR_RANGE_REDUCTION:
			return "Sonar range reduced by " + str(int(strength * 100)) + "%"
		PenaltyType.MOVEMENT_SPEED_REDUCTION:
			return "Movement speed reduced by " + str(int(strength * 100)) + "%"
		PenaltyType.SONAR_COOLDOWN_INCREASE:
			return "Sonar cooldown increased by " + str(int(strength * 100)) + "%"
		PenaltyType.HEALTH_DRAIN:
			return "Health slowly drains over time"
		PenaltyType.TIME_PRESSURE:
			return "Must complete " + str(int(strength * 100)) + "% faster than normal"
		PenaltyType.VISION_REDUCTION:
			return "Visual range reduced by " + str(int(strength * 100)) + "%"
		PenaltyType.CORRUPTION_BUILDUP:
			return "Corruption builds up " + str(int(strength * 100)) + "% faster"
		PenaltyType.ENEMY_ATTRACTION:
			return "Enemies spawn " + str(int(strength * 100)) + "% more frequently"
		_:
			return "Unknown penalty"
func _generate_quest_description(quest: QuestData) -> String:
	var base_description = ""
	match quest.type:
		QuestType.KILL_ENEMIES:
			base_description = "Eliminate " + str(quest.target) + " shadowy entities"
		QuestType.COLLECT_RUNES:
			base_description = "Gather " + str(quest.target) + " mystical runes"
		QuestType.SURVIVE_TIME:
			base_description = "Endure the darkness for " + str(quest.target) + " seconds"
		QuestType.REACH_DISTANCE:
			base_description = "Travel " + str(quest.target) + " units into the void"
		_:
			base_description = "Unknown quest"
	if quest.is_death_quest:
		base_description += "\n?? DEATH QUEST - Time limit: " + str(int(quest.time_limit)) + "s"
	if quest.has_penalty and quest.penalty_description != "":
		base_description += "\n? PENALTY: " + quest.penalty_description
	return base_description
func _make_death_quest(quest: QuestData, level: int):
	var base_time = 120.0
	var level_modifier = 1.0 + (level * 0.2)
	var difficulty_modifier = 1.0
	match quest.type:
		QuestType.KILL_ENEMIES:
			difficulty_modifier = 1.5
		QuestType.COLLECT_RUNES:
			difficulty_modifier = 1.2
		QuestType.SURVIVE_TIME:
			difficulty_modifier = 1.1
		QuestType.REACH_DISTANCE:
			difficulty_modifier = 1.3
	var time_limit = base_time * level_modifier * difficulty_modifier
	quest.set_death_quest(time_limit)
func accept_quest(quest: QuestData) -> bool:
	if active_quests.size() >= max_active_quests:
		return false
	if quest in available_quests:
		available_quests.erase(quest)
		active_quests.append(quest)
		quest.status = QuestData.Status.ACTIVE
		if quest.has_penalty:
			_apply_quest_penalty(quest)
		_play_quest_accepted_sound()
		quest_accepted.emit(quest)
		return true
	return false
func _complete_quest(quest: QuestData):
	if quest in active_quests:
		active_quests.erase(quest)
		completed_quests.append(quest)
		quest.status = QuestData.Status.COMPLETED
		if quest.has_penalty:
			_remove_quest_penalties(quest)
		if reward_system and reward_system.has_method("give_reward"):
			reward_system.give_reward(quest.reward_type, quest.reward_amount)
		_play_quest_completed_sound()
		_play_reward_received_sound(quest.reward_type)
		quest_completed.emit(quest)
func abandon_quest(quest: QuestData) -> bool:
	if quest in active_quests:
		active_quests.erase(quest)
		quest.status = QuestData.Status.FAILED
		if quest.has_penalty:
			_remove_quest_penalties(quest)
		quest_failed.emit(quest)
		return true
	return false
func get_active_quests() -> Array[QuestData]:
	return active_quests.duplicate()
func get_available_quests() -> Array[QuestData]:
	return available_quests.duplicate()
func get_completed_quests() -> Array[QuestData]:
	return completed_quests.duplicate()
func has_active_quests() -> bool:
	return active_quests.size() > 0
func has_available_quests() -> bool:
	return available_quests.size() > 0
func register_enemy(enemy: Node):
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_killed)
func _apply_quest_penalty(quest: QuestData):
	if not quest.has_penalty:
		return
	active_penalties[quest.penalty_type] = quest.penalty_strength
	quest_penalty_applied.emit(quest.penalty_type, quest.penalty_strength)
	match quest.penalty_type:
		PenaltyType.SONAR_RANGE_REDUCTION:
			pass
		PenaltyType.MOVEMENT_SPEED_REDUCTION:
			pass
		PenaltyType.SONAR_COOLDOWN_INCREASE:
			pass
		PenaltyType.HEALTH_DRAIN:
			health_drain_timer = 0.0
func _remove_quest_penalties(quest: QuestData):
	if not quest.has_penalty:
		return
	if active_penalties.has(quest.penalty_type):
		active_penalties.erase(quest.penalty_type)
		quest_penalty_removed.emit(quest.penalty_type)
	quest.clear_penalty()
	quest.description = _generate_quest_description(quest)
func get_penalty_multiplier(penalty_type: PenaltyType) -> float:
	if active_penalties.has(penalty_type):
		return active_penalties[penalty_type]
	return 0.0
func has_active_penalty(penalty_type: PenaltyType) -> bool:
	return active_penalties.has(penalty_type)
func get_active_penalties() -> Dictionary:
	return active_penalties.duplicate()
func _setup_audio():
	quest_offered_sound = AudioStreamPlayer.new()
	quest_offered_sound.name = "QuestOfferedSound"
	add_child(quest_offered_sound)
	quest_accepted_sound = AudioStreamPlayer.new()
	quest_accepted_sound.name = "QuestAcceptedSound"
	add_child(quest_accepted_sound)
	quest_completed_sound = AudioStreamPlayer.new()
	quest_completed_sound.name = "QuestCompletedSound"
	add_child(quest_completed_sound)
	reward_received_sound = AudioStreamPlayer.new()
	reward_received_sound.name = "RewardReceivedSound"
	add_child(reward_received_sound)
	medkit_use_sound = AudioStreamPlayer.new()
	medkit_use_sound.name = "MedkitUseSound"
	add_child(medkit_use_sound)
	_generate_audio_streams()
func _generate_audio_streams():
	quest_offered_sound.stream = _create_ethereal_tone(440.0, 0.8)
	quest_accepted_sound.stream = _create_positive_chime(523.25, 0.6)
	quest_completed_sound.stream = _create_success_fanfare()
	reward_received_sound.stream = _create_magical_sparkle()
	medkit_use_sound.stream = _create_healing_sound()
func _create_ethereal_tone(frequency: float, duration: float) -> AudioStream:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = duration
	return generator
func _create_positive_chime(frequency: float, duration: float) -> AudioStream:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = duration
	return generator
func _create_success_fanfare() -> AudioStream:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 1.2
	return generator
func _create_magical_sparkle() -> AudioStream:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.6
	return generator
func _create_healing_sound() -> AudioStream:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.8
	return generator
func _play_quest_offered_sound():
	if quest_offered_sound:
		quest_offered_sound.pitch_scale = randf_range(0.9, 1.1)
		quest_offered_sound.volume_db = -8
		quest_offered_sound.play()
func _play_quest_accepted_sound():
	if quest_accepted_sound:
		quest_accepted_sound.pitch_scale = randf_range(1.0, 1.2)
		quest_accepted_sound.volume_db = -6
		quest_accepted_sound.play()
func _play_quest_completed_sound():
	if quest_completed_sound:
		quest_completed_sound.pitch_scale = 1.0
		quest_completed_sound.volume_db = -4
		quest_completed_sound.play()
func _play_reward_received_sound(reward_type: String):
	if reward_received_sound:
		var pitch = 1.0
		match reward_type:
			"medkit":
				pitch = 0.8
			"attack_boost":
				pitch = 1.2
			"speed_boost":
				pitch = 1.1
			"sonar_boost":
				pitch = 0.9
			"rune_duration":
				pitch = 1.0
		reward_received_sound.pitch_scale = pitch
		reward_received_sound.volume_db = -5
		reward_received_sound.play()
func get_quest_save_data() -> Dictionary:
	var save_data = {
		"last_quest_level": last_quest_level,
		"enemies_killed": enemies_killed_this_session,
		"runes_collected": runes_collected_this_session,
		"survival_timer": survival_timer,
		"active_quests": [],
		"completed_quests": []
	}
	for quest in active_quests:
		save_data.active_quests.append({
			"id": quest.id,
			"type": quest.type,
			"target": quest.target,
			"progress": quest.progress,
			"reward_type": quest.reward_type,
			"reward_amount": quest.reward_amount,
			"level_assigned": quest.level_assigned
		})
	return save_data
func load_quest_save_data(data: Dictionary):
	if data.has("last_quest_level"):
		last_quest_level = data.last_quest_level
	if data.has("enemies_killed"):
		enemies_killed_this_session = data.enemies_killed
	if data.has("runes_collected"):
		runes_collected_this_session = data.runes_collected
	if data.has("survival_timer"):
		survival_timer = data.survival_timer
	if data.has("active_quests"):
		active_quests.clear()
		for quest_data in data.active_quests:
			var quest = QuestData.new(quest_data.type, quest_data.target, quest_data.reward_type, quest_data.reward_amount, quest_data.level_assigned)
			quest.id = quest_data.id
			quest.progress = quest_data.progress
			quest.status = QuestData.Status.ACTIVE
			quest.description = _generate_quest_description(quest)
			active_quests.append(quest)
func _setup_dialogue():
	dialogue_player = AudioStreamPlayer.new()
	add_child(dialogue_player)
	dialogue_player.volume_db = -5
func _play_quest_dialogue():
	if dialogue_played:
		return
	var audio_path = "res://assets/dialogue/quests.mp3"
	if ResourceLoader.exists(audio_path):
		var audio_stream = load(audio_path)
		dialogue_player.stream = audio_stream
		dialogue_player.play()
		dialogue_played = true
