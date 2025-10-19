extends Control
const BUTTON_FONT_SIZE = 22
const BUTTON_MIN_WIDTH = 300
const BUTTON_MIN_HEIGHT = 55
const SLIDER_MIN_WIDTH = 360
const SLIDER_MIN_HEIGHT = 30
const COLOR_NORMAL = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_HOVER = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_PRESSED = Color(0.8, 0.1, 0.1, 1.0)
const COLOR_ACTIVE_FONT = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_ACTIVE_HOVER = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_ACTIVE_PRESSED = Color(1.0, 1.0, 1.0, 1.0)
const TOGGLE_ACTIVE_MODULATE = Color(1.05, 0.75, 0.75, 1.0)
const MAIN_MENU_SCENE = "res://scenes/ui/MainMenu.tscn"
const SCARY_FONT = preload("res://assets/fonts/October Crow.ttf")
var transitioning = false
var volume_slider: HSlider
var volume_value_label: Label
var vsync_toggle: CheckButton
var show_fps_toggle: CheckButton
var fullscreen_toggle: CheckButton
var display_toggles: Array = []
var shake_slider: HSlider
var shake_value_label: Label
var sensitivity_slider: HSlider
var sensitivity_value_label: Label
var controls_columns: HBoxContainer
var control_columns: Array = []
var reset_bindings_button: Button
var action_buttons = {}
var pending_action = ""
var listening_button: Button = null
func _ready() -> void:
	SettingsManager.ensure_actions_registered()
	setup_controls_tab()
	style_all_buttons(self)
	style_all_sliders(self)
	setup_audio_controls()
	setup_display_controls()
	setup_gameplay_controls()
	setup_tab_titles()
	style_tab_bar()
	connect_misc_logic()
	connect_button_logic()
	set_process_unhandled_input(false)
func setup_tab_titles() -> void:
	var tabs = find_child("TabContainer") as TabContainer
	if not tabs:
		return
	for index in range(tabs.get_tab_count()):
		var title = tabs.get_tab_title(index)
		tabs.set_tab_title(index, title.to_upper())
func style_tab_bar() -> void:
	var tabs = find_child("TabContainer") as TabContainer
	if not tabs:
		return
	var tab_bar = tabs.get_tab_bar()
	if tab_bar:
		tab_bar.add_theme_font_override("font", SCARY_FONT)
		tab_bar.add_theme_font_size_override("font_size", 20)
func setup_audio_controls() -> void:
	volume_slider = find_child("VolumeSlider") as HSlider
	volume_value_label = find_child("VolumeValue") as Label
	if volume_value_label:
		volume_value_label.add_theme_font_override("font", SCARY_FONT)
	var value = float(SettingsManager.get_setting(SettingsManager.SECTION_AUDIO, "master_volume", 50.0))
	if volume_slider:
		volume_slider.value = value
		_update_volume_value_label(value)
		if not volume_slider.value_changed.is_connected(_on_volume_changed):
			volume_slider.value_changed.connect(_on_volume_changed)
		_setup_slider_feedback(volume_slider)
func setup_display_controls() -> void:
	vsync_toggle = find_child("VSyncToggle") as CheckButton
	show_fps_toggle = find_child("ShowFpsToggle") as CheckButton
	fullscreen_toggle = find_child("FullscreenToggle") as CheckButton
	display_toggles.clear()
	if vsync_toggle:
		vsync_toggle.button_pressed = bool(SettingsManager.get_setting(SettingsManager.SECTION_DISPLAY, "vsync", true))
		if not vsync_toggle.toggled.is_connected(_on_vsync_toggled):
			vsync_toggle.toggled.connect(_on_vsync_toggled)
		_register_display_toggle(vsync_toggle)
	if show_fps_toggle:
		show_fps_toggle.button_pressed = bool(SettingsManager.get_setting(SettingsManager.SECTION_DISPLAY, "show_fps", false))
		if not show_fps_toggle.toggled.is_connected(_on_show_fps_toggled):
			show_fps_toggle.toggled.connect(_on_show_fps_toggled)
		_register_display_toggle(show_fps_toggle)
	if fullscreen_toggle:
		fullscreen_toggle.button_pressed = bool(SettingsManager.get_setting(SettingsManager.SECTION_DISPLAY, "fullscreen", false))
		if not fullscreen_toggle.toggled.is_connected(_on_fullscreen_toggled):
			fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
		_register_display_toggle(fullscreen_toggle)
