class_name InventoryPage
extends RefCounted
## The INVENTORY tab, in three columns:
##   EQUIPPED - one card per slot (Wand, Charm, Vest) with its stats.
##   BACKPACK - a grid of tiles bordered in rarity color, plus Salvage All.
##   DETAILS  - the selected item, compared stat by stat against what is
##              equipped in its slot, with Equip, Salvage and Upgrade.

const TILE_SIZE := Vector2(104, 66)
const GRID_COLUMNS := 4
const CARD_HEIGHT := 60.0
const EQUIPPED_WIDTH := 290.0
const DETAILS_WIDTH := 360.0
## Rarities Salvage All offers, and which need a second press to confirm.
const SALVAGE_ALL_RARITIES: PackedInt32Array = [0, 1]
const CONFIRM_RARITY := 1

## The selected item (equipped or in the backpack), or null.
var selected: ItemData
## Result line under the details, e.g. after refining.
var result_text := ""
var result_color := Color.WHITE

var _menu: CharacterMenu
var _inventory: Inventory
var _loot: LootConfig
var _refinery: Refinery
var _confirm_rarity := -1


func _init(menu: CharacterMenu, inventory: Inventory, loot: LootConfig,
		refinery: Refinery) -> void:
	_menu = menu
	_inventory = inventory
	_loot = loot
	_refinery = refinery


## Clears selection and messages (when the menu opens).
func reset() -> void:
	selected = null
	result_text = ""
	_confirm_rarity = -1


func select(item: ItemData) -> void:
	selected = null if selected == item else item
	result_text = ""
	_confirm_rarity = -1


func is_equipped(item: ItemData) -> bool:
	return item != null and _inventory.equipped[item.slot] == item


## Salvage All for a rarity: magic asks twice, commons go at once.
## Returns the stones gained (0 if only asking for confirmation).
func press_salvage_all(rarity: int) -> int:
	if rarity == CONFIRM_RARITY and _confirm_rarity != rarity:
		_confirm_rarity = rarity
		return 0
	_confirm_rarity = -1
	if selected != null and not is_equipped(selected) and selected.rarity == rarity:
		selected = null
	var preview: Array = _inventory.salvage_all_preview(rarity, _loot.salvage_stones)
	var gained := _inventory.salvage_all(rarity, _loot.salvage_stones)
	result_text = "Salvaged %d %s item%s for %d stones" % [preview[0],
			_loot.rarity_names[rarity].to_lower(), "" if preview[0] == 1 else "s", gained]
	result_color = Color(0.8, 0.85, 1.0)
	return gained


## Builds into parent and returns the control that should take focus.
func build(parent: Container) -> Control:
	if selected != null and not is_equipped(selected) and not _inventory.backpack.has(selected):
		selected = null
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	parent.add_child(columns)
	var focus := _build_equipped(MenuWidgets.column(columns, EQUIPPED_WIDTH))
	var grid_focus := _build_backpack(MenuWidgets.column(columns))
	var detail_focus := _build_details(MenuWidgets.column(columns, DETAILS_WIDTH))
	if detail_focus != null:
		return detail_focus
	return grid_focus if grid_focus != null else focus


func _build_equipped(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("EQUIPPED"))
	var first: Control = null
	for slot in _inventory.equipped.size():
		var item := _inventory.equipped[slot]
		var slot_name := _loot.slot_names[slot].to_upper()
		if item == null:
			parent.add_child(MenuWidgets.empty_card("%s\nempty" % slot_name,
					Vector2(0, CARD_HEIGHT)))
			continue
		var card := MenuWidgets.button("%s\n%s" % [slot_name, item.display_name()])
		card.custom_minimum_size.y = CARD_HEIGHT
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		MenuWidgets.style_item(card, _loot.rarity_colors[item.rarity], item == selected)
		card.pressed.connect(_menu.select_item.bind(item))
		parent.add_child(card)
		parent.add_child(MenuWidgets.label("  " + "\n  ".join(item.describe_lines()),
				MenuWidgets.SMALL_FONT - 2, Color(1, 1, 1, 0.75)))
		if first == null:
			first = card
	return first


func _build_backpack(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("BACKPACK  %d/%d" % [_inventory.backpack.size(),
			_inventory.backpack_size]))
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
		var plus := "  +%d" % item.upgrade_level if item.upgrade_level > 0 else ""
		var tile := MenuWidgets.button("%s%s\n%s" % [_loot.slot_names[item.slot].to_upper(), plus,
				_loot.rarity_names[item.rarity]], MenuWidgets.SMALL_FONT - 2)
		tile.custom_minimum_size = TILE_SIZE
		MenuWidgets.style_item(tile, _loot.rarity_colors[item.rarity], item == selected)
		tile.pressed.connect(_menu.select_item.bind(item))
		grid.add_child(tile)
		if first == null:
			first = tile
	_build_salvage_all(parent)
	return first


