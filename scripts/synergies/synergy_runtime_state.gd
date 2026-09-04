class_name SynergyRuntimeState
extends RefCounted

var inferno_triggered_this_turn: bool = false
var cinder_precision_triggered_this_turn: bool = false
var runic_flow_triggered_this_turn: bool = false
var iron_vigil_triggered_this_combat: bool = false


func reset_for_combat() -> void:
	inferno_triggered_this_turn = false
	cinder_precision_triggered_this_turn = false
	runic_flow_triggered_this_turn = false
	iron_vigil_triggered_this_combat = false


func begin_player_turn() -> void:
	inferno_triggered_this_turn = false
	cinder_precision_triggered_this_turn = false
	runic_flow_triggered_this_turn = false
