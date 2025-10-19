extends CanvasLayer
class_name BossUI

var boss: Boss
var health_bar_container: Control
var health_bar_background: ColorRect
var health_bar_fill: ColorRect
var boss_name_label: Label
var health_percentage_label: Label
var phase_indicators: Array[ColorRect] = []

var is_visible: bool = false
var fill_tween: Tween

const SCARY_FONT = preload("res://assets/fonts/October Crow.ttf")

func _ready():
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_for_boss(target_boss: Boss):
	boss = target_boss
	_create_health_bar_ui()

func _create_health_bar_ui():
	health_bar_container = Control.new()
	health_bar_container.name = "BossHealthBarContainer"
	health_bar_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	health_bar_container.anchor_left = 0.0
	health_bar_container.anchor_right = 1.0
	health_bar_container.anchor_top = 0.0
	health_bar_container.offset_top = 20
	health_bar_container.offset_bottom = 100
	health_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar_container.visible = false
	add_child(health_bar_container)

	var outer_border = ColorRect.new()
	outer_border.anchor_left = 0.05
	outer_border.anchor_right = 0.95
	outer_border.offset_top = 10
	outer_border.offset_bottom = 70
	outer_border.color = Color(0.8, 0.1, 0.1, 0.9)
	health_bar_container.add_child(outer_border)

	health_bar_background = ColorRect.new()
	health_bar_background.anchor_left = 0.05
	health_bar_background.anchor_right = 0.95
	health_bar_background.offset_left = 5
	health_bar_background.offset_right = -5
	health_bar_background.offset_top = 15
	health_bar_background.offset_bottom = 65
	health_bar_background.color = Color(0.1, 0.05, 0.05, 0.95)
	health_bar_container.add_child(health_bar_background)

	health_bar_fill = ColorRect.new()
	health_bar_fill.anchor_left = 0.05
	health_bar_fill.anchor_right = 0.95
	health_bar_fill.offset_left = 10
	health_bar_fill.offset_right = -10
	health_bar_fill.offset_top = 20
	health_bar_fill.offset_bottom = 60
	health_bar_fill.color = _get_boss_color()
	health_bar_container.add_child(health_bar_fill)

	boss_name_label = Label.new()
	boss_name_label.text = boss.boss_name
	boss_name_label.anchor_left = 0.06
	boss_name_label.anchor_top = 0.3
	boss_name_label.offset_bottom = 35
	boss_name_label.offset_right = 400
	boss_name_label.add_theme_font_override("font", SCARY_FONT)
	boss_name_label.add_theme_font_size_override("font_size", 24)
	boss_name_label.add_theme_color_override("font_color", Color.WHITE)
	boss_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	boss_name_label.add_theme_constant_override("shadow_offset_x", 3)
	boss_name_label.add_theme_constant_override("shadow_offset_y", 3)
	boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_bar_container.add_child(boss_name_label)

	health_percentage_label = Label.new()
	health_percentage_label.text = "100%"
	health_percentage_label.anchor_left = 0.74
	health_percentage_label.anchor_right = 0.94
	health_percentage_label.anchor_top = 0.3
	health_percentage_label.offset_bottom = 35
	health_percentage_label.add_theme_font_override("font", SCARY_FONT)
	health_percentage_label.add_theme_font_size_override("font_size", 20)
	health_percentage_label.add_theme_color_override("font_color", Color.WHITE)
	health_percentage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	health_percentage_label.add_theme_constant_override("shadow_offset_x", 2)
	health_percentage_label.add_theme_constant_override("shadow_offset_y", 2)
	health_percentage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_percentage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	health_bar_container.add_child(health_percentage_label)

	_create_phase_indicators()

func _create_phase_indicators():
	var indicator_positions = [0.75, 0.5, 0.25]

	for i in range(indicator_positions.size()):
		var phase_line = ColorRect.new()
		var anchor_pos = 0.05 + (0.9 * indicator_positions[i])
		phase_line.anchor_left = anchor_pos
		phase_line.anchor_right = anchor_pos
		phase_line.offset_left = -1
		phase_line.offset_right = 1
		phase_line.offset_top = 15
		phase_line.offset_bottom = 65
		phase_line.color = Color(1.0, 1.0, 1.0, 0.6)
		health_bar_container.add_child(phase_line)
		phase_indicators.append(phase_line)

func _get_boss_color() -> Color:
	match boss.boss_type:
		Boss.BossType.DREAD:
			return Color(0.6, 0.2, 0.8, 0.9)
		Boss.BossType.WRAITH:
			return Color(0.4, 0.7, 1.0, 0.9)
		Boss.BossType.SENTINEL:
			return Color(0.8, 0.6, 0.2, 0.9)
		Boss.BossType.LORD_OF_DARKNESS:
			return Color(0.9, 0.1, 0.1, 0.9)
		_:
			return Color(0.7, 0.3, 0.3, 0.9)

func show_health_bar():
	if is_visible:
		return

	is_visible = true
	health_bar_container.visible = true

	var slide_tween = create_tween()
	health_bar_container.position.y = -80
	slide_tween.tween_property(health_bar_container, "position:y", 20, 1.0)

	_animate_health_fill_initial()

func hide_health_bar():
	if not is_visible:
		return

	is_visible = false
	var hide_tween = create_tween()
	hide_tween.tween_property(health_bar_container, "modulate:a", 0.0, 1.0)
	hide_tween.tween_callback(func(): health_bar_container.visible = false)

func update_health_bar(current_health: int, max_health: int):
	if not is_visible:
		return

	var health_percentage = float(current_health) / float(max_health)
	var target_anchor = 0.05 + (0.9 * health_percentage)

	if fill_tween:
		fill_tween.kill()

	fill_tween = create_tween()
	fill_tween.tween_property(health_bar_fill, "anchor_right", target_anchor, 0.3)

	health_percentage_label.text = str(int(health_percentage * 100)) + "%"

	_update_health_color(health_percentage)

func _animate_health_fill_initial():
	health_bar_fill.anchor_right = 0.05

	var initial_tween = create_tween()
	initial_tween.tween_property(health_bar_fill, "anchor_right", 0.95, 1.5)

func _update_health_color(health_percentage: float):
	var base_color = _get_boss_color()
	var damage_color = Color.RED

	if health_percentage > 0.5:
		health_bar_fill.color = base_color
	elif health_percentage > 0.25:
		var mix_factor = (0.5 - health_percentage) / 0.25
		health_bar_fill.color = base_color.lerp(damage_color, mix_factor * 0.5)
	else:
		var mix_factor = (0.25 - health_percentage) / 0.25
		health_bar_fill.color = damage_color.lerp(Color(1.0, 0.3, 0.3), mix_factor)

		if health_percentage < 0.1:
			_create_critical_health_effect()

func _create_critical_health_effect():
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(health_bar_fill, "color", Color(1.0, 0.6, 0.6), 0.3)
	pulse_tween.tween_property(health_bar_fill, "color", Color(1.0, 0.1, 0.1), 0.3)

func flash_damage():
	var flash_overlay = ColorRect.new()
	flash_overlay.position = Vector2(110, 20)
	flash_overlay.size = Vector2(1700, 40)
	flash_overlay.color = Color(1.0, 0.8, 0.8, 0.8)
	health_bar_container.add_child(flash_overlay)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash_overlay, "modulate:a", 0.0, 0.2)
	flash_tween.tween_callback(func(): flash_overlay.queue_free())
