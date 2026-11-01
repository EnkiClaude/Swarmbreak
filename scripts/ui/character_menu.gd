class_name CharacterMenu
extends CanvasLayer
## The character screen, with two tabs: CHARACTER (path, skills, totals,
## New Game; see CharacterPage) and INVENTORY (equipment, backpack, item
## details; see InventoryPage). Opens with character_menu (Tab/C, Start,
## touch CHAR) or straight to the inventory with menu_inventory (I, Y);
## LB/RB or Q/E switch tabs while open. Pauses the game while open, and
## touches act as mouse clicks so its buttons work on phones. It is small and
## the game is paused, so it simply rebuilds itself after every change.

signal opened
signal closed
signal job_chosen(job: int)
signal refined(result: Refinery.Result, item: ItemData)
signal egg_taken(egg: ItemData)
## The player confirmed erasing their save and starting over.
signal new_game_requested

enum Tab { CHARACTER, INVENTORY, PET }

const PANEL_MARGIN := 40.0
## Two picks of the same item within this many milliseconds toggle wearing it.
const DOUBLE_PICK_MSEC := 450
const TAB_NAMES: PackedStringArray = ["CHARACTER", "INVENTORY", "PET"]

## The open tab, a Tab value.
var tab: int = Tab.CHARACTER

var _progress: PlayerProgress
var _tree: SkillTree
var _inventory: Inventory
var _stats: PlayerStats
var _loot: LootConfig
var _jobs: JobTree
var _refinery: Refinery
var _character_page: CharacterPage
var _inventory_page: InventoryPage
## Null until setup_pets(); the PET tab shows only then.
var _pet_page: PetPage
var _pets: PetConfig
var _quests: QuestLog
var _panel: PanelContainer
var _content: VBoxContainer
## New Game needs a second press to confirm.
var _confirm_new_game := false
## The floating item tooltip and the control it belongs to.
var _tooltip: Control
var _tooltip_owner: Control
## The last item picked and when, to spot a double pick.
var _last_pick: ItemData
var _last_pick_msec := 0


func setup(progress: PlayerProgress, tree: SkillTree, inventory: Inventory, stats: PlayerStats,
		loot: LootConfig, jobs: JobTree = null, refinery: Refinery = null) -> void:
	_progress = progress
	_tree = tree
	_inventory = inventory
	_stats = stats
	_loot = loot
	_jobs = jobs
	_refinery = refinery
	_character_page = CharacterPage.new(self, progress, tree, stats, jobs)
	_inventory_page = InventoryPage.new(self, inventory, loot, refinery)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = PANEL_MARGIN
	_panel.offset_top = PANEL_MARGIN * 0.6
	_panel.offset_right = -PANEL_MARGIN
	_panel.offset_bottom = -PANEL_MARGIN * 0.6
	var style := StyleBoxFlat.new()
	# Fully opaque: HUD text bleeding through reads as clutter on the cards.
	style.bg_color = Color(0.06, 0.07, 0.09, 1.0)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 12)
	scroll.add_child(_content)
	visible = false


## Adds the PET tab: the pet, the quest and egg choices.
func setup_pets(pets: PetConfig, quests: QuestLog) -> void:
	_pets = pets
	_quests = quests
	_pet_page = PetPage.new(self, _inventory, _loot, pets, quests)


## Opens the PET tab with the Egg Keeper's eggs on offer.
func open_keeper() -> void:
	if _pet_page == null:
		return
	_pet_page.at_keeper = true
	open(Tab.PET)


## Takes an egg: the quest's reward if one is waiting, otherwise from the
## Egg Keeper. It's worn if the pet slot is empty, else goes to the backpack.
func take_egg(kind: int) -> void:
	var q := _quests.current()
	if not _quests.reward_waiting(q) and not _pet_page.at_keeper:
		return
	var egg := PetRules.make_egg(_pets, kind)
	if not _inventory.add(egg):
		_inventory_page.result_text = "No room for the egg - make space in your backpack"
		_rebuild()
		return
	if _quests.reward_waiting(q):
		_quests.claim(q)
	egg_taken.emit(egg)
	_rebuild()


func is_open() -> bool:
	return visible


