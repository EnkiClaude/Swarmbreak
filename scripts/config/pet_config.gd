class_name PetConfig
extends Resource
## Pets: the eggs, how they level, hatch and evolve, what share of the
## player's kill XP they take, how far a hatched pet collects loot, how it
## follows, and the Egg Keeper in town.

@export var pets: Array[PetDef] = []
@export var max_level: int = 50
## The egg hatches at this level and evolves every this many levels after.
@export var levels_per_stage: int = 10
## Stages past the egg (hatched, then evolutions).
@export var max_stage: int = 4
## XP for level 2; each level needs xp_growth more, and each stage
## stage_xp_multiplier more on top.
@export var xp_first_level: float = 20.0
@export var xp_growth: float = 1.1
@export var stage_xp_multiplier: float = 1.6
## The pet earns this fraction of the player's kill XP as a bonus (base plus
## per stage); the player's own XP is never reduced.
@export var xp_share_base: float = 0.08
@export var xp_share_per_stage: float = 0.04
## Once hatched, loot within this distance of the player is collected:
## pickup_radius_base plus pickup_radius_per_level for every pet level.
@export var pickup_radius_base: float = 2.0
@export var pickup_radius_per_level: float = 1.0
## Model height per stage.
@export var height_per_stage: PackedFloat32Array = [0.45, 0.55, 0.8, 1.05, 1.35]
## Where the pet floats or walks: behind and beside the player.
@export var follow_offset: Vector2 = Vector2(0.9, 1.4)
@export var follow_sharpness: float = 6.0
## A hatched pet flies to drops in its range at this speed (m/s) and picks
## one up within fetch_reach of it.
@export var fetch_speed: float = 18.0
@export var fetch_reach: float = 1.0
## Rarity color an egg item shows in (LootConfig.rarity_colors).
@export var egg_rarity: int = 2

@export_group("Egg Keeper")
## Where the keeper stands, from the town's center.
@export var keeper_offset: Vector2 = Vector2(9.0, 5.0)
## Walking this close opens the keeper's eggs.
@export var keeper_radius: float = 2.6
@export var keeper_color: Color = Color(0.35, 0.55, 0.35)
