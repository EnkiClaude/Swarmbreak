class_name DungeonDef
extends Resource
## A dungeon: a hallway with rooms down both sides (DungeonLayout), entered
## through a gate in the open world. Each room holds a camp; rooms get
## deeper toward the boss room at the far end, and deeper rooms hold harder
## monsters that drop more Geon and better gear. Some rooms are spawners
## that refill at once.

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
## Rooms on each side of the hallway, from the entrance toward the boss.
@export var rooms_per_side: int = 4
@export var room_width: float = 20.0
## A room's length along the hallway.
@export var room_length: float = 18.0
@export var corridor_width: float = 8.0
@export var door_width: float = 6.0
## Hallway before the first rooms, where the player arrives.
@export var entry_length: float = 18.0
@export var boss_room_width: float = 28.0
@export var boss_room_length: float = 22.0

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
## Each room deeper adds this many levels to its monsters (and their loot).
@export var depth_level_step: int = 1
## A boss camp in the room across the hallway's far end.
@export var has_boss: bool = true
@export var boss_camp_size: int = 24
## Camps in each side room, spread over it.
@export var camps_per_room: int = 4
## Camps around the boss in its room, plus spawners there that keep adding
## awake monsters (boss_room_spawners, spawner_population each).
@export var boss_room_camps: int = 4
@export var boss_room_spawners: int = 2

@export_group("Spawners")
## Spawners keep `spawner_population` monsters alive near them, one more every
## `spawner_interval` seconds (0: one per frame, so instant) while the player
## is close: a farming spot. The rooms at spawner_depth are spawners, up to
## spawner_count of them.
@export var spawner_count: int = 2
@export var spawner_depth: int = 1
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