func setup_gameplay_controls() -> void:
	shake_slider = find_child("ShakeSlider") as HSlider
	shake_value_label = find_child("ShakeValue") as Label
	sensitivity_slider = find_child("SensitivitySlider") as HSlider
	sensitivity_value_label = find_child("SensitivityValue") as Label
	if shake_value_label:
		shake_value_label.add_theme_font_override("font", SCARY_FONT)
	if sensitivity_value_label:
		sensitivity_value_label.add_theme_font_override("font", SCARY_FONT)
	var shake_strength = float(SettingsManager.get_setting(SettingsManager.SECTION_GAMEPLAY, "screen_shake_intensity", 1.0))
	var sensitivity = float(SettingsManager.get_setting(SettingsManager.SECTION_GAMEPLAY, "mouse_sensitivity", 1.0))
	if shake_slider:
		shake_slider.value = clamp(shake_strength, 0.0, 2.0) * 100.0
		_update_shake_value_label(shake_slider.value)
		if not shake_slider.value_changed.is_connected(_on_shake_changed):
			shake_slider.value_changed.connect(_on_shake_changed)
		_setup_slider_feedback(shake_slider)
	if sensitivity_slider:
		sensitivity_slider.value = clamp(sensitivity, sensitivity_slider.min_value, sensitivity_slider.max_value)
		_update_sensitivity_value_label(sensitivity_slider.value)
		if not sensitivity_slider.value_changed.is_connected(_on_sensitivity_changed):
			sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
		_setup_slider_feedback(sensitivity_slider)
func connect_misc_logic() -> void:
	reset_bindings_button = find_child("ResetBindings") as Button
	if reset_bindings_button and not reset_bindings_button.pressed.is_connected(_on_reset_bindings_pressed):
		reset_bindings_button.pressed.connect(_on_reset_bindings_pressed.bind(reset_bindings_button))
