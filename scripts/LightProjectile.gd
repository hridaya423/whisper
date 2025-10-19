extends Area2D
class_name LightProjectile
const SPEED = 400.0
const LIFETIME = 3.0
var direction = Vector2.RIGHT
var lifetime_timer = 0.0
var sprite: Sprite2D
var glow_particles: CPUParticles2D
var charge_level = 0.0
var base_size = 32
var base_damage = 1
var base_speed = 400.0
var meteor_shield: Sprite2D
var meteor_trail: CPUParticles2D
func set_direction(value: Vector2):
	direction = value.normalized() if value.length_squared() > 0 else Vector2.RIGHT
	rotation = direction.angle()
func set_charge_level(level: float):
	charge_level = clamp(level, 0.0, 1.0)
	if charge_level > 0.5:
		_create_meteor_effect()
	else:
		if sprite:
			var charge_color = Color.WHITE.lerp(Color(0.3, 0.6, 1.0), charge_level)
			sprite.modulate = charge_color
	var collision = get_child(0) if get_child_count() > 0 else null
	if collision and collision is CollisionShape2D:
		var shape = collision.shape as CircleShape2D
		if shape:
			shape.radius = 12 + (charge_level * 8)
	if glow_particles:
		glow_particles.amount = int(15 + (charge_level * 25))
		glow_particles.scale_amount_max = 0.8 + (charge_level * 0.7)
func _ready():
	add_to_group("player_projectiles")

	if direction.length_squared() == 0:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	rotation = direction.angle()
	collision_layer = 4
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_create_light_visuals()
	_create_collision()
	_create_particle_trail()
	z_index = 100

func _exit_tree():
	if glow_particles and is_instance_valid(glow_particles):
		glow_particles.emitting = false
	if meteor_trail and is_instance_valid(meteor_trail):
		meteor_trail.emitting = false
func _create_light_visuals():
	sprite = Sprite2D.new()
	add_child(sprite)
	var size = 32
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size/2, size/2)
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			var normalized_distance = distance / (size/2)
			var core_alpha = max(0, 1.0 - (normalized_distance * 2.0))
			var glow_alpha = max(0, 0.6 - normalized_distance)
			var alpha = max(core_alpha, glow_alpha * 0.3)
			var color: Color
			if core_alpha > 0:
				color = Color(1.0, 1.0, 1.0, alpha)
			else:
				color = Color(1.0, 0.9, 0.6, alpha)
			image.set_pixel(x, y, color)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.material = CanvasItemMaterial.new()
	sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
func _create_collision():
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12
	collision.shape = shape
	add_child(collision)
func _create_particle_trail():
	glow_particles = CPUParticles2D.new()
	add_child(glow_particles)
	glow_particles.emitting = true
	glow_particles.amount = 15
	glow_particles.lifetime = 0.8
	glow_particles.texture = null
	glow_particles.direction = Vector2(-1, 0)
	glow_particles.spread = 20.0
	glow_particles.initial_velocity_min = 20.0
	glow_particles.initial_velocity_max = 50.0
	glow_particles.scale_amount_min = 0.3
	glow_particles.scale_amount_max = 0.8
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 0.8, 0.8))
	gradient.add_point(1.0, Color(1.0, 0.6, 0.2, 0.0))
	glow_particles.color_ramp = gradient
func _create_meteor_effect():
	meteor_shield = Sprite2D.new()
	add_child(meteor_shield)
	meteor_shield.position = Vector2(25, 0)
	meteor_shield.z_index = -1
	var shield_size = Vector2(60, 40)
	var texture = ImageTexture.new()
	var image = Image.create(int(shield_size.x), int(shield_size.y), false, Image.FORMAT_RGBA8)
	for x in range(int(shield_size.x)):
		for y in range(int(shield_size.y)):
			var pos = Vector2(x, y)
			var center = Vector2(shield_size.x/2, shield_size.y/2)
			var normalized_x = (x - center.x) / (shield_size.x/2)
			var normalized_y = (y - center.y) / (shield_size.y/2)
			var flame_intensity = 0.0
			if normalized_x < 0:
				var back_intensity = 1.0 - abs(normalized_y) * 1.2
				flame_intensity = max(0, back_intensity * (1.0 + normalized_x * 0.5))
			else:
				var front_intensity = 1.0 - abs(normalized_y) * 2.0
				flame_intensity = max(0, front_intensity * (1.0 - normalized_x * 1.5))
			var fire_color: Color
			if flame_intensity > 0.7:
				fire_color = Color(1.0, 1.0, 0.9, flame_intensity)
			elif flame_intensity > 0.4:
				fire_color = Color(0.3, 0.7, 1.0, flame_intensity * 0.8)
			else:
				fire_color = Color(0.1, 0.4, 0.8, flame_intensity * 0.6)
			image.set_pixel(x, y, fire_color)
	texture.set_image(image)
	meteor_shield.texture = texture
	meteor_shield.material = CanvasItemMaterial.new()
	meteor_shield.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	meteor_trail = CPUParticles2D.new()
	add_child(meteor_trail)
	meteor_trail.position = Vector2(-10, 0)
	meteor_trail.emitting = true
	meteor_trail.amount = 30
	meteor_trail.lifetime = 1.2
	meteor_trail.direction = Vector2(-1, 0)
	meteor_trail.spread = 30.0
	meteor_trail.initial_velocity_min = 50.0
	meteor_trail.initial_velocity_max = 100.0
	meteor_trail.scale_amount_min = 0.5
	meteor_trail.scale_amount_max = 1.2
	var trail_gradient = Gradient.new()
	trail_gradient.add_point(0.0, Color(0.3, 0.8, 1.0, 1.0))
	trail_gradient.add_point(0.7, Color(1.0, 0.8, 0.3, 0.6))
	trail_gradient.add_point(1.0, Color(0.1, 0.1, 0.3, 0.0))
	meteor_trail.color_ramp = trail_gradient
