class_name PetSystem
extends Node3D
## The pet in the inventory's pet slot, brought to life: it follows the
## player (an egg floats, a hatched pet walks), earns a share of the
## player's kill XP as a bonus (the player still gets all of theirs;
## PetRules), levels, hatches and evolves (rebuilding its
## model), and once hatched fetches drops around the player: it flies to
## the nearest one in range (LootSystem.nearest_to_fetch()) and LootSystem
## collects it when the pet gets there. From PetConfig.attack_level it zaps
## the enemies around it (fight(), in the damage window), and from
## aggro_level it wakes camps around itself.

signal leveled(item: ItemData)
signal evolved(item: ItemData, stage: int)
## The pet zapped enemies around a point.
signal zapped(at: Vector2)

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
var _swarm: SwarmManager
var _camps: CampDirector
var _effects: EffectSystem
var _zap_effect := -1
var _next_zap := 0.0
var _next_aggro := 0.0


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


## Lets the pet fight: zaps through the swarm, wakes camps, shows a strike.
func setup_combat(swarm: SwarmManager, camps: CampDirector, effects: EffectSystem) -> void:
	_swarm = swarm
	_camps = camps
	_effects = effects
	if config.attack_effect != null:
		_zap_effect = effects.register(config.attack_effect)


## Call between SwarmManager.simulate() and resolve_deaths().
func fight() -> void:
	var item := pet()
	if item == null or _swarm == null:
		return
	var now := _swarm.now()
	var at := Vector2(position.x, position.z)
	var damage := PetRules.attack_damage(config, item.pet_level)
	if damage > 0.0 and now >= _next_zap:
		_next_zap = now + config.attack_interval
		if _swarm.damage_circle(at, config.attack_radius, damage, 0.0) > 0:
			var hits := _swarm.hit_positions()
			for k in mini(_swarm.hit_sample_count(), 3):
				if _zap_effect >= 0:
					_effects.spawn(_zap_effect, Vector3(hits[k].x, 0.0, hits[k].y), 0.6)
			zapped.emit(at)
	var reach := PetRules.aggro_range(config, item.pet_level)
	if reach > 0.0 and now >= _next_aggro and _camps != null:
		_next_aggro = now + config.aggro_interval
		_camps.lure(at, reach)


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
		_loot.collector_reach = 0.0
		return
	var stage := PetRules.stage(config, item.pet_level)
	if item.pet_type != _shown_type or stage != _shown_stage:
		_rebuild(item, stage)
	visible = true
	_loot.collect_radius = PetRules.pickup_radius(config, item.pet_level)
	_loot.collector_reach = config.fetch_reach if stage >= 1 else 0.0
	var before := position
	var fetching := -1
	if stage >= 1:
		fetching = _loot.nearest_to_fetch(Vector2(position.x, position.z))
	if fetching >= 0:
		# Off to the drop, straight and quick.
		var drop := _loot.item_position(fetching)
		var target := Vector3(drop.x, 0.0, drop.y)
		position = position.move_toward(target, config.fetch_speed * delta)
	else:
		# Behind the player and off to its right, turning with it.
		var facing := _player.facing
		var right := Vector3(-facing.z, 0.0, facing.x)
		var goal := _player.position + right * config.follow_offset.x \
				- facing * config.follow_offset.y
		if stage <= 0:
			goal.y += 1.1
		position = position.lerp(goal, 1.0 - exp(-config.follow_sharpness * delta))
	_loot.collector_position = Vector2(position.x, position.z)
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
