extends Node
class_name RewardSystem
enum BoostType {
	ATTACK_BOOST,
	SPEED_BOOST,
	SONAR_BOOST,
	RUNE_DURATION_BOOST
}
class ActiveBoost:
	var type: BoostType
	var duration: float
	var remaining_time: float
	var strength: float
	func _init(boost_type: BoostType, boost_duration: float, boost_strength: float = 1.0):
		type = boost_type
		duration = boost_duration
		remaining_time = boost_duration
		strength = boost_strength
	func update(delta: float) -> bool:
		remaining_time -= delta
		return remaining_time > 0
	func get_progress() -> float:
		return remaining_time / duration if duration > 0 else 0.0
var active_boosts: Array[ActiveBoost] = []
var player: Node
var medkit_system: Node
var rune_system: Node
var quest_system: Node
var current_attack_multiplier: float = 1.0
var current_speed_multiplier: float = 1.0
var current_sonar_range_multiplier: float = 1.0
var rune_duration_bonus: float = 0.0
var boost_ui_container: Control
var boost_icons: Array[Control] = []
signal reward_given(reward_type: String, amount: int)
signal boost_activated(boost_type: BoostType, duration: float)
signal boost_expired(boost_type: BoostType)
signal boost_updated(boost_type: BoostType, remaining_time: float)
func _ready():
	_setup_references()
	_setup_boost_ui()
	set_process(true)
func _setup_references():
	player = get_tree().get_first_node_in_group("player")
	rune_system = _find_node_by_name(get_tree().current_scene, "RuneSystem")
	quest_system = _find_node_by_name(get_tree().current_scene, "QuestSystem")
	if quest_system:
		quest_system.reward_system = self
func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	return null
func _setup_boost_ui():
	if not player:
		return
	boost_ui_container = Control.new()
	boost_ui_container.name = "BoostUIContainer"
	boost_ui_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	boost_ui_container.position = Vector2(-200, 20)
	boost_ui_container.size = Vector2(180, 200)
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer:
		ui_layer.add_child(boost_ui_container)
func _process(delta):
	_update_active_boosts(delta)
	_update_boost_ui()
func _update_active_boosts(delta: float):
	var expired_boosts = []
	for boost in active_boosts:
		if not boost.update(delta):
			expired_boosts.append(boost)
		else:
			boost_updated.emit(boost.type, boost.remaining_time)
	for expired_boost in expired_boosts:
		_remove_boost(expired_boost)
	_recalculate_multipliers()
func _remove_boost(boost: ActiveBoost):
	active_boosts.erase(boost)
	boost_expired.emit(boost.type)
func _recalculate_multipliers():
	current_attack_multiplier = 1.0
	current_speed_multiplier = 1.0
	current_sonar_range_multiplier = 1.0
	rune_duration_bonus = 0.0
	for boost in active_boosts:
		match boost.type:
			BoostType.ATTACK_BOOST:
				current_attack_multiplier *= (1.0 + boost.strength)
			BoostType.SPEED_BOOST:
				current_speed_multiplier *= (1.0 + boost.strength)
			BoostType.SONAR_BOOST:
				current_sonar_range_multiplier *= (1.0 + boost.strength)
			BoostType.RUNE_DURATION_BOOST:
				rune_duration_bonus += boost.strength
func give_reward(reward_type: String, amount: int):
	match reward_type:
		"medkit":
			_give_medkit_reward(amount)
		"rune_duration":
			_give_rune_duration_boost(amount)
		"attack_boost":
			_give_attack_boost(amount)
		"speed_boost":
			_give_speed_boost(amount)
		"sonar_boost":
			_give_sonar_boost(amount)
	reward_given.emit(reward_type, amount)
	_show_reward_notification(reward_type, amount)
func _give_medkit_reward(amount: int):
	if not medkit_system:
		medkit_system = _find_node_by_name(get_tree().current_scene, "MedkitSystem")
	if medkit_system and medkit_system.has_method("add_medkits"):
		medkit_system.add_medkits(amount)
	else:
		if player and player.has_method("heal"):
			player.heal(amount * 2)
