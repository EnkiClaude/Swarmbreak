class_name NovaConfig
extends Resource
## The nova: an area pulse centered on the player.

@export var radius: float = 6.0
@export var damage: float = 25.0
## Meters per second added to each enemy hit, pointing away from the player.
@export var knockback: float = 8.0
@export var cooldown: float = 1.2
@export var effect: EffectType
