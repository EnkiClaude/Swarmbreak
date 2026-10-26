class_name ProgressionConfig
extends Resource
## XP curve and what each level gives.

## XP needed for level 2; each level after needs xp_growth times more.
@export var xp_first_level: float = 25.0
@export var xp_growth: float = 1.3
@export var max_level: int = 50
@export var skill_points_per_level: int = 1
@export var health_per_level: float = 6.0
@export var mana_per_level: float = 4.0
@export var level_up_color: Color = Color(0.6, 1.0, 0.5)
