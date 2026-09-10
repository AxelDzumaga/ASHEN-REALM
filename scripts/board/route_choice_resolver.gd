class_name RouteChoiceResolver
extends RefCounted

## get_base_destination() es la única fórmula usada por el gameplay real
## (BoardTurnController / Board2D / Map3D): el D4 sigue siendo la autoridad
## total sobre el destino. Un FORK pre-generado (ver RouteBranchData) puede
## pausar el recorrido a mitad de camino, pero nunca cambia este número.
##
## get_destinations()/is_meaningful() y el gate de abajo son el mecanismo de
## bifurcación DINÁMICA anterior a MAP3D-HUMAN-004 (base+1 + probabilidad).
## Quedan retenidos únicamente porque tools/simulation/full_run_simulation.gd
## (fuera de alcance de esta feature — es economía/balance, no routing) los
## sigue usando para sus propias corridas batch; el BoardTurnController real
## ya NO los llama. No usar este mecanismo para nueva UI/gameplay de routing.
const DEFAULT_BRANCH_PERCENT := 45


static func get_base_destination(sequence_size: int, current_position: int, roll: int) -> int:
	if sequence_size <= 0:
		return current_position
	return mini(current_position + clampi(roll, DiceRoller.MIN_RESULT, DiceRoller.MAX_RESULT), sequence_size - 1)


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
