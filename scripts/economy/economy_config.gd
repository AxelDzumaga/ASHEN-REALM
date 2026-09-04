class_name EconomyConfig
extends RefCounted

enum Currency { ASH, GUARDIAN_SIGIL }

const GUARDIAN_SIGIL_NAME := "Sigilos de Guardián"
const FORGE_SHARD_NAME := "Fragmentos de Forja"
const SHOP_ROTATION_RUNS: int = 3


static func currency_name(currency: Currency) -> String:
	return "CENIZA" if currency == Currency.ASH else "SIGILOS"


static func currency_icon(currency: Currency) -> StringName:
	return &"ash" if currency == Currency.ASH else &"boss"

