class_name TreasureReward
extends RefCounted

enum Reward {
	HEAL,
	ATTACK,
	DEFENSE,
	MAX_HEALTH_AND_HEAL,
	RUN_ASH,
}


static func roll() -> Reward:
	match randi_range(0, 4):
		0:
			return Reward.HEAL
		1:
			return Reward.ATTACK
		2:
			return Reward.DEFENSE
		3:
			return Reward.MAX_HEALTH_AND_HEAL
		_:
			return Reward.RUN_ASH


static func apply(reward: Reward, run: RunState) -> String:
	match reward:
		Reward.HEAL:
			var recovered: int = run.heal(25)
			return "Recuperaste %d de Vida" % recovered
		Reward.ATTACK:
			run.attack += 4
			return "+4 de Ataque"
		Reward.DEFENSE:
			run.defense += 2
			return "+2 de Defensa"
		Reward.MAX_HEALTH_AND_HEAL:
			run.max_health += 12
			run.heal_structural(12)
			return "+12 de Vida máxima y +12 de Vida"
		Reward.RUN_ASH:
			run.run_ash += 25
			return "+25 de Ceniza para esta partida"
		_:
			return "El tesoro se desvaneció."
