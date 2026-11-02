class_name SummonConfig
extends Resource
## The summonable boss: any monster may drop a shard (at shard_drop_chance
## per kill, whatever its level); shards_needed of them summon the boss
## where the player stands (not in town), with an awake escort. It's far
## tougher than a camp boss and drops far better loot.

@export var boss_name: String = "Dread Lord"
@export var shard_name: String = "Sigil Shard"
@export var shards_needed: int = 10
@export var shard_drop_chance: float = 0.004
@export var shard_color: Color = Color(0.85, 0.15, 0.9)
## Index into the swarm's enemy types for the boss and its escort.
@export var boss_type: int = 2
@export var escort_type: int = 1
@export var escort_count: int = 40
## Its health is a camp boss's at the same level times this.
@export var health_multiplier: float = 10.0
## Distance from the player it appears at, and how far its escort spreads.
@export var spawn_distance: float = 9.0
@export var escort_spread: float = 7.0
## Rewards: drops (items at least min_rarity, with item_chance each), Geon
## times a camp boss's, and a chance of a legendary on top.
@export var reward_drops: int = 8
@export var min_rarity: int = 3
@export var item_chance: float = 0.6
@export var geon_multiplier: float = 6.0
@export var legendary_chance: float = 0.5
@export var color: Color = Color(0.85, 0.2, 0.9)
