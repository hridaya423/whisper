extends CharacterBody2D
class_name Boss

const DAMAGE_NUMBER_SCENE := preload("res://scripts/ui/DamageNumber.gd")

enum BossType {
	DREAD,
	WRAITH,
	SENTINEL,
	LORD_OF_DARKNESS
}

enum BossPhase {
	PHASE_1,
	PHASE_2,
	PHASE_3,
	PHASE_4
}

enum BossState {
	INACTIVE,      
	CINEMATIC,  
	COMBAT,
	DEFEATED 
}

@export var boss_type: BossType = BossType.SENTINEL
@export var boss_name: String = "Unknown Boss"
@export var max_health: int = 400
@export var movement_speed: float = 100.0

var current_health: int
var current_phase: BossPhase = BossPhase.PHASE_1
var current_state: BossState = BossState.INACTIVE
var is_vulnerable: bool = true

var is_in_cinematic: bool = false:
	get: return current_state == BossState.CINEMATIC
var is_defeated: bool = false:
	get: return current_state == BossState.DEFEATED
var encounter_started: bool = false:
	get: return current_state != BossState.INACTIVE

var player: Player
var boss_ui
var cinematic_system

var attack_timer: float = 0.0
var phase_transition_triggered: bool = false

signal boss_spawned(boss: Boss)
signal boss_phase_changed(boss: Boss, new_phase: BossPhase)
signal boss_damaged(boss: Boss, damage: int)
signal boss_defeated(boss: Boss)
signal boss_attack_started(boss: Boss, attack_name: String)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var area_detector: Area2D = $AreaDetector
@onready var hurt_box: Area2D = $HurtBox

func _ready():
	current_health = max_health
	z_index = 100
	add_to_group("bosses")

	player = get_tree().get_first_node_in_group("player")
	_setup_collision_detection()

	call_deferred("_setup_boss_systems_deferred")

func _setup_boss_systems_deferred():
	await get_tree().process_frame
	_setup_boss_systems()
	boss_spawned.emit(self)

func _setup_boss_systems():
	var game_scene = get_tree().current_scene
	if not game_scene:
		print("Error: current_scene is null, retrying...")
		await get_tree().process_frame
		game_scene = get_tree().current_scene
		if not game_scene:
			print("Error: Still no current_scene available")
			return

	var BossUIScript = load("res://scripts/bosses/BossUI.gd")
	boss_ui = BossUIScript.new()
	boss_ui.setup_for_boss(self)
	game_scene.add_child(boss_ui)

	var BossCinematicScript = load("res://scripts/bosses/BossCinematic.gd")
	cinematic_system = BossCinematicScript.new()
	cinematic_system.setup_for_boss(self)
	game_scene.add_child(cinematic_system)

func _setup_collision_detection():
	if area_detector:
		area_detector.body_entered.connect(_on_player_detected)

	if hurt_box:
		hurt_box.area_entered.connect(_on_projectile_hit)

func _physics_process(delta):
	if current_state != BossState.COMBAT:
		return

	attack_timer += delta
	_update_boss_behavior(delta)
	move_and_slide()

func _update_boss_behavior(delta):
	pass

func _on_player_detected(body):
	if body is Player and current_state == BossState.INACTIVE:
		start_boss_encounter()

func start_boss_encounter():
	current_state = BossState.CINEMATIC

	cinematic_system.start_cinematic()
	await cinematic_system.cinematic_finished

	current_state = BossState.COMBAT
	is_vulnerable = true
	boss_ui.show_health_bar()


func _on_projectile_hit(area):
	if area.is_in_group("player_projectiles") and is_vulnerable and current_state == BossState.COMBAT:
		var impact_position: Vector2 = global_position
		if area is Node2D:
			impact_position = (area as Node2D).global_position
		take_damage(1, impact_position)

func take_damage(amount: int, hit_position: Vector2 = Vector2.INF, config: Dictionary = {}):
	if not is_vulnerable or current_state != BossState.COMBAT:
		return

	if hit_position == Vector2.INF:
		hit_position = global_position

	current_health -= amount
	current_health = max(0, current_health)

	_create_hit_feedback()
	if amount > 0:
		_spawn_damage_number(amount, hit_position, config)

	boss_damaged.emit(self, amount)
	boss_ui.update_health_bar(current_health, max_health)
	boss_ui.flash_damage()

	_check_phase_transitions()

	if current_health <= 0:
		_defeat_boss()

