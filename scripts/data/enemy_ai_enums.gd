class_name EnemyAIEnums
extends RefCounted

enum Role {
	ASSAULT,
	BRUTE,
	DEFENDER,
	SUPPORT,
	BOSS,
}

enum TargetPolicy {
	PRIMARY_PLAYER,
	LOWEST_HP,
	RANDOM_ALIVE,
	COMPANION_PREFERRED,
}

enum ActionType {
	ATTACK,
	ATTACK_STATUS,
	SELF_BUFF,
	SUMMON,
}

enum PresentationType {
	MELEE,
	HEAVY,
	STATIC,
	RANGED,
}


static func get_role_name(role: Role) -> String:
	match role:
		Role.ASSAULT:
			return "ASALTO"
		Role.BRUTE:
			return "BRUTO"
		Role.DEFENDER:
			return "DEFENSOR"
		Role.SUPPORT:
			return "APOYO"
		Role.BOSS:
			return "JEFE"
		_:
			return "ENEMIGO"
