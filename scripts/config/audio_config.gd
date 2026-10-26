class_name AudioConfig
extends Resource
## Sound effect levels. The sounds themselves are generated placeholders
## (SfxBank) until real assets exist.

@export var voices: int = 12
@export var pitch_variance: float = 0.08
@export var bolt_fire_db: float = -16.0
@export var bolt_burst_db: float = -10.0
@export var nova_db: float = -3.0
@export var kill_db: float = -14.0
## Kill crunch gets this much louder per doubling of kills in one hit.
@export var kill_db_per_doubling: float = 2.5
@export var kill_db_max: float = -2.0
@export var lure_db: float = -6.0
@export var dodge_db: float = -12.0
@export var hurt_db: float = -9.0
## Shortest gap between hurt sounds while being hit continuously.
@export var hurt_interval: float = 0.3
@export var denied_db: float = -10.0
