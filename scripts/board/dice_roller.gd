class_name DiceRoller
extends RefCounted

const MIN_RESULT: int = 1
const MAX_RESULT: int = 4

var _random := RandomNumberGenerator.new()


func _init() -> void:
	_random.randomize()


func roll(forced_result: int = 0) -> int:
	if forced_result != 0:
		assert(forced_result >= MIN_RESULT and forced_result <= MAX_RESULT, "Forced dice result must be within the configured range.")
		return clampi(forced_result, MIN_RESULT, MAX_RESULT)

	return _random.randi_range(MIN_RESULT, MAX_RESULT)