func setup_controls_tab() -> void:
	controls_columns = find_child("ControlsColumns") as HBoxContainer
	control_columns.clear()
	action_buttons.clear()
	if controls_columns:
		for child in controls_columns.get_children():
			if child is VBoxContainer:
				control_columns.append(child)
				for grandchild in child.get_children():
					grandchild.queue_free()
	if control_columns.is_empty():
		return
	var definitions = SettingsManager.get_key_actions()
	var total = definitions.size()
	if total == 0:
		return
	var left_count = int((total + 1) / 2)
	var column_totals = [left_count, total - left_count]
	var column_filled = [0, 0]
	for index in range(total):
		var definition = definitions[index]
		var action = String(definition.get("action", ""))
		if action.is_empty():
			continue
		var column_index = 0 if index < left_count else 1
		column_index = min(column_index, control_columns.size() - 1)
		var column = control_columns[column_index] as VBoxContainer
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label = Label.new()
		label.text = String(definition.get("label", action.to_upper())).to_upper()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_override("font", SCARY_FONT)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", COLOR_NORMAL)
		row.add_child(label)
		var button = Button.new()
		button.focus_mode = Control.FOCUS_ALL
		button.toggle_mode = false
		button.custom_minimum_size = Vector2(220, BUTTON_MIN_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		row.add_child(button)
		var binding_event = SettingsManager.get_binding_for_action(action)
		var display_text = SettingsManager.format_event(binding_event)
		_set_button_display(button, display_text)
		button.pressed.connect(_on_binding_button_pressed.bind(action, button))
		column.add_child(row)
		action_buttons[action] = button
		column_filled[column_index] += 1
		if column_filled[column_index] < column_totals[column_index]:
			var separator = HSeparator.new()
			separator.modulate = Color(0.3, 0.3, 0.3, 0.35)
			separator.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			column.add_child(separator)
func _on_binding_button_pressed(action: String, button: Button) -> void:
	if transitioning:
		return
	if pending_action != "":
		_cancel_binding_listen()
	pending_action = action
	listening_button = button
	_set_button_display(button, "PRESS SOMETHING")
	button.add_theme_color_override("font_color", Color(1, 0.6, 0.6, 1))
	set_process_unhandled_input(true)
func _on_reset_bindings_pressed(button: Button) -> void:
	if transitioning:
		return
	if pending_action != "":
		_cancel_binding_listen()
	SettingsManager.reset_control_defaults()
	for action in action_buttons.keys():
		var event = SettingsManager.get_binding_for_action(action)
		_set_button_display(action_buttons[action], SettingsManager.format_event(event))
func _on_volume_changed(value: float) -> void:
	_update_volume_value_label(value)
	SettingsManager.set_setting(SettingsManager.SECTION_AUDIO, "master_volume", value)
func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.set_setting(SettingsManager.SECTION_DISPLAY, "vsync", pressed)
	_refresh_toggle_state(vsync_toggle)
func _on_show_fps_toggled(pressed: bool) -> void:
	SettingsManager.set_setting(SettingsManager.SECTION_DISPLAY, "show_fps", pressed)
	_refresh_toggle_state(show_fps_toggle)
func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_setting(SettingsManager.SECTION_DISPLAY, "fullscreen", pressed)
	_refresh_toggle_state(fullscreen_toggle)
func _on_shake_changed(value: float) -> void:
	_update_shake_value_label(value)
	SettingsManager.set_setting(SettingsManager.SECTION_GAMEPLAY, "screen_shake_intensity", value / 100.0)
func _on_sensitivity_changed(value: float) -> void:
	_update_sensitivity_value_label(value)
	SettingsManager.set_setting(SettingsManager.SECTION_GAMEPLAY, "mouse_sensitivity", value)
func _setup_slider_feedback(slider: HSlider) -> void:
	if not slider:
		return
	if not slider.drag_started.is_connected(_on_slider_drag_started):
		slider.drag_started.connect(_on_slider_drag_started.bind(slider))
	if not slider.drag_ended.is_connected(_on_slider_drag_ended):
		slider.drag_ended.connect(_on_slider_drag_ended.bind(slider))
func _register_display_toggle(button: Button) -> void:
	if not button:
		return
	if display_toggles.find(button) == -1:
		display_toggles.append(button)
	button.add_theme_font_override("font", SCARY_FONT)
	button.add_theme_font_size_override("font_size", 18)
	_refresh_toggle_state(button)
func _refresh_toggle_state(button: Button) -> void:
	if not button:
		return
	var active = button.button_pressed
	var base_color = COLOR_ACTIVE_FONT if active else COLOR_NORMAL
	var hover_color = COLOR_ACTIVE_HOVER if active else COLOR_HOVER
	var pressed_color = COLOR_ACTIVE_PRESSED if active else COLOR_PRESSED
	button.add_theme_color_override("font_color", base_color)
	button.add_theme_color_override("font_hover_color", hover_color)
	button.add_theme_color_override("font_focus_color", hover_color)
	button.add_theme_color_override("font_pressed_color", pressed_color)
	button.modulate = TOGGLE_ACTIVE_MODULATE if active else Color(1, 1, 1, 1)
func _update_volume_value_label(value: float) -> void:
	if volume_value_label:
		volume_value_label.text = "%d%%" % int(round(value))
func _update_shake_value_label(value: float) -> void:
	if shake_value_label:
		shake_value_label.text = "%d%%" % int(round(value))
func _update_sensitivity_value_label(value: float) -> void:
	if sensitivity_value_label:
		sensitivity_value_label.text = str("%.2f" % value).to_upper() + "X"
func _set_button_display(button: Button, text: String) -> void:
	if not button:
		return
	var display = text.to_upper()
	button.text = display
	button.set_meta("original_text", display)
func _cancel_binding_listen() -> void:
	if listening_button:
		listening_button.remove_theme_color_override("font_color")
		var current_event = SettingsManager.get_binding_for_action(pending_action) if pending_action in action_buttons else null
		if current_event:
			_set_button_display(listening_button, SettingsManager.format_event(current_event))
	pending_action = ""
	listening_button = null
	set_process_unhandled_input(false)
func _finish_binding(event: InputEvent) -> void:
	if pending_action == "" or not listening_button:
		return
	SettingsManager.set_binding_for_action(pending_action, event)
	_set_button_display(listening_button, SettingsManager.format_event(event))
	listening_button.remove_theme_color_override("font_color")
	pending_action = ""
	listening_button = null
	set_process_unhandled_input(false)
func _unhandled_input(event: InputEvent) -> void:
	if pending_action == "":
		return
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if key_event.keycode == Key.KEY_ESCAPE or key_event.physical_keycode == Key.KEY_ESCAPE:
			_cancel_binding_listen()
			get_viewport().set_input_as_handled()
			return
		_finish_binding(key_event)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if not mouse_event.pressed:
			return
		_finish_binding(mouse_event)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if not joy_event.pressed:
			return
		_finish_binding(joy_event)
		get_viewport().set_input_as_handled()
func _on_slider_drag_started(slider: HSlider) -> void:
	if transitioning or not slider:
		return
	var tween = create_tween()
	tween.tween_property(slider, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.1)
func _on_slider_drag_ended(value_changed: bool, slider: HSlider) -> void:
	if not slider:
		return
	var tween = create_tween()
	tween.tween_property(slider, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
func style_all_buttons(node: Node):
	for child in node.get_children():
		if child is Button:
			style_single_button(child)
		if child.get_child_count() > 0:
			style_all_buttons(child)
func style_all_sliders(node: Node):
	for child in node.get_children():
		if child is HSlider:
			style_single_slider(child)
		if child.get_child_count() > 0:
			style_all_sliders(child)
func style_single_button(button: Button):
	var default_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_MIN_HEIGHT)
	if button is CheckButton:
		default_size = Vector2(220, BUTTON_MIN_HEIGHT * 0.75)
	if button.custom_minimum_size == Vector2.ZERO:
		button.custom_minimum_size = default_size
	button.add_theme_font_override("font", SCARY_FONT)
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.add_theme_color_override("font_color", COLOR_NORMAL)
	button.add_theme_color_override("font_hover_color", COLOR_HOVER)
	button.add_theme_color_override("font_pressed_color", COLOR_PRESSED)
	button.add_theme_color_override("font_focus_color", Color(0.9, 0.9, 0.9, 0.9))
	button.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	button.add_theme_constant_override("shadow_offset_x", 2)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_stylebox_override("normal", create_button_normal_stylebox())
	button.add_theme_stylebox_override("hover", create_button_hover_stylebox())
	button.add_theme_stylebox_override("pressed", create_button_pressed_stylebox())
	button.add_theme_stylebox_override("focus", create_button_focus_stylebox())
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = button.text.to_upper()
	button.set_meta("original_text", button.text)
	button.set_meta("is_hovering", false)
	setup_button_animations(button)
func style_single_slider(slider: HSlider):
	slider.custom_minimum_size = Vector2(SLIDER_MIN_WIDTH, SLIDER_MIN_HEIGHT)
	slider.add_theme_stylebox_override("slider", create_slider_track_stylebox())
	slider.add_theme_stylebox_override("grabber", create_slider_grabber_stylebox())
	slider.add_theme_stylebox_override("grabber_highlight", create_slider_grabber_highlight_stylebox())
	slider.add_theme_stylebox_override("grabber_area", create_slider_fill_stylebox())
	slider.add_theme_stylebox_override("grabber_area_highlight", create_slider_fill_highlight_stylebox())
	setup_slider_animations(slider)
func create_slider_track_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style
func create_slider_fill_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.1, 0.1, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.2, 0.2, 0.6)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	return style
func create_slider_fill_highlight_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.15, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.3, 0.3, 0.8)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	style.shadow_color = Color(0.8, 0.2, 0.2, 0.3)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 0)
	return style