## Opens on the given tab (or the last one used).
func open(on_tab: int = -1) -> void:
	if on_tab >= 0:
		tab = on_tab
	if visible:
		_rebuild()
		return
	visible = true
	_confirm_new_game = false
	_inventory_page.reset()
	_inventory.sort_backpack()
	get_tree().paused = true
	Input.emulate_mouse_from_touch = true
	_rebuild()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_clear_tooltip()
	if _pet_page != null:
		_pet_page.at_keeper = false
	get_tree().paused = false
	Input.emulate_mouse_from_touch = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func show_tab(new_tab: int) -> void:
	tab = new_tab
	_confirm_new_game = false
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if GamepadCompat.is_raw_trigger(event):
		return
	if event.is_action_pressed("character_menu"):
		toggle()
	elif event.is_action_pressed("menu_inventory"):
		if visible and tab == Tab.INVENTORY:
			close()
		else:
			open(Tab.INVENTORY)
	elif visible and event.is_action_pressed("ui_cancel"):
		close()
	elif visible and (event.is_action_pressed("skill_lure") or event.is_action_pressed("attack_nova")):
		var step := 1 if event.is_action_pressed("attack_nova") else -1
		show_tab(posmod(tab + step, _tab_count()))
	else:
		return
	get_viewport().set_input_as_handled()


# --- Actions (buttons call these; tests may too) ---

func rank_up(skill: int) -> void:
	if _progress.rank_up(skill):
		_stats.recompute()
	_rebuild()


## Puts up to amount points into an attribute.
func raise_attribute(attribute: int, amount: int = 1) -> void:
	_progress.raise_attribute(attribute, amount)
	_rebuild()


func choose_job(index: int) -> void:
	if _jobs != null and _progress.choose_job(_jobs, index):
		_stats.recompute()
		job_chosen.emit(index)
	_rebuild()


## Selects an item; picking the same item again quickly (double-click,
## double-tap, or A twice) wears it, or takes it off if it's worn.
func select_item(item: ItemData) -> void:
	var now := Time.get_ticks_msec()
	var again := item == _last_pick and now - _last_pick_msec <= DOUBLE_PICK_MSEC
	_last_pick = item
	_last_pick_msec = now
	if again:
		_last_pick = null
		toggle_equip(item)
		return
	_inventory_page.select(item)
	_rebuild()


## Takes the item off if it's worn, otherwise wears it where it goes.
func toggle_equip(item: ItemData) -> void:
	var position := _inventory.position_of(item)
	if position >= 0:
		unequip(position)
	else:
		equip_item(item)
	_inventory_page.selected = item


func selected_item() -> ItemData:
	return _inventory_page.selected


## Wears an item at position (-1: where it goes by default).
func equip_item(item: ItemData, position: int = -1) -> void:
	if _inventory.equip_item(item, position):
		_inventory_page.result_text = "Equipped %s" % item.display_name()
		_inventory_page.result_color = MenuWidgets.GOOD_COLOR
	else:
		_inventory_page.result_text = "No room in the backpack for what comes off"
		_inventory_page.result_color = MenuWidgets.BAD_COLOR
	_inventory.sort_backpack()
	_rebuild()


func unequip(position: int) -> void:
	var item := _inventory.equipped[position]
	if item != null and _inventory.unequip(position):
		_inventory_page.result_text = "Took off %s" % item.display_name()
		_inventory_page.result_color = MenuWidgets.TEXT_COLOR
	_inventory.sort_backpack()
	_rebuild()


## Floats an item's tooltip beside the control that shows it.
## Focus the menu gives a control by itself (on opening or rebuilding)
## shows no tooltip; only the player's own hovering or navigating does.
func show_tooltip(item: ItemData, owner: Control) -> void:
	_clear_tooltip()
	if _auto_focusing:
		return
	if not is_instance_valid(owner) or not owner.is_inside_tree():
		return
	_tooltip = ItemTooltip.build(item, _inventory, _loot)
	_tooltip_owner = owner
	add_child(_tooltip)
	var screen := get_viewport().get_visible_rect().size
	var rect := owner.get_global_rect()
	var tip := _tooltip.get_combined_minimum_size()
	var at := Vector2(rect.end.x + 8.0, rect.position.y)
	if at.x + tip.x > screen.x:
		at.x = rect.position.x - tip.x - 8.0
	at.x = clampf(at.x, 0.0, maxf(screen.x - tip.x, 0.0))
	at.y = clampf(at.y, 0.0, maxf(screen.y - tip.y, 0.0))
	_tooltip.position = at


func hide_tooltip(owner: Control) -> void:
	if owner == _tooltip_owner:
		_clear_tooltip()


func tooltip_showing() -> bool:
	return _tooltip != null


## Freed at the end of the frame, not removed now: focus and mouse-exit
## signals can arrive while the menu is busy removing children.
func _clear_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false
		_tooltip.queue_free()
	_tooltip = null
	_tooltip_owner = null


