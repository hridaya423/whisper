extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: int = 1
var lifetime: float = 0.0
var max_lifetime: float = 5.0
var is_deflected: bool = false

const DEFLECT_SPEED_MULTIPLIER := 1.2
const DEFLECT_DAMAGE_MULTIPLIER := 2.0

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	global_position += direction * speed * delta
	rotation = direction.angle()

	lifetime += delta
	if lifetime >= max_lifetime:
		queue_free()

func _on_body_entered(body):
	if is_deflected:
		if body is Player:
			return
		if body is Boss:
			var boss: Boss = body
			var config := {
				"is_player_attack": true,
				"is_projectile": true,
				"is_parry_deflect": true
			}
			boss.take_damage(damage, global_position, config)
			_create_impact_effect()
			queue_free()
		else:
			_create_impact_effect()
			queue_free()
		return

	if body is Player:
		if body.has_method("try_parry") and body.try_parry(self):
			return
		for i in range(damage):
			body.take_damage()
		_create_impact_effect()
		queue_free()

func deflect_from_player(player: Player):
	if is_deflected:
		return

	is_deflected = true
	direction = -direction.normalized()

	var target_boss := _find_nearest_boss()
	if target_boss:
		var to_boss := target_boss.global_position - global_position
		if to_boss.length_squared() > 0.01:
			direction = to_boss.normalized()

	speed *= DEFLECT_SPEED_MULTIPLIER
	damage = max(1, int(round(damage * DEFLECT_DAMAGE_MULTIPLIER)))
	rotation = direction.angle()
	lifetime = 0.0

func _find_nearest_boss() -> Boss:
	var bosses := get_tree().get_nodes_in_group("bosses")
	var closest_boss: Boss = null
	var closest_distance := INF
	for boss in bosses:
		if not (boss is Boss):
			continue
		var distance := (boss as Boss).global_position.distance_to(global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_boss = boss
	return closest_boss

func _create_impact_effect():
	var particles = CPUParticles2D.new()
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.6
	particles.color = Color(0.6, 0.4, 0.2, 0.8)
	particles.direction = -direction
	particles.spread = 60
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.gravity = Vector2(0, 200)

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(particles):
		particles.queue_free()
