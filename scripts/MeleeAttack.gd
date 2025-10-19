extends Node2D
class_name MeleeAttack

const DEFAULT_COLOR := Color(1.0, 0.95, 0.6, 0.95)
const TRAIL_END_COLOR := Color(1.0, 0.4, 0.2, 0.0)

@export var arc_degrees: float = 120.0
@export var arc_radius: float = 60.0
@export var lifetime: float = 0.3
@export var line_width: float = 10.0
@export var arc_point_count: int = 24
@export var damage_multiplier: float = 2.0

var player: Player
var attack_direction: Vector2 = Vector2.RIGHT
var damage_amount: int = 1
var line: Line2D
var trail_particles: CPUParticles2D

func setup(player_ref: Player, direction: Vector2, base_damage: float):
	player = player_ref
	attack_direction = direction.normalized()
	damage_amount = max(1, int(round(base_damage * damage_multiplier)))
	set_as_top_level(true)
	global_position = player_ref.global_position
	z_index = player_ref.z_index + 1

	_create_arc_visual()
	_spawn_arc_glow()
	_perform_hit_detection()
	_play_animation()

func _create_arc_visual():
	line = Line2D.new()
	add_child(line)
	line.default_color = DEFAULT_COLOR
	line.width = line_width
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.z_index = 1
	line.closed = false
	line.antialiased = true
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.texture_mode = Line2D.LINE_TEXTURE_STRETCH

	var gradient := Gradient.new()
	gradient.add_point(0.0, DEFAULT_COLOR)
	gradient.add_point(1.0, TRAIL_END_COLOR)
	line.gradient = gradient

	var points: Array[Vector2] = []
	var half_arc := arc_degrees * 0.5
	var step := arc_degrees / float(max(1, arc_point_count - 1))
	for i in range(arc_point_count):
		var angle_deg := -half_arc + step * i
		var angle_rad := deg_to_rad(angle_deg)
		var point := Vector2(cos(angle_rad), sin(angle_rad)) * arc_radius
		points.append(point)
	line.points = PackedVector2Array(points)

	rotation = attack_direction.angle()



func _perform_hit_detection():
	if not player:
		return

	var scene := get_tree()
	if not scene:
		return

	var targets: Array = []
	var groups := ["enemies", "bosses"]
	for group in groups:
		for node in scene.get_nodes_in_group(group):
			if not (node is Node2D):
				continue
			if node == player:
				continue
			if not node.is_inside_tree():
				continue
			if not node.visible:
				continue

			var node_position: Vector2 = (node as Node2D).global_position
			var offset := node_position - global_position
			var distance := offset.length()
			if distance == 0 or distance > arc_radius:
				continue

			var orientation := offset.normalized()
			var angle_to_target := rad_to_deg(attack_direction.angle_to(orientation))
			if abs(angle_to_target) > arc_degrees * 0.5:
				continue

			if targets.has(node):
				continue
			targets.append(node)

	if targets.is_empty():
		return

	for target in targets:
		if not target:
			continue
		if target.has_method("take_damage"):
			var hit_position: Vector2 = global_position
			if target is Node2D:
				hit_position = (target as Node2D).global_position
			var hit_config := {
				"is_player_attack": true,
				"is_melee": true
			}
			target.take_damage(damage_amount, hit_position, hit_config)

func _spawn_arc_glow():
	trail_particles = CPUParticles2D.new()
	add_child(trail_particles)
	trail_particles.position = Vector2.ZERO
	trail_particles.emitting = true
	trail_particles.one_shot = true
	trail_particles.amount = 20
	trail_particles.lifetime = lifetime * 1.1
	trail_particles.explosiveness = 1.0
	trail_particles.direction = Vector2.RIGHT
	trail_particles.spread = arc_degrees
	trail_particles.speed_scale = 1.0
	trail_particles.initial_velocity_min = arc_radius * 3.5
	trail_particles.initial_velocity_max = arc_radius * 4.5
	trail_particles.gravity = Vector2.ZERO
	trail_particles.scale_amount_min = 0.1
	trail_particles.scale_amount_max = 0.35
	trail_particles.color = Color(1.0, 0.7, 0.2, 0.6)
	trail_particles.z_index = z_index

	trail_particles.color_ramp = _build_color_ramp()

func _play_animation():
	if not line:
		queue_free()
		return

	line.modulate = DEFAULT_COLOR
	line.width = line_width
	line.rotation = -deg_to_rad(arc_degrees * 0.5)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(line, "rotation", deg_to_rad(arc_degrees * 0.5), lifetime)
	tween.parallel().tween_property(line, "modulate:a", 0.0, lifetime)
	tween.parallel().tween_property(line, "width", 0.0, lifetime)
	tween.tween_callback(func():
		if trail_particles and is_instance_valid(trail_particles):
			trail_particles.emitting = false
		queue_free()
	)

func _build_color_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color(1.0, 0.95, 0.6, 0.8))
	ramp.add_point(0.4, Color(1.0, 0.6, 0.3, 0.4))
	ramp.add_point(1.0, Color(1.0, 0.4, 0.2, 0.0))
	return ramp
