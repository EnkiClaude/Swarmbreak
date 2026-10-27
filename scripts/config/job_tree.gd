class_name JobTree
extends Resource
## The job paths and the levels where they unlock and promote.

@export var unlock_level: int = 10
@export var rank2_level: int = 25
@export var jobs: Array[JobDef] = []
