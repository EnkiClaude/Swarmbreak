class_name EnchantPage
extends RefCounted
## The ENCHANT tab: talisman stacks on the left (one row per kind and tier,
## with how many); on the right, dissolving the chosen stack first, then
## essence, then the chosen stack and a button per worn
## item with a free socket (with its chance), or, with none chosen, every
## worn item's sockets and the talisman stats it already carries. Talismans
## can also be dissolved into Arcane Essence, which binds Scrolls of Power
## (one attribute point each).

const LIST_WIDTH := 520.0

## The talisman stack (id) chosen, or -1.
var selected := -1
## Result line after an attempt.
var result_text := ""
var result_color := Color.WHITE

var _menu: CharacterMenu
var _inventory: Inventory
var _loot: LootConfig
var _rules: TalismanRules


func _init(menu: CharacterMenu, inventory: Inventory, loot: LootConfig,
		rules: TalismanRules) -> void:
	_menu = menu
	_inventory = inventory
	_loot = loot
	_rules = rules


func reset() -> void:
	selected = -1
	result_text = ""


## Chooses a stack (again: lets go of it).
func select(id: int) -> void:
	selected = -1 if selected == id else id
	result_text = ""


## Builds into parent and returns the control that should take focus.
func build(parent: Container) -> Control:
	if selected >= 0 and _inventory.talisman_count(selected) <= 0:
		selected = -1
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	parent.add_child(columns)
	var focus := _build_list(MenuWidgets.column(columns, LIST_WIDTH))
	var right := MenuWidgets.column(columns)
	var dissolve: Control = null
	if selected >= 0:
		dissolve = _build_dissolve(right, selected)
	_build_essence(right)
	var apply: Control = null
	if selected >= 0:
		apply = _build_talisman(right, selected)
	else:
		_build_sockets(right)
	if result_text != "":
		right.add_child(MenuWidgets.label(result_text, MenuWidgets.SMALL_FONT + 1, result_color))
	if apply == null:
		apply = dissolve
	return apply if apply != null else focus


## One row per talisman stack: count, name and what it gives.
func _build_list(parent: VBoxContainer) -> Control:
	var ids := _inventory.talisman_ids()
	var total := 0
	for id in ids:
		total += _inventory.talisman_count(id)
	parent.add_child(MenuWidgets.title("TALISMANS  %d" % total))
	if ids.is_empty():
		parent.add_child(MenuWidgets.label("None yet. They drop from camps; apply them to " +
				"worn gear for extra stats.", MenuWidgets.SMALL_FONT - 3, MenuWidgets.DIM_COLOR))
		return null
	var first: Control = null
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
		MenuWidgets.style_item(b, color, id == selected)
		b.pressed.connect(_menu.select_talisman.bind(id))
		grid.add_child(b)
		if first == null or id == selected:
			first = b
	return first


## Essence on hand, and binding the next Scroll of Power.
func _build_essence(parent: VBoxContainer) -> void:
	var cost := _rules.scroll_cost(_inventory)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := MenuWidgets.label("%s: %d" % [_loot.essence_name.to_upper(), _inventory.essence],
			MenuWidgets.SMALL_FONT + 1, _loot.essence_color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var b := MenuWidgets.button("BIND %s (%d): +1 attribute point" % [
			_loot.scroll_name.to_upper(), cost], MenuWidgets.SMALL_FONT - 2)
	b.disabled = _inventory.essence < cost
	b.add_theme_color_override("font_color", _loot.essence_color)
	b.pressed.connect(_menu.bind_scroll)
	row.add_child(b)
	parent.add_child(HSeparator.new())


## Every worn item's sockets and what its talismans already give.
func _build_sockets(parent: VBoxContainer) -> void:
	parent.add_child(MenuWidgets.title("SOCKETS ON WORN GEAR"))
	parent.add_child(MenuWidgets.label("Choose a talisman on the left, then the gear to apply " +
			"it to. A failed attempt only loses the talisman.", MenuWidgets.SMALL_FONT - 2,
			MenuWidgets.DIM_COLOR))
	for position in InventoryPage.CARD_ORDER:
		var gear := _inventory.equipped[position]
		if gear == null or _rules.sockets(gear) == 0:
			continue
		var lines := PackedStringArray()
		for k in gear.talisman_stats.size():
			lines.append(PlayerStat.describe(gear.talisman_stats[k], gear.talisman_values[k]))
		var text := "%s: %s   %d / %d sockets%s" % [Inventory.EQUIP_NAMES[position],
				gear.display_name(), gear.talisman_sockets_used, _rules.sockets(gear),
				("\n    " + ", ".join(lines)) if not lines.is_empty() else ""]
		parent.add_child(MenuWidgets.label(text, MenuWidgets.SMALL_FONT - 2,
				_loot.rarity_colors[gear.rarity]))


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
	for position in InventoryPage.CARD_ORDER:
		var gear := _inventory.equipped[position]
		if gear == null or _rules.sockets(gear) == 0:
			continue
		any = true
		var free := _rules.free_sockets(gear)
		var text := "%s: %s   %s" % [Inventory.EQUIP_NAMES[position], gear.display_name(),
				("%d%%  (%d free)" % [roundi(_rules.chance_for(gear) * 100.0), free])
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


## Dissolving the chosen stack (one, or all of it) for essence: first on the
## right, so it's right there once a talisman is chosen.
func _build_dissolve(parent: VBoxContainer, id: int) -> Control:
	var each := TalismanRules.essence_of(_loot, id)
	var have := _inventory.talisman_count(id)
	parent.add_child(MenuWidgets.label("DISSOLVE %s  (%d essence each)" % [
			TalismanRules.display_name(_loot, id).to_upper(), each], MenuWidgets.SMALL_FONT - 2,
			_loot.essence_color))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var one := MenuWidgets.button("DISSOLVE ONE  +%d" % each, MenuWidgets.SMALL_FONT - 2)
	one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	one.add_theme_color_override("font_color", _loot.essence_color)
	one.pressed.connect(_menu.dissolve_talisman.bind(id, 1))
	row.add_child(one)
	var all := MenuWidgets.button("DISSOLVE ALL %d  +%d" % [have, each * have],
			MenuWidgets.SMALL_FONT - 2)
	all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all.add_theme_color_override("font_color", _loot.essence_color)
	all.pressed.connect(_menu.dissolve_talisman.bind(id, have))
	row.add_child(all)
	return one
