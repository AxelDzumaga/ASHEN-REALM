class_name FeatureFlags
extends RefCounted

## Producción: Map3D es la presentación de expedición normal. Board2D se
## mantiene sólo como fallback de debug/paridad de dominio (ver
## board_presentations_contract_test.gd) — no persistida, no expuesta al
## jugador; cambiarla a false localmente vuelve a Board2D para triage.
const USE_3D_BOARD := true