func create_slider_grabber_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5, 0.7)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	return style
func create_slider_grabber_highlight_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.4, 0.4, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 1.0, 1.0, 0.8)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.shadow_color = Color(1.0, 1.0, 1.0, 0.3)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 0)
	return style
func create_button_normal_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.border_width_left = 2
	style.border_color = Color(0.3, 0.3, 0.3, 0.3)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style
func create_button_hover_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_width_left = 3
	style.border_width_right = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.4)
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_left = 2
	style.shadow_color = Color(1.0, 1.0, 1.0, 0.15)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 0)
	style.content_margin_left = 35
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style
func create_button_pressed_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.05, 0.05, 0.4)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.8, 0.2, 0.2, 0.8)
	style.content_margin_left = 32
	style.content_margin_right = 28
	style.content_margin_top = 17
	style.content_margin_bottom = 13
	return style
func create_button_focus_stylebox() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 2
	style.border_color = Color(0.5, 0.5, 0.5, 0.2)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style
func setup_button_animations(button: Button):
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover.bind(button))
	if not button.mouse_exited.is_connected(_on_button_unhover):
		button.mouse_exited.connect(_on_button_unhover.bind(button))
func setup_slider_animations(slider: HSlider):
	if not slider.mouse_entered.is_connected(_on_slider_hover):
		slider.mouse_entered.connect(_on_slider_hover.bind(slider))
	if not slider.mouse_exited.is_connected(_on_slider_unhover):
		slider.mouse_exited.connect(_on_slider_unhover.bind(slider))
