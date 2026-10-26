class_name LootConfig
extends Resource
## Item drops, rarities, pickup and the backpack.

## Items dropped when a camp's last member dies.
@export var camp_drop_min: int = 1
@export var camp_drop_max: int = 2
## Extra items dropped by the last camp of a zone.
@export var zone_clear_bonus_drops: int = 2
## Rarity weights for common, magic, rare.
@export var rarity_weights: PackedFloat32Array = [60.0, 30.0, 10.0]
## Affixes rolled for common, magic, rare.
@export var rarity_affixes: PackedInt32Array = [1, 2, 3]
@export var rarity_names: PackedStringArray = ["Common", "Magic", "Rare"]
@export var rarity_colors: PackedColorArray = [
	Color(0.92, 0.92, 0.92), Color(0.4, 0.6, 1.0), Color(1.0, 0.85, 0.3),
]
## Affix rolls grow by this fraction per zone level above 1.
@export var value_growth_per_zone: float = 0.15
@export var slot_names: PackedStringArray = ["Wand", "Charm", "Vest"]
@export var rare_prefixes: PackedStringArray = [
	"Grim", "Storm", "Hollow", "Ember", "Dread", "Bright", "Iron", "Wild",
]
@export var affixes: Array[AffixDef] = []
@export var pickup_radius: float = 1.2
## Items within this distance drift toward the player.
@export var magnet_radius: float = 4.0
@export var magnet_speed: float = 10.0
@export var drop_scatter: float = 1.5
@export var ground_capacity: int = 64
@export var backpack_size: int = 16
@export var gem_size: float = 0.32
@export var beam_height: float = 3.5
