extends Node
const SETTINGS_FILE_PATH = "user://settings.cfg"
const SECTION_AUDIO = "audio"
const SECTION_DISPLAY = "display"
const SECTION_GAMEPLAY = "gameplay"
const SECTION_CONTROLS = "controls"
var key_actions: Array = []
var settings = {}
signal fps_visibility_changed(visible: bool)
func _init() -> void:
	key_actions = _build_key_actions()
func _ready() -> void:
	_load_defaults()
	_load_from_disk()
	_apply_all()
func get_setting(section: String, key: String, default_value = null):
	if settings.has(section) and settings[section].has(key):
		return settings[section][key]
	return default_value
func set_setting(section: String, key: String, value, apply: bool = true) -> void:
	if not settings.has(section):
		settings[section] = {}
	settings[section][key] = value
	_save()
	if apply:
		_apply_setting(section, key)
func reset_to_defaults() -> void:
	_load_defaults(true)
	_save()
	_apply_all()
func reset_control_defaults() -> void:
	settings[SECTION_CONTROLS] = {}
	ensure_actions_registered()
	_save()
func get_key_actions() -> Array:
	return key_actions.duplicate(true)
func get_binding_for_action(action: String) -> InputEvent:
	var stored = settings.get(SECTION_CONTROLS, {}).get(action, null)
	if stored == null:
		return _get_action_definition(action).get("primary_default")
	return _deserialize_event(stored)
func set_binding_for_action(action: String, event: InputEvent) -> void:
	var definition = _get_action_definition(action)
	if definition.is_empty():
		return
	_clear_action_events(action)
	InputMap.action_add_event(action, event)
	for extra in definition.get("secondary_defaults", []):
		InputMap.action_add_event(action, extra)
	if not settings.has(SECTION_CONTROLS):
		settings[SECTION_CONTROLS] = {}
	settings[SECTION_CONTROLS][action] = _serialize_event(event)
	_save()
func ensure_actions_registered() -> void:
	var control_settings = settings.get(SECTION_CONTROLS, {})
	for definition in key_actions:
		var action = definition.get("action", "")
		if action == "":
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_clear_action_events(action)
		var stored = control_settings.get(action, null)
		var primary_event: InputEvent
		if stored == null:
			primary_event = definition.get("primary_default")
		else:
			primary_event = _deserialize_event(stored)
		InputMap.action_add_event(action, primary_event)
		for extra in definition.get("secondary_defaults", []):
			InputMap.action_add_event(action, extra)
func apply_audio_settings() -> void:
	var master = float(get_setting(SECTION_AUDIO, "master_volume", 50.0))
	var linear = clamp(master, 0.0, 100.0) / 100.0
	var db_value = -80.0
	if linear > 0.0:
		db_value = linear_to_db(linear)
	var master_index = AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, db_value)
func apply_display_settings() -> void:
	var vsync_enabled = bool(get_setting(SECTION_DISPLAY, "vsync", true))
	var fullscreen = bool(get_setting(SECTION_DISPLAY, "fullscreen", false))
	var vsync_mode = DisplayServer.VSYNC_DISABLED
	if vsync_enabled:
		vsync_mode = DisplayServer.VSYNC_ENABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	var window_mode = DisplayServer.WINDOW_MODE_WINDOWED
	if fullscreen:
		window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(window_mode)
	var show_fps = bool(get_setting(SECTION_DISPLAY, "show_fps", false))
	emit_signal("fps_visibility_changed", show_fps)
func apply_gameplay_settings() -> void:
	pass
func apply_control_settings() -> void:
	ensure_actions_registered()
func format_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.physical_keycode != Key.KEY_NONE:
			return OS.get_keycode_string(key_event.physical_keycode)
		return OS.get_keycode_string(key_event.keycode)
	elif event is InputEventMouseButton:
		var button = (event as InputEventMouseButton).button_index
		if button == MOUSE_BUTTON_LEFT:
			return "MOUSE LMB"
		elif button == MOUSE_BUTTON_RIGHT:
			return "MOUSE RMB"
		elif button == MOUSE_BUTTON_MIDDLE:
			return "MOUSE MMB"
		return "MOUSE %d" % button
	elif event is InputEventJoypadButton:
		return "JOYPAD %d" % (event as InputEventJoypadButton).button_index
	return "UNBOUND"
func _apply_setting(section: String, key: String) -> void:
	match section:
		SECTION_AUDIO:
			apply_audio_settings()
		SECTION_DISPLAY:
			apply_display_settings()
		SECTION_GAMEPLAY:
			apply_gameplay_settings()
		SECTION_CONTROLS:
			apply_control_settings()
