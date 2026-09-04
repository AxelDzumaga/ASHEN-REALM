class_name EquipmentVisualData
extends Resource

enum DisplayMode {
	NONE,
	ATTACHMENT,
	ACCENT,
	FULL_VARIANT,
}

enum ProceduralStyle {
	NONE,
	ASHEN_BLADE,
	CINDER_KNIFE,
	EMBER_FANG,
	RUNIC_EDGE,
	WARDENS_EDGE,
	BLOOD_CLEAVER,
	WORN_ASHMAIL,
	CINDER_CARAPACE,
	EMBERGUARD_ARMOR,
	MIRE_VEST,
	WARDEN_PLATE,
	LAST_GUARD,
}

@export var visual_id: StringName
@export var display_name: String
@export var slot: EquipmentData.Slot = EquipmentData.Slot.WEAPON
@export var display_mode: DisplayMode = DisplayMode.NONE
@export var procedural_style: ProceduralStyle = ProceduralStyle.NONE
@export var icon_id: StringName = &"loot"
@export var attachment_texture: Texture2D
@export var attachment_anchor: Vector2 = Vector2(0.5, 0.5)
@export var attachment_offset_ratio: Vector2 = Vector2.ZERO
@export_range(0.25, 2.0, 0.01) var attachment_scale: float = 1.0
@export_range(-180.0, 180.0, 0.5) var attachment_rotation_degrees: float = 0.0
@export_range(-8, 8, 1) var attachment_z_index: int = 0
@export var visible_idle: bool = true
@export var visible_attack: bool = true
@export var visible_hit: bool = true
@export var visible_death: bool = true
@export var accent: Color = Color("e6a23c")
@export var secondary_accent: Color = Color("78451f")
@export var fallback_style: ProceduralStyle = ProceduralStyle.NONE
@export var frame_sync_profile_id: StringName = &""
@export var full_variant: CharacterVisualData


func is_visible_for(animation_name: StringName) -> bool:
	match animation_name:
		&"attack":
			return visible_attack
		&"hit":
			return visible_hit
		&"death":
			return visible_death
		_:
			return visible_idle
