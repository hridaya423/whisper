extends Node
class_name BossCinematic

const Boss = preload("res://scripts/bosses/Boss.gd")

var boss: Boss
var player: Player
var camera: Camera2D
var dialogue_system

var _canvas: CanvasLayer
var _active_camera_tweens: Array[Tween] = []

func _get_canvas() -> CanvasLayer:
	if not is_instance_valid(_canvas):
		_canvas = CanvasLayer.new()
		_canvas.name = "CinematicCanvas"
		get_tree().root.add_child(_canvas)
	return _canvas

func _register_camera_tween(tween: Tween) -> Tween:
	_active_camera_tweens.append(tween)
	tween.finished.connect(func():
		_active_camera_tweens.erase(tween)
	)
	return tween

func _create_camera_tween() -> Tween:
	return _register_camera_tween(create_tween())

func _stop_camera_tweens():
	if _active_camera_tweens.is_empty():
		return
	for tween in _active_camera_tweens:
		if tween and tween.is_running():
			tween.kill()
	_active_camera_tweens.clear()

var original_camera_position: Vector2
var original_camera_zoom: Vector2
var original_camera_parent: Node
var player_input_locked: bool = false

signal cinematic_finished

var dialogue_system_initialized = false
var can_skip: bool = false
var cinematic_skipped: bool = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	camera = get_tree().get_first_node_in_group("camera")
	if boss and not dialogue_system_initialized:
		_create_dialogue_system()

func setup_for_boss(target_boss: Boss):
	boss = target_boss
	if not dialogue_system_initialized:
		call_deferred("_create_dialogue_system")

func _create_dialogue_system():
	if dialogue_system_initialized:
		return
	dialogue_system_initialized = true

	var BossDialogueScript = load("res://scripts/bosses/BossDialogue.gd")
	dialogue_system = BossDialogueScript.new()
	_get_canvas().add_child(dialogue_system)
	dialogue_system.setup_for_boss(boss)
	dialogue_system.all_dialogue_completed.connect(_on_dialogue_finished)

func start_cinematic():
	cinematic_skipped = false
	can_skip = false

	if not player:
		player = get_tree().get_first_node_in_group("player")
		print("[CINEMATIC] Retrieved player: ", player != null)

	if not camera:
		camera = get_tree().get_first_node_in_group("camera")

	if not camera:
		camera = get_viewport().get_camera_2d()

	_lock_player_input()
	_store_camera_state()

	if not dialogue_system:
		_create_dialogue_system()
		await get_tree().process_frame

	can_skip = true
	await _play_entrance_sequence()

	if cinematic_skipped:
		_finish_cinematic_immediately()
		return

	await _play_dialogue_sequence()

	if cinematic_skipped:
		_finish_cinematic_immediately()
		return

	print("Cinematic sequence complete!")

func _input(event):
	if can_skip and not cinematic_skipped:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			print("[CINEMATIC] SKIPPED!")
			cinematic_skipped = true

func _finish_cinematic_immediately():
	var canvas = _get_canvas()
	for child in canvas.get_children():
		if child.name == "CinematicVignette" or child is ColorRect:
			child.queue_free()

	_stop_camera_tweens()

	if camera:
		camera.offset = Vector2.ZERO
		camera.zoom = original_camera_zoom
		camera.rotation = 0.0

	Engine.time_scale = 1.0
	if boss and boss.boss_ui:
		boss.boss_ui.show_health_bar()

	_restore_camera_and_unlock()

func _lock_player_input():
	player_input_locked = true
	if player:
		player.set_physics_process(false)
		player.velocity = Vector2.ZERO

	_stop_camera_tweens()

	if camera:
		original_camera_parent = camera.get_parent()
		var camera_global_pos = camera.global_position

		print("[CINEMATIC] BEFORE reparent - Parent: ", original_camera_parent.name)
		print("[CINEMATIC] BEFORE reparent - Global pos: ", camera_global_pos)
		print("[CINEMATIC] BEFORE reparent - Local pos: ", camera.position)

		camera.reparent(get_tree().current_scene)
		camera.global_position = camera_global_pos

		print("[CINEMATIC] AFTER reparent - Parent: ", camera.get_parent().name)
		print("[CINEMATIC] AFTER reparent - Global pos: ", camera.global_position)
		print("[CINEMATIC] AFTER reparent - Local pos: ", camera.position)
		print("[CINEMATIC] Camera enabled: ", camera.enabled)

		camera.position_smoothing_enabled = false
		camera.enabled = true
		print("[CINEMATIC] Camera reparented and ready for control")