func salvage_item(item: ItemData) -> void:
	var gained := _inventory.salvage_item(item, _loot.salvage_stones)
	_inventory_page.select(null)
	_inventory_page.result_text = "Salvaged for %d %s" % [gained, _loot.currency_name]
	_inventory_page.result_color = Color(0.8, 0.85, 1.0)
	_rebuild()


## Salvage All for a rarity, or -1 for everything (all but commons need a
## second press). Returns the Geon gained.
func salvage_all(rarity: int) -> int:
	var gained := _inventory_page.press_salvage_all(rarity)
	_rebuild()
	return gained


## Refines with a Blessed Stone: always succeeds while one is left.
func refine_blessed(item: ItemData) -> Refinery.Result:
	return refine(item, true)


## Tries to refine an item (one press of UPGRADE).
func refine(item: ItemData, blessed: bool = false) -> Refinery.Result:
	var before := item.upgrade_level
	var result := _refinery.attempt_blessed(item, _inventory) if blessed \
			else _refinery.attempt(item, _inventory)
	var page := _inventory_page
	match result:
		Refinery.Result.SUCCESS:
			page.result_text = "SUCCESS! +%d -> +%d" % [before, item.upgrade_level]
			page.result_color = MenuWidgets.GOOD_COLOR
		Refinery.Result.DOWNGRADED:
			page.result_text = "Failed - dropped to +%d. Try again!" % item.upgrade_level
			page.result_color = MenuWidgets.BAD_COLOR
		Refinery.Result.FAILED:
			page.result_text = "Failed - still +0. Try again!"
			page.result_color = MenuWidgets.BAD_COLOR
		Refinery.Result.NOT_ENOUGH_STONES:
			page.result_text = "Not enough %s" % _loot.currency_name
			page.result_color = Color(1.0, 0.7, 0.3)
		Refinery.Result.MAXED:
			page.result_text = "Already at the maximum"
			page.result_color = Color(1.0, 0.85, 0.3)
	refined.emit(result, item)
	_rebuild()
	return result


## First press asks for confirmation; the second erases and restarts.
func press_new_game() -> void:
	if not _confirm_new_game:
		_confirm_new_game = true
		_rebuild()
		return
	_confirm_new_game = false
	close()
	new_game_requested.emit()


# --- Building ---

func _tab_count() -> int:
	return TAB_NAMES.size() if _pet_page != null else TAB_NAMES.size() - 1


## True while _grab_focus_later() moves focus, so no tooltip pops up.
var _auto_focusing := false


func _rebuild() -> void:
	_clear_tooltip()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var header_focus := _build_header()
	var focus: Control
	if tab == Tab.CHARACTER:
		focus = _character_page.build(_content, _confirm_new_game)
	elif tab == Tab.PET and _pet_page != null:
		focus = _pet_page.build(_content)
	else:
		focus = _inventory_page.build(_content)
	_grab_focus_later.call_deferred(focus if focus != null else header_focus)


## Deferred so the new controls are laid out first. A quick second rebuild
## may already have replaced the control, so check it's still on screen.
func _grab_focus_later(target: Control) -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		_auto_focusing = true
		target.grab_focus()
		_auto_focusing = false


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var current: Control = null
	for index in _tab_count():
		var b := MenuWidgets.button(TAB_NAMES[index], MenuWidgets.FONT_SIZE - 2)
		b.custom_minimum_size.x = 190.0
		b.toggle_mode = true
		b.button_pressed = index == tab
		b.pressed.connect(show_tab.bind(index))
		row.add_child(b)
		if index == tab:
			current = b
	var job := ""
	if _jobs != null and _progress.job >= 0:
		job = "%s   " % _progress.job_title(_jobs)
	var xp := "MAX" if _progress.is_max_level() else "%d / %d" % [
			floori(_progress.xp), ceili(_progress.xp_to_next())]
	var summary := MenuWidgets.label("   %sLEVEL %d   XP %s   %s %d   %ss %d" % [job,
			_progress.level, xp, _loot.currency_name, _inventory.stones, _loot.blessed_name,
			_inventory.blessed_stones], MenuWidgets.SMALL_FONT + 1)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(summary)
	var close_button := MenuWidgets.button("CLOSE")
	close_button.pressed.connect(close)
	row.add_child(close_button)
	_content.add_child(HSeparator.new())
	# The open tab's own button: safe to land on (A doesn't close the menu).
	return current if current != null else close_button
