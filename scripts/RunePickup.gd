
extends Sprite2D
class_name RunePickup

@export var rune_type: RuneSystem.RuneType = RuneSystem.RuneType.RANGE_AMPLIFIER
@export var pickup_distance: float = 50.0

var rune_system: RuneSystem
var collected = false
var player_nearby = false
var current_player = null

func _ready():
	rune_system = get_node("../../RuneSystem")  
	setup_visual()

func setup_visual():
	if texture == null:
		var image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		texture = ImageTexture.create_from_image(image)
	
	z_index = 100

func _process(delta):
	if collected:
		return
	
	
	position.y += sin(Time.get_time_dict_from_system()["second"] * 2.0) * 0.2
	
	
	check_player_proximity()
	
	if player_nearby:
		
		var pulse = 0.8 + sin(Time.get_time_dict_from_system()["second"] * 5.0) * 0.2
		modulate.a = pulse
		
		
		if Input.is_key_pressed(KEY_G):
			collect_rune()
	else:
		
		var pulse = 0.5 + sin(Time.get_time_dict_from_system()["second"] * 2.0) * 0.2
		modulate.a = pulse

func check_player_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = get_node_or_null("../Player")
	
	if player == null:
		for child in get_tree().current_scene.get_children():
			if "Player" in child.name:
				player = child
				break
	
	if player == null:
		player_nearby = false
		current_player = null
		return
	
	var distance = global_position.distance_to(player.global_position)
	var was_nearby = player_nearby
	
	player_nearby = distance <= pickup_distance
	
	if player_nearby and not was_nearby:
		current_player = player
		print("Near rune - Press G to collect")
	elif not player_nearby and was_nearby:
		current_player = null

func collect_rune():
	if collected or not player_nearby:
		return
	
	
	if rune_system and rune_system.is_rune_on_cooldown(rune_type):
		var remaining = int(rune_system.get_rune_cooldown_time(rune_type))
		print("Rune on cooldown for ", remaining, " seconds")
		return
	
	collected = true
	
	
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(2.0, 2.0), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	
	
	await tween.finished
	
	
	if rune_system:
		await rune_system.activate_rune(rune_type)
	
	
	queue_free()
	
	print("Rune collected: ", get_rune_name())

func get_rune_name() -> String:
	match rune_type:
		RuneSystem.RuneType.RANGE_AMPLIFIER:
			return "Range Amplifier"
		RuneSystem.RuneType.DURATION_CRYSTAL:
			return "Duration Crystal"
		_:
			return "Unknown Rune"