func _unlock_player_input():
	player_input_locked = false
	if player:
		player.set_physics_process(true)

	_stop_camera_tweens()

	if camera and original_camera_parent:
		camera.reparent(original_camera_parent)
		camera.position = Vector2.ZERO
		if player:
			camera.global_position = player.global_position
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0
		camera.position_smoothing_enabled = true

func _store_camera_state():
	if camera:
		original_camera_position = camera.global_position
		original_camera_zoom = camera.zoom
		print("Stored camera state - pos: ", original_camera_position, " zoom: ", original_camera_zoom)

func _play_entrance_sequence():
	if player:
		player.velocity = Vector2.ZERO

	var black_screen = ColorRect.new()
	black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black_screen.color = Color.BLACK
	black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_canvas().add_child(black_screen)

	await get_tree().create_timer(0.2).timeout

	var fade = create_tween()
	fade.tween_property(black_screen, "modulate:a", 0.0, 0.3)
	await fade.finished
	black_screen.queue_free()

	await _fade_screen_edges()

	await _boss_entrance_effects()

func _fade_screen_edges():
	var vignette_container = Control.new()
	vignette_container.name = "CinematicVignette"
	vignette_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_canvas().add_child(vignette_container)

	var top_bar = ColorRect.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 80 
	top_bar.color = Color.BLACK
	top_bar.modulate.a = 0.0
	vignette_container.add_child(top_bar)

	var bottom_bar = ColorRect.new()
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = -80  
	bottom_bar.color = Color.BLACK
	bottom_bar.modulate.a = 0.0
	vignette_container.add_child(bottom_bar)

	var fade_tween = create_tween()
	fade_tween.parallel().tween_property(top_bar, "modulate:a", 1.0, 0.5)
	fade_tween.parallel().tween_property(bottom_bar, "modulate:a", 1.0, 0.5)
	await fade_tween.finished

func _camera_pan_to_boss():
	if not camera or not boss or not player:
		print("ERROR: Camera pan failed - missing components")
		return

	Engine.time_scale = 0.3

	var cam_tween = _create_camera_tween()
	cam_tween.set_trans(Tween.TRANS_SINE)
	cam_tween.set_ease(Tween.EASE_IN_OUT)

	var boss_focus_pos = boss.global_position + Vector2(0, -80)
	cam_tween.tween_property(camera, "global_position", boss_focus_pos, 2.5)
	cam_tween.parallel().tween_property(camera, "zoom", Vector2(1.3, 1.3), 2.5)

	cam_tween.tween_interval(2.0)

	var final_pos = boss.global_position + Vector2(0, -40)
	cam_tween.tween_property(camera, "global_position", final_pos, 2.0)
	cam_tween.parallel().tween_property(camera, "zoom", Vector2(1.1, 1.1), 2.0)

	await cam_tween.finished

	Engine.time_scale = 1.0

func _boss_entrance_effects():
	var pulse_count = 3
	for i in range(pulse_count):
		var intensity = float(i + 1) / pulse_count
		_create_tension_pulse(intensity)
		await get_tree().create_timer(0.2).timeout

	await get_tree().create_timer(0.2).timeout

	var flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.8, 0.2, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_canvas().add_child(flash)

	for i in range(3):
		var color_flash = ColorRect.new()
		color_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 0:
			color_flash.color = Color(0.5, 0.1, 0.2)
		elif i == 1:
			color_flash.color = Color(0.3, 0.1, 0.4)
		else:
			color_flash.color = Color(0.2, 0.05, 0.1)
		color_flash.modulate.a = 0.4
		_get_canvas().add_child(color_flash)

		var color_tween = create_tween()
		color_tween.tween_property(color_flash, "modulate:a", 0.0, 0.2)
		color_tween.tween_callback(func(): color_flash.queue_free())

	_create_boss_entrance_particles()

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(func(): flash.queue_free())

	_create_dramatic_screen_shake()

	_create_shockwave()

	_show_boss_title_card()

	await get_tree().create_timer(1.2).timeout