func _build_salvage_all(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	for rarity in SALVAGE_ALL_RARITIES:
		var preview: Array = _inventory.salvage_all_preview(rarity, _loot.salvage_stones)
		var rarity_name := _loot.rarity_names[rarity].to_upper()
		var text := "SALVAGE ALL %s\n%d items -> %d stones" % [rarity_name, preview[0], preview[1]]
		if _confirm_rarity == rarity:
			text = "TAP AGAIN TO SALVAGE\n%d %s items" % [preview[0], rarity_name.to_lower()]
		var b := MenuWidgets.button(text, MenuWidgets.SMALL_FONT - 2)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = MenuWidgets.BUTTON_HEIGHT * 1.3
		b.disabled = preview[0] == 0
		b.add_theme_color_override("font_color", MenuWidgets.BAD_COLOR if _confirm_rarity == rarity
				else _loot.rarity_colors[rarity])
		b.pressed.connect(_menu.salvage_all.bind(rarity))
		row.add_child(b)


func _build_details(parent: VBoxContainer) -> Control:
	parent.add_child(MenuWidgets.title("DETAILS   (stones: %d)" % _inventory.stones))
	if selected == null:
		parent.add_child(MenuWidgets.label("Tap an item to see it here and compare it with " +
				"what you're wearing.", MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
		_add_result(parent)
		return null
	var item := selected
	var color := _loot.rarity_colors[item.rarity]
	var equipped := is_equipped(item)
	parent.add_child(MenuWidgets.label(item.display_name(), MenuWidgets.FONT_SIZE, color))
	parent.add_child(MenuWidgets.label("%s %s   -   zone %d%s" % [_loot.rarity_names[item.rarity],
			_loot.slot_names[item.slot], item.item_level, "   -   EQUIPPED" if equipped else ""],
			MenuWidgets.SMALL_FONT - 1, MenuWidgets.DIM_COLOR))
	if equipped:
		parent.add_child(MenuWidgets.label("  " + "\n  ".join(item.describe_lines())))
	else:
		_build_comparison(parent, item)
	var focus: Control = null
	if not equipped:
		var row := HBoxContainer.new()
		parent.add_child(row)
		var equip := MenuWidgets.button("EQUIP")
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip.pressed.connect(_menu.equip_item.bind(item))
		row.add_child(equip)
		var salvage := MenuWidgets.button("SALVAGE +%d" % Inventory.salvage_value(item,
				_loot.salvage_stones))
		salvage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		salvage.pressed.connect(_menu.salvage_item.bind(item))
		row.add_child(salvage)
		focus = equip
	var upgrade := _build_refine(parent, item)
	_add_result(parent)
	return focus if focus != null else upgrade


func _build_comparison(parent: VBoxContainer, item: ItemData) -> void:
	var current := _inventory.equipped[item.slot]
	if current == null:
		parent.add_child(MenuWidgets.label("Your %s slot is empty - all of this is a gain:" %
				_loot.slot_names[item.slot].to_lower(), MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
	else:
		parent.add_child(MenuWidgets.label("Compared with your %s:" % current.display_name(),
				MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
	for row in ItemCompare.compare(item, current):
		var stat: int = row["stat"]
		var change: ItemCompare.Change = row["change"]
		var text := ""
		var color := MenuWidgets.TEXT_COLOR
		match change:
			ItemCompare.Change.BETTER:
				text = "%s   (%s)" % [PlayerStat.describe(stat, row["value"]),
						PlayerStat.describe_delta(stat, row["delta"])]
				color = MenuWidgets.GOOD_COLOR
			ItemCompare.Change.WORSE:
				text = "%s   (%s)" % [PlayerStat.describe(stat, row["value"]),
						PlayerStat.describe_delta(stat, row["delta"])]
				color = MenuWidgets.BAD_COLOR
			ItemCompare.Change.SAME:
				text = "%s   (same)" % PlayerStat.describe(stat, row["value"])
			ItemCompare.Change.GAINED:
				text = "%s   (new)" % PlayerStat.describe(stat, row["value"])
				color = MenuWidgets.GOOD_COLOR
			ItemCompare.Change.LOST:
				text = "loses %s" % PlayerStat.describe(stat, -float(row["delta"]))
				color = MenuWidgets.BAD_COLOR
		parent.add_child(MenuWidgets.label("  " + text, MenuWidgets.SMALL_FONT, color))


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
	b.pressed.connect(_menu.refine.bind(item))
	parent.add_child(b)
	var note := "Fails drop it one level; it never breaks."
	if item.fail_streak > 0:
		note += " Luck +%d%% from %d failures." % [
				roundi(item.fail_streak * _loot.upgrade_pity_per_fail * 100.0), item.fail_streak]
	parent.add_child(MenuWidgets.label(note, MenuWidgets.SMALL_FONT - 2, MenuWidgets.DIM_COLOR))
	return null if b.disabled else b


func _add_result(parent: VBoxContainer) -> void:
	if result_text != "":
		parent.add_child(MenuWidgets.label(result_text, MenuWidgets.SMALL_FONT + 1, result_color))
