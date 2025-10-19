extends Control
class_name QuestUI
const SCARY_FONT = preload("res://assets/fonts/October Crow.ttf")
const READABLE_FONT = preload("res://assets/fonts/Federant-Regular.ttf")
const QuestData = preload("res://scripts/quests/QuestData.gd")
const COLOR_BACKGROUND = Color(0.02, 0.02, 0.02, 0.95)
const COLOR_BORDER = Color(0.6, 0.1, 0.1, 0.8)
const COLOR_TITLE = Color(0.9, 0.1, 0.1, 1.0)
const COLOR_TEXT = Color(0.8, 0.8, 0.8)
const COLOR_REWARD = Color(0.8, 0.8, 0.3)
const COLOR_PENALTY = Color(0.8, 0.4, 0.1)
const COLOR_DEATH_QUEST = Color(0.9, 0.0, 0.0, 1.0)
var quest_system: QuestSystem
var quest_panel: Panel
var quest_list: VBoxContainer
var close_button: Button
var active_quest_container: VBoxContainer
var quest_containers: Dictionary = {}
var is_showing: bool = false
var available_quests: Array[QuestData] = []
var _player_node: Node = null
var _ui_layer_node: Node = null
var _cached_tree_paused: bool = false
var _cached_process_mode: int = Node.PROCESS_MODE_INHERIT
var _cached_ui_process_mode: int = Node.PROCESS_MODE_INHERIT
var _cached_player_process: bool = true
var _cached_player_physics: bool = true
var _player_state_cached: bool = false
var _gameplay_frozen: bool = false
signal quest_selected(quest: QuestData)
signal quest_ui_closed()
func _ready():
	visible = true
	is_showing = false
	_setup_improved_ui()
	_setup_active_quest_display()
	hide_quest_panel()
	_ui_layer_node = _find_ui_layer()
	set_process(true)
func set_quest_system_reference(qs: QuestSystem):
	quest_system = qs
	if quest_system and quest_system.has_signal("quest_offered"):
		quest_system.quest_offered.connect(_on_quests_offered)
		quest_system.quest_accepted.connect(_on_quest_accepted_for_display)
		quest_system.quest_completed.connect(_on_quest_completed_for_display)
		quest_system.quest_failed.connect(_on_quest_failed_for_display)
		quest_system.quest_progress_updated.connect(_on_quest_progress_updated_for_display)

func update_level_display(level: int):
	var level_ui_layer = get_node_or_null("LevelUILayer")
	if level_ui_layer:
		var level_display = level_ui_layer.get_node_or_null("LevelDisplay")
		if level_display:
			level_display.text = "LEVEL " + str(level)