func _create_hit_feedback():
	var original_modulate = modulate
	modulate = Color.WHITE
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", original_modulate, 0.1)

	Engine.time_scale = 0.3
	await get_tree().create_timer(0.05, true, false, true).timeout
	if not is_instance_valid(self):
		return
	Engine.time_scale = 1.0

	_create_hit_particles()

	var camera = get_tree().get_first_node_in_group("camera")
	if camera and is_instance_valid(camera):
		_apply_hit_camera_shake(camera)

func _create_hit_particles():
	var hit_particles = CPUParticles2D.new()
	add_child(hit_particles)
	hit_particles.emitting = true
	hit_particles.one_shot = true
	hit_particles.amount = 15
	hit_particles.lifetime = 0.5
	hit_particles.explosiveness = 0.9
	hit_particles.direction = Vector2(0, -1)
	hit_particles.spread = 180
	hit_particles.initial_velocity_min = 100
	hit_particles.initial_velocity_max = 200
	hit_particles.color = Color(1.0, 0.8, 0.3, 1.0)
	hit_particles.scale_amount_min = 0.5
	hit_particles.scale_amount_max = 1.5

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		if is_instance_valid(hit_particles):
			hit_particles.queue_free()
		return
	if is_instance_valid(hit_particles):
		hit_particles.queue_free()

func _apply_hit_camera_shake(camera: Camera2D):
	var shake_tween = create_tween()
	shake_tween.tween_property(camera, "rotation", 0.05, 0.05)
	shake_tween.tween_property(camera, "rotation", -0.05, 0.05)
	shake_tween.tween_property(camera, "rotation", 0.0, 0.05)

func _check_phase_transitions():
	var health_percentage = float(current_health) / float(max_health)
	var new_phase = current_phase

	if health_percentage <= 0.75 and current_phase == BossPhase.PHASE_1:
		new_phase = BossPhase.PHASE_2
	elif health_percentage <= 0.50 and current_phase == BossPhase.PHASE_2:
		new_phase = BossPhase.PHASE_3
	elif health_percentage <= 0.25 and current_phase == BossPhase.PHASE_3:
		new_phase = BossPhase.PHASE_4

	if new_phase != current_phase:
		_transition_to_phase(new_phase)

func _transition_to_phase(new_phase: BossPhase):
	current_phase = new_phase
	boss_phase_changed.emit(self, new_phase)
	_on_phase_changed(new_phase)

func _on_phase_changed(new_phase: BossPhase):
	pass

func _defeat_boss():
	current_state = BossState.DEFEATED
	is_vulnerable = false
	boss_defeated.emit(self)
	boss_ui.hide_health_bar()

	_play_death_animation()

func _play_death_animation():
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate:a", 0.0, 2.0)
	death_tween.tween_callback(queue_free)

func get_distance_to_player() -> float:
	if player and is_instance_valid(player):
		return global_position.distance_to(player.global_position)
	return 999.0

func get_direction_to_player() -> Vector2:
	if player and is_instance_valid(player):
		return (player.global_position - global_position).normalized()
	return Vector2.ZERO

func set_vulnerability(vulnerable: bool):
	is_vulnerable = vulnerable

func get_boss_dialogue() -> Array[String]:
	return ["..."]

func _spawn_damage_number(amount: float, hit_position: Vector2, config: Dictionary):
	if DAMAGE_NUMBER_SCENE == null:
		return

	var scene_root = get_tree().current_scene
	if scene_root == null:
		return

	var damage_number: DamageNumber = DAMAGE_NUMBER_SCENE.new()
	damage_number.z_index = 1000
	scene_root.add_child(damage_number)

	var options := config.duplicate(true) if config and config is Dictionary else {}
	if not options.has("is_boss"):
		options["is_boss"] = true

	damage_number.show_damage(amount, hit_position, options)
