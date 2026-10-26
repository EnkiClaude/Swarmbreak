class_name HudConfig
extends Resource
## Health and mana bars, minimap and hurt vignette.

@export var bar_width: float = 340.0
@export var bar_height: float = 16.0
## Center of the bars, as a fraction of the screen.
@export var bar_position: Vector2 = Vector2(0.5, 0.955)
@export var bar_gap: float = 6.0
@export var health_color: Color = Color(0.85, 0.2, 0.2)
@export var mana_color: Color = Color(0.25, 0.5, 1.0)
@export var xp_color: Color = Color(0.6, 1.0, 0.5)
@export var bar_back_color: Color = Color(0, 0, 0, 0.55)
@export var minimap_size: float = 150.0
## Top-right corner inset of the minimap, in pixels.
@export var minimap_margin: float = 10.0
@export var minimap_back_color: Color = Color(0, 0, 0, 0.45)
@export var minimap_camp_color: Color = Color(0.9, 0.3, 0.25)
@export var minimap_awake_color: Color = Color(1.0, 0.75, 0.2)
@export var minimap_player_color: Color = Color(0.3, 0.8, 1.0)
@export var hurt_vignette_color: Color = Color(0.9, 0.05, 0.05, 0.45)
@export var hurt_vignette_fade: float = 3.0
