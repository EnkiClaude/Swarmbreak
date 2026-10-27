class_name JobDef
extends Resource
## A job path: chosen at JobTree.unlock_level, promoted at JobTree.rank2_level.

@export var display_name: String = "Job"
@export_multiline var description: String = ""
@export var rank2_name: String = "Job II"
@export_multiline var rank2_description: String = ""
@export var color: Color = Color.WHITE
@export var rank1: JobPerks
@export var rank2: JobPerks
