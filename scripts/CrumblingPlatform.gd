extends AnimatableBody2D

@export var platform_size: Vector2 = Vector2(64, 16)
@export var crumble_delay: float = 1.2
@export var crumble_duration: float = 1.0
@export var respawn_time: float = 5.0
@export var shake_intensity: float = 2.0

enum State { IDLE, CRUMBLING, FALLING, RESPAWNING }

var current_state: State = State.IDLE
var crumble_timer: float = 0.0
var shake_timer: float = 0.0
var original_position: Vector2
var player_on_platform: bool = false

var debris_particles: CPUParticles2D

func _ready():
	add_to_group("sonar_platforms")
	position = position.snapped(Vector2(16, 16))
	original_position = position

	if $Sprite2D:
		$Sprite2D.visible = false

	if $CollisionShape2D and $CollisionShape2D.shape is RectangleShape2D:
		$CollisionShape2D.shape.size = platform_size

	_create_debris_particles()

	var area = Area2D.new()
	add_child(area)
	var area_shape = CollisionShape2D.new()
	area_shape.shape = RectangleShape2D.new()
	area_shape.shape.size = platform_size + Vector2(2, 2)
	area.add_child(area_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _create_debris_particles():
	debris_particles = CPUParticles2D.new()
	add_child(debris_particles)

	debris_particles.emitting = false
	debris_particles.one_shot = true
	debris_particles.amount = 20
	debris_particles.lifetime = 1.5
	debris_particles.explosiveness = 0.8

	debris_particles.direction = Vector2(0, 1)
	debris_particles.spread = 45.0
	debris_particles.initial_velocity_min = 50.0
	debris_particles.initial_velocity_max = 150.0

	debris_particles.gravity = Vector2(0, 300)

	debris_particles.scale_amount_min = 2.0
	debris_particles.scale_amount_max = 6.0
	debris_particles.color = Color(0.5, 0.5, 0.5, 0.8)

func _on_body_entered(body):
	if body is CharacterBody2D and current_state == State.IDLE:
		player_on_platform = true
		_start_crumble()

func _on_body_exited(body):
	if body is CharacterBody2D:
		player_on_platform = false

func _start_crumble():
	if current_state != State.IDLE:
		return

	current_state = State.CRUMBLING
	crumble_timer = 0.0

func _process(delta):
	match current_state:
		State.CRUMBLING:
			_update_crumbling(delta)
		State.FALLING:
			pass
		State.RESPAWNING:
			pass

func _update_crumbling(delta):
	crumble_timer += delta

	var progress = crumble_timer / crumble_delay
	var current_shake = shake_intensity * progress

	shake_timer += delta * 15.0 
	var shake_offset = Vector2(
		sin(shake_timer) * current_shake,
		cos(shake_timer * 1.3) * current_shake * 0.5
	)
	position = original_position + shake_offset

	if crumble_timer >= crumble_delay:
		_fall()

func _fall():
	current_state = State.FALLING

	debris_particles.emitting = true
	debris_particles.restart()

	if $CollisionShape2D:
		$CollisionShape2D.disabled = true

	var fall_tween = create_tween()
	fall_tween.set_parallel(true)
	fall_tween.tween_property(self, "position", position + Vector2(0, 100), crumble_duration).set_ease(Tween.EASE_IN)
	fall_tween.tween_property(self, "modulate:a", 0.0, crumble_duration * 0.8)

	fall_tween.chain().tween_callback(_start_respawn)

func _start_respawn():
	current_state = State.RESPAWNING

	await get_tree().create_timer(respawn_time).timeout

	_respawn()

func _respawn():
	position = original_position

	var respawn_tween = create_tween()
	respawn_tween.tween_property(self, "modulate:a", 1.0, 0.5)

	await respawn_tween.finished

	if $CollisionShape2D:
		$CollisionShape2D.disabled = false

	current_state = State.IDLE
	crumble_timer = 0.0
	shake_timer = 0.0
