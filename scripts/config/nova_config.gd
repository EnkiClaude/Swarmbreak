class_name NovaConfig
extends Resource
## The Frost Nova: an icy pulse centered on the player that damages and
## slows everything it reaches (no knockback, so tough packs stay on you).

@export var radius: float = 6.0
@export var damage: float = 25.0
## Meters per second added to each enemy hit, pointing away from the player.
@export var knockback: float = 0.0
## Frost: enemies caught move at slow_factor of their speed for slow_duration.
@export var slow_factor: float = 0.25
@export var slow_duration: float = 2.5
@export var cooldown: float = 1.2
@export var mana_cost: float = 35.0
@export var effect: EffectType
## Lightning that strikes enemies the nova hits; open ground when it hits few.
@export var strike_effect: EffectType
@export var strikes: int = 8
