extends Node

var rune_system: RuneSystem
var player: Node
var sonar_system: Node

var active_synergy = null
var synergy_uses_remaining = 0
var corruption_effects = []

signal synergy_activated(synergy_data: Dictionary)
signal synergy_used(uses_remaining: int)
signal synergy_expired
signal corruption_started(corruption_data: Dictionary)


var minor_buffs = [
	{"type": "health_boost", "value": 20, "display": "+20 health"},
	{"type": "sonar_range", "value": 1.3, "display": "+30% sonar range"},
	{"type": "sonar_duration", "value": 1.3, "display": "+30% sonar duration"},
	{"type": "attack_damage", "value": 1.3, "display": "+30% attack damage"},
	{"type": "movement_speed", "value": 1.2, "display": "+20% movement speed"}
]

var major_buffs = [
	{"type": "health_boost", "value": 50, "display": "+50 health"},
	{"type": "sonar_range", "value": 1.6, "display": "+60% sonar range"},
	{"type": "sonar_duration", "value": 1.6, "display": "+60% sonar duration"},
	{"type": "cooldown_reduction", "value": 0.7, "display": "-30% sonar cooldown"},
	{"type": "attack_damage", "value": 1.6, "display": "+60% attack damage"},
	{"type": "movement_speed", "value": 1.4, "display": "+40% movement speed"}
]

var ultimate_buffs = [
	{"type": "health_boost", "value": 100, "display": "+100 health"},
	{"type": "sonar_range", "value": 2.0, "display": "+100% sonar range"},
	{"type": "sonar_duration", "value": 2.0, "display": "+100% sonar duration"},
	{"type": "cooldown_reduction", "value": 0.5, "display": "-50% sonar cooldown"},
	{"type": "attack_damage", "value": 2.0, "display": "+100% attack damage"},
	{"type": "movement_speed", "value": 1.6, "display": "+60% movement speed"}
]

var temp_debuffs = [
	{
		"type": "flickering_sonar", "display": "sonar flicker (10 uses)",
		"data": {"frequency": 2, "intensity": 0.6, "uses_remaining": 10}, "is_permanent": false
	},
	{
		"type": "shrinking_range", "display": "unstable range (10 uses)",
		"data": {"min_range": 0.5, "max_range": 1.0, "uses_remaining": 10}, "is_permanent": false
	},
	{
		"type": "weakened_attack", "display": "weak attacks (10 uses)",
		"data": {"damage_multiplier": 0.7, "uses_remaining": 10}, "is_permanent": false
	}
]

var permanent_debuffs = [
	{
		"type": "flickering_sonar", "display": "permanent sonar flicker",
		"data": {"frequency": 1, "intensity": 0.4, "uses_remaining": -1}, "is_permanent": true
	},
	{
		"type": "shrinking_range", "display": "permanent range chaos",
		"data": {"min_range": 0.3, "max_range": 0.9, "uses_remaining": -1}, "is_permanent": true
	},
	{
		"type": "weakened_attack", "display": "permanent weak attacks",
		"data": {"damage_multiplier": 0.6, "uses_remaining": -1}, "is_permanent": true
	}
]

var synergy_names = [
	"whisper", "echo", "pulse", "void", "shadow", "silence", "drift", "fade"
]

func _ready():
	await get_tree().process_frame
	rune_system = get_node("../RuneSystem")
	player = get_tree().get_first_node_in_group("player")
	sonar_system = get_node("../SonarSystem")

func _process(delta):
	if corruption_effects.size() > 0:
		_update_corruption_effects(delta)

func can_create_synergy() -> Dictionary:
	var inventory = rune_system.get_inventory()

	var total = 0
	for count in inventory.values():
		total += count

	if total < 2:
		return {"can_synergize": false, "reason": "Need at least 2 runes in inventory"}

	if active_synergy != null:
		return {"can_synergize": false, "reason": "Already have active synergy"}

	var synergies = []

	synergies.append({
		"runes": [],
		"synergy": _create_synergy("minor", 2, "temp", 1, 3)
	})

	synergies.append({
		"runes": [],
		"synergy": _create_synergy("major", 2, "temp", randi_range(1, 2), 2)
	})

	synergies.append({
		"runes": [],
		"synergy": _create_synergy("major", 3, "permanent", 1, 3)
	})

	synergies.append({
		"runes": [],
		"synergy": _create_synergy("ultimate", 4, "permanent", 2, 1)
	})

	var mixed = _create_synergy("major", 2, "mixed", 2, 2)
	synergies.append({
		"runes": [],
		"synergy": mixed
	})

	return {"can_synergize": true, "synergies": synergies}

