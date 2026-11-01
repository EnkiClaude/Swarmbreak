class_name PetSystem
extends Node3D
## The pet in the inventory's pet slot, brought to life: it follows the
## player (an egg floats, a hatched pet walks), earns a share of the
## player's kill XP as a bonus (the player still gets all of theirs;
## PetRules), levels, hatches and evolves (rebuilding its
## model), and once hatched sets how far around the player LootSystem
## collects drops by itself.

signal leveled(item: ItemData)
signal evolved(item: ItemData, stage: int)

const HERO_SHADER := preload("res://shaders/hero.gdshader")

var config: PetConfig
var _inventory: Inventory
var _loot: LootSystem
var _player: Player
var _body: MeshInstance3D
var _material: ShaderMaterial
## What the current model shows: kind and stage (-1: none built).
var _shown_type := -1
var _shown_stage := -1
var _stride := 0.0


func setup(p_config: PetConfig, inventory: Inventory, loot: LootSystem, player: Player) -> void:
	config = p_config
	_inventory = inventory
	_loot = loot
	_player = player
	_material = ShaderMaterial.new()
	_material.shader = HERO_SHADER
	_body = MeshInstance3D.new()
	_body.name = "Body"
	add_child(_body)
	visible = false


## The equipped pet, or null.
func pet() -> ItemData:
	return _inventory.equipped[Inventory.Equip.PET]


## Gives the pet a bonus worth its share of the XP the player just earned.
## Never takes anything from the player.
func gain_kill_xp(player_xp: float) -> void:
	var item := pet()
	if item == null or player_xp <= 0.0:
		return
	var stage_before := PetRules.stage(config, item.pet_level)
	var share := PetRules.xp_share(config, item.pet_level)
	if PetRules.gain_xp(config, item, player_xp * share) <= 0:
		return
	_inventory.notify_changed()
	leveled.emit(item)
	var stage := PetRules.stage(config, item.pet_level)
	if stage != stage_before:
		evolved.emit(item, stage)


func tick(delta: float) -> void:
	var item := pet()
	if item == null:
		visible = false
		_loot.collect_radius = 0.0
		return
	var stage := PetRules.stage(config, item.pet_level)
	if item.pet_type != _shown_type or stage != _shown_stage:
		_rebuild(item, stage)
	visible = true
	_loot.collect_radius = config.pickup_radius_per_stage[mini(stage,
			config.pickup_radius_per_stage.size() - 1)]
	# Behind the player and off to its right, turning with it.
	var facing := _player.facing
	var right := Vector3(-facing.z, 0.0, facing.x)
	var goal := _player.position + right * config.follow_offset.x - facing * config.follow_offset.y
	if stage <= 0:
		goal.y += 1.1
	var before := position
	position = position.lerp(goal, 1.0 - exp(-config.follow_sharpness * delta))
	var moved := Vector2(position.x - before.x, position.z - before.z)
	var speed := moved.length() / maxf(delta, 0.0001)
	if moved.length_squared() > 0.000001:
		rotation.y = atan2(-moved.x, -moved.y)
	_stride += speed * 6.0 * delta + delta * 2.0
	_material.set_shader_parameter("walk", clampf(speed / 6.0, 0.0, 1.0))
	_material.set_shader_parameter("phase", _stride)


## Jumps to the player at once (after travel).
func snap_to_player() -> void:
	position = _player.position


func _rebuild(item: ItemData, stage: int) -> void:
	_shown_type = item.pet_type
	_shown_stage = stage
	var def := config.pets[clampi(item.pet_type, 0, config.pets.size() - 1)]
	var height := config.height_per_stage[mini(stage, config.height_per_stage.size() - 1)]
	_body.mesh = CharacterModels.pet(stage, height, def.color, def.accent_color, _material)
