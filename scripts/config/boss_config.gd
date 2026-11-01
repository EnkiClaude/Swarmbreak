class_name BossConfig
extends Resource
## Camp bosses: how tough they are, their ground slam and their rewards.

@export var display_name: String = "Camp Warlord"
## Index of the boss in SwarmConfig.enemy_types.
@export var type_index: int = 2
## Most bosses in the swarm at once (camps streamed in near the player).
@export var max_active: int = 8
## Boss health multiplies by (1 + this) per camp level above 1.
@export var health_growth: float = 0.3

@export_group("Slam")
## Starts a slam when the player is this close.
@export var slam_trigger_range: float = 6.0
@export var slam_radius: float = 4.5
## Time between the warning ring appearing and the hit. Match the
## telegraph effect's duration.
@export var slam_windup: float = 1.1
@export var slam_cooldown: float = 4.0
@export var slam_damage: float = 32.0
@export var telegraph_effect: EffectType

@export_group("Rewards")
@export var extra_drops: int = 2
## 0 common, 1 magic, 2 rare.
@export var min_drop_rarity: int = 2
@export var stones: int = 6
## The boss health bar shows while an awake boss is this close.
@export var hud_range: float = 30.0
