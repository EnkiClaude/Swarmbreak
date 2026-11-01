class_name DungeonDef
extends Resource
## A dungeon: an enclosed hall entered through a gate in the open world, with
## harder monsters, better drops, spawners that refill at once, and a boss
## at the far end.

@export var display_name: String = "Dungeon"
## Usually an indoor theme (walls, ceiling, lanterns).
@export var theme: ZoneTheme
## The hall spans -half_extent..half_extent on X and Z.
@export var half_extent: float = 40.0
@export var level: int = 4
## Index into WorldConfig.regions of the region holding the entrance gate.
@export var region: int = 0
## Where the gate stands, relative to that region's center.
@export var gate_offset: Vector2 = Vector2.ZERO
## Color of the gate's glowing doorway and its minimap marker.
@export var gate_color: Color = Color(0.9, 0.3, 0.25)

@export_group("Monsters")
@export var camp_count: int = 6
@export var camp_size_min: int = 16
@export var camp_size_max: int = 32
## Swarm enemy types (SwarmConfig.enemy_types) of ordinary and heavy members.
@export var enemy_type: int = 0
@export var heavy_type: int = 1
@export var heavy_chance: float = 0.25
## Monster contact damage multiplies by this on top of the level scaling.
@export var damage_multiplier: float = 1.25
## Seconds before a cleared camp (the boss's too) comes back; 0 brings it
## back at once, even right where the player stands.
@export var camp_respawn_time: float = 0.0
## A boss camp at the far end of the hall.
@export var has_boss: bool = true
@export var boss_camp_size: int = 24

@export_group("Spawners")
## Spawners keep `spawner_population` monsters alive near them, one more every
## `spawner_interval` seconds (0: one per frame, so instant) while the player
## is close: a farming spot.
@export var spawner_count: int = 2
@export var spawner_population: int = 30
@export var spawner_interval: float = 0.0
## Per spawner kill: chance of an item, and of a refining stone.
@export var spawner_item_chance: float = 0.03
@export var spawner_stone_chance: float = 0.08

@export_group("Rewards")
## Camp drops roll at least this rarity (0 common, 1 magic, 2 rare).
@export var min_drop_rarity: int = 1
## Extra items per cleared camp.
@export var extra_drops: int = 1
## Refining stones from camps multiply by this.
@export var stones_multiplier: float = 2.0
