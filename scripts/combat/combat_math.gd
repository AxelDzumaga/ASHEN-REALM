class_name CombatMath
extends RefCounted

const DEFENSE_SCALE: int = 10


static func calculate_damage(attack: int, defense: int) -> int:
	var safe_attack: int = maxi(1, attack)
	var safe_defense: int = maxi(0, defense)
	var denominator: int = 100 + safe_defense * DEFENSE_SCALE
	return maxi(1, ceili(float(safe_attack * 100) / float(denominator)))
