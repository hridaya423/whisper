
extends Area2D
class_name DarkProjectile

const SPEED = 300.0
const LIFETIME = 4.0

var direction = Vector2.RIGHT
var lifetime_timer = 0.0
var sprite: Sprite2D
var smoke_particles: CPUParticles2D

func _ready():
	
	collision_layer = 8  
	collision_mask = 1   
	
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	
	_create_dark_visuals()
	_create_collision()
	_create_smoke_trail()
	
	z_index = 99

func _create_dark_visuals():
	sprite = Sprite2D.new()
	add_child(sprite)
	
	
	var size = 36
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size/2, size/2)
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)
			var normalized_distance = distance / (size/2)
			
			
			var core_alpha = max(0, 1.0 - (normalized_distance * 1.5))  
			var energy_alpha = max(0, 0.7 - normalized_distance)  
			var alpha = max(core_alpha, energy_alpha * 0.4)
			
			
			var color: Color
			if core_alpha > 0.3:
				color = Color(0.4, 0.1, 0.6, alpha)  
			else:
				color = Color(0.1, 0.2, 0.5, alpha)  
			
			
			if randf() < 0.1 and alpha > 0.3:
				color = Color(0.6, 0.3, 0.8, alpha)  
			
			image.set_pixel(x, y, color)
	
	sprite.texture = ImageTexture.create_from_image(image)
	
	
	sprite.material = CanvasItemMaterial.new()
	sprite.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX

func _create_collision():
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14  
	collision.shape = shape
	add_child(collision)

func _create_smoke_trail():
	smoke_particles = CPUParticles2D.new()
	add_child(smoke_particles)
	
	smoke_particles.emitting = true
	smoke_particles.amount = 20
	smoke_particles.lifetime = 1.2
	smoke_particles.texture = null
	
	
	smoke_particles.direction = Vector2(-1, 0)
	smoke_particles.spread = 30.0
	smoke_particles.initial_velocity_min = 30.0
	smoke_particles.initial_velocity_max = 70.0
	smoke_particles.scale_amount_min = 0.4
	smoke_particles.scale_amount_max = 1.0
	
	
	var smoke_gradient = Gradient.new()
	smoke_gradient.add_point(0.0, Color(0.3, 0.1, 0.5, 0.6))
	smoke_gradient.add_point(0.5, Color(0.2, 0.1, 0.3, 0.4))
	smoke_gradient.add_point(1.0, Color(0.1, 0.05, 0.2, 0.0))
	smoke_particles.color_ramp = smoke_gradient

func _physics_process(delta):
	global_position += direction * SPEED * delta
	
	lifetime_timer += delta
	if lifetime_timer >= LIFETIME:
		_fade_out()
		return
	
	
	var wobble_x = sin(lifetime_timer * 8.0) * 3.0
	var wobble_y = cos(lifetime_timer * 6.0) * 2.0
	global_position += Vector2(wobble_x, wobble_y) * delta
	
	var pulse = 0.85 + sin(lifetime_timer * 10.0) * 0.15
	var energy_flicker = 1.0 + sin(lifetime_timer * 15.0) * 0.3
	
	sprite.scale = Vector2(pulse, pulse)
	sprite.modulate = Color(energy_flicker * 0.8, energy_flicker * 0.4, energy_flicker)
	sprite.rotation += delta * 3.0

func _on_body_entered(body):
	print("Dark projectile hit body: ", body.name)
	if body.name == "Player" and body.has_method("take_damage"):
		body.take_damage()
		_create_dark_impact_effect()
		queue_free()

func _on_area_entered(area):
	print("Dark projectile hit area: ", area.name)
	if area != self and not (area is DarkProjectile):
		_create_dark_impact_effect()
		queue_free()

func _create_dark_impact_effect():
	var impact = Node2D.new()
	get_parent().add_child(impact)
	impact.global_position = global_position
	
	var explosion = Sprite2D.new()
	impact.add_child(explosion)
	
	var explosion_image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	var center = Vector2(40, 40)
	
	for x in range(80):
		for y in range(80):
			var distance = Vector2(x, y).distance_to(center)
			var alpha = max(0, 0.8 - (distance / 40.0))
			
			explosion_image.set_pixel(x, y, Color(0.3, 0.1, 0.6, alpha))
	
	explosion.texture = ImageTexture.create_from_image(explosion_image)
	explosion.z_index = 98
	
	
	var dark_burst = CPUParticles2D.new()
	impact.add_child(dark_burst)
	dark_burst.emitting = false
	dark_burst.amount = 30
	dark_burst.lifetime = 0.8
	dark_burst.explosiveness = 1.0
	dark_burst.direction = Vector2(0, -1)
	dark_burst.spread = 360.0
	dark_burst.initial_velocity_min = 60.0
	dark_burst.initial_velocity_max = 120.0
	
	var dark_gradient = Gradient.new()
	dark_gradient.add_point(0.0, Color(0.4, 0.1, 0.6, 0.8))
	dark_gradient.add_point(0.5, Color(0.2, 0.1, 0.4, 0.6))
	dark_gradient.add_point(1.0, Color(0.1, 0.05, 0.2, 0.0))
	dark_burst.color_ramp = dark_gradient
	dark_burst.emitting = true
	
	var tween = impact.create_tween()
	tween.parallel().tween_property(explosion, "scale", Vector2(2.5, 2.5), 0.5)
	tween.parallel().tween_property(explosion, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): impact.queue_free())

func _fade_out():
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(smoke_particles, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func(): queue_free())
