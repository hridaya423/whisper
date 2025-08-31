

extends Node
class_name RuneSystem

enum RuneType {
	RANGE_AMPLIFIER,
	DURATION_CRYSTAL
}


var active_runes = {}
var rune_cooldowns = {}  

var rune_multipliers = {
	"range": 1.0,
	"duration": 1.0
}


var rune_configs = {
	RuneType.RANGE_AMPLIFIER: {
		"name": "Range Amplifier",
		"description": "Your sonar reaches twice as far, revealing distant secrets hidden in the darkness... Use it wisely.",
		"range_multiplier": 2.0,
		"duration_multiplier": 1.0,
		"effect_duration": 30.0,  
		"cooldown_duration": 60.0  
	},
	RuneType.DURATION_CRYSTAL: {
		"name": "Duration Crystal", 
		"description": "Your sonar now lingers much longer, the echoes refuse to fade... The shadows will reveal their secrets.",
		"range_multiplier": 1.0,
		"duration_multiplier": 5.0,
		"effect_duration": 25.0,  
		"cooldown_duration": 30.0  
	}
}


var level_manager: Node
var using_level_manager_ui: bool = false

signal rune_activated(rune_type: RuneType)
signal rune_deactivated(rune_type: RuneType)

func _ready():
	print("Rune system initialized")
	
	
	level_manager = _find_level_manager()
	if level_manager and level_manager.has_signal("show_level_message"):
		using_level_manager_ui = true
		print("Connected to LevelManager UI system")
	else:
		print("Could not connect to LevelManager UI - messages will use print")

func _find_level_manager() -> Node:
	
	var paths_to_try = [
		"../LevelManager",
		"../../LevelManager",
		get_tree().current_scene.get_node("LevelManager") if get_tree().current_scene.has_node("LevelManager") else null
	]
	
	for path in paths_to_try:
		if path and is_instance_valid(path):
			return path
	
	
	return _find_node_by_name(get_tree().current_scene, "LevelManager")

func _find_node_by_name(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	
	for child in node.get_children():
		var result = _find_node_by_name(child, name)
		if result:
			return result
	
	return null

func _process(delta):
	
	var runes_to_remove = []
	
	for rune_type in active_runes:
		active_runes[rune_type] -= delta
		if active_runes[rune_type] <= 0:
			runes_to_remove.append(rune_type)
	
	
	for rune_type in runes_to_remove:
		_expire_rune(rune_type)
	
	
	for rune_type in rune_cooldowns.keys():
		if rune_cooldowns[rune_type] > 0:
			rune_cooldowns[rune_type] -= delta

func activate_rune(rune_type: RuneType):
	
	if is_rune_on_cooldown(rune_type):
		var remaining_cooldown = int(rune_cooldowns[rune_type])
		_show_cooldown_message(rune_type, remaining_cooldown)
		return false
	
	
	if rune_type in active_runes:
		active_runes[rune_type] = rune_configs[rune_type].effect_duration
		_show_refresh_message(rune_type)
	else:
		
		active_runes[rune_type] = rune_configs[rune_type].effect_duration
		_show_activation_message(rune_type)
	
	_update_multipliers()
	rune_activated.emit(rune_type)
	
	print("Rune activated: ", rune_configs[rune_type].name)
	print("New multipliers - Range: ", rune_multipliers.range, "x, Duration: ", rune_multipliers.duration, "x")
	return true

func _expire_rune(rune_type: RuneType):
	
	active_runes.erase(rune_type)
	
	
	rune_cooldowns[rune_type] = rune_configs[rune_type].cooldown_duration
	
	
	_update_multipliers()
	
	
	_show_expiration_message(rune_type)
	
	rune_deactivated.emit(rune_type)
	print("Rune expired: ", rune_configs[rune_type].name)

func _show_activation_message(rune_type: RuneType):
	var config = rune_configs[rune_type]
	var duration = int(config.effect_duration)
	
	var message = config.name.to_upper() + " ACQUIRED!\n\n" + config.description + "\n\nActive for " + str(duration) + " seconds. "
	
	_display_typewriter_message(message)

func _show_refresh_message(rune_type: RuneType):
	var config = rune_configs[rune_type]
	var message = config.name.to_upper() + " REFRESHED!\n\nDuration restored... the power flows anew."
	
	_display_typewriter_message(message)

func _show_expiration_message(rune_type: RuneType):
	var config = rune_configs[rune_type]
	var cooldown = int(config.cooldown_duration)
	
	var message = config.name + " has faded away...\n\nThe ancient power retreats into shadow.\n\nCooldown: " + str(cooldown) + " seconds."
	
	_display_typewriter_message(message)

func _show_cooldown_message(rune_type: RuneType, remaining_seconds: int):
	var config = rune_configs[rune_type]
	var message = config.name + " is still recharging...\n\nThe ancient energies need time to rebuild.\n\n" + str(remaining_seconds) + " seconds remaining."
	
	_display_typewriter_message(message)

func _display_typewriter_message(message: String):
	if using_level_manager_ui and level_manager:
		
		level_manager.emit_signal("show_level_message", message)
		print("Displaying rune message via LevelManager UI")
		
		
		await get_tree().process_frame
		get_tree().paused = true
		
		
		var typewriter_speed = 0.08
		var character_variation = 0.03
		var display_time = len(message) * (typewriter_speed + character_variation) + 3.0
		
		
		var timer = Timer.new()
		timer.process_mode = Node.PROCESS_MODE_ALWAYS
		timer.wait_time = display_time
		timer.one_shot = true
		add_child(timer)
		timer.start()
		
		await timer.timeout
		
		
		timer.queue_free()
		get_tree().paused = false
		
		
		if level_manager.has_method("_fade_out_message"):
			level_manager._fade_out_message()
		
		print("Rune message completed, game unpaused, message fading")
	else:
		
		print("RUNE MESSAGE: ", message)

func _update_multipliers():
	rune_multipliers.range = 1.0
	rune_multipliers.duration = 1.0
	
	for rune_type in active_runes:
		var config = rune_configs[rune_type]
		rune_multipliers.range *= config.range_multiplier
		rune_multipliers.duration *= config.duration_multiplier

func is_rune_on_cooldown(rune_type: RuneType) -> bool:
	return rune_type in rune_cooldowns and rune_cooldowns[rune_type] > 0

func get_rune_cooldown_time(rune_type: RuneType) -> float:
	if rune_type in rune_cooldowns:
		return max(0.0, rune_cooldowns[rune_type])
	return 0.0

func get_rune_active_time(rune_type: RuneType) -> float:
	if rune_type in active_runes:
		return active_runes[rune_type]
	return 0.0

func get_range_multiplier() -> float:
	return rune_multipliers.range

func get_duration_multiplier() -> float:
	return rune_multipliers.duration

func has_rune(rune_type: RuneType) -> bool:
	return rune_type in active_runes

func get_active_rune_names() -> Array[String]:
	var names: Array[String] = []
	for rune_type in active_runes:
		names.append(rune_configs[rune_type].name)
	return names