func _setup_improved_ui():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quest_panel = Panel.new()
	quest_panel.position = Vector2(200, 100)
	quest_panel.size = Vector2(800, 600)
	quest_panel.add_theme_stylebox_override("panel", _create_panel_style())
	add_child(quest_panel)
	var title = Label.new()
	title.text = "THE VOID BECKONS..."
	title.position = Vector2(20, 20)
	title.size = Vector2(760, 60)
	title.add_theme_font_override("font", SCARY_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_panel.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "Choose your burden, or walk away unshackled..."
	subtitle.position = Vector2(20, 80)
	subtitle.size = Vector2(760, 20)
	subtitle.add_theme_font_override("font", SCARY_FONT)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_panel.add_child(subtitle)
	var warning = Label.new()
	warning.text = "⚠ WARNING: You may not see another offer for a long time..."
	warning.position = Vector2(20, 105)
	warning.size = Vector2(760, 15)
	warning.add_theme_font_override("font", SCARY_FONT)
	warning.add_theme_font_size_override("font_size", 12)
	warning.add_theme_color_override("font_color", Color(0.8, 0.4, 0.1, 0.8))
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_panel.add_child(warning)
	var scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(20, 125)
	scroll_container.size = Vector2(760, 375)
	quest_panel.add_child(scroll_container)
	quest_list = VBoxContainer.new()
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_list.add_theme_constant_override("separation", 15)
	scroll_container.add_child(quest_list)
	close_button = Button.new()
	close_button.text = "IGNORE THE CALL"
	close_button.position = Vector2(300, 510)
	close_button.size = Vector2(200, 50)
	close_button.add_theme_font_override("font", SCARY_FONT)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", COLOR_TEXT)
	close_button.add_theme_color_override("font_hover_color", COLOR_TITLE)
	close_button.add_theme_color_override("font_shadow_color", Color.BLACK)
	close_button.add_theme_constant_override("shadow_offset_x", 2)
	close_button.add_theme_constant_override("shadow_offset_y", 2)
	close_button.pressed.connect(_on_close_button_pressed)
	quest_panel.add_child(close_button)
func _setup_active_quest_display():
	var level_ui_layer = CanvasLayer.new()
	level_ui_layer.layer = 10
	level_ui_layer.name = "LevelUILayer"
	add_child(level_ui_layer)

	var level_display = Label.new()
	level_display.text = "LEVEL 1"
	level_display.name = "LevelDisplay"
	level_display.position = Vector2(20, 20)
	level_display.size = Vector2(200, 30)
	level_display.add_theme_font_override("font", SCARY_FONT)
	level_display.add_theme_font_size_override("font_size", 18)
	level_display.add_theme_color_override("font_color", Color(0.9, 0.6, 0.1))
	level_display.add_theme_color_override("font_shadow_color", Color.BLACK)
	level_display.add_theme_constant_override("shadow_offset_x", 2)
	level_display.add_theme_constant_override("shadow_offset_y", 2)
	level_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_ui_layer.add_child(level_display)

	active_quest_container = VBoxContainer.new()
	active_quest_container.name = "ActiveQuestContainer"
	active_quest_container.position = Vector2(20, 200)
	active_quest_container.size = Vector2(380, 250)
	active_quest_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active_quest_container.add_theme_constant_override("separation", 12)
	active_quest_container.visible = false
	add_child(active_quest_container)
	var debug_bg = ColorRect.new()
	debug_bg.color = Color(0.5, 0.1, 0.1, 0.8)
	debug_bg.position = Vector2(-8, -8)
	debug_bg.size = Vector2(396, 266)
	active_quest_container.add_child(debug_bg)
	var title_label = Label.new()
	title_label.text = "ACTIVE QUESTS"
	title_label.add_theme_font_override("font", SCARY_FONT)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_quest_container.add_child(title_label)
func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BACKGROUND
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = COLOR_BORDER
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 15
	style.shadow_offset = Vector2(0, 8)
	return style
func _style_button(button: Button):
	button.add_theme_font_override("font", SCARY_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_TITLE)
	button.add_theme_color_override("font_shadow_color", Color.BLACK)
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
func _on_quests_offered(quests):
	available_quests.clear()
	for quest in quests:
		available_quests.append(quest)
	show_quest_panel()
func _find_ui_layer() -> Node:
	var parent_node = get_parent()
	if parent_node:
		return parent_node
	if get_tree() and get_tree().current_scene:
		return get_tree().current_scene.get_node_or_null("CanvasLayer")
	return null
func _get_player() -> Node:
	if _player_node and is_instance_valid(_player_node):
		return _player_node
	var player_group = get_tree().get_nodes_in_group("player")
	if player_group.size() > 0:
		_player_node = player_group[0]
		return _player_node
	if get_tree().current_scene:
		var candidate = get_tree().current_scene.get_node_or_null("Player")
		if candidate:
			_player_node = candidate
	return _player_node
func _freeze_gameplay():
	if _gameplay_frozen:
		return
	_gameplay_frozen = true
	_cached_tree_paused = get_tree().paused
	_cached_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ui_layer = _find_ui_layer()
	if ui_layer and is_instance_valid(ui_layer):
		_ui_layer_node = ui_layer
		_cached_ui_process_mode = ui_layer.process_mode
		ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	else:
		_ui_layer_node = null
	var player_ref = _get_player()
	if player_ref and is_instance_valid(player_ref):
		_cached_player_physics = player_ref.is_physics_processing()
		_cached_player_process = player_ref.is_processing()
		player_ref.set_physics_process(false)
		player_ref.set_process(false)
		_player_state_cached = true
	else:
		_player_state_cached = false
	get_tree().paused = true
func _resume_gameplay():
	if not _gameplay_frozen:
		return
	_gameplay_frozen = false
	get_tree().paused = _cached_tree_paused
	process_mode = _cached_process_mode
	if _ui_layer_node and is_instance_valid(_ui_layer_node):
		_ui_layer_node.process_mode = _cached_ui_process_mode
	if _player_state_cached:
		var player_ref = _get_player()
		if player_ref and is_instance_valid(player_ref):
			player_ref.set_physics_process(_cached_player_physics)
			player_ref.set_process(_cached_player_process)
		_player_state_cached = false
func _populate_quest_list():
	for child in quest_list.get_children():
		child.queue_free()
	for i in range(available_quests.size()):
		var quest = available_quests[i]
		var quest_panel = _create_quest_panel(quest)
		quest_list.add_child(quest_panel)
func show_quest_panel():
	if is_showing:
		return
	is_showing = true
	visible = true
	quest_panel.visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_populate_quest_list()
	_freeze_gameplay()
func hide_quest_panel():
	if not quest_panel:
		return
	if not is_showing:
		quest_panel.visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _gameplay_frozen:
			_resume_gameplay()
		return
	is_showing = false
	quest_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resume_gameplay()
func _on_quest_accepted(quest: QuestData):
	if quest_system and quest_system.accept_quest(quest):
		quest_selected.emit(quest)
		available_quests.erase(quest)
		_populate_quest_list()
		if available_quests.size() == 0 or quest_system.get_active_quests().size() >= quest_system.max_active_quests:
			hide_quest_panel()
func _on_close_button_pressed():
	quest_ui_closed.emit()
	hide_quest_panel()
func _create_quest_panel(quest: QuestData) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(740, 120)
	panel.add_theme_stylebox_override("panel", _create_quest_panel_style())
	var content = VBoxContainer.new()
	content.position = Vector2(15, 10)
	content.size = Vector2(710, 100)
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var title_container = HBoxContainer.new()
	content.add_child(title_container)
	var quest_type = Label.new()
	quest_type.text = _get_quest_type_name(quest.type)
	quest_type.add_theme_font_override("font", SCARY_FONT)
	quest_type.add_theme_font_size_override("font_size", 16)
	quest_type.add_theme_color_override("font_color", COLOR_TITLE)
	title_container.add_child(quest_type)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_container.add_child(spacer)
	if quest.is_death_quest:
		var death_label = Label.new()
		death_label.text = "💀 DEATH QUEST"
		death_label.add_theme_font_override("font", SCARY_FONT)
		death_label.add_theme_font_size_override("font_size", 14)
		death_label.add_theme_color_override("font_color", COLOR_DEATH_QUEST)
		title_container.add_child(death_label)
	var desc = Label.new()
	desc.text = quest.description.split("\n")[0]
	desc.add_theme_font_override("font", READABLE_FONT)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(desc)
	var info_container = HBoxContainer.new()
	content.add_child(info_container)
	var reward_label = Label.new()
	reward_label.text = "REWARD: " + _get_reward_description(quest.reward_type, quest.reward_amount)
	reward_label.add_theme_font_override("font", READABLE_FONT)
	reward_label.add_theme_font_size_override("font_size", 12)
	reward_label.add_theme_color_override("font_color", COLOR_REWARD)
	reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_container.add_child(reward_label)
	if quest.has_penalty:
		var penalty_label = Label.new()
		penalty_label.text = "⚠ " + quest.penalty_description
		penalty_label.add_theme_font_override("font", READABLE_FONT)
		penalty_label.add_theme_font_size_override("font_size", 11)
		penalty_label.add_theme_color_override("font_color", COLOR_PENALTY)
		info_container.add_child(penalty_label)
	var accept_button = Button.new()
	accept_button.text = "ACCEPT"
	accept_button.position = Vector2(650, 85)
	accept_button.size = Vector2(80, 30)
	accept_button.add_theme_font_override("font", SCARY_FONT)
	accept_button.add_theme_font_size_override("font_size", 12)
	accept_button.add_theme_color_override("font_color", COLOR_TEXT)
	accept_button.add_theme_color_override("font_hover_color", COLOR_REWARD)
	accept_button.pressed.connect(_on_quest_accepted.bind(quest))
	panel.add_child(accept_button)
	return panel
func _create_quest_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.6)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style
func _get_quest_type_name(quest_type: int) -> String:
	match quest_type:
		0: return "ELIMINATION"
		1: return "COLLECTION"
		2: return "SURVIVAL"
		3: return "EXPLORATION"
		_: return "UNKNOWN"