func _give_rune_duration_boost(duration_bonus: float):
	var boost = ActiveBoost.new(BoostType.RUNE_DURATION_BOOST, 300.0, duration_bonus)
	_add_boost(boost)
	if rune_system and rune_system.has_method("extend_active_rune_duration"):
		rune_system.extend_active_rune_duration(duration_bonus)
func _give_attack_boost(duration: float):
	var boost = ActiveBoost.new(BoostType.ATTACK_BOOST, duration, 0.5)
	_add_boost(boost)
func _give_speed_boost(duration: float):
	var boost = ActiveBoost.new(BoostType.SPEED_BOOST, duration, 0.25)
	_add_boost(boost)
func _give_sonar_boost(duration: float):
	var boost = ActiveBoost.new(BoostType.SONAR_BOOST, duration, 0.3)
	_add_boost(boost)
func _add_boost(boost: ActiveBoost):
	var existing_boost = null
	for active_boost in active_boosts:
		if active_boost.type == boost.type:
			existing_boost = active_boost
			break
	if existing_boost:
		if boost.duration > existing_boost.remaining_time:
			existing_boost.remaining_time = boost.duration
			existing_boost.duration = boost.duration
			existing_boost.strength = max(existing_boost.strength, boost.strength)
	else:
		active_boosts.append(boost)
	boost_activated.emit(boost.type, boost.duration)
func _show_reward_notification(reward_type: String, amount: int):
	if not player:
		return
	var notification = _create_reward_notification(reward_type, amount)
	var ui_layer = player.get_node_or_null("health_ui_layer")
	if ui_layer:
		ui_layer.add_child(notification)
		_animate_notification(notification)
func _create_reward_notification(reward_type: String, amount: int) -> Control:
	var notification = Control.new()
	notification.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	notification.position = Vector2(-150, -100)
	notification.size = Vector2(300, 80)
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.9)
	bg.size = notification.size
	notification.add_child(bg)
	var border = ColorRect.new()
	border.color = Color(0.8, 0.2, 0.2, 0.8)
	border.position = Vector2(-2, -2)
	border.size = Vector2(304, 84)
	notification.add_child(border)
	notification.move_child(border, 0)
	var title_label = Label.new()
	title_label.text = "REWARD RECEIVED"
	title_label.position = Vector2(10, 5)
	title_label.size = Vector2(280, 25)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 1)
	title_label.add_theme_constant_override("shadow_offset_y", 1)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.add_child(title_label)
	var desc_label = Label.new()
	desc_label.text = _get_reward_description(reward_type, amount)
	desc_label.position = Vector2(10, 30)
	desc_label.size = Vector2(280, 40)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	desc_label.add_theme_constant_override("shadow_offset_x", 1)
	desc_label.add_theme_constant_override("shadow_offset_y", 1)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	notification.add_child(desc_label)
	return notification
func _get_reward_description(reward_type: String, amount: int) -> String:
	match reward_type:
		"medkit":
			return str(amount) + " Healing Kit" + ("s" if amount > 1 else "") + " Received"
		"rune_duration":
			return "Rune Duration +" + str(amount) + " seconds"
		"attack_boost":
			return "Attack Power +50% for " + str(amount) + "s"
		"speed_boost":
			return "Movement Speed +25% for " + str(amount) + "s"
		"sonar_boost":
			return "Sonar Range +30% for " + str(amount) + "s"
		_:
			return "Unknown Reward"
func _animate_notification(notification: Control):
	notification.modulate = Color(1, 1, 1, 0)
	notification.scale = Vector2(0.3, 0.3)
	var tween = notification.create_tween()
	tween.set_parallel(true)
	tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	tween.tween_property(notification, "scale", Vector2(1.0, 1.0), 0.3)
	await tween.tween_interval(3.0)
	tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	await tween.finished
	notification.queue_free()
