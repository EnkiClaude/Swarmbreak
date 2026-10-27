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
## The player confirmed erasing their save and starting over.
signal new_game_requested

enum Tab { CHARACTER, INVENTORY }

const PANEL_MARGIN := 40.0
const TAB_NAMES: PackedStringArray = ["CHARACTER", "INVENTORY"]

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
var _panel: PanelContainer
var _content: VBoxContainer
## New Game needs a second press to confirm.
var _confirm_new_game := false


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
		show_tab(Tab.INVENTORY if tab == Tab.CHARACTER else Tab.CHARACTER)
	else:
		return
	get_viewport().set_input_as_handled()


# --- Actions (buttons call these; tests may too) ---

func rank_up(skill: int) -> void:
	if _progress.rank_up(skill):
		_stats.recompute()
	_rebuild()


func choose_job(index: int) -> void:
	if _jobs != null and _progress.choose_job(_jobs, index):
		_stats.recompute()
		job_chosen.emit(index)
	_rebuild()


func select_item(item: ItemData) -> void:
	_inventory_page.select(item)
	_rebuild()


func selected_item() -> ItemData:
	return _inventory_page.selected


func equip_item(item: ItemData) -> void:
	_inventory.equip_item(item)
	_inventory.sort_backpack()
	_inventory_page.result_text = "Equipped %s" % item.display_name()
	_inventory_page.result_color = MenuWidgets.GOOD_COLOR
	_rebuild()


func salvage_item(item: ItemData) -> void:
	var gained := _inventory.salvage_item(item, _loot.salvage_stones)
	_inventory_page.select(null)
	_inventory_page.result_text = "Salvaged for %d stones" % gained
	_inventory_page.result_color = Color(0.8, 0.85, 1.0)
	_rebuild()


## Salvage All for a rarity (magic needs a second press). Returns stones gained.
func salvage_all(rarity: int) -> int:
	var gained := _inventory_page.press_salvage_all(rarity)
	_rebuild()
	return gained


## Tries to refine an item (one press of UPGRADE).
func refine(item: ItemData) -> Refinery.Result:
	var before := item.upgrade_level
	var result := _refinery.attempt(item, _inventory)
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
			page.result_text = "Not enough stones"
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

func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var header_focus := _build_header()
	var focus: Control
	if tab == Tab.CHARACTER:
		focus = _character_page.build(_content, _confirm_new_game)
	else:
		focus = _inventory_page.build(_content)
	_grab_focus_later.call_deferred(focus if focus != null else header_focus)


## Deferred so the new controls are laid out first. A quick second rebuild
## may already have replaced the control, so check it's still on screen.
func _grab_focus_later(target: Control) -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		target.grab_focus()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	for index in TAB_NAMES.size():
		var b := MenuWidgets.button(TAB_NAMES[index], MenuWidgets.FONT_SIZE - 2)
		b.custom_minimum_size.x = 190.0
		b.toggle_mode = true
		b.button_pressed = index == tab
		b.pressed.connect(show_tab.bind(index))
		row.add_child(b)
	var job := ""
	if _jobs != null and _progress.job >= 0:
		job = "%s   " % _progress.job_title(_jobs)
	var xp := "MAX" if _progress.is_max_level() else "%d / %d" % [
			floori(_progress.xp), ceili(_progress.xp_to_next())]
	var summary := MenuWidgets.label("   %sLEVEL %d   XP %s   Stones %d" % [job, _progress.level,
			xp, _inventory.stones], MenuWidgets.SMALL_FONT + 1)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(summary)
	var close_button := MenuWidgets.button("CLOSE")
	close_button.pressed.connect(close)
	row.add_child(close_button)
	_content.add_child(HSeparator.new())
	return close_button