func _physics_process(delta):
	rotation = direction.angle()
	var current_speed = base_speed * (1.0 + charge_level * 0.5)
	global_position += direction * current_speed * delta
	lifetime_timer += delta
	if lifetime_timer >= LIFETIME:
		_fade_and_destroy()
		return
	if charge_level > 0.5 and meteor_shield:
		sprite.scale = Vector2(1.0, 1.0)
		sprite.modulate = Color(1.2, 1.2, 1.2, 0.8)
		if meteor_shield:
			var flicker = 0.8 + sin(lifetime_timer * 15.0) * 0.2
			meteor_shield.modulate = Color(flicker, flicker * 0.9, flicker * 1.1)
			meteor_shield.rotation = sin(lifetime_timer * 8.0) * 0.1
	else:
		var pulse = 0.9 + sin(lifetime_timer * 12.0) * 0.1
		var brightness = 1.0 + sin(lifetime_timer * 8.0) * 0.2
		sprite.scale = Vector2(pulse, pulse)
		sprite.modulate = Color(brightness, brightness, brightness * 0.9)
		sprite.rotation += delta * 4.0
func _on_body_entered(body):
	print("Light projectile hit body: ", body.name)
	if body.has_method("take_damage"):
		var damage_amount = base_damage + int(charge_level * 2)

		if body.is_in_group("bosses"):
			var boss_hit_config: Dictionary = {
				"is_player_attack": true,
				"is_projectile": true,
				"projectile_charge": charge_level
			}
			body.take_damage(damage_amount, global_position, boss_hit_config)
		else:
			var enemy_hit_config: Dictionary = {
				"is_player_attack": true,
				"is_projectile": true,
				"projectile_charge": charge_level
			}
			for i in range(damage_amount):
				body.take_damage(1, global_position, enemy_hit_config)

		_create_light_impact_effect()
		queue_free()
func _on_area_entered(area):
	print("Light projectile hit area: ", area.name)
	if area != self and not (area is LightProjectile):
		_create_light_impact_effect()
		queue_free()
func _create_light_impact_effect():
	var parent = get_parent()
	if not parent or not is_instance_valid(parent):
		return
	var impact = Node2D.new()
	parent.add_child(impact)
	impact.global_position = global_position
	var flash = Sprite2D.new()
	impact.add_child(flash)
	var flash_image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center = Vector2(32, 32)
	for x in range(64):
		for y in range(64):
			var distance = Vector2(x, y).distance_to(center)
			var alpha = max(0, 1.0 - (distance / 32.0))
			flash_image.set_pixel(x, y, Color(1.0, 1.0, 0.9, alpha))
	flash.texture = ImageTexture.create_from_image(flash_image)
	flash.material = CanvasItemMaterial.new()
	flash.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flash.z_index = 99
	var burst = CPUParticles2D.new()
	impact.add_child(burst)
	burst.emitting = false
	burst.amount = 25
	burst.lifetime = 0.6
	burst.explosiveness = 1.0
	burst.direction = Vector2(0, -1)
	burst.spread = 360.0
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 150.0
	burst.scale_amount_min = 0.5
	burst.scale_amount_max = 1.2
	var burst_gradient = Gradient.new()
	burst_gradient.add_point(0.0, Color(1.0, 1.0, 0.8, 1.0))
	burst_gradient.add_point(1.0, Color(1.0, 0.4, 0.1, 0.0))
	burst.color_ramp = burst_gradient
	burst.emitting = true
	var tween = impact.create_tween()
	tween.parallel().tween_property(flash, "scale", Vector2(3.0, 3.0), 0.4)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.finished.connect(func(): impact.queue_free())
func _fade_and_destroy():
	if not is_instance_valid(self):
		return
	var tween = create_tween()
	if sprite and is_instance_valid(sprite):
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	if glow_particles and is_instance_valid(glow_particles):
		tween.parallel().tween_property(glow_particles, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		if is_instance_valid(self):
			queue_free()
	)
