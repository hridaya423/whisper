extends Node
class_name ParrySystem

signal parry_started
signal parry_window_ended(success: bool)
signal parry_success
signal parry_failed

@export var parry_window_duration: float = 0.3
@export var failure_cooldown: float = 0.5

var parry_active: bool = false
var parry_on_cooldown: bool = false

var _window_timer: Timer
var _cooldown_timer: Timer

func _ready():
	_window_timer = Timer.new()
	_window_timer.one_shot = true
	_window_timer.timeout.connect(_on_parry_window_timeout)
	add_child(_window_timer)

	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

func can_start_parry() -> bool:
	return not parry_active and not parry_on_cooldown

func start_parry() -> bool:
	if not can_start_parry():
		return false

	parry_active = true
	_window_timer.stop()
	_window_timer.wait_time = parry_window_duration
	_window_timer.start()
	parry_started.emit()
	return true

func try_parry_hit() -> bool:
	if not parry_active:
		return false

	parry_active = false
	if not _window_timer.is_stopped():
		_window_timer.stop()
	parry_success.emit()
	parry_window_ended.emit(true)
	return true

func force_end_parry(success: bool):
	if not parry_active:
		return
	parry_active = false
	if not _window_timer.is_stopped():
		_window_timer.stop()
	parry_window_ended.emit(success)

func is_on_cooldown() -> bool:
	return parry_on_cooldown

func _on_parry_window_timeout():
	if not parry_active:
		return

	parry_active = false
	parry_on_cooldown = true
	_cooldown_timer.stop()
	_cooldown_timer.wait_time = failure_cooldown
	_cooldown_timer.start()
	parry_failed.emit()
	parry_window_ended.emit(false)

func _on_cooldown_timeout():
	parry_on_cooldown = false