func _get_reward_description(reward_type: String, amount: int) -> String:
	match reward_type:
		"medkit": return str(amount) + " Medkit" + ("s" if amount > 1 else "")
		"rune_duration": return "Rune Duration +" + str(amount) + "s"
		"attack_boost": return "Attack Boost +" + str(amount) + "s"
		"speed_boost": return "Speed Boost +" + str(amount) + "s"
		"sonar_boost": return "Sonar Boost +" + str(amount) + "s"
		_: return "Unknown Reward"
func _on_quest_accepted_for_display(quest):
	_add_active_quest_display(quest)
func _on_quest_completed_for_display(quest):
	_remove_active_quest_display(quest)
func _on_quest_failed_for_display(quest):
	_remove_active_quest_display(quest)
func _on_quest_progress_updated_for_display(quest):
	_update_active_quest_display(quest)
func _add_active_quest_display(quest):
	if quest.id in quest_containers:
		return
	var quest_panel = _create_active_quest_panel(quest)
	active_quest_container.add_child(quest_panel)
	quest_containers[quest.id] = quest_panel
	active_quest_container.visible = true
func _remove_active_quest_display(quest):
	if quest.id in quest_containers:
		var quest_panel = quest_containers[quest.id]
		quest_containers.erase(quest.id)
		quest_panel.queue_free()
		if quest_containers.size() == 0:
			active_quest_container.visible = false
