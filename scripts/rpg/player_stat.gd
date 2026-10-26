class_name PlayerStat
extends RefCounted
## The stats that skills and items can raise. Percent stats are summed and
## applied as (1 + total); flat stats are added to the base value.

enum Id {
	MAX_HEALTH,
	MAX_MANA,
	HEALTH_REGEN,
	MANA_REGEN,
	MOVE_SPEED,
	BOLT_DAMAGE,
	FIRE_RATE,
	NOVA_DAMAGE,
	NOVA_RADIUS,
	LURE_RADIUS,
	MANA_PER_KILL,
	DODGE_COOLDOWN,
	ARMOR,
}

const COUNT := 13
const NAMES: PackedStringArray = [
	"max health", "max mana", "health per second", "mana regeneration", "move speed",
	"bolt damage", "fire rate", "nova damage", "nova radius", "lure radius",
	"mana per kill", "dodge cooldown reduction", "damage reduction",
]
## 1 where the stat is a percentage (stored as 0.12 for +12%).
const IS_PERCENT: PackedByteArray = [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1]
## Highest total allowed, so stacking can't break the game.
const CAPS: PackedFloat32Array = [
	1e9, 1e9, 1e9, 1e9, 1.0, 1e9, 2.0, 1e9, 1.0, 1.5, 1e9, 0.6, 0.75,
]


static func describe(stat: int, value: float) -> String:
	if IS_PERCENT[stat] != 0:
		return "+%d%% %s" % [roundi(value * 100.0), NAMES[stat]]
	# Up to two decimals, trailing zeros dropped: 15, 1.5, 0.15.
	return "+%s %s" % [String.num(value, 2), NAMES[stat]]
