extends Area2D
class_name LightProjectile

const SPEED = 400.0
const LIFETIME = 3.0

var direction = Vector2.RIGHT
var lifetime_timer = 0.0
var sprite: Sprite2D
var glow_particles: CPUParticles2D

func _ready():
	
	collision_layer = 4  
	collision_mask = 2   
	
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	
	_create_light_visuals()
	_create_collision()
	_create_particle_trail()
	
	z_index = 100

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

func _physics_process(delta):
	
	global_position += direction * SPEED * delta
	
	
	lifetime_timer += delta
	if lifetime_timer >= LIFETIME:
		_fade_and_destroy()
		return
	
	
	var pulse = 0.9 + sin(lifetime_timer * 12.0) * 0.1
	var brightness = 1.0 + sin(lifetime_timer * 8.0) * 0.2
	
	sprite.scale = Vector2(pulse, pulse)
	sprite.modulate = Color(brightness, brightness, brightness * 0.9)
	
	
	sprite.rotation += delta * 4.0

func _on_body_entered(body):
	print("Light projectile hit body: ", body.name)
	if body.has_method("take_damage") and body != get_parent().get_node("Player"):
		body.take_damage()
		_create_light_impact_effect()
		queue_free()

func _on_area_entered(area):
	print("Light projectile hit area: ", area.name)
	if area != self and not (area is LightProjectile):
		_create_light_impact_effect()
		queue_free()

func _create_light_impact_effect():
	
	var impact = Node2D.new()
	get_parent().add_child(impact)
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
	var tween = create_tween()
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(glow_particles, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): queue_free())
