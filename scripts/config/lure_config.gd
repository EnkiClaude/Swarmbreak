class_name LureConfig
extends Resource
## The lure: a war cry that wakes every camp in range and hurries awake
## enemies toward the player, for gathering packs before a nova.

@export var radius: float = 30.0
@export var cooldown: float = 5.0
@export var mana_cost: float = 20.0
## Awake enemies in range move this much faster for boost_duration seconds.
@export var speed_multiplier: float = 1.7
@export var boost_duration: float = 3.0
@export var effect: EffectType