func _update_boost_ui():
	if not boost_ui_container:
		return
	for icon in boost_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	boost_icons.clear()
	var y_offset = 0
	for boost in active_boosts:
		var icon = _create_boost_icon(boost)
		icon.position = Vector2(0, y_offset)
		boost_ui_container.add_child(icon)
		boost_icons.append(icon)
		y_offset += 45
func _create_boost_icon(boost: ActiveBoost) -> Control:
	var icon_container = Control.new()
	icon_container.size = Vector2(180, 40)
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.8)
	bg.size = icon_container.size
	icon_container.add_child(bg)
	var progress_bg = ColorRect.new()
	progress_bg.color = Color(0.3, 0.3, 0.3, 0.6)
	progress_bg.position = Vector2(5, 25)
	progress_bg.size = Vector2(170, 10)
	icon_container.add_child(progress_bg)
	var progress_fill = ColorRect.new()
	progress_fill.color = _get_boost_color(boost.type)
	progress_fill.position = Vector2(5, 25)
	var progress = boost.get_progress()
	progress_fill.size = Vector2(170 * progress, 10)
	icon_container.add_child(progress_fill)
	var name_label = Label.new()
	name_label.text = _get_boost_name(boost.type)
	name_label.position = Vector2(5, 2)
	name_label.size = Vector2(120, 20)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	icon_container.add_child(name_label)
	var time_label = Label.new()
	time_label.text = str(int(boost.remaining_time)) + "s"
	time_label.position = Vector2(130, 2)
	time_label.size = Vector2(45, 20)
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.add_theme_color_override("font_color", _get_boost_color(boost.type))
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	icon_container.add_child(time_label)
	return icon_container
func _get_boost_name(boost_type: BoostType) -> String:
	match boost_type:
		BoostType.ATTACK_BOOST:
			return "ATTACK BOOST"
		BoostType.SPEED_BOOST:
			return "SPEED BOOST"
		BoostType.SONAR_BOOST:
			return "SONAR BOOST"
		BoostType.RUNE_DURATION_BOOST:
			return "RUNE BOOST"
		_:
			return "UNKNOWN"
func _get_boost_color(boost_type: BoostType) -> Color:
	match boost_type:
		BoostType.ATTACK_BOOST:
			return Color(1.0, 0.3, 0.3)
		BoostType.SPEED_BOOST:
			return Color(0.3, 1.0, 0.3)
		BoostType.SONAR_BOOST:
			return Color(0.3, 0.3, 1.0)
		BoostType.RUNE_DURATION_BOOST:
			return Color(1.0, 0.8, 0.3)
		_:
			return Color.WHITE
func get_attack_multiplier() -> float:
	return current_attack_multiplier
func get_speed_multiplier() -> float:
	return current_speed_multiplier
func get_sonar_range_multiplier() -> float:
	return current_sonar_range_multiplier
func get_rune_duration_bonus() -> float:
	return rune_duration_bonus
func has_boost(boost_type: BoostType) -> bool:
	for boost in active_boosts:
		if boost.type == boost_type:
			return true
	return false
func get_boost_remaining_time(boost_type: BoostType) -> float:
	for boost in active_boosts:
		if boost.type == boost_type:
			return boost.remaining_time
	return 0.0
func get_boost_save_data() -> Dictionary:
	var save_data = {
		"active_boosts": []
	}
	for boost in active_boosts:
		save_data.active_boosts.append({
			"type": boost.type,
			"duration": boost.duration,
			"remaining_time": boost.remaining_time,
			"strength": boost.strength
		})
	return save_data
func load_boost_save_data(data: Dictionary):
	if data.has("active_boosts"):
		active_boosts.clear()
		for boost_data in data.active_boosts:
			var boost = ActiveBoost.new(boost_data.type, boost_data.duration, boost_data.strength)
			boost.remaining_time = boost_data.remaining_time
			active_boosts.append(boost)
