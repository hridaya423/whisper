extends CharacterBody2D
class_name Player

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const SONAR_COOLDOWN = 1.0
const SONAR_RANGE = 150.0
const MIN_LANDING_VELOCITY = 150.0  
const ATTACK_COOLDOWN = 0.5

var MAX_HEALTH = 10
var sonar_timer = 0.0	
var attack_timer = 0.0
var can_sonar = true
var can_attack = true
var health = MAX_HEALTH
var invulnerable = false
var invulnerable_timer = 0.0
var invulnerable_duration = 1.5
var facing_direction = Vector2.RIGHT
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_plane_y = 1000
var footstep_timer = 0.0
var base_footstep_interval = 0.4
var was_on_floor = false
var last_velocity_y = 0.0


var health_ui_layer: CanvasLayer
var health_bar_background: ColorRect
var health_bar_fill: ColorRect
var health_label: Label

@export var light_projectile_scene: PackedScene

@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var landing_audio: AudioStreamPlayer2D = $LandingAudio
@onready var sonar_audio: AudioStreamPlayer2D = $SonarAudio
@onready var attack_audio: AudioStreamPlayer2D = $AttackAudio
@onready var sprite: Sprite2D = $Sprite2D  

signal sonar_pulse_emitted(position: Vector2, range: float, direction: Vector2)
signal player_died

func _ready():
	z_index = 101 
	
	var game_manager = get_node("../GameManager")
	if game_manager:
		sonar_pulse_emitted.connect(game_manager._on_player_sonar_pulse)
	
	
	_setup_health_ui()
	_update_health_ui()

func _setup_health_ui():
	
	health_ui_layer = CanvasLayer.new()
	health_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(health_ui_layer)
	
	
	var health_container = Control.new()
	health_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	health_container.position = Vector2(20, -60)  
	health_container.size = Vector2(200, 40)
	health_ui_layer.add_child(health_container)
	
	
	var outer_border = ColorRect.new()
	outer_border.position = Vector2(-4, -2)
	outer_border.size = Vector2(168, 28)
	outer_border.color = Color(0.15, 0.0, 0.0, 0.9)  
	health_container.add_child(outer_border)
	
	
	health_bar_background = ColorRect.new()
	health_bar_background.position = Vector2(0, 0)
	health_bar_background.size = Vector2(160, 24)
	health_bar_background.color = Color(0.08, 0.0, 0.0, 0.95)  
	health_container.add_child(health_bar_background)
	
	
	health_bar_fill = ColorRect.new()
	health_bar_fill.position = Vector2(2, 2)
	health_bar_fill.size = Vector2(156, 20)
	health_bar_fill.color = Color(0.6, 0.05, 0.05)  
	health_container.add_child(health_bar_fill)

func _update_health_ui():
	if not health_bar_fill:
		return
	
	
	var health_percentage = float(health) / float(MAX_HEALTH)
	
	
	var max_width = 156.0
	var current_width = max_width * health_percentage
	health_bar_fill.size.x = current_width
	
	
	if health_percentage > 0.7:
		health_bar_fill.color = Color(0.6, 0.05, 0.05)  
	elif health_percentage > 0.4:
		health_bar_fill.color = Color(0.7, 0.1, 0.0)   
	elif health_percentage > 0.2:
		health_bar_fill.color = Color(0.8, 0.0, 0.0)   
	else:
		health_bar_fill.color = Color(0.9, 0.05, 0.05) 
	
	
	if health_percentage <= 0.3:
		_create_critical_health_effect()

func _create_critical_health_effect():
	
	var tween = create_tween()
	tween.set_loops()
	
	tween.tween_property(health_bar_fill, "color", Color(1.0, 0.2, 0.2), 0.6)
	tween.tween_property(health_bar_fill, "color", Color(0.4, 0.0, 0.0), 0.6)