func _apply_all() -> void:
	apply_audio_settings()
	apply_display_settings()
	apply_gameplay_settings()
	apply_control_settings()
func _load_defaults(force: bool = false) -> void:
	if force or settings.is_empty():
		settings = {
			SECTION_AUDIO: {
				"master_volume": 50.0,
			},
			SECTION_DISPLAY: {
				"vsync": true,
				"show_fps": false,
				"fullscreen": false,
			},
			SECTION_GAMEPLAY: {
				"screen_shake_intensity": 1.0,
				"mouse_sensitivity": 1.0,
			},
			SECTION_CONTROLS: {},
		}
func _load_from_disk() -> void:
	var file = ConfigFile.new()
	if file.load(SETTINGS_FILE_PATH) != OK:
		return
	for section in settings.keys():
		for key in settings[section].keys():
			if file.has_section_key(section, key):
				settings[section][key] = file.get_value(section, key, settings[section][key])
	for definition in key_actions:
		var action = definition.get("action", "")
		if action != "" and file.has_section_key(SECTION_CONTROLS, action):
			settings[SECTION_CONTROLS][action] = file.get_value(SECTION_CONTROLS, action)
func _save() -> void:
	var file = ConfigFile.new()
	file.load(SETTINGS_FILE_PATH)
	for section in settings.keys():
		for key in settings[section].keys():
			file.set_value(section, key, settings[section][key])
	file.save(SETTINGS_FILE_PATH)
func _build_key_actions() -> Array:
	return [
		{
			"action": "move_left",
			"label": "MOVE LEFT",
			"primary_default": _event_key(Key.KEY_A),
			"secondary_defaults": [_event_key(Key.KEY_LEFT)],
		},
		{
			"action": "move_right",
			"label": "MOVE RIGHT",
			"primary_default": _event_key(Key.KEY_D),
			"secondary_defaults": [_event_key(Key.KEY_RIGHT)],
		},
		{
			"action": "jump",
			"label": "JUMP",
			"primary_default": _event_key(Key.KEY_SPACE),
			"secondary_defaults": [_event_key(Key.KEY_W)],
		},
		{
			"action": "sonar",
			"label": "SONAR PULSE",
			"primary_default": _event_key(Key.KEY_E),
			"secondary_defaults": [_event_key(Key.KEY_ENTER), _event_mouse_button(MOUSE_BUTTON_LEFT)],
		},
		{
			"action": "attack",
			"label": "ATTACK",
			"primary_default": _event_key(Key.KEY_Q),
			"secondary_defaults": [],
		},
		{
			"action": "interact",
			"label": "INTERACT",
			"primary_default": _event_key(Key.KEY_G),
			"secondary_defaults": [_event_key(Key.KEY_F)],
		},
		{
			"action": "slot_1",
			"label": "SWAP TO SLOT 1",
			"primary_default": _event_physical_key(Key.KEY_1),
			"secondary_defaults": [],
		},
		{
			"action": "slot_2",
			"label": "SWAP TO SLOT 2",
			"primary_default": _event_physical_key(Key.KEY_2),
			"secondary_defaults": [],
		},
		{
			"action": "slot_3",
			"label": "SWAP TO SLOT 3",
			"primary_default": _event_physical_key(Key.KEY_3),
			"secondary_defaults": [],
		},
	]
static func _event_key(keycode: Key) -> InputEventKey:
	var event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	return event
static func _event_physical_key(keycode: Key) -> InputEventKey:
	var event = InputEventKey.new()
	event.physical_keycode = keycode
	return event
static func _event_mouse_button(button_index: int) -> InputEventMouseButton:
	var event = InputEventMouseButton.new()
	event.button_index = button_index
	return event
func _get_action_definition(action: String) -> Dictionary:
	for definition in key_actions:
		if definition.get("action", "") == action:
			return definition
	return {}
func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
		}
	elif event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": event.button_index,
		}
	elif event is InputEventJoypadButton:
		return {
			"type": "joypad_button",
			"button_index": event.button_index,
		}
	return {}
func _deserialize_event(data: Dictionary) -> InputEvent:
	var event: InputEvent
	var type = data.get("type", "key")
	match type:
		"key":
			event = InputEventKey.new()
			event.keycode = int(data.get("keycode", 0))
			event.physical_keycode = int(data.get("physical_keycode", 0))
		"mouse_button":
			event = InputEventMouseButton.new()
			event.button_index = int(data.get("button_index", MOUSE_BUTTON_LEFT))
		"joypad_button":
			event = InputEventJoypadButton.new()
			event.button_index = int(data.get("button_index", 0))
		_:
			event = InputEventKey.new()
	return event
func _clear_action_events(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, existing)
