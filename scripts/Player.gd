extends CharacterBody2D
class_name Player

const SPEED = 200.0
const JUMP_VELOCITY = -400.0
const SONAR_COOLDOWN = 1.0
const SONAR_RANGE = 150.0

var sonar_timer = 0.0
var can_sonar = true
var facing_direction = Vector2.RIGHT
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var death_plane_y = 1000

var footstep_timer = 0.0
var footstep_interval = 0.195

@onready var footstep_audio: AudioStreamPlayer2D = $FootstepAudio
@onready var sonar_audio: AudioStreamPlayer2D = $SonarAudio

signal sonar_pulse_emitted(position: Vector2, range: float, direction: Vector2)
signal player_died

func _ready():
	z_index = 101 
	
	var game_manager = get_node("../GameManager")
	if game_manager:
		sonar_pulse_emitted.connect(game_manager._on_player_sonar_pulse)

func _physics_process(delta):
	if !can_sonar:
		sonar_timer -= delta
		if sonar_timer <= 0:
			can_sonar = true
	
	if not is_on_floor():
		velocity.y += gravity * delta
		
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	if (Input.is_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_E)) and can_sonar:
		emit_sonar_pulse()
	
	var direction = 0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction = -1
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction = 1
	
	var is_moving = direction != 0 and is_on_floor()
	
	if direction:
		velocity.x = direction * SPEED
		facing_direction = Vector2.RIGHT if direction > 0 else Vector2.LEFT
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 3)
	
	_handle_footstep_audio(delta, is_moving)

	if global_position.y > death_plane_y:
		player_died.emit()

	if not is_inside_tree():
		return
	
	move_and_slide()

func emit_sonar_pulse():
	if !can_sonar:
		return
	
	can_sonar = false
	sonar_timer = SONAR_COOLDOWN
	
	_play_sonar_sound()
	
	sonar_pulse_emitted.emit(global_position, SONAR_RANGE, facing_direction)

func _handle_footstep_audio(delta: float, is_moving: bool):
	if is_moving:
		footstep_timer += delta
		if footstep_timer >= footstep_interval:
			footstep_timer = 0.0
			_play_footstep_sound()
	else:
		footstep_timer = 0.0

func _play_footstep_sound():
	if footstep_audio:
		footstep_audio.pitch_scale = randf_range(0.8, 1.2)
		footstep_audio.play()

func _play_sonar_sound():
	if sonar_audio:
		sonar_audio.pitch_scale = randf_range(0.9, 1.1)
		sonar_audio.play()
