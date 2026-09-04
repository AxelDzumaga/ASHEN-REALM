class_name RouteChoiceResolver
extends RefCounted

## Agency acotada sobre el tablero lineal: el D4 fija el destino base y una
## bifurcacion puede ofrecer el tile inmediatamente posterior. No muta la run.
const DEFAULT_BRANCH_PERCENT := 45


static func get_destinations(
	sequence: Array[int],
	current_position: int,
	roll: int,
	board_seed: int,
	choice_ordinal: int,
	on_cooldown: bool = false,
	branch_percent: int = DEFAULT_BRANCH_PERCENT,
) -> Array[int]:
	var result: Array[int] = []
	if sequence.is_empty() or current_position < 0 or current_position >= sequence.size() - 1:
		return result
	var last_index: int = sequence.size() - 1
	var base_destination: int = mini(current_position + clampi(roll, DiceRoller.MIN_RESULT, DiceRoller.MAX_RESULT), last_index)
	result.append(base_destination)
	if on_cooldown or base_destination >= last_index:
		return result
	var alternate_destination: int = base_destination + 1
	if sequence[base_destination] == sequence[alternate_destination]:
		return result
	var gate: int = _stable_gate(board_seed, current_position, roll, choice_ordinal)
	if gate < clampi(branch_percent, 0, 100):
		result.append(alternate_destination)
	return result


static func is_meaningful(sequence: Array[int], destinations: Array[int]) -> bool:
	return destinations.size() == 2 and sequence[destinations[0]] != sequence[destinations[1]]


static func is_valid_destination(current_position: int, sequence_size: int, destination: int) -> bool:
	return destination > current_position and destination >= 0 and destination < sequence_size


static func _stable_gate(board_seed: int, position: int, roll: int, ordinal: int) -> int:
	var mixed: int = absi(board_seed ^ ((position + 1) * 104729) ^ (roll * 65537) ^ ((ordinal + 1) * 4099) ^ 0x67A9)
	return mixed % 100
