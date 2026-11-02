class_name InventoryPage
extends RefCounted
## The INVENTORY tab, in three columns:
##   EQUIPPED - a card per position (main and off hand, armor, amulet, two
##              rings, belt) with the item's icon.
##   BACKPACK - a grid of icon tiles bordered in rarity color, plus Salvage
##              All for each rarity and for everything.
##   DETAILS  - the selected item, compared stat by stat against what wearing
##              it would take off, with Equip (left or right for rings),
##              Unequip, Salvage and Upgrade; a selected talisman stack
##              lists the worn gear it can be applied to.
## Talismans stack in a list under the backpack grid (one row per kind and
## tier, with how many).
## Hovering or focusing an item shows its tooltip (ItemTooltip) beside it.
## After any action, focus goes back to the item the player was on, so a
## controller's A never lands on a button by itself.

const TILE_SIZE := Vector2(60, 60)
const GRID_COLUMNS := 8
const CARD_SIZE := Vector2(170, 58)
const EQUIPPED_WIDTH := 350.0
const DETAILS_WIDTH := 330.0
## Equipment positions in the order the cards show, two per row.
const CARD_ORDER: PackedInt32Array = [
	Inventory.Equip.HELM, Inventory.Equip.AMULET, Inventory.Equip.MAIN_HAND,
	Inventory.Equip.OFF_HAND, Inventory.Equip.ARMOR, Inventory.Equip.GLOVES,
	Inventory.Equip.PANTS, Inventory.Equip.BELT, Inventory.Equip.BOOTS, Inventory.Equip.PET,
	Inventory.Equip.RING_1, Inventory.Equip.RING_2,
]
## Outline shown in an empty position, indexed by Inventory.Equip.
const EMPTY_GLYPHS: PackedInt32Array = [
	ItemKindDef.Icon.WAND, ItemKindDef.Icon.AMULET, ItemKindDef.Icon.ROBE, ItemKindDef.Icon.TOME,
	ItemKindDef.Icon.BELT, ItemKindDef.Icon.RING, ItemKindDef.Icon.RING, ItemKindDef.Icon.HELM,
	ItemKindDef.Icon.GLOVES, ItemKindDef.Icon.PANTS, ItemKindDef.Icon.BOOTS, ItemKindDef.Icon.EGG,
]
## Salvage All buttons: one per rarity, then -1 for everything. All but
## commons need a second press to confirm.
const SALVAGE_ALL_CHOICES: PackedInt32Array = [0, 1, 2, 3, 4, 5, -1]
const NO_CONFIRM := -2

## The selected item (equipped or in the backpack), or null.
var selected: ItemData
## The item whose tile last had focus or was picked: focus returns to it.
var focus_item: ItemData
## Applies talismans (null hides them).
var talismans: TalismanRules
## The summonable boss, for the shard count and SUMMON (null hides them).
var summon_config: SummonConfig
## The talisman stack (id) shown in the details, or -1.
var selected_talisman := -1
## Result line under the details, e.g. after refining.
var result_text := ""
var result_color := Color.WHITE

var _menu: CharacterMenu
var _inventory: Inventory
var _loot: LootConfig
var _refinery: Refinery
var _confirm_rarity := NO_CONFIRM
var _focus_tile: Control


func _init(menu: CharacterMenu, inventory: Inventory, loot: LootConfig,
		refinery: Refinery) -> void:
	_menu = menu
	_inventory = inventory
	_loot = loot
	_refinery = refinery


## Clears selection and messages (when the menu opens).
func reset() -> void:
	selected = null
	selected_talisman = -1
	focus_item = null
	result_text = ""
	_confirm_rarity = NO_CONFIRM


func select(item: ItemData) -> void:
	selected = null if selected == item else item
	selected_talisman = -1
	result_text = ""
	_confirm_rarity = NO_CONFIRM


## Shows a talisman stack in the details (again: hides it).
func select_talisman(id: int) -> void:
	selected_talisman = -1 if selected_talisman == id else id
	selected = null
	result_text = ""
	_confirm_rarity = NO_CONFIRM


func is_equipped(item: ItemData) -> bool:
	return _inventory.is_equipped(item)