func _on_button_hover(button: Button):
	if transitioning:
		return
	button.set_meta("is_hovering", true)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.2)
	start_glitch_effect(button)
func _on_button_unhover(button: Button):
	if transitioning:
		return
	button.set_meta("is_hovering", false)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)
	stop_glitch_effect(button)
func _on_slider_hover(slider: HSlider):
	if transitioning:
		return
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_loops()
	tween.tween_property(slider, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.8)
	tween.tween_property(slider, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)
	slider.set_meta("hover_tween", tween)
func _on_slider_unhover(slider: HSlider):
	if transitioning:
		return
	if slider.has_meta("hover_tween"):
		var tween = slider.get_meta("hover_tween")
		if tween:
			tween.kill()
	var tween = create_tween()
	tween.tween_property(slider, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.2)
func start_glitch_effect(button: Button):
	if transitioning:
		return
	var timer = Timer.new()
	timer.wait_time = 0.1
	timer.timeout.connect(_glitch_text.bind(button, timer))
	button.add_child(timer)
	timer.start()
	button.set_meta("glitch_timer_node", timer)
func stop_glitch_effect(button: Button):
	if button.has_meta("glitch_timer_node"):
		var timer = button.get_meta("glitch_timer_node")
		if timer and is_instance_valid(timer):
			timer.queue_free()
	if button.has_meta("original_text"):
		button.text = button.get_meta("original_text")
func _glitch_text(button: Button, timer: Timer):
	if transitioning or not button.get_meta("is_hovering"):
		timer.queue_free()
		button.text = button.get_meta("original_text")
		return
	var original = button.get_meta("original_text")
	var glitched = ""
	for i in range(original.length()):
		if randf() < 0.05:
			glitched += char(randi_range(65, 90))
		else:
			glitched += original[i]
	button.text = glitched
func connect_button_logic():
	var back_button = find_button_by_text("GO BACK")
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed.bind(back_button))
func _on_back_pressed(button: Button):
	if transitioning:
		return
	transitioning = true
	play_click_animation_and_transition(button, MAIN_MENU_SCENE)
func play_click_animation_and_transition(button: Button, scene_path: String):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	var original_pos = button.position
	for i in range(5):
		tween.tween_property(button, "position", original_pos + Vector2(randf_range(-8, 8), randf_range(-3, 3)), 0.05)
	tween.tween_property(button, "position", original_pos, 0.05)
	tween.parallel().tween_property(button, "modulate", Color(2, 0.5, 0.5, 1), 0.1)
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.4)
	tween.parallel().tween_property(button, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.4)
	await get_tree().create_timer(0.15).timeout
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = get_viewport().size
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fade)
	move_child(fade, get_child_count() - 1)
	var fade_tween = create_tween()
	fade_tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.3)
	await fade_tween.finished
	get_tree().change_scene_to_file(scene_path)
func find_button_by_text(text: String) -> Button:
	return find_button_recursive(self, text.to_upper())
func find_button_recursive(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.to_upper() == text:
			return child
		var result = find_button_recursive(child, text)
		if result:
			return result
	return null
