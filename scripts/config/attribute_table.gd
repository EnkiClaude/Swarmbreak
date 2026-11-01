class_name AttributeTable
extends Resource
## The character attributes and how many points each level gives to spend on them.

@export var attributes: Array[AttributeDef] = []
## Attribute points gained per level after the first.
@export var points_per_level: int = 5
## Points a new character starts with.
@export var starting_points: int = 0
