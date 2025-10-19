extends Area2D
class_name WindTunnel

@export var wind_direction: Vector2 = Vector2.RIGHT
@export var wind_strength: float = 35.0 
@export var area_size: Vector2 = Vector2(256, 32) 
@export var speed_boost_multiplier: float = 1.5  
@export var always_active: bool = true
@export var toggle_interval: float = 2.0
@export var active_duration: float = 1.5

@export_group("Realism")
@export var gust_frequency: float = 1.5
@export var gust_strength: float = 0.5 
@export var turbulence: float = 0.2 
@export var edge_falloff: float = 0.4 

const MIN_INTERVAL: float = 0.1

var _is_active: bool = true
var _toggle_timer: float = 0.0
var _collision_shape: CollisionShape2D
var _wave_offset: float = 0.0
var _gust_timer: float = 0.0
var _current_gust: float = 0.0
var _noise_offset: float = 0.0
var _bodies_in_wind: Dictionary = {}
var _wind_particles: Array = [] 

func _ready() -> void:
	add_to_group("sonar_platforms")
	add_to_group("wind_tunnels")
	position = position.snapped(Vector2(16, 16))

	monitoring = true
	monitorable = true
	collision_layer = 0
	collision_mask = 1

	_configure_collision_shape()
	_is_active = always_active
	set_process(true)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_initialize_wind_particles()

func _configure_collision_shape() -> void:
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "CollisionShape2D"
	add_child(_collision_shape)

	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = area_size
	_collision_shape.shape = rect

func _initialize_wind_particles() -> void:
	var num_particles: int = 20
	var half_size: Vector2 = area_size * 0.5
	var normalized: Vector2 = wind_direction.normalized()

	for i in range(num_particles):
		var particle: Dictionary = {}
		if abs(normalized.x) > abs(normalized.y):
			particle.position = Vector2(
				-half_size.x,
				randf_range(-half_size.y, half_size.y)
			)
		else:
			particle.position = Vector2(
				randf_range(-half_size.x, half_size.x),
				-half_size.y if normalized.y > 0 else half_size.y
			)

		particle.speed = randf_range(0.8, 1.2)
		particle.length = randf_range(8.0, 16.0) 
		particle.offset_y = randf_range(-3.0, 3.0) 

		_wind_particles.append(particle)

func _process(delta: float) -> void:
	if not always_active:
		_handle_toggle(delta)

	var current_strength: float = _get_current_base_strength()
	_wave_offset += delta * 50.0 * (current_strength / wind_strength)
	if _wave_offset > 100.0:
		_wave_offset = 0.0

	_gust_timer += delta
	if _gust_timer >= gust_frequency:
		_gust_timer = 0.0
		_current_gust = randf_range(0.5, 1.0) * gust_strength

	var gust_cycle: float = _gust_timer / gust_frequency
	var gust_curve: float = sin(gust_cycle * PI) 
	_current_gust = lerp(0.0, _current_gust, gust_curve)

	_noise_offset += delta * 2.0

	for body in _bodies_in_wind.keys():
		if body == null or not is_instance_valid(body):
			_bodies_in_wind.erase(body)
			continue
		_bodies_in_wind[body] = min(_bodies_in_wind[body] + delta / 0.3, 1.0)

	_update_wind_particles(delta)

func _update_wind_particles(delta: float) -> void:
	var half_size: Vector2 = area_size * 0.5
	var normalized: Vector2 = wind_direction.normalized()
	var current_strength: float = _get_current_base_strength()
	var speed_multiplier: float = current_strength / wind_strength

	for particle in _wind_particles:
		var move_speed: float = 80.0 * particle.speed * speed_multiplier
		particle.position += normalized * move_speed * delta

		var wobble: float = sin(_noise_offset + particle.position.x * 0.2) * particle.offset_y
		if abs(normalized.x) > abs(normalized.y):
			particle.position.y += wobble * delta * 10.0
		else:
			particle.position.x += wobble * delta * 10.0

		var is_out_of_bounds: bool = false
		if abs(normalized.x) > abs(normalized.y):
			if particle.position.x > half_size.x:
				is_out_of_bounds = true
		else:
			if normalized.y > 0 and particle.position.y > half_size.y:
				is_out_of_bounds = true
			elif normalized.y < 0 and particle.position.y < -half_size.y:
				is_out_of_bounds = true

		if is_out_of_bounds:
			if abs(normalized.x) > abs(normalized.y):
				particle.position = Vector2(
					-half_size.x,
					randf_range(-half_size.y, half_size.y)
				)
			else:
				particle.position = Vector2(
					randf_range(-half_size.x, half_size.x),
					-half_size.y if normalized.y > 0 else half_size.y
				)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody2D:
		_bodies_in_wind[body] = 0.0

func _on_body_exited(body: Node) -> void:
	_bodies_in_wind.erase(body)

func _handle_toggle(delta: float) -> void:
	var effective_interval: float = max(toggle_interval, MIN_INTERVAL)
	_toggle_timer += delta

	var cycle_time: float = effective_interval + max(active_duration, 0.0)
	var time_in_cycle: float = fmod(_toggle_timer, cycle_time)

	_is_active = time_in_cycle < max(active_duration, 0.0)

func is_body_in_wind(body: Node) -> bool:
	return body in _bodies_in_wind

func get_wind_force() -> Vector2:
	if not _is_active:
		return Vector2.ZERO
	return wind_direction.normalized() * wind_strength

func get_wind_force_at_position(body: Node, body_position: Vector2) -> Vector2:
	if not _is_active:
		return Vector2.ZERO

	if body not in _bodies_in_wind:
		return Vector2.ZERO

	var base_strength: float = _get_current_base_strength()

	var local_pos: Vector2 = to_local(body_position)
	var half_size: Vector2 = area_size * 0.5
	var normalized_distance: Vector2 = Vector2(
		abs(local_pos.x) / half_size.x,
		abs(local_pos.y) / half_size.y
	)
	var max_distance: float = max(normalized_distance.x, normalized_distance.y)
	var edge_multiplier: float = 1.0 - (max_distance * edge_falloff)
	edge_multiplier = clamp(edge_multiplier, 0.2, 1.0)

	var turbulence_value: float = sin(_noise_offset * 3.14 + body_position.x * 0.1) * turbulence
	var turbulence_multiplier: float = 1.0 + turbulence_value

	var ramp_multiplier: float = _bodies_in_wind[body]

	var speed_boost: float = 1.0
	if body is CharacterBody2D:
		var player_velocity: Vector2 = body.velocity
		var wind_dir_normalized: Vector2 = wind_direction.normalized()

		var alignment: float = player_velocity.normalized().dot(wind_dir_normalized)

		if alignment > 0.5:
			speed_boost = speed_boost_multiplier

	var final_strength: float = base_strength * edge_multiplier * turbulence_multiplier * ramp_multiplier * speed_boost

	return wind_direction.normalized() * final_strength

func _get_current_base_strength() -> float:
	return wind_strength * (1.0 + _current_gust)

func get_sonar_edges() -> Array:
	var edges: Array = []
	var normalized: Vector2 = wind_direction.normalized()

	for particle in _wind_particles:
		var pos: Vector2 = particle.position
		var streak_length: float = particle.length

		var streak_start: Vector2 = pos - (normalized * streak_length * 0.5)
		var streak_end: Vector2 = pos + (normalized * streak_length * 0.5)

		edges.append({
			"start": to_global(streak_start),
			"end": to_global(streak_end)
		})

	return edges