func _physics_process(delta):
	
	if !can_sonar:
		sonar_timer -= delta
		if sonar_timer <= 0:
			can_sonar = true
	
	if !can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	
	if invulnerable:
		invulnerable_timer -= delta
		if invulnerable_timer <= 0:
			invulnerable = false
			modulate = Color.WHITE
		else:
			
			var flash = sin(invulnerable_timer * 20.0)
			modulate.a = 0.5 + abs(flash) * 0.5
	
	if not is_on_floor():
		velocity.y += gravity * delta
		
	
	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	
	if (Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_E)) and can_sonar:
		emit_sonar_pulse()
	
	
	if Input.is_key_pressed(KEY_Q) and can_attack:
		shoot_light_projectile()
	
	
	var direction = 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction = -1
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction = 1
	
	var is_moving = direction != 0 and is_on_floor()
	
	if direction:
		velocity.x = direction * SPEED
		facing_direction = Vector2.RIGHT if direction > 0 else Vector2.LEFT
		update_sprite_direction()  
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3)
	
	var current_speed = abs(velocity.x)
	var step_interval = clamp(0.36 - (current_speed / SPEED) * 0.12, 0.24, 0.36)
	
	handle_footstep_audio(delta, is_moving, step_interval)
	handle_landing_sound()

	if global_position.y > death_plane_y:
		player_died.emit()

	if not is_inside_tree():
		return
	
	last_velocity_y = velocity.y
	was_on_floor = is_on_floor()
	move_and_slide()

func update_sprite_direction():
	if sprite:
		
		
		if facing_direction == Vector2.LEFT:
			sprite.flip_h = false
		else:
			sprite.flip_h = true

func emit_sonar_pulse():
	if !can_sonar:
		return
	
	can_sonar = false
	sonar_timer = SONAR_COOLDOWN
	
	play_sonar_sound()
	
	sonar_pulse_emitted.emit(global_position, SONAR_RANGE, facing_direction)

func shoot_light_projectile():
	if !can_attack or !light_projectile_scene:
		return
	
	can_attack = false
	attack_timer = ATTACK_COOLDOWN
	
	
	var projectile = light_projectile_scene.instantiate()
	get_parent().add_child(projectile)
	
	
	projectile.global_position = global_position + facing_direction * 30 
	projectile.direction = facing_direction
	
	play_attack_sound()

func handle_footstep_audio(delta: float, is_moving: bool, step_interval: float):
	if is_moving:
		footstep_timer += delta
		if footstep_timer >= step_interval:
			footstep_timer = 0.0
			play_footstep_sound()
	else:
		footstep_timer = 0.0

func handle_landing_sound():
	if is_on_floor() and !was_on_floor and abs(last_velocity_y) > MIN_LANDING_VELOCITY:
		play_landing_sound()

func play_footstep_sound():
	if footstep_audio:
		footstep_audio.pitch_scale = randf_range(0.9, 1.1)
		footstep_audio.volume_db = randf_range(-1.5, 0)
		footstep_audio.play()

func play_landing_sound():
	if landing_audio:
		landing_audio.pitch_scale = randf_range(0.9, 1.05)
		landing_audio.volume_db = randf_range(-2, 0)
		landing_audio.play()

func play_sonar_sound():
	if sonar_audio:
		sonar_audio.pitch_scale = randf_range(0.9, 1.1)
		sonar_audio.play()

func play_attack_sound():
	if attack_audio:
		attack_audio.pitch_scale = randf_range(0.95, 1.05)
		attack_audio.play()

func take_damage():
	if invulnerable:
		return
	
	health -= 1
	print("Player health: ", health)
	
	
	_update_health_ui()
	
	
	_create_damage_screen_effect()
	
	if health <= 0:
		player_died.emit()
	else:
		invulnerable = true
		invulnerable_timer = invulnerable_duration
		
		
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.RED, 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _create_damage_screen_effect():
	
	var damage_flash = ColorRect.new()
	health_ui_layer.add_child(damage_flash)
	damage_flash.color = Color(0.7, 0.0, 0.0, 0.4)  
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	
	var tween = damage_flash.create_tween()
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.4)  
	tween.finished.connect(func(): damage_flash.queue_free())


func heal(amount: int):
	health = min(health + amount, MAX_HEALTH)
	_update_health_ui()
	print("Player healed! Health: ", health)


func set_max_health(new_max: int):
	var old_percentage = float(health) / float(MAX_HEALTH)
	MAX_HEALTH = new_max
	health = int(old_percentage * MAX_HEALTH)  
	_update_health_ui()
