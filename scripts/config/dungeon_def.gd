class_name DungeonDef
extends Resource
## A dungeon (DungeonLayout), entered through a gate in the open world: a
## safe lobby, a corridor to a big open room with camps spread over it, and
## a corridor on to the boss room, whose camps are harder and drop more Geon
## and better gear. Monsters that die are replaced at once.

@export var display_name: String = "Dungeon"
## Usually an indoor theme (walls, ceiling, lanterns).
@export var theme: ZoneTheme
@export var level: int = 4
## Index into WorldConfig.regions of the region holding the entrance gate.
@export var region: int = 0
## Where the gate stands, relative to that region's center.
@export var gate_offset: Vector2 = Vector2.ZERO
## Color of the gate's glowing doorway and its minimap marker.
@export var gate_color: Color = Color(0.9, 0.3, 0.25)

@export_group("Layout")
## From the portal north: a safe lobby, a corridor, a big open room (the
## arena), another corridor, and the boss room.
@export var lobby_width: float = 16.0
@export var lobby_length: float = 18.0
@export var corridor_width: float = 8.0
@export var corridor_length: float = 14.0
@export var arena_width: float = 56.0
@export var arena_length: float = 44.0
@export var boss_room_width: float = 64.0
@export var boss_room_length: float = 50.0

@export_group("Monsters")
## Members per room's camp.
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
## Every monster that dies is replaced at once, nonstop (not the boss's
## camp, which comes back whole once cleared). Their kills drop loot one at
## a time (spawner_drop_chance, spawner_geon_chance).
@export var instant_respawn: bool = true
## The boss room's monsters are this many levels above the arena's.
@export var depth_level_step: int = 1
## A boss camp in the middle of the boss room.
@export var has_boss: bool = true
@export var boss_camp_size: int = 24
## Camps spread over the arena (the first of them spawners, up to
## arena_spawners) and around the boss in its room (plus boss_room_spawners).
@export var arena_camps: int = 5
@export var arena_spawners: int = 0
@export var boss_room_camps: int = 10
@export var boss_room_spawners: int = 0

@export_group("Spawners")
## Spawners keep `spawner_population` monsters alive near them, one more every
## `spawner_interval` seconds (0: one per frame, so instant) while the player
## is close: a farming spot (arena_spawners, boss_room_spawners).
@export var spawner_population: int = 30
@export var spawner_interval: float = 0.0
## Per spawner kill: chance of a drop (an item at LootConfig.item_drop_chance,
## otherwise Geon), and of an extra small pile of Geon.
@export var spawner_drop_chance: float = 0.03
@export var spawner_geon_chance: float = 0.08

@export_group("Rewards")
## Camp drops roll at least this rarity (0 common, 1 magic, 2 rare).
@export var min_drop_rarity: int = 1
## Extra drops per cleared camp.
@export var extra_drops: int = 1
## Geon piles from camps and spawners multiply by this.
@export var geon_multiplier: float = 2.0
## Each room deeper adds this to the Geon multiplier.
@export var depth_geon_step: float = 0.5
## Every this many rooms deeper raises the minimum item rarity by one.
@export var deep_rarity_depth: int = 3
## The item set (index into SetList.sets) this dungeon's boss drops, or -1.
@export var set_index: int = -1
