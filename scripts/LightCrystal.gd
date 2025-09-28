extends Sprite2D
class_name LightCrystal
@export var heal_amount: int = 5
@export var power_up_duration: float = 20.0
@export var recharge_time: float = 30.0
@export var glow_intensity: float = 1.5
var is_active = true
var is_recharging = false
var recharge_timer = 0.0
@onready var area: Area2D = $Area2D
@onready var activation_audio: AudioStreamPlayer2D = $ActivationAudio
var dialogue_player: AudioStreamPlayer2D
var dialogue_played = false
signal crystal_activated(heal_amount: int, power_duration: float)
func _ready():
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	modulate.a = 1.0
	add_to_group("light_crystals")
	setup_dialogue()
func _process(delta):
	if is_recharging:
		_handle_recharge(delta)
	else:
		_animate_glow(delta)
func _animate_glow(delta):
	if is_active:
		var pulse = sin(Time.get_ticks_msec() * 0.003) * 0.3 + 0.7
		modulate = Color(1.0 + pulse * glow_intensity, 1.0 + pulse * glow_intensity, 1.0 + pulse * glow_intensity)
	else:
		modulate = Color(0.3, 0.3, 0.4, 0.8)
func _handle_recharge(delta):
	recharge_timer -= delta
	if recharge_timer <= 0:
		_reactivate_crystal()
func _reactivate_crystal():
	is_recharging = false
	is_active = true
	recharge_timer = 0.0
	print("Light Crystal recharged and ready!")
func _on_body_entered(body):
	if body is Player and is_active:
		_activate_crystal(body)
func _on_body_exited(body):
	pass
func _activate_crystal(player: Player):
	if not is_active or is_recharging:
		return
	player.heal(heal_amount)
	_grant_power_up(player)
	is_active = false
	is_recharging = true
	recharge_timer = recharge_time
	if activation_audio:
		activation_audio.play()
	play_crystal_dialogue()
	crystal_activated.emit(heal_amount, power_up_duration)
	print("Crystal activated! Healed " + str(heal_amount) + " HP and gained power-up for " + str(power_up_duration) + "s")
func _grant_power_up(player: Player):
	var sonar_duration_boost = 2.0
	var jump_boost = 1.3
	var dash_boost = 0.4
	player._apply_crystal_power_up(sonar_duration_boost, jump_boost, dash_boost, power_up_duration)
func setup_dialogue():
	dialogue_player = AudioStreamPlayer2D.new()
	add_child(dialogue_player)
	dialogue_player.volume_db = -5
func play_crystal_dialogue():
	if dialogue_played:
		return
	var audio_path = "res://assets/dialogue/crystal.mp3"
	if ResourceLoader.exists(audio_path):
		var audio_stream = load(audio_path)
		dialogue_player.stream = audio_stream
		dialogue_player.play()
		dialogue_played = true
		print("Playing crystal dialogue")