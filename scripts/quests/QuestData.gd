extends RefCounted
class_name QuestData
enum Status {
	AVAILABLE,
	ACTIVE,
	COMPLETED,
	FAILED
}
var id: String
var type: int
var target: int
var progress: int = 0
var reward_type: String = ""
var reward_amount: int = 0
var level_assigned: int = 0
var description: String = ""
var status: Status = Status.AVAILABLE
var is_death_quest: bool = false
var time_limit: float = 0.0
var time_remaining: float = 0.0
var has_penalty: bool = false
var penalty_type
var penalty_strength: float = 0.0
var penalty_description: String = ""
func _init(quest_type: int, quest_target: int, reward: String, reward_amt: int, level: int) -> void:
	type = quest_type
	target = max(1, quest_target)
	reward_type = reward
	reward_amount = max(0, reward_amt)
	level_assigned = level
	id = str(Time.get_ticks_usec())
	progress = 0
	description = ""
	status = Status.AVAILABLE
func is_completed() -> bool:
	return progress >= target or status == Status.COMPLETED
func get_progress_percentage() -> float:
	if target <= 0:
		return 1.0
	return clamp(float(progress) / float(target), 0.0, 1.0)
func set_death_quest(limit_seconds: float) -> void:
	is_death_quest = true
	time_limit = max(limit_seconds, 0.0)
	time_remaining = time_limit
func update_time(delta: float) -> void:
	if not is_death_quest or status == Status.FAILED:
		return
	time_remaining = max(0.0, time_remaining - delta)
	if time_remaining <= 0.0:
		status = Status.FAILED
func set_penalty(p_type, strength: float, description_text: String) -> void:
	has_penalty = true
	penalty_type = p_type
	penalty_strength = max(0.0, strength)
	penalty_description = description_text
func clear_penalty() -> void:
	has_penalty = false
	penalty_type = null
	penalty_strength = 0.0
	penalty_description = ""
func reset_progress() -> void:
	progress = 0
	status = Status.AVAILABLE
	is_death_quest = false
	time_limit = 0.0
	time_remaining = 0.0
	has_penalty = false
	penalty_type = null
	penalty_strength = 0.0
	penalty_description = ""