class_name ArenaConfig
extends Resource
## Size and look of the flat combat arena.

## The arena is a square spanning -half_extent..half_extent on X and Z, in meters.
@export var half_extent: float = 40.0
@export var floor_color: Color = Color(0.15, 0.16, 0.18)
@export var grid_line_color: Color = Color(0.23, 0.25, 0.28)
@export var grid_cell_size: float = 2.0
@export var border_color: Color = Color(0.45, 0.32, 0.2)
@export var border_height: float = 0.6