func _create_tension_pulse(intensity: float):
	var pulse = ColorRect.new()
	pulse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pulse.color = Color.WHITE
	pulse.modulate.a = 0.0
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_canvas().add_child(pulse)

	var max_alpha = 0.3 * intensity
	var pulse_tween = create_tween()
	pulse_tween.tween_property(pulse, "modulate:a", max_alpha, 0.08)
	pulse_tween.tween_property(pulse, "modulate:a", 0.0, 0.25)
	pulse_tween.tween_callback(func(): pulse.queue_free())

	if camera:
		var shake_amount = 15.0 * intensity
		var current_pos = camera.global_position
		var shake_offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		var shake_tween = _create_camera_tween()
		shake_tween.tween_property(camera, "global_position", current_pos + shake_offset, 0.05)
		shake_tween.tween_property(camera, "global_position", current_pos, 0.2)

func _show_boss_title_card():
	var title_container = Control.new()
	title_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_canvas().add_child(title_container)

	var boss_name_label = Label.new()
	boss_name_label.text = boss.boss_name
	boss_name_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	boss_name_label.offset_left = -500
	boss_name_label.offset_right = 500
	boss_name_label.offset_top = -60
	boss_name_label.offset_bottom = 60
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var scary_font = load("res://assets/fonts/October Crow.ttf")
	var font_size = 96
	boss_name_label.add_theme_font_override("font", scary_font)
	boss_name_label.add_theme_font_size_override("font_size", font_size)
	boss_name_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.3))
	boss_name_label.add_theme_color_override("font_outline_color", Color(0.1, 0.0, 0.05))
	boss_name_label.add_theme_constant_override("outline_size", 14)

	boss_name_label.modulate.a = 0.0
	title_container.add_child(boss_name_label)

	var title_tween = create_tween()
	title_tween.tween_property(boss_name_label, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	title_tween.tween_interval(0.8)
	title_tween.tween_property(boss_name_label, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	title_tween.tween_callback(func(): title_container.queue_free())

func _create_shockwave():
	for i in range(3):
		await get_tree().create_timer(0.15 * i).timeout

		var shockwave = Node2D.new()
		boss.add_child(shockwave)

		var wave_sprite = Sprite2D.new()
		shockwave.add_child(wave_sprite)

		var size = 128
		var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		var center = Vector2(size/2, size/2)

		for x in range(size):
			for y in range(size):
				var pos = Vector2(x, y)
				var dist = pos.distance_to(center)
				var normalized_dist = dist / (size/2)

				var ring_intensity = 0.0
				if normalized_dist > 0.8 and normalized_dist < 1.0:
					ring_intensity = (1.0 - abs(normalized_dist - 0.9) / 0.1)

				var alpha = ring_intensity * 0.9
				image.set_pixel(x, y, Color(0.6, 0.2, 0.3, alpha))

		wave_sprite.texture = ImageTexture.create_from_image(image)
		wave_sprite.material = CanvasItemMaterial.new()
		wave_sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

		var expand_tween = create_tween()
		expand_tween.parallel().tween_property(wave_sprite, "scale", Vector2(10, 10), 1.2).set_ease(Tween.EASE_OUT)
		expand_tween.parallel().tween_property(wave_sprite, "modulate:a", 0.0, 1.2)
		expand_tween.tween_callback(func(): shockwave.queue_free())

func _create_boss_entrance_particles():
	var entrance_particles = CPUParticles2D.new()
	boss.add_child(entrance_particles)

	match boss.boss_type:
		Boss.BossType.SENTINEL:
			_setup_sentinel_entrance_particles(entrance_particles)
		Boss.BossType.DREAD:
			_setup_dread_entrance_particles(entrance_particles)
		Boss.BossType.WRAITH:
			_setup_wraith_entrance_particles(entrance_particles)
		Boss.BossType.LORD_OF_DARKNESS:
			_setup_lord_entrance_particles(entrance_particles)

	entrance_particles.emitting = true
	entrance_particles.restart()

func _setup_sentinel_entrance_particles(particles: CPUParticles2D):
	particles.amount = 150
	particles.lifetime = 2.5
	particles.direction = Vector2(0, -1)
	particles.spread = 360.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 200.0
	particles.color = Color(0.3, 0.15, 0.25, 0.9)
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 2.5

func _setup_dread_entrance_particles(particles: CPUParticles2D):
	particles.amount = 80
	particles.lifetime = 3.0
	particles.direction = Vector2(0, 0)
	particles.spread = 360.0
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 80.0
	particles.color = Color(0.2, 0.1, 0.4, 0.9)
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 1.5

func _setup_wraith_entrance_particles(particles: CPUParticles2D):
	particles.amount = 60
	particles.lifetime = 4.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 100.0
	particles.color = Color(0.4, 0.7, 1.0, 0.6)
	particles.scale_amount_min = 0.2
	particles.scale_amount_max = 1.0

func _setup_lord_entrance_particles(particles: CPUParticles2D):
	particles.amount = 150
	particles.lifetime = 3.5
	particles.direction = Vector2(0, 0)
	particles.spread = 360.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.color = Color(0.8, 0.1, 0.1, 1.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 3.0

func _create_dramatic_screen_shake():
	if not camera:
		return

	print("Creating dramatic screen shake")
	var base_pos = camera.global_position

	for i in range(20):
		var shake_tween = _create_camera_tween()
		var intensity = lerp(40.0, 8.0, float(i) / 20.0)
		var shake_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(camera, "global_position", base_pos + shake_offset, 0.08)
		shake_tween.tween_property(camera, "global_position", base_pos, 0.08)
		await get_tree().create_timer(0.04).timeout

	print("Screen shake complete")

func _play_dialogue_sequence():
	var dialogue_lines = boss.get_boss_dialogue()
	print("Playing dialogue sequence. Lines: ", dialogue_lines)

	if not dialogue_lines or dialogue_lines.is_empty():
		print("No dialogue lines found!")
		_on_dialogue_finished()
		return

	if dialogue_system:
		print("Starting dialogue with ", dialogue_lines.size(), " lines")

		dialogue_system.create_boss_specific_effects()
		dialogue_system.start_dialogue(dialogue_lines)

		await _camera_pan_to_boss()

		await dialogue_system.all_dialogue_completed

		print("Dialogue and camera pan completed!")
	else:
		print("No dialogue system")
		_on_dialogue_finished()

func _on_dialogue_finished():
	await _camera_return_to_player()
	_unlock_player_input()
	await _remove_vignette()
	cinematic_finished.emit()

func _camera_return_to_player():
	if not camera or not player:
		return

	var return_tween = _create_camera_tween()
	return_tween.tween_property(camera, "global_position", player.global_position, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return_tween.parallel().tween_property(camera, "zoom", original_camera_zoom, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await return_tween.finished

func _remove_vignette():
	var vignette = _get_canvas().get_node_or_null("CinematicVignette")

	if vignette:
		var fade_out_tween = create_tween()
		fade_out_tween.tween_property(vignette, "modulate:a", 0.0, 1.0)
		fade_out_tween.tween_callback(func():
			if is_instance_valid(vignette):
				vignette.queue_free()
		)
		await fade_out_tween.finished

func _restore_camera_and_unlock():
	_unlock_player_input()

func create_boss_specific_cinematic_effects():
	match boss.boss_type:
		Boss.BossType.SENTINEL:
			_create_sentinel_cinematic()
		Boss.BossType.DREAD:
			_create_dread_cinematic()
		Boss.BossType.WRAITH:
			_create_wraith_cinematic()
		Boss.BossType.LORD_OF_DARKNESS:
			_create_lord_cinematic()

func _create_sentinel_cinematic():
	var ground_rumble = create_tween()
	ground_rumble.set_loops(10)
	ground_rumble.tween_callback(_create_small_screen_shake)
	ground_rumble.tween_interval(0.2)

func _create_dread_cinematic():
	var darkness_overlay = ColorRect.new()
	darkness_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	darkness_overlay.color = Color(0.1, 0.0, 0.2, 0.0)
	
	_get_canvas().add_child(darkness_overlay)

	var darkness_tween = create_tween()
	darkness_tween.tween_property(darkness_overlay, "color:a", 0.4, 2.0)

func _create_wraith_cinematic():
	var ethereal_distortion = _create_camera_tween()
	ethereal_distortion.set_loops(5)
	ethereal_distortion.tween_property(camera, "zoom", Vector2(1.3, 1.3), 0.3)
	ethereal_distortion.tween_property(camera, "zoom", Vector2(1.7, 1.7), 0.3)

func _create_lord_cinematic():
	var reality_distortion = ColorRect.new()
	reality_distortion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reality_distortion.color = Color(0.5, 0.1, 0.1, 0.0)

	_get_canvas().add_child(reality_distortion)

	var distortion_tween = create_tween()
	distortion_tween.tween_property(reality_distortion, "color:a", 0.6, 1.0)
	distortion_tween.tween_property(reality_distortion, "color:a", 0.0, 1.0)

func _create_small_screen_shake():
	if camera:
		var small_shake = _create_camera_tween()
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		small_shake.tween_property(camera, "offset", offset, 0.05)
		small_shake.tween_property(camera, "offset", Vector2.ZERO, 0.05)
