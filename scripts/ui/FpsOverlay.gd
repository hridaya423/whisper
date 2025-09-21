extends CanvasLayer

var fps_label: Label

func _ready() -> void:
	layer = 100
	set_process(true)
	var container = MarginContainer.new()

	container.anchor_left = 1.0
	container.anchor_right = 1.0
	container.anchor_top = 0.0
	container.anchor_bottom = 0.0
	container.offset_left = -220
	container.offset_right = -20
	container.offset_top = 20
	container.offset_bottom = 20
	container.add_theme_constant_override("margin_left", 0)
	container.add_theme_constant_override("margin_right", 0)
	container.add_theme_constant_override("margin_top", 0)
	container.add_theme_constant_override("margin_bottom", 0)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	fps_label = Label.new()
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.add_theme_font_size_override("font_size", 22)
	fps_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.9))
	fps_label.text = "FPS: --"
	container.add_child(fps_label)

	var fps_callable = Callable(self, "_on_fps_visibility_changed")
	if not SettingsManager.is_connected("fps_visibility_changed", fps_callable):
		SettingsManager.connect("fps_visibility_changed", fps_callable)

	visible = bool(SettingsManager.get_setting(SettingsManager.SECTION_DISPLAY, "show_fps", false))
	_update_fps_label()

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_fps_label()

func _update_fps_label() -> void:
	if not fps_label:
		return
	var fps = int(round(Engine.get_frames_per_second()))
	fps_label.text = "%d FPS" % max(fps, 0)

func _on_fps_visibility_changed(visible_now: bool) -> void:
	visible = visible_now
	if visible:
		_update_fps_label()


