extends Node2D
class_name DamageNumber

const NORMAL_COLOR := Color(1, 1, 1, 1)
const CRITICAL_COLOR := Color(1, 0.9, 0.3, 1)
const BOSS_COLOR := Color(1, 0.25, 0.25, 1)
const DAMAGE_FONT := preload("res://assets/fonts/October Crow.ttf")

@export var float_duration: float = 0.8
@export var float_offset: Vector2 = Vector2(0, -30)
@export var base_font_size: int = 18
@export var max_font_size: int = 36
@export var font_growth_per_point: float = 0.6
@export var random_spawn_offset: Vector2 = Vector2(8, 4)

var _label: Label
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready():
	_rng.randomize()

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", base_font_size)
	if DAMAGE_FONT:
		_label.add_theme_font_override("font", DAMAGE_FONT)
	add_child(_label)

	self.modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE

func show_damage(amount: float, world_position: Vector2, config: Dictionary = {}):
	var text_override: String = config.get("text", "")
	var is_critical: bool = config.get("is_critical", false)
	var is_boss: bool = config.get("is_boss", false)
	var custom_color: Color = config.get("color", Color.TRANSPARENT)

	var display_text := text_override if text_override != "" else _format_amount(amount, config)
	_label.text = display_text

	var color := _resolve_color(custom_color, is_boss, is_critical, config)
	_label.modulate = color

	var font_size := _calculate_font_size(amount, config)
	_label.add_theme_font_size_override("font_size", font_size)

	var minimum_size := _label.get_minimum_size()
	_label.size = minimum_size
	_label.position = -minimum_size * 0.5

	var offset := Vector2(
		_rng.randf_range(-random_spawn_offset.x, random_spawn_offset.x),
		_rng.randf_range(-random_spawn_offset.y, random_spawn_offset.y)
	)
	global_position = world_position + offset
	scale = Vector2.ONE
	self.modulate = Color(1, 1, 1, 1)

	_play_float_animation()

func _play_float_animation():
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", global_position + float_offset, float_duration)
	tween.parallel().tween_property(self, "modulate:a", 0.0, float_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(self, "scale", Vector2.ONE * 1.15, min(float_duration * 0.45, 0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)

func _resolve_color(custom_color: Color, is_boss: bool, is_critical: bool, config: Dictionary) -> Color:
	if custom_color.a > 0.0:
		return custom_color
	if config.get("is_weakpoint", false) or is_critical:
		return CRITICAL_COLOR
	if is_boss:
		return BOSS_COLOR
	return NORMAL_COLOR

func _calculate_font_size(amount: float, config: Dictionary) -> int:
	if config.has("font_size"):
		return int(config["font_size"])
	var magnitude: float = absf(amount)
	var size := base_font_size + int(ceil(magnitude * font_growth_per_point))
	return clampi(size, base_font_size, max_font_size)

func _format_amount(amount: float, config: Dictionary) -> String:
	if config.has("text_prefix") or config.has("text_suffix"):
		var prefix := str(config.get("text_prefix", ""))
		var suffix := str(config.get("text_suffix", ""))
		return prefix + str(roundi(amount)) + suffix
	return str(roundi(amount))
