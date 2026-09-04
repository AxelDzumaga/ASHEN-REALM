extends Control

signal back_requested

@onready var reset_button: Button = %ResetButton
@onready var back_button: Button = %BackButton
@onready var confirmation: VBoxContainer = %Confirmation
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton
@onready var debug_complete_button: Button = %DebugCompleteButton
@onready var sections: VBoxContainer = $Margin/Layout/Scroll/Sections

func _ready() -> void:
	reset_button.pressed.connect(_show_confirmation)
	back_button.pressed.connect(_on_back_pressed)
	yes_button.pressed.connect(_reset_tutorials)
	no_button.pressed.connect(_hide_confirmation)
	debug_complete_button.visible = DebugConfig.DEBUG_TOOLS_ENABLED
	_add_icon_legend()
	_add_biome_rules()
	_add_companion_guide()
	_add_enemy_ai_guide()
	_add_boss_guide()
	if DebugConfig.DEBUG_TOOLS_ENABLED:
		debug_complete_button.pressed.connect(TutorialManager.complete_all_debug)
	back_button.grab_focus()

func _show_confirmation() -> void:
	confirmation.visible = true
	yes_button.grab_focus()

func _hide_confirmation() -> void:
	confirmation.visible = false
	reset_button.grab_focus()

func _reset_tutorials() -> void:
	TutorialManager.reset_all()
	_hide_confirmation()

func _on_back_pressed() -> void:
	back_button.disabled = true
	back_requested.emit()


func _add_icon_legend() -> void:
	var legend: GridContainer = GridContainer.new()
	legend.name = "VisualLegend"
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 8)
	legend.add_theme_constant_override("v_separation", 8)
	_add_legend_badge(legend, &"health", "VIDA", AshenBadge.Variant.HEAL)
	_add_legend_badge(legend, &"attack", "ATAQUE", AshenBadge.Variant.DANGER)
	_add_legend_badge(legend, &"defense", "DEFENSA", AshenBadge.Variant.NEUTRAL)
	_add_legend_badge(legend, &"ember", "BRASA", AshenBadge.Variant.EMBER)
	_add_legend_badge(legend, &"skill", "HABILIDAD ACTIVA", AshenBadge.Variant.EMBER)
	_add_legend_badge(legend, &"elite", "ÉLITE", AshenBadge.Variant.DANGER)
	_add_legend_badge(legend, &"boss", "JEFE", AshenBadge.Variant.DANGER)
	sections.add_child(legend)


func _add_biome_rules() -> void:
	var guide: Label = Label.new()
	guide.name = "BiomeRulesGuide"
	guide.add_theme_font_size_override("font_size", 18)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var lines: Array[String] = ["REGIONES · VENTAJAS Y RIESGOS"]
	for biome: BiomeData in BiomeCatalog.get_all():
		lines.append("%s\n%s" % [biome.display_name.to_upper(), BiomeModifierResolver.get_detailed_summary(biome)])
	guide.text = "\n\n".join(lines)
	sections.add_child(guide)


func _add_companion_guide() -> void:
	var guide: Label = Label.new()
	guide.name = "CompanionGuide"
	guide.add_theme_font_size_override("font_size", 18)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "COMPAÑEROS\nEquipá o desequipá tu Companion en el Refugio antes de iniciar una run. Actúa automáticamente después del Ashen Wanderer, prioriza tu objetivo, no consume Brasa y posee stats, estados, pasiva y habilidad propios."
	sections.add_child(guide)


func _add_enemy_ai_guide() -> void:
	var guide: Label = Label.new()
	guide.name = "EnemyAIGuide"
	guide.add_theme_font_size_override("font_size", 18)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "ROLES ENEMIGOS\nCada enemigo puede ser ASALTO, BRUTO, DEFENSOR o APOYO. Puede elegir al Wanderer o al Companion y algunas acciones aplican estados. Identificá al objetivo prioritario antes de actuar."
	sections.add_child(guide)


func _add_boss_guide() -> void:
	var guide: Label = Label.new()
	guide.name = "BossGuide"
	guide.add_theme_font_size_override("font_size", 18)
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.text = "JEFES\nLos Jefes cambian de fase al perder Vida. Leé sus telegraphs: algunos preparan contraataques o invocan refuerzos seleccionables. Los refuerzos no entregan recompensas individuales."
	sections.add_child(guide)


func _add_legend_badge(parent: GridContainer, icon_id: StringName, text: String, variant: AshenBadge.Variant) -> void:
	var badge: AshenBadge = AshenBadge.new()
	badge.configure(icon_id, text, variant, AshenIcon.DisplaySize.MEDIUM)
	parent.add_child(badge)
