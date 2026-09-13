class_name CombatRules
extends RefCounted

## Combat Domain M5 — autoridad canónica de límites de PRODUCTO/DOMINIO del
## combate (a diferencia de CombatTeamUtils, que sigue siendo operaciones de
## equipo: living_actors/has_living_actor/is_defeated). MAX_TEAM_SIZE es una
## regla de negocio (cuántos actores caben por equipo), no una operación —
## por eso vive acá y no en CombatTeamUtils, a pesar de que la auditoría M5
## había sugerido lo segundo (decisión explícita de override).
##
## CombatTurnController NO conoce esta constante — sigue aceptando arrays
## genéricos de cualquier tamaño, tal como antes de M5 (ver handoff M5).
## Este límite se aplica en las capas de composición/generación de
## contenido (construcción de equipo, generación de encuentros, datos de
## boss), nunca dentro del controller de turnos.
##
## Los @export_range de datos de contenido (EncounterTemplateData.slots,
## BossEncounterData.max_active_enemies) no pueden referenciar esta
## constante directamente — GDScript exige literales en los argumentos de
## @export_range. Esos literales quedan documentados como un espejo manual
## de MAX_TEAM_SIZE; la validación en tiempo de ejecución (is_eligible(),
## etc.) sigue leyendo MAX_TEAM_SIZE acá, nunca el literal del editor.

const MAX_TEAM_SIZE: int = 5


## Combat Domain M5 — asignador genérico de formation_slot, reemplaza el
## hardcodeo previo (available_slots = [0, 2]) que solo servía para "boss en
## slot 1 + hasta 2 minions". Determinista: siempre devuelve los slots
## libres en orden ascendente dentro de 0..MAX_TEAM_SIZE-1, nunca repite un
## slot ya ocupado, nunca devuelve fuera de rango, y devuelve MENOS de
## `count` entradas (nunca más) si no hay suficiente lugar — nunca inventa
## un slot inexistente. No conoce equipos ni CombatActor: opera solo sobre
## los índices ya ocupados que el llamador le pase.
static func find_available_formation_slots(occupied_slots: Array[int], count: int) -> Array[int]:
	var available: Array[int] = []
	if count <= 0:
		return available
	for slot: int in range(MAX_TEAM_SIZE):
		if available.size() >= count:
			break
		if slot not in occupied_slots:
			available.append(slot)
	return available