## Salvage All for a rarity (-1: everything in the backpack). Commons go at
## once; the rest ask twice. Returns the Geon gained (0 if only asking).
func press_salvage_all(rarity: int) -> int:
	if rarity != 0 and _confirm_rarity != rarity:
		_confirm_rarity = rarity
		return 0
	_confirm_rarity = NO_CONFIRM
	if selected != null and not is_equipped(selected) and (rarity < 0 or selected.rarity == rarity):
		selected = null
	var preview: Array = _inventory.salvage_all_preview(rarity, _loot.salvage_stones)
	var gained := _inventory.salvage_all(rarity, _loot.salvage_stones)
	result_text = "Salvaged %d %sitem%s for %d %s" % [preview[0],
			_salvage_name(rarity).to_lower() + " " if rarity >= 0 else "",
			"" if preview[0] == 1 else "s", gained, _loot.currency_name]
	result_color = Color(0.8, 0.85, 1.0)
	return gained


func _salvage_name(rarity: int) -> String:
	return _loot.rarity_names[rarity] if rarity >= 0 else "Everything"


## Builds into parent and returns the control that should take focus.
func build(parent: Container) -> Control:
	if selected != null and not is_equipped(selected) and not _inventory.backpack.has(selected):
		selected = null
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	parent.add_child(columns)
	_focus_tile = null
	_build_equipped(MenuWidgets.column(columns, EQUIPPED_WIDTH))
	_build_backpack(MenuWidgets.column(columns))
	var detail_focus := _build_details(MenuWidgets.column(columns, DETAILS_WIDTH))
	# Back to the item the player was on; with none (just opened), focus stays
	# on the tab header, so nothing looks picked until the player moves.
	return _focus_tile if _focus_tile != null else detail_focus


