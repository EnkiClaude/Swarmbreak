class_name PetDef
extends Resource
## One kind of pet egg: its names through each stage, colors, and the stats
## it gives (base plus per level), geared toward one build.

@export var display_name: String = "Ember"
## Name at each stage: the egg, then hatched and each evolution.
@export var stage_names: PackedStringArray = ["Ember Egg", "Emberling", "Ember Drake"]
## One line on what build the pet suits, shown when choosing an egg.
@export var build_hint: String = ""
@export var color: Color = Color(0.9, 0.4, 0.2)
@export var accent_color: Color = Color(1.0, 0.85, 0.3)
## Stats given while equipped: base_values[k] + per_level[k] * (level - 1).
@export var stats: Array[PlayerStat.Id] = []
@export var base_values: PackedFloat32Array = []
@export var per_level: PackedFloat32Array = []
