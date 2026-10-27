class_name SaveCodec
extends RefCounted
## Turns the player's progress, inventory and zone level into a plain
## Dictionary (for JSON) and back. Decoding never trusts the data: missing
## keys fall back to defaults and out-of-range values are clamped, so an old
## or hand-edited save still loads.

const VERSION := 1
const MAX_RARITY := 2


static func encode(progress: PlayerProgress, inventory: Inventory, zone_level: int) -> Dictionary:
	var equipped: Array = []
	for item in inventory.equipped:
		equipped.append(item_to_dict(item) if item != null else null)
	var backpack: Array = []
	for item in inventory.backpack:
		backpack.append(item_to_dict(item))
	return {
		"version": VERSION,
		"zone_level": zone_level,
		"progress": {
			"level": progress.level,
			"xp": progress.xp,
			"skill_points": progress.skill_points,
			"ranks": Array(progress.ranks),
			"job": progress.job,
			"job_rank": progress.job_rank,
		},
		"inventory": {
			"stones": inventory.stones,
			"equipped": equipped,
			"backpack": backpack,
		},
	}


## Fills progress and inventory from data and returns the saved zone level.
## jobs bounds the job index; max_level and upgrade_max clamp what they say.
static func decode(data: Dictionary, progress: PlayerProgress, inventory: Inventory,
		jobs: JobTree, max_level: int, upgrade_max: int) -> int:
	var p := _dict(data.get("progress"))
	progress.level = clampi(_int(p.get("level"), 1), 1, max_level)
	progress.xp = maxf(_float(p.get("xp"), 0.0), 0.0)
	progress.skill_points = maxi(_int(p.get("skill_points"), 0), 0)
	var ranks := _array(p.get("ranks"))
	for k in progress.ranks.size():
		progress.ranks[k] = maxi(_int(ranks[k], 0), 0) if k < ranks.size() else 0
	var job := _int(p.get("job"), -1)
	progress.job = job if jobs != null and job >= 0 and job < jobs.jobs.size() else -1
	progress.job_rank = clampi(_int(p.get("job_rank"), 0), 1, 2) if progress.job >= 0 else 0

	var inv := _dict(data.get("inventory"))
	inventory.stones = maxi(_int(inv.get("stones"), 0), 0)
	var equipped := _array(inv.get("equipped"))
	for slot in inventory.equipped.size():
		var item: ItemData = null
		if slot < equipped.size() and equipped[slot] is Dictionary:
			item = item_from_dict(equipped[slot], upgrade_max)
		inventory.equipped[slot] = item if item != null and item.slot == slot else null
	inventory.backpack.clear()
	for entry in _array(inv.get("backpack")):
		if inventory.backpack.size() >= inventory.backpack_size:
			break
		if entry is Dictionary:
			inventory.backpack.append(item_from_dict(entry, upgrade_max))
	return maxi(_int(data.get("zone_level"), 1), 1)


static func item_to_dict(item: ItemData) -> Dictionary:
	return {
		"slot": item.slot,
		"rarity": item.rarity,
		"name": item.item_name,
		"stats": Array(item.stats),
		"values": Array(item.values),
		"item_level": item.item_level,
		"upgrade_level": item.upgrade_level,
		"upgrade_bonus": item.upgrade_bonus,
		"fail_streak": item.fail_streak,
	}


static func item_from_dict(d: Dictionary, upgrade_max: int) -> ItemData:
	var item := ItemData.new()
	item.slot = clampi(_int(d.get("slot"), 0), 0, 2)
	item.rarity = clampi(_int(d.get("rarity"), 0), 0, MAX_RARITY)
	item.item_name = str(d.get("name", "Item"))
	var stats := _array(d.get("stats"))
	var values := _array(d.get("values"))
	for k in mini(stats.size(), values.size()):
		var stat := _int(stats[k], -1)
		if stat >= 0 and stat < PlayerStat.COUNT:
			item.stats.append(stat)
			item.values.append(_float(values[k], 0.0))
	item.item_level = maxi(_int(d.get("item_level"), 1), 1)
	item.upgrade_level = clampi(_int(d.get("upgrade_level"), 0), 0, upgrade_max)
	item.upgrade_bonus = maxf(_float(d.get("upgrade_bonus"), 0.0), 0.0)
	item.fail_streak = maxi(_int(d.get("fail_streak"), 0), 0)
	return item


# JSON turns every number into a float and anything can be missing, so read
# each value defensively.
static func _int(v: Variant, fallback: int) -> int:
	if v is int or v is float:
		return int(v)
	return fallback


static func _float(v: Variant, fallback: float) -> float:
	if v is int or v is float:
		return float(v)
	return fallback


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _array(v: Variant) -> Array:
	return v if v is Array else []