func _create_synergy(buff_tier: String, buff_count: int, debuff_tier: String, debuff_count: int, uses: int) -> Dictionary:
	var name = synergy_names[randi() % synergy_names.size()]

	var buffs = []
	var buff_pool = []
	match buff_tier:
		"minor": buff_pool = minor_buffs.duplicate()
		"major": buff_pool = major_buffs.duplicate()
		"ultimate": buff_pool = ultimate_buffs.duplicate()

	for i in range(min(buff_count, buff_pool.size())):
		var idx = randi() % buff_pool.size()
		buffs.append(buff_pool[idx].duplicate())
		buff_pool.remove_at(idx)

	var debuffs = []
	var debuff_pool = []

	if debuff_tier == "temp":
		debuff_pool = temp_debuffs.duplicate()
	elif debuff_tier == "permanent":
		debuff_pool = permanent_debuffs.duplicate()
	elif debuff_tier == "mixed":
		debuff_pool = temp_debuffs.duplicate() + permanent_debuffs.duplicate()

	for i in range(min(debuff_count, debuff_pool.size())):
		var idx = randi() % debuff_pool.size()
		debuffs.append(debuff_pool[idx].duplicate())
		debuff_pool.remove_at(idx)

	return {
		"name": name,
		"buffs": buffs,
		"debuffs": debuffs,
		"uses": uses,
		"description": "",
		"warning": ""
	}

func activate_synergy(rune_types: Array, synergy_data: Dictionary) -> bool:
	if not player or not rune_system:
		return false

	var active_rune_bonuses = _calculate_active_rune_bonuses()

	if not _consume_runes_from_inventory():
		print("Failed to consume runes from inventory")
		return false

	active_synergy = synergy_data
	synergy_uses_remaining = synergy_data.uses

	_apply_buffs(synergy_data.buffs)

	_apply_active_rune_bonuses(active_rune_bonuses, 0.6)

	_create_activation_particles()

	synergy_activated.emit(synergy_data)
	return true

func _calculate_active_rune_bonuses() -> Dictionary:
	"""Calculate bonuses from currently active runes"""
	var bonuses = {
		"range": rune_system.get_range_multiplier(),
		"duration": rune_system.get_duration_multiplier(),
		"cooldown": rune_system.get_cooldown_multiplier()
	}
	print("Active rune bonuses - Range: ", bonuses.range, "x, Duration: ", bonuses.duration, "x, Cooldown: ", bonuses.cooldown, "x")
	return bonuses

func _apply_active_rune_bonuses(bonuses: Dictionary, scale: float):

	if bonuses.range > 1.0:
		var range_bonus = (bonuses.range - 1.0) * scale
		var current_mult = player.get_meta("synergy_sonar_range", 1.0)
		player.set_meta("synergy_sonar_range", current_mult * (1.0 + range_bonus))
		print("Added scaled rune range bonus: +", range_bonus * 100, "% (total synergy range: ", current_mult * (1.0 + range_bonus), "x)")

	if bonuses.duration > 1.0:
		var duration_bonus = (bonuses.duration - 1.0) * scale
		var current_mult = player.get_meta("synergy_sonar_duration", 1.0)
		player.set_meta("synergy_sonar_duration", current_mult * (1.0 + duration_bonus))
		print("Added scaled rune duration bonus: +", duration_bonus * 100, "%")

	if bonuses.cooldown < 1.0:
		var cooldown_reduction = (1.0 - bonuses.cooldown) * scale
		var current_mult = player.get_meta("synergy_cooldown_mult", 1.0)
		player.set_meta("synergy_cooldown_mult", current_mult * (1.0 - cooldown_reduction))

func _consume_runes_from_inventory() -> bool:
	var inventory = rune_system.get_inventory()
	var total_inventory = 0
	for count in inventory.values():
		total_inventory += count

	if total_inventory < 2:
		return false

	var active_runes = rune_system.get_active_runes()
	for i in range(active_runes.size()):
		if active_runes[i] != null:
			print("Deactivating active rune in slot ", i)
			rune_system.deactivate_rune(i)

	var consumed = 0
	for rune_type in inventory.keys():
		while inventory[rune_type] > 0 and consumed < 2:
			rune_system.drop_rune()
			consumed += 1
			print("Consumed rune ", consumed, "/2 from inventory")
			if consumed >= 2:
				break
		if consumed >= 2:
			break

	return consumed >= 2

func _apply_buffs(buffs: Array):
	print("Applying ", buffs.size(), " buffs")
	for buff in buffs:
		print("Applying buff: ", buff.type, " = ", buff.value)
		match buff.type:
			"health_boost":
				var current_health = player.health
				player.MAX_HEALTH += buff.value
				player.health = current_health + buff.value
				player.set_meta("synergy_health_boost", buff.value)
				print("Health boosted! New max: ", player.MAX_HEALTH, ", Current: ", player.health)
			"sonar_range":
				player.set_meta("synergy_sonar_range", buff.value)
				print("Sonar range buff set: ", buff.value)
			"sonar_duration":
				player.set_meta("synergy_sonar_duration", buff.value)
				print("Sonar duration buff set: ", buff.value)
			"cooldown_reduction":
				player.set_meta("synergy_cooldown_mult", buff.value)
				print("Cooldown reduction buff set: ", buff.value)
			"attack_damage":
				player.set_meta("synergy_attack_damage", buff.value)
				print("Attack damage buff set: ", buff.value)
			"movement_speed":
				player.set_meta("synergy_movement_speed", buff.value)
	