func _create_active_quest_panel(quest) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(380, 120)
	panel.add_theme_stylebox_override("panel", _create_active_panel_style())

	var desc = Label.new()
	desc.text = quest.description.split("\n")[0]
	desc.position = Vector2(12, 8)
	desc.size = Vector2(356, 20)
	desc.add_theme_font_override("font", READABLE_FONT)
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc)

	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.position = Vector2(12, 32)
	progress_bar.size = Vector2(280, 18)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = quest.get_progress_percentage() * 100
	progress_bar.add_theme_stylebox_override("background", _create_progress_bg_style())
	progress_bar.add_theme_stylebox_override("fill", _create_progress_fill_style(quest))
	panel.add_child(progress_bar)

	var progress_text = Label.new()
	progress_text.name = "ProgressText"
	progress_text.text = str(quest.progress) + " / " + str(quest.target)
	progress_text.position = Vector2(300, 30)
	progress_text.size = Vector2(68, 18)
	progress_text.add_theme_font_override("font", READABLE_FONT)
	progress_text.add_theme_font_size_override("font_size", 11)
	progress_text.add_theme_color_override("font_color", COLOR_REWARD)
	progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(progress_text)

	var reward_label = Label.new()
	reward_label.name = "RewardLabel"
	reward_label.text = "🏆 " + _get_reward_description(quest.reward_type, quest.reward_amount)
	reward_label.position = Vector2(12, 56)
	reward_label.size = Vector2(356, 16)
	reward_label.add_theme_font_override("font", READABLE_FONT)
	reward_label.add_theme_font_size_override("font_size", 10)
	reward_label.add_theme_color_override("font_color", COLOR_REWARD)
	panel.add_child(reward_label)

	if quest.is_death_quest:
		var timer_label = Label.new()
		timer_label.name = "TimerLabel"
		timer_label.text = "⏰ " + _format_time(quest.time_remaining)
		timer_label.position = Vector2(12, 76)
		timer_label.size = Vector2(200, 16)
		timer_label.add_theme_font_override("font", READABLE_FONT)
		timer_label.add_theme_font_size_override("font_size", 10)
		timer_label.add_theme_color_override("font_color", COLOR_DEATH_QUEST)
		panel.add_child(timer_label) 

	if quest.has_penalty:
		var penalty_label = Label.new()
		penalty_label.name = "PenaltyLabel"
		penalty_label.text = "⚠ " + quest.penalty_description
		penalty_label.position = Vector2(12, (96 if quest.is_death_quest else 76))
		penalty_label.size = Vector2(356, 16)
		penalty_label.add_theme_font_override("font", READABLE_FONT)
		penalty_label.add_theme_font_size_override("font_size", 10)
		penalty_label.add_theme_color_override("font_color", COLOR_PENALTY)
		panel.add_child(penalty_label)

	return panel
func _create_active_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.02, 0.02, 0.95)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color.RED
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
func _update_active_quest_display(quest):
	if not quest.id in quest_containers:
		return
	var quest_panel = quest_containers[quest.id]
	var progress_bar = quest_panel.get_node("ProgressBar")
	if progress_bar:
		progress_bar.value = quest.get_progress_percentage() * 100
	var progress_text = quest_panel.get_node("ProgressText")
	if progress_text:
		progress_text.text = str(quest.progress) + " / " + str(quest.target)
	if quest.is_death_quest:
		var timer_label = quest_panel.get_node_or_null("TimerLabel")
		if timer_label:
			timer_label.text = "⏰ " + _format_time(quest.time_remaining)
func _format_time(seconds: float) -> String:
	var minutes = int(seconds) / 60
	var secs = int(seconds) % 60
	return "%02d:%02d" % [minutes, secs]
func _process(delta):
	if quest_system:
		for quest in quest_system.get_active_quests():
			if quest.is_death_quest:
				_update_active_quest_display(quest)
func _create_progress_bg_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.1, 0.1, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 0)
	return style
func _create_progress_fill_style(quest = null) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if quest and quest.is_death_quest:
		style.bg_color = Color(0.9, 0.2, 0.1, 0.95)
	elif quest and quest.has_penalty:
		style.bg_color = Color(0.8, 0.4, 0.1, 0.9)
	else:
		style.bg_color = Color(0.2, 0.6, 0.3, 0.9)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.shadow_color = style.bg_color
	style.shadow_color.a = 0.5
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 0)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(style.bg_color.r * 1.2, style.bg_color.g * 1.2, style.bg_color.b * 1.2, 0.8)
	return style
func _input(event):
	if not is_showing:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close_button_pressed()
