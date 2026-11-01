class_name RegionDef
extends Resource
## One square region of the open world: how it looks and what lives there.
## WorldConfig.regions lists them row by row, north (-Z) to south, west to east.

@export var display_name: String = "Region"
## Floor colors, props and atmosphere. Only outdoor fields apply in the open
## world: the floor is always open ground, and there are no walls or ceiling.
@export var theme: ZoneTheme
## Difficulty: monster health and damage, XP and item level grow with it.
@export var level: int = 1
## A town: no camps, and where the player respawns.
@export var is_town: bool = false
@export var camp_count: int = 7
@export var camp_size_min: int = 12
@export var camp_size_max: int = 30
## Swarm enemy types (SwarmConfig.enemy_types) of ordinary and heavy members.
@export var enemy_type: int = 0
@export var heavy_type: int = 1
## Chance each camp member is heavy_type.
@export var heavy_chance: float = 0.1
## The biggest this many camps get a boss at their center.
@export var boss_camps: int = 1
