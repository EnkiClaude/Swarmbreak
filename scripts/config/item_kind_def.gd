class_name ItemKindDef
extends Resource
## A base item type (Staff, Tome, Ring...): its slot, whether it takes both
## hands, the icon the inventory draws for it, and the stat every one of them
## carries (its implicit) before rolled affixes.

## Glyphs ItemIcon can draw.
enum Icon { WAND, SWORD, STAFF, GREATSWORD, TOME, SHIELD, ROBE, PLATE, AMULET, BELT, RING }

@export var display_name: String = "Wand"
@export var slot: AffixDef.Slot = AffixDef.Slot.WEAPON
## A two-handed weapon leaves no room for an off-hand item.
@export var two_handed: bool = false
@export var icon: Icon = Icon.WAND
## Relative chance of dropping among all kinds.
@export var weight: float = 1.0
@export var has_implicit: bool = false
@export var implicit_stat: PlayerStat.Id = PlayerStat.Id.BOLT_DAMAGE
@export var implicit_min: float = 0.0
@export var implicit_max: float = 0.0