func _build_equipped(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("EQUIPPED"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var first: Control = null
	for position in CARD_ORDER:
		var item := _inventory.equipped[position]
		var card := MenuWidgets.slot_card(Inventory.EQUIP_NAMES[position], item,
				EMPTY_GLYPHS[position], _loot, item != null and item == selected, CARD_SIZE)
		grid.add_child(card)
		if item == null:
			continue
		_hook_item(card, item)
		if first == null:
			first = card
	return first


## Click selects; hover or focus shows the tooltip.
func _hook_item(control: Button, item: ItemData) -> void:
	if item == focus_item:
		_focus_tile = control
	control.pressed.connect(_remember.bind(item))
	control.focus_entered.connect(_remember.bind(item))
	control.pressed.connect(_menu.select_item.bind(item))
	control.mouse_entered.connect(_menu.show_tooltip.bind(item, control))
	control.focus_entered.connect(_menu.show_tooltip.bind(item, control))
	control.mouse_exited.connect(_menu.hide_tooltip.bind(control))
	control.focus_exited.connect(_menu.hide_tooltip.bind(control))


func _remember(item: ItemData) -> void:
	focus_item = item


func _build_backpack(parent: VBoxContainer) -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	parent.add_child(head)
	var title := MenuWidgets.title("BACKPACK  %d/%d" % [_inventory.backpack.size(),
			_inventory.backpack_size])
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var sort := MenuWidgets.button("SORT: %s" % Inventory.SORT_NAMES[_inventory.sort_mode].to_upper(),
			MenuWidgets.SMALL_FONT - 2)
	sort.tooltip_text = "Change how the backpack is ordered"
	sort.pressed.connect(_menu.cycle_sort)
	head.add_child(sort)
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var first: Control = null
	for index in _inventory.backpack_size:
		if index >= _inventory.backpack.size():
			grid.add_child(MenuWidgets.empty_card("", TILE_SIZE))
			continue
		var item := _inventory.backpack[index]
		var tile := MenuWidgets.item_tile(item, _loot, item == selected, TILE_SIZE)
		_hook_item(tile, item)
		grid.add_child(tile)
		if first == null:
			first = tile
	_build_talisman_list(parent)
	_build_summon(parent)
	_build_salvage_all(parent)
	return first


## Shards toward the summonable boss, and SUMMON once there are enough.
func _build_summon(parent: VBoxContainer) -> void:
	if summon_config == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var have := _inventory.summon_shards
	var l := MenuWidgets.label("%sS  %d/%d" % [summon_config.shard_name.to_upper(), have,
			summon_config.shards_needed], MenuWidgets.SMALL_FONT, summon_config.shard_color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := MenuWidgets.button("SUMMON THE %s" % summon_config.boss_name.to_upper(),
			MenuWidgets.SMALL_FONT - 2)
	b.disabled = have < summon_config.shards_needed
	b.add_theme_color_override("font_color", summon_config.color.lightened(0.3))
	b.pressed.connect(_menu.request_summon)
	row.add_child(b)


## One row per talisman stack: count, name and what it gives.
func _build_talisman_list(parent: VBoxContainer) -> void:
	if talismans == null:
		return
	var ids := _inventory.talisman_ids()
	var total := 0
	for id in ids:
		total += _inventory.talisman_count(id)
	parent.add_child(MenuWidgets.label("TALISMANS  %d" % total, MenuWidgets.SMALL_FONT,
			MenuWidgets.TITLE_COLOR))
	if ids.is_empty():
		parent.add_child(MenuWidgets.label("None yet. They drop from camps; apply them to " +
				"worn gear for extra stats.", MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for id: int in ids:
		if not TalismanRules.is_valid(_loot, id):
			continue
		var color := _loot.rarity_colors[TalismanRules.tier_of(id)]
		var text := "x%d  %s\n%s" % [_inventory.talisman_count(id),
				TalismanRules.display_name(_loot, id),
				", ".join(TalismanRules.describe_lines(_loot, id))]
		var b := MenuWidgets.button(text, MenuWidgets.SMALL_FONT - 4)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		MenuWidgets.style_item(b, color, id == selected_talisman)
		b.pressed.connect(_menu.select_talisman.bind(id))
		grid.add_child(b)
		if id == selected_talisman:
			_focus_tile = b


func _build_salvage_all(parent: VBoxContainer) -> void:
	parent.add_child(MenuWidgets.label("SALVAGE ALL (equipped items are never touched)",
			MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for rarity in SALVAGE_ALL_CHOICES:
		var preview: Array = _inventory.salvage_all_preview(rarity, _loot.salvage_stones)
		var label := _salvage_name(rarity).to_upper()
		var text := "%s\n%d items -> %d %s" % [label, preview[0], preview[1], _loot.currency_name]
		if _confirm_rarity == rarity:
			text = "TAP AGAIN\nsalvage %d items" % preview[0]
		var b := MenuWidgets.button(text, MenuWidgets.SMALL_FONT - 3)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = MenuWidgets.BUTTON_HEIGHT * 1.2
		b.disabled = preview[0] == 0
		var color := _loot.rarity_colors[rarity] if rarity >= 0 else Color(1.0, 0.6, 0.4)
		b.add_theme_color_override("font_color", MenuWidgets.BAD_COLOR if _confirm_rarity == rarity
				else color)
		b.pressed.connect(_menu.salvage_all.bind(rarity))
		grid.add_child(b)


func _build_details(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("DETAILS   (%s: %d)" % [_loot.currency_name,
			_inventory.stones]))
	if selected_talisman >= 0 and _inventory.talisman_count(selected_talisman) > 0:
		var first := _build_talisman(parent, selected_talisman)
		_add_result(parent)
		return first
	if selected == null:
		parent.add_child(MenuWidgets.label("Tap an item to see it here and compare it with " +
				"what you're wearing. Double-click (or double-tap) to wear it or take it off.",
				MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
		_add_result(parent)
		return null
	var item := selected
	var color := _loot.rarity_colors[item.rarity]
	var equipped := is_equipped(item)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	parent.add_child(head)
	var icon := ItemIcon.make(ItemIcon.glyph_for(item, _loot), color)
	icon.custom_minimum_size = Vector2(56, 56)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(MenuWidgets.label(item.display_name(), MenuWidgets.FONT_SIZE - 2, color))
	names.add_child(MenuWidgets.label(ItemTooltip.describe_kind(item, _loot) + ("   -   EQUIPPED"
			if equipped else ""), MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
	if equipped:
		parent.add_child(MenuWidgets.label("  " + "\n  ".join(item.describe_lines())))
	else:
		ItemTooltip.add_comparison(parent, item, _inventory, _loot, MenuWidgets.SMALL_FONT)
	ItemTooltip.add_set_lines(parent, item, _inventory, MenuWidgets.SMALL_FONT - 1)
	ItemTooltip.add_socket_line(parent, item, _loot, MenuWidgets.SMALL_FONT - 1)
	var focus: Control = null
	var row := HBoxContainer.new()
	parent.add_child(row)
	if equipped:
		var off := MenuWidgets.button("UNEQUIP")
		off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		off.disabled = _inventory.backpack.size() >= _inventory.backpack_size
		off.pressed.connect(_menu.unequip.bind(_inventory.position_of(item)))
		row.add_child(off)
	else:
		for position in Inventory.positions_for(item.slot):
			var rings := item.slot == AffixDef.Slot.RING
			var equip := MenuWidgets.button(("EQUIP " + Inventory.EQUIP_NAMES[position].get_slice(" ",
					0).to_upper()) if rings else "EQUIP")
			equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			equip.disabled = not _inventory.can_equip(item, position)
			equip.pressed.connect(_menu.equip_item.bind(item, position))
			row.add_child(equip)
			if focus == null and not equip.disabled:
				focus = equip
		var salvage := MenuWidgets.button("SALVAGE +%d" % Inventory.salvage_value(item,
				_loot.salvage_stones))
		salvage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		salvage.pressed.connect(_menu.salvage_item.bind(item))
		row.add_child(salvage)
	var upgrade := _build_refine(parent, item)
	_add_result(parent)
	return focus if focus != null else upgrade


## A talisman stack: its name, build, stats, and a button per worn item
## with a free socket (with its chance).
func _build_talisman(parent: VBoxContainer, id: int) -> Control:
	var color := _loot.rarity_colors[TalismanRules.tier_of(id)]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	parent.add_child(head)
	var icon := ItemIcon.make(ItemKindDef.Icon.TALISMAN, color)
	icon.custom_minimum_size = Vector2(56, 56)
	head.add_child(icon)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	names.add_child(MenuWidgets.label(TalismanRules.display_name(_loot, id),
			MenuWidgets.FONT_SIZE - 2, color))
	names.add_child(MenuWidgets.label("%s   -   you have %d" % [TalismanRules.build_hint(_loot, id),
			_inventory.talisman_count(id)], MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
	parent.add_child(MenuWidgets.label("  " + "\n  ".join(TalismanRules.describe_lines(_loot, id))))
	parent.add_child(MenuWidgets.label("APPLY TO WORN GEAR (uses one; if it fails it crumbles, " +
			"the gear is never harmed)", MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
	var first: Control = null
	var any := false
	for position in CARD_ORDER:
		var gear := _inventory.equipped[position]
		if gear == null or talismans.sockets(gear) == 0:
			continue
		any = true
		var free := talismans.free_sockets(gear)
		var text := "%s: %s   %s" % [Inventory.EQUIP_NAMES[position], gear.display_name(),
				("%d%%  (%d free)" % [roundi(talismans.chance_for(gear) * 100.0), free])
				if free > 0 else "no free socket"]
		var b := MenuWidgets.button(text, MenuWidgets.SMALL_FONT - 2)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = free <= 0
		b.add_theme_color_override("font_color", _loot.rarity_colors[gear.rarity])
		b.pressed.connect(_menu.apply_talisman.bind(id, gear))
		parent.add_child(b)
		if first == null and not b.disabled:
			first = b
	if not any:
		parent.add_child(MenuWidgets.label("Wear some gear first.", MenuWidgets.SMALL_FONT,
				MenuWidgets.DIM_COLOR))
	return first


func _build_refine(parent: VBoxContainer, item: ItemData) -> Control:
	if _refinery == null:
		return null
	if _refinery.is_maxed(item):
		parent.add_child(MenuWidgets.label("Fully refined (+%d)" % item.upgrade_level,
				MenuWidgets.SMALL_FONT, Color(1.0, 0.85, 0.3)))
		return null
	var cost := _refinery.cost_for(item)
	var chance := roundi(_refinery.chance_for(item) * 100.0)
	var b := MenuWidgets.button("UPGRADE +%d -> +%d   %d%%   cost %d" % [item.upgrade_level,
			item.upgrade_level + 1, chance, cost])
	b.disabled = _inventory.stones < cost
	b.pressed.connect(_menu.refine.bind(item, false))
	parent.add_child(b)
	var blessed := MenuWidgets.button("%s  +%d -> +%d   100%%   (have %d)" % [
			_loot.blessed_name.to_upper(), item.upgrade_level, item.upgrade_level + 1,
			_inventory.blessed_stones])
	blessed.disabled = _inventory.blessed_stones <= 0
	blessed.add_theme_color_override("font_color", _loot.blessed_color)
	blessed.pressed.connect(_menu.refine_blessed.bind(item))
	parent.add_child(blessed)
	var note := "Fails drop it one level; it never breaks."
	if item.fail_streak > 0:
		note += " Luck +%d%% from %d failures." % [
				roundi(item.fail_streak * _loot.upgrade_pity_per_fail * 100.0), item.fail_streak]
	parent.add_child(MenuWidgets.label(note, MenuWidgets.SMALL_FONT - 2, MenuWidgets.DIM_COLOR))
	return null if b.disabled else b


func _add_result(parent: VBoxContainer) -> void:
	if result_text != "":
		parent.add_child(MenuWidgets.label(result_text, MenuWidgets.SMALL_FONT + 1, result_color))