func use_synergy():
	if active_synergy == null or synergy_uses_remaining <= 0:
		return

	synergy_uses_remaining -= 1
	synergy_used.emit(synergy_uses_remaining)

	if synergy_uses_remaining <= 0:
		_end_synergy()

func _end_synergy():
	if active_synergy == null:
		return

	_remove_buffs(active_synergy.buffs)

	_apply_corruption(active_synergy.debuffs)

	_create_corruption_particles()

	synergy_expired.emit()

	active_synergy = null
	synergy_uses_remaining = 0

func _remove_buffs(buffs: Array):
	for buff in buffs:
		match buff.type:	
			"health_boost":
				if player.has_meta("synergy_health_boost"):
					var boost = player.get_meta("synergy_health_boost")
					player.MAX_HEALTH -= boost
					player.health = min(player.health, player.MAX_HEALTH)
					player.remove_meta("synergy_health_boost")
			"sonar_range":
				player.remove_meta("synergy_sonar_range")
			"sonar_duration":
				player.remove_meta("synergy_sonar_duration")
			"cooldown_reduction":
				player.remove_meta("synergy_cooldown_mult")
			"attack_damage":
				player.remove_meta("synergy_attack_damage")
			"movement_speed":
				player.remove_meta("synergy_movement_speed")

func _apply_corruption(debuffs: Array):
	corruption_effects.clear()

	for debuff in debuffs:
		var effect = {
			"type": debuff.type,
			"data": debuff.data.duplicate(),
			"sonar_counter": 0,
			"is_permanent": debuff.is_permanent
		}
		corruption_effects.append(effect)

	if player and not player.sonar_pulse_emitted.is_connected(_on_player_sonar):
		player.sonar_pulse_emitted.connect(_on_player_sonar)

	corruption_started.emit({"debuffs": debuffs})

func _on_player_sonar(position: Vector2, range: float, direction: Vector2):
	var effects_to_remove = []

	for i in range(corruption_effects.size()):
		var effect = corruption_effects[i]

		if not effect.is_permanent:
			if effect.data.has("uses_remaining"):
				effect.data.uses_remaining -= 1
				if effect.data.uses_remaining <= 0:
					effects_to_remove.append(i)
					continue

		_apply_corruption_effect(effect)

	for i in range(effects_to_remove.size() - 1, -1, -1):
		var idx = effects_to_remove[i]
		_remove_corruption_effect(corruption_effects[idx])
		corruption_effects.remove_at(idx)

func _update_corruption_effects(delta: float):
	for effect in corruption_effects:
		if effect.type == "flickering_sonar":
			effect.sonar_counter += delta
			if effect.sonar_counter >= effect.data.frequency:
				effect.sonar_counter = 0.0
				if sonar_system:
					sonar_system.modulate = Color(1, 1, 1, effect.data.intensity)
					await get_tree().create_timer(0.1).timeout
					sonar_system.modulate = Color.WHITE

func _apply_corruption_effect(effect: Dictionary):
	match effect.type:
		"shrinking_range":
			var data = effect.data
			var random_mult = randf_range(data.min_range, data.max_range)
			player.set_meta("corruption_range_mult", random_mult)

		"weakened_attack":
			var data = effect.data
			player.set_meta("corruption_damage_mult", data.damage_multiplier)

func _remove_corruption_effect(effect: Dictionary):
	match effect.type:
		"shrinking_range":
			player.remove_meta("corruption_range_mult")
		"weakened_attack":
			player.remove_meta("corruption_damage_mult")

func _create_activation_particles():
	if not player:
		return

	var particles = CPUParticles2D.new()
	player.add_child(particles)

	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.8
	particles.explosiveness = 0.9

	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 80
	particles.initial_velocity_max = 150

	particles.gravity = Vector2(0, 150)
	particles.color = Color(0.7, 0.7, 0.8, 1.0)

	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0

	await get_tree().create_timer(1.5).timeout
	particles.queue_free()

func _create_corruption_particles():
	if not player:
		return

	var particles = CPUParticles2D.new()
	player.add_child(particles)

	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	particles.lifetime = 1.2
	particles.explosiveness = 0.8

	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 60
	particles.initial_velocity_max = 120

	particles.gravity = Vector2(0, 100)
	particles.color = Color(0.3, 0.3, 0.35, 0.9)

	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0

	await get_tree().create_timer(2.0).timeout
	particles.queue_free()

func get_active_synergy() -> Dictionary:
	if active_synergy == null:
		return {}
	return active_synergy

func get_synergy_uses_remaining() -> int:
	return synergy_uses_remaining

func has_active_synergy() -> bool:
	return active_synergy != null

func is_corrupted() -> bool:
	return corruption_effects.size() > 0
