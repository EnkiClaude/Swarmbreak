class_name LootConfig
extends Resource
## Item drops, rarities, pickup and the backpack.

## The currency (refining, salvage), as shown to the player.
@export var currency_name: String = "Geon"
## Each drop is an item with this chance; otherwise it's a pile of Geon.
@export var item_drop_chance: float = 0.1
## Geon in one pile at level 1; piles grow by geon_growth_per_level per level.
@export var geon_pile_min: int = 2
@export var geon_pile_max: int = 5
@export var geon_growth_per_level: float = 0.25
@export var geon_color: Color = Color(1.0, 0.8, 0.3)
## A rare stone any monster may drop, whatever its level: refining with it
## always succeeds.
@export var blessed_name: String = "Blessed Stone"
@export var blessed_drop_chance: float = 0.002
@export var blessed_color: Color = Color(0.7, 0.9, 1.0)
## Drops when a camp's last member dies (items or Geon piles).
@export var camp_drop_min: int = 1
@export var camp_drop_max: int = 2
## Rarities: common, magic, rare, epic, legendary, then set (never rolled:
## set items come only from dungeon bosses, see SetList).
## Rarity weights when rolling; 0 never rolls.
@export var rarity_weights: PackedFloat32Array = [60.0, 30.0, 10.0, 1.2, 0.25, 0.0]
## Affixes rolled per rarity.
@export var rarity_affixes: PackedInt32Array = [1, 2, 3, 4, 5, 4]
## Every rolled value is multiplied by this per rarity.
@export var rarity_power: PackedFloat32Array = [1.0, 1.0, 1.0, 1.3, 1.6, 1.5]
@export var rarity_names: PackedStringArray = ["Common", "Magic", "Rare", "Epic", "Legendary", "Set"]
@export var rarity_colors: PackedColorArray = [
	Color(0.92, 0.92, 0.92), Color(0.4, 0.6, 1.0), Color(1.0, 0.85, 0.3), Color(0.72, 0.38, 1.0),
	Color(1.0, 0.5, 0.12), Color(0.35, 0.95, 0.4),
]
## Items of this rarity and up announce themselves when picked up.
@export var announce_rarity: int = 3
## Affix rolls grow by this fraction per item level (camp level) above 1.
@export var value_growth_per_zone: float = 0.15
## Base item types that can drop; each says its slot (see ItemKindDef).
@export var item_kinds: Array[ItemKindDef] = []
## Names of AffixDef.Slot values, for labels.
@export var slot_names: PackedStringArray = [
	"Weapon", "Amulet", "Armor", "Off hand", "Belt", "Ring", "Helm", "Gloves", "Pants", "Boots", "Pet",
]
@export var rare_prefixes: PackedStringArray = [
	"Grim", "Storm", "Hollow", "Ember", "Dread", "Bright", "Iron", "Wild",
]
## Name prefixes for legendary items (rare and epic use rare_prefixes).
@export var legendary_prefixes: PackedStringArray = [
	"Ancient", "Eternal", "Sovereign", "Celestial", "Abyssal", "Radiant",
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

@export_group("Refining")
@export var upgrade_max: int = 10
## Each + adds this fraction to every stat on the item.
@export var upgrade_bonus_per_level: float = 0.08
## Success chance to reach +1, +2, ... +upgrade_max.
@export var upgrade_chances: PackedFloat32Array = [
	0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.42, 0.34, 0.27, 0.2,
]
## Each failure in a row on an item adds this to its next chance.
@export var upgrade_pity_per_fail: float = 0.04
## Geon to attempt +1 is cost_base; each level adds cost_per_level.
@export var upgrade_cost_base: int = 1
@export var upgrade_cost_per_level: int = 1
## Geon from salvaging an item, per rarity.
@export var salvage_stones: PackedInt32Array = [1, 3, 6, 15, 40, 30]
@export var beam_height: float = 3.5

@export_group("Talismans")
## Talismans drop with rolled stats and can be applied to worn gear, one
## per free socket. A failed attempt destroys the talisman, never the gear.
@export var talisman_name: String = "Talisman"
## Chance a camp drop that isn't an item is a talisman instead of Geon.
@export var talisman_drop_chance: float = 0.06
## Highest talisman rarity that can roll (they don't come in set rarity).
@export var talisman_max_rarity: int = 4
## Stats a talisman carries, per rarity.
@export var talisman_stat_counts: PackedInt32Array = [1, 1, 1, 2, 2, 2]
## A talisman's stats are this fraction of an affix's roll.
@export var talisman_power: float = 0.6
## Sockets an item has for talismans, per rarity.
@export var talisman_sockets: PackedInt32Array = [1, 1, 2, 2, 3, 3]
## Success chance for the first, second, third talisman on an item.
@export var talisman_chances: PackedFloat32Array = [0.75, 0.55, 0.4]
