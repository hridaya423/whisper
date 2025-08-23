extends Node

func _ready():
	RenderingServer.set_default_clear_color(Color.BLACK)
	var player = get_node("../Player")
	if player:
		player.player_died.connect(_on_player_died)

func _on_player_died():
	var fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = get_viewport().size
	get_tree().root.add_child(fade)
	
	var tween = create_tween()
	tween.tween_property(fade, "color", Color(0, 0, 0, 1), 0.5)
	await tween.finished
	
	get_tree().change_scene_to_file("res://scenes/ui/DeathScreen.tscn")

func _on_player_sonar_pulse(position: Vector2, range: float, direction: Vector2):
	var sonar_system = get_node("../SonarSystem")
	if sonar_system:
		sonar_system._on_sonar_pulse(position, range, direction)
