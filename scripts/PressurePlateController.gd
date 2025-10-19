extends Node2D

signal sequence_completed
signal sequence_failed
signal sequence_reset

@export_group("Sequence Settings")
@export var require_order: bool = true
@export var allow_mistakes: bool = false
@export var reset_on_mistake: bool = true
@export var completion_delay: float = 0.3

@export_group("Feedback")
@export var show_success_particles: bool = true
@export var show_failure_effect: bool = true

@export_group("Connected Nodes")
@export var success_nodes: Array[NodePath] = []
@export var failure_nodes: Array[NodePath] = []

var _plates: Array[PressurePlate] = []
var _current_step: int = 0
var _is_complete: bool = false
var _completion_timer: float = 0.0

func _ready() -> void:
	call_deferred("_setup_plates")

func _setup_plates() -> void:
	_plates.clear()
	var plate_nodes: Array[Node] = get_tree().get_nodes_in_group("pressure_plates")

	for node in plate_nodes:
		if node is PressurePlate:
			var plate: PressurePlate = node as PressurePlate
			_plates.append(plate)
			plate.activated.connect(_on_plate_activated.bind(plate))
			plate.deactivated.connect(_on_plate_deactivated.bind(plate))

	_plates.sort_custom(_sort_by_sequence_number)

	if _plates.size() > 0:
		print("PressurePlateController: Found %d plates" % _plates.size())
	else:
		push_warning("PressurePlateController: No pressure plates found in scene!")

func _sort_by_sequence_number(a: PressurePlate, b: PressurePlate) -> bool:
	return a.get_sequence_number() < b.get_sequence_number()

func _process(delta: float) -> void:
	if _is_complete:
		_completion_timer += delta
		if _completion_timer >= max(completion_delay, 0.0):
			_trigger_completion()

func _on_plate_activated(plate: PressurePlate) -> void:
	if _is_complete:
		return

	var plate_sequence: int = plate.get_sequence_number()

	if require_order:
		var expected_sequence: int = _current_step + 1
		if plate_sequence == expected_sequence:
			_current_step += 1
			_check_completion()
		else:
			_handle_mistake(plate)
	else:
		if not plate.is_pressed():
			return
		_check_completion()

func _on_plate_deactivated(plate: PressurePlate) -> void:
	if _is_complete:
		return

	if not require_order:
		_current_step = 0
		_is_complete = false

func _check_completion() -> void:
	if require_order:
		if _current_step >= _plates.size():
			_complete_sequence()
	else:
		var all_pressed: bool = true
		for plate in _plates:
			if not plate.is_pressed():
				all_pressed = false
				break
		if all_pressed:
			_complete_sequence()

func _complete_sequence() -> void:
	if _is_complete:
		return

	_is_complete = true
	_completion_timer = 0.0

	if show_success_particles:
		_spawn_success_particles()

func _trigger_completion() -> void:
	sequence_completed.emit()
	_activate_success_nodes()

	print("PressurePlateController: Sequence completed!")

func _handle_mistake(plate: PressurePlate) -> void:
	if allow_mistakes:
		return

	sequence_failed.emit()
	_activate_failure_nodes()

	if show_failure_effect:
		_spawn_failure_effect(plate)

	if reset_on_mistake:
		reset_sequence()

	print("PressurePlateController: Wrong plate activated! Expected %d, got %d" % [_current_step + 1, plate.get_sequence_number()])

func reset_sequence() -> void:
	_current_step = 0
	_is_complete = false
	_completion_timer = 0.0

	for plate in _plates:
		if not plate.stays_pressed:
			plate.reset()

	sequence_reset.emit()
	print("PressurePlateController: Sequence reset")

func _activate_success_nodes() -> void:
	for path in success_nodes:
		var node: Node = get_node_or_null(path)
		if node and node.has_method("activate"):
			node.activate()
		elif node and node.has_method("open"):
			node.open()
		elif node and node.has_method("disable"):
			node.disable()

func _activate_failure_nodes() -> void:
	for path in failure_nodes:
		var node: Node = get_node_or_null(path)
		if node and node.has_method("activate"):
			node.activate()
		elif node and node.has_method("spawn"):
			node.spawn()

func _spawn_success_particles() -> void:
	for plate in _plates:
		var particles: CPUParticles2D = CPUParticles2D.new()
		plate.add_child(particles)

		particles.emitting = true
		particles.one_shot = true
		particles.amount = 20
		particles.lifetime = 1.0
		particles.explosiveness = 0.8

		particles.direction = Vector2(0, -1)
		particles.spread = 45.0
		particles.initial_velocity_min = 80.0
		particles.initial_velocity_max = 150.0
		particles.gravity = Vector2(0, 200)

		particles.color = Color(0.2, 1.0, 0.3, 1.0)
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 5.0

		await get_tree().create_timer(particles.lifetime + 0.5).timeout
		if is_instance_valid(particles):
			particles.queue_free()

func _spawn_failure_effect(plate: PressurePlate) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	plate.add_child(particles)

	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.8
	particles.explosiveness = 1.0

	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 300)

	particles.color = Color(1.0, 0.2, 0.2, 1.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	await get_tree().create_timer(particles.lifetime + 0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func get_current_step() -> int:
	return _current_step

func get_total_steps() -> int:
	return _plates.size()

func is_sequence_complete() -> bool:
	return _is_complete
