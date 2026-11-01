class_name HudConfig
extends Resource
## HUD layout and colors: the framed character panel (top left), the round
## minimap (top right), the skill column (right edge) and the hurt vignette.

@export_group("Character panel")
## Top-left corner of the panel, in pixels.
@export var panel_position: Vector2 = Vector2(14.0, 14.0)
@export var panel_width: float = 300.0
@export var bar_height: float = 15.0
@export var bar_gap: float = 5.0
@export var health_color: Color = Color(0.82, 0.16, 0.14)
@export var mana_color: Color = Color(0.22, 0.45, 0.95)
@export var xp_color: Color = Color(0.95, 0.78, 0.3)
@export var bar_back_color: Color = Color(0, 0, 0, 0.6)
@export var panel_color: Color = Color(0.07, 0.045, 0.03, 0.78)
## Gold frame around the panel, the minimap and the skill slots.
@export var frame_color: Color = Color(0.82, 0.63, 0.32)

@export_group("Minimap")
@export var minimap_radius: float = 80.0
## Top-right corner inset of the minimap, in pixels.
@export var minimap_margin: float = 16.0
## Meters from the player to the minimap's edge.
@export var minimap_range: float = 60.0
@export var minimap_back_color: Color = Color(0.05, 0.06, 0.05, 0.72)
@export var minimap_ring_color: Color = Color(0.55, 0.38, 0.2)
@export var minimap_wall_color: Color = Color(0.85, 0.75, 0.55, 0.5)
@export var minimap_camp_color: Color = Color(0.9, 0.3, 0.25)
@export var minimap_awake_color: Color = Color(1.0, 0.75, 0.2)
@export var minimap_player_color: Color = Color(0.4, 0.9, 1.0)

@export_group("Skills")
@export var skill_slot_size: float = 54.0
@export var skill_gap: float = 8.0
## Inset of the column from the right edge, in pixels.
@export var skill_margin: float = 14.0
## Vertical center of the column, as a fraction of the screen height.
@export var skill_center_y: float = 0.5
@export var skill_back_color: Color = Color(0.08, 0.05, 0.04, 0.8)
@export var skill_cooldown_color: Color = Color(0, 0, 0, 0.6)
## Tint on a skill the player hasn't the mana for.
@export var skill_no_mana_color: Color = Color(0.2, 0.3, 0.9, 0.45)

@export_group("Hurt")
@export var hurt_vignette_color: Color = Color(0.9, 0.05, 0.05, 0.45)
@export var hurt_vignette_fade: float = 3.0
