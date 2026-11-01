class_name PetPage
extends RefCounted
## The PET tab: the equipped pet (stage, level and XP toward the next, the
## XP share it takes, when it hatches or evolves next, the stats it gives),
## the current quest, and eggs to choose: one as the quest's reward, or any
## while standing at the Egg Keeper (free, for testing).

## Columns keep a width so their wrapping text lays out in lines, not words.
const PET_COLUMN_WIDTH := 420.0
const EGG_COLUMN_WIDTH := 340.0

var _menu: CharacterMenu
var _inventory: Inventory
var _loot: LootConfig
var _pets: PetConfig
var _quests: QuestLog
## True while the menu was opened by walking up to the Egg Keeper.
var at_keeper := false


func _init(menu: CharacterMenu, inventory: Inventory, loot: LootConfig, pets: PetConfig,
		quests: QuestLog) -> void:
	_menu = menu
	_inventory = inventory
	_loot = loot
	_pets = pets
	_quests = quests


## Builds into parent and returns the control that should take focus.
func build(parent: Container) -> Control:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	parent.add_child(columns)
	_build_pet(MenuWidgets.column(columns, PET_COLUMN_WIDTH))
	return _build_eggs(MenuWidgets.column(columns, EGG_COLUMN_WIDTH))


func _build_pet(parent: VBoxContainer) -> void:
	parent.add_child(MenuWidgets.title("YOUR PET"))
	var item := _inventory.equipped[Inventory.Equip.PET]
	if item == null:
		parent.add_child(MenuWidgets.label("No pet yet. Finish the Egg Keeper's quest (or visit " +
				"her in Jade Village) for an egg, then wear it in the Pet slot.",
				MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
	else:
		var def := _pets.pets[clampi(item.pet_type, 0, _pets.pets.size() - 1)]
		var stage := PetRules.stage(_pets, item.pet_level)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		parent.add_child(head)
		var icon := ItemIcon.make(ItemKindDef.Icon.EGG, def.color)
		icon.custom_minimum_size = Vector2(56, 56)
		head.add_child(icon)
		var name_label := MenuWidgets.label("%s\nLevel %d   -   %s" % [item.item_name,
				item.pet_level, "egg" if stage == 0 else "stage %d" % stage],
				MenuWidgets.SMALL_FONT + 2, def.color)
		# A wrapping label in a row needs the row's width, or it gets none and
		# breaks after every word.
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		if item.pet_level < _pets.max_level:
			parent.add_child(MenuWidgets.label("XP %d / %d   (earns %d%% of your kill XP as a bonus; yours isn't reduced)" % [
					floori(item.pet_xp), ceili(PetRules.xp_to_next(_pets, item.pet_level)),
					roundi(PetRules.xp_share(_pets, item.pet_level) * 100.0)]))
		if stage < _pets.max_stage:
			var next := (stage + 1) * _pets.levels_per_stage
			parent.add_child(MenuWidgets.label("%s at level %d" % ["Hatches" if stage == 0
					else "Evolves", next], MenuWidgets.SMALL_FONT, Color(1.0, 0.85, 0.4)))
		if stage >= 1:
			parent.add_child(MenuWidgets.label("Collects drops within %d m of you" %
					roundi(_pets.pickup_radius_per_stage[mini(stage,
					_pets.pickup_radius_per_stage.size() - 1)]), MenuWidgets.SMALL_FONT,
					MenuWidgets.GOOD_COLOR))
		parent.add_child(MenuWidgets.label("  " + "\n  ".join(item.describe_lines())))
	var q := _quests.current()
	if q >= 0:
		var def := _quests.list.quests[q]
		parent.add_child(MenuWidgets.title("QUEST"))
		parent.add_child(MenuWidgets.label(_quests.summary(q), MenuWidgets.SMALL_FONT,
				Color(1.0, 0.85, 0.4)))
		parent.add_child(MenuWidgets.label(def.description, MenuWidgets.SMALL_FONT - 2,
				MenuWidgets.DIM_COLOR))


## Egg choices: the quest reward if it's waiting, or the keeper's eggs.
func _build_eggs(parent: VBoxContainer) -> Control:
	var reward := _quests.reward_waiting(_quests.current())
	if not reward and not at_keeper:
		parent.add_child(MenuWidgets.title("EGGS"))
		parent.add_child(MenuWidgets.label("The Egg Keeper stands in the town square. Walk up " +
				"to her to see her eggs.", MenuWidgets.SMALL_FONT, MenuWidgets.DIM_COLOR))
		return null
	parent.add_child(MenuWidgets.title("CHOOSE AN EGG" if reward else "THE EGG KEEPER'S EGGS"))
	if not reward:
		parent.add_child(MenuWidgets.label("For testing: take any egg, free.",
				MenuWidgets.SMALL_FONT - 2, MenuWidgets.DIM_COLOR))
	var first: Control = null
	for kind in _pets.pets.size():
		var def := _pets.pets[kind]
		var b := MenuWidgets.button("%s\n%s" % [def.stage_names[0].to_upper(), def.build_hint],
				MenuWidgets.SMALL_FONT - 2)
		b.custom_minimum_size.y = MenuWidgets.BUTTON_HEIGHT * 1.4
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", def.color.lightened(0.2))
		b.pressed.connect(_menu.take_egg.bind(kind))
		parent.add_child(b)
		if first == null:
			first = b
	return first
