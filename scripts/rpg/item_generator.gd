class_name ItemGenerator
extends RefCounted
## Rolls random items: a kind (which sets the slot, hands and implicit stat),
## a rarity, then distinct affixes allowed in that slot, with values growing
## with the level of the camp that dropped it and with the rarity's power.
## Also makes set pieces (fixed stats, from SetList).

var _config: LootConfig
var _rng := RandomNumberGenerator.new()


func _init(config: LootConfig, seed_value: int = 0) -> void:
	_config = config
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## min_rarity forces at least that rarity (bosses drop rares).
## force_kind and force_rarity (>= 0) pick them instead of rolling.
func roll(zone_level: int, min_rarity: int = 0, force_kind: int = -1,
		force_rarity: int = -1) -> ItemData:
	var item := ItemData.new()
	var kind: ItemKindDef = null
	if _config.item_kinds.is_empty():
		item.slot = _rng.randi_range(0, AffixDef.Slot.PET - 1)
	else:
		if force_kind >= 0:
			item.kind = clampi(force_kind, 0, _config.item_kinds.size() - 1)
		else:
			var kind_weights := PackedFloat32Array()
			for def in _config.item_kinds:
				kind_weights.append(def.weight)
			item.kind = _pick_weighted(kind_weights)
		kind = _config.item_kinds[item.kind]
		item.slot = kind.slot
		item.two_handed = kind.two_handed
	item.rarity = force_rarity if force_rarity >= 0 \
			else maxi(_pick_weighted(_config.rarity_weights), min_rarity)
	item.upgrade_bonus = _config.upgrade_bonus_per_level
	item.item_level = zone_level
	var growth := _growth(zone_level) * _power(item.rarity)
	if kind != null and kind.has_implicit:
		item.stats.append(kind.implicit_stat)
		item.values.append(_round_value(kind.implicit_stat,
				_rng.randf_range(kind.implicit_min, kind.implicit_max) * growth))
	var allowed: Array[AffixDef] = []
	for affix in _config.affixes:
		if affix.slots.has(item.slot) and not item.stats.has(affix.stat):
			allowed.append(affix)
	var wanted := mini(_config.rarity_affixes[item.rarity], allowed.size())
	for _n in wanted:
		var weights := PackedFloat32Array()
		for affix in allowed:
			weights.append(affix.weight)
		var picked := allowed[_pick_weighted(weights)]
		allowed.erase(picked)
		var value := _rng.randf_range(picked.min_value, picked.max_value) * growth
		item.stats.append(picked.stat)
		item.values.append(_round_value(picked.stat, value))
	item.item_name = _name_for(item, kind)
	return item


## A piece of Dreadforged armor (LootConfig.dread_rarity), which only the
## Dread Lord drops: an armor kind (armor, helm, gloves, pants, boots, belt
## or shield) rolled at that rarity, named "Dreadforged <kind>".
func roll_dread(zone_level: int) -> ItemData:
	var armor := PackedInt32Array()
	for k in _config.item_kinds.size():
		if _config.dread_slots.has(int(_config.item_kinds[k].slot)):
			armor.append(k)
	var kind := armor[_rng.randi() % armor.size()] if not armor.is_empty() else -1
	var item := roll(zone_level, 0, kind, _config.dread_rarity)
	var base := _config.item_kinds[item.kind].display_name if item.kind >= 0 else "Armor"
	item.item_name = "%s %s" % [_config.dread_prefix, base]
	return item


## One piece of a set, picked at random, at a level.
func roll_set_piece(sets: SetList, set_index: int, zone_level: int) -> ItemData:
	var def := sets.sets[set_index]
	var piece := def.pieces[_rng.randi() % def.pieces.size()]
	var item := ItemData.new()
	item.kind = clampi(piece.kind, 0, _config.item_kinds.size() - 1)
	var kind := _config.item_kinds[item.kind]
	item.slot = kind.slot
	item.two_handed = kind.two_handed
	item.rarity = sets.set_rarity
	item.set_id = set_index
	item.item_name = piece.piece_name
	item.item_level = zone_level
	item.upgrade_bonus = _config.upgrade_bonus_per_level
	var growth := _growth(zone_level)
	for k in mini(piece.stats.size(), piece.values.size()):
		item.stats.append(piece.stats[k])
		item.values.append(_round_value(piece.stats[k], piece.values[k] * growth))
	return item


func _growth(zone_level: int) -> float:
	return 1.0 + _config.value_growth_per_zone * (zone_level - 1)


func _power(rarity: int) -> float:
	if _config.rarity_power.is_empty():
		return 1.0
	return _config.rarity_power[clampi(rarity, 0, _config.rarity_power.size() - 1)]


func _name_for(item: ItemData, kind: ItemKindDef) -> String:
	var base := kind.display_name if kind != null else _config.slot_names[item.slot]
	if item.rarity == _config.dread_rarity:
		return "%s %s" % [_config.dread_prefix, base]
	if item.rarity >= 4 and not _config.legendary_prefixes.is_empty():
		return "%s %s" % [_config.legendary_prefixes[_rng.randi() %
				_config.legendary_prefixes.size()], base]
	if item.rarity >= 2 and not _config.rare_prefixes.is_empty():
		return "%s %s" % [_config.rare_prefixes[_rng.randi() % _config.rare_prefixes.size()], base]
	# Named after its first rolled affix (after the implicit, if any).
	var first := 1 if kind != null and kind.has_implicit else 0
	if item.rarity == 1 and item.stats.size() > first:
		return "%s of %s" % [base, PlayerStat.NAMES[item.stats[first]].capitalize()]
	return base


func _round_value(stat: int, value: float) -> float:
	if PlayerStat.IS_PERCENT[stat] != 0:
		return roundf(value * 100.0) / 100.0
	return roundf(value * 10.0) / 10.0


func _pick_weighted(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := _rng.randf() * total
	var last := 0
	for k in weights.size():
		if weights[k] <= 0.0:
			continue
		last = k
		r -= weights[k]
		if r <= 0.0:
			return k
	# Rounding left a sliver: the last entry that can roll (never a 0 weight).
	return last
