class_name EffectType
extends Resource
## A pooled visual effect: one mesh instance that grows and fades out.
## Sizes are radii in meters; spawn() multiplies them by a per-instance size.

enum Shape { SPHERE, RING }

@export var shape: Shape = Shape.SPHERE
@export var color: Color = Color(1, 1, 1, 0.8)
@export var duration: float = 0.25
@export var start_scale: float = 1.0
@export var end_scale: float = 1.5
## Vertical squash; 1 keeps the shape round.
@export var flatten: float = 1.0
## Height above the ground the effect is centered at.
@export var height: float = 0.5
## Most instances of this effect alive at once. Extra spawns are dropped.
@export var capacity: int = 256
