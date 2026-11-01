class_name EnemyType
extends Resource
## Tuning for one kind of swarm enemy. Each type gets its own MultiMesh,
## drawn with its model (CharacterModels) in its three colors.

## The shape it's built as.
enum Model { GOBLIN, OGRE, WARLORD, SKELETON, TREANT, WISP }

@export var display_name: String = "Enemy"
@export var model: Model = Model.GOBLIN
## Main color (skin, bark, bone, robe), then a second (clothes, leaves, cape)
## and an accent (eyes, gems, blade edges).
@export var color: Color = Color(0.85, 0.25, 0.2)
@export var secondary_color: Color = Color(0.4, 0.3, 0.2)
@export var accent_color: Color = Color(1.0, 0.85, 0.3)
## Walk cycle speed (radians per second) and how far limbs swing (radians).
@export var walk_cycle_speed: float = 9.0
@export var walk_swing: float = 0.6
@export var max_health: float = 20.0
## Fraction of knockback ignored (1 = immovable).
@export var knockback_resist: float = 0.0
## XP the player earns for killing one.
@export var xp: float = 1.0
@export var body_radius: float = 0.35
@export var body_height: float = 1.0
@export var max_speed: float = 4.0
## Meters per second squared toward the desired velocity.
@export var acceleration: float = 14.0
## Neighbours closer than this push each other apart.
@export var separation_radius: float = 0.8
## Meters per second of push at full overlap, summed over neighbours.
@export var separation_strength: float = 6.0
## Damage per second dealt to the player while touching it.
@export var contact_dps: float = 6.0
## Extra reach beyond touching that still counts as hitting the player.
@export var attack_reach: float = 0.2
@export var cast_shadow: bool = false
@export var death_effect: EffectType
