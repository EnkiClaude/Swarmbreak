class_name LootSystem
extends Node3D
## Items and piles of Geon lying on the ground. Drops scatter around where a
## camp was cleared; each is an item at LootConfig.item_drop_chance, otherwise
## a pile of Geon growing with the level. Loot near the player drifts toward
## it and is picked up on touch. Items the inventory can't take right now stay
## put (no magnet) until there's room; Geon and Blessed Stones always fit
## (a Blessed Stone shows as a pale gem with a beam). Gems bob and spin;
## magic and rare items also show a light beam; Geon shows as gold coins.
## Ground slots are a fixed pool drawn with three InstanceBatches.

signal picked_up(item: ItemData)
signal picked_up_geon(amount: int)
signal picked_up_blessed
signal picked_up_talisman(id: int)
signal picked_up_shard
## Within this distance of the player, a hatched pet fetches loot: it flies
## to the nearest drop (nearest_to_fetch()) and the drop is collected once
## the pet (collector_position) is within collector_reach of it.
## 0: only the player's own pickup and magnet.
var collect_radius := 0.0
var collector_position := Vector2.ZERO
var collector_reach := 0.0
## Walked over an item with a full backpack.
signal backpack_full

## _blessed value marking a summoning shard (1 is a Blessed Stone).
const SHARD := 2
const GEM_SEGMENTS := 4
const BOB_HEIGHT := 0.15
const BOB_SPEED := 3.0
const SPIN_SPEED := 2.0
const BEAM_ALPHA := 0.35
const FULL_WARNING_INTERVAL := 2.0

var _config: LootConfig
var _player_pos := Vector2.ZERO
var _inventory: Inventory
var _generator: ItemGenerator
var _positions: PackedVector3Array = []
var _items: Array[ItemData] = []
## Geon in each ground slot; 0 for an item.
var _geon := PackedInt32Array()
## 1 for a Blessed Stone (no item, no Geon).
var _blessed := PackedByteArray()
## Talisman id + 1 lying in each slot, or 0.
var _talisman := PackedInt32Array()
## Color summoning shards are drawn in (set by main).
var shard_color := Color(0.85, 0.15, 0.9)
## Rolls dropped talismans (set by main; null: none drop).
var talismans: TalismanRules
var _count := 0
var _time := 0.0
var _full_warning_in := 0.0
var _gems: InstanceBatch
var _beams: InstanceBatch
var _coins: InstanceBatch
var _rng := RandomNumberGenerator.new()


func setup(config: LootConfig, inventory: Inventory, generator: ItemGenerator) -> void:
	_config = config
	_inventory = inventory
	_generator = generator
	_rng.randomize()
	_positions.resize(config.ground_capacity)
	_positions.fill(Vector3.ZERO)
	_items.resize(config.ground_capacity)
	_geon.resize(config.ground_capacity)
	_geon.fill(0)
	_blessed.resize(config.ground_capacity)
	_blessed.fill(0)
	_talisman.resize(config.ground_capacity)
	_talisman.fill(0)
	_gems = InstanceBatch.new()
	_gems.name = "Gems"
	_gems.setup(_make_gem_mesh(), config.ground_capacity)
	add_child(_gems)
	_beams = InstanceBatch.new()
	_beams.name = "Beams"
	_beams.setup(_make_beam_mesh(), config.ground_capacity)
	add_child(_beams)
	_coins = InstanceBatch.new()
	_coins.name = "Coins"
	_coins.setup(_make_coin_mesh(), config.ground_capacity)
	add_child(_coins)


## Rolls and drops `amount` items scattered around a ground position.
func drop(at: Vector2, amount: int, zone_level: int, min_rarity: int = 0) -> void:
	for _n in amount:
		place(_generator.roll(zone_level, min_rarity), _scatter(at))


## `amount` drops around a ground position: each an item at item_drop_chance
## (at least min_rarity), else a talisman at talisman_drop_chance, otherwise
## a pile of Geon for the level, times geon_multiplier. Returns how many
## were gear items (talismans not counted).
func drop_rewards(at: Vector2, amount: int, level: int, min_rarity: int = 0,
		geon_multiplier: float = 1.0, item_chance: float = -1.0) -> int:
	var items := 0
	var chance := item_chance if item_chance >= 0.0 else _config.item_drop_chance
	for _n in amount:
		if _rng.randf() < chance:
			place(_generator.roll(level, min_rarity), _scatter(at))
			items += 1
		elif talismans != null and _rng.randf() < _config.talisman_drop_chance:
			place_talisman(talismans.roll(min_rarity), _scatter(at))
		else:
			place_geon(geon_pile(level, geon_multiplier), _scatter(at))
	return items


## A random pile size for a level.
func geon_pile(level: int, multiplier: float = 1.0) -> int:
	var growth := 1.0 + _config.geon_growth_per_level * (level - 1)
	return maxi(1, roundi(_rng.randi_range(_config.geon_pile_min, _config.geon_pile_max)
			* growth * multiplier))


## Drops one piece of a set (dungeon bosses).
func drop_set_piece(at: Vector2, sets: SetList, set_index: int, level: int) -> void:
	place(_generator.roll_set_piece(sets, set_index, level), _scatter(at))


## Puts a pile of Geon on the ground. False if the ground pool is full.
func place_geon(amount: int, at: Vector2) -> bool:
	if amount <= 0 or not place(null, at):
		return false
	_geon[_count - 1] = amount
	return true


## Puts a Blessed Stone on the ground. False if the ground pool is full.
## Puts a talisman on the ground. False if the ground pool is full.
func place_talisman(id: int, at: Vector2) -> bool:
	if not place(null, at):
		return false
	_talisman[_count - 1] = id + 1
	return true


## The talisman id lying in slot i, or -1.
func talisman_at(i: int) -> int:
	return _talisman[i] - 1


## Puts a summoning shard on the ground. False if the ground pool is full.
func place_shard(at: Vector2) -> bool:
	if not place(null, at):
		return false
	_blessed[_count - 1] = SHARD
	return true


func place_blessed(at: Vector2) -> bool:
	if not place(null, at):
		return false
	_blessed[_count - 1] = 1
	return true


## Geon lying on the ground in total.
func ground_geon() -> int:
	var total := 0
	for i in _count:
		total += _geon[i]
	return total


func _scatter(at: Vector2) -> Vector2:
	return at + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * _config.drop_scatter


## Puts a specific item on the ground. False if the ground pool is full.
func place(item: ItemData, at: Vector2) -> bool:
	if _count >= _config.ground_capacity:
		return false
	_positions[_count] = Vector3(at.x, 0.0, at.y)
	_items[_count] = item
	_geon[_count] = 0
	_blessed[_count] = 0
	_talisman[_count] = 0
	_count += 1
	return true


func clear() -> void:
	for i in _count:
		_items[i] = null
	_count = 0


func ground_count() -> int:
	return _count


## The i-th ground drop's item (null for Geon and Blessed Stones).
func item_at(i: int) -> ItemData:
	return _items[i]


## Ground position of the i-th item (0 <= i < ground_count()).
func item_position(i: int) -> Vector2:
	return Vector2(_positions[i].x, _positions[i].z)


func tick(delta: float, player_pos: Vector2) -> void:
	_time += delta
	_full_warning_in -= delta
	_player_pos = player_pos
	var magnet_sq := _config.magnet_radius * _config.magnet_radius
	var pickup_sq := _config.pickup_radius * _config.pickup_radius
	var fetch_sq := collect_radius * collect_radius
	var reach_sq := collector_reach * collector_reach
	for i in range(_count - 1, -1, -1):
		var p: Vector3 = _positions[i]
		var at := Vector2(p.x, p.z)
		var to_player := player_pos - at
		var d_sq := to_player.length_squared()
		var item := _items[i]
		if d_sq > magnet_sq:
			# Out of the player's reach: the pet collects it once it gets there.
			if d_sq <= fetch_sq and reach_sq > 0.0 \
					and at.distance_squared_to(collector_position) <= reach_sq \
					and (item == null or _inventory.can_accept(item)):
				_collect(i, item)
			continue
		if item != null and not _inventory.can_accept(item):
			# Leave it where it lies; pulling it along would pile items under the player.
			if d_sq <= pickup_sq and _full_warning_in <= 0.0:
				_full_warning_in = FULL_WARNING_INTERVAL
				backpack_full.emit()
			continue
		if d_sq <= pickup_sq:
			_collect(i, item)
		else:
			var step := to_player.normalized() * minf(_config.magnet_speed * delta, sqrt(d_sq))
			_positions[i] = Vector3(p.x + step.x, p.y, p.z + step.y)
	_draw()


## The nearest drop the pet should fetch, from a point: inside collect_radius
## of the player, beyond the player's own magnet, with room for it. -1: none.
func nearest_to_fetch(from: Vector2) -> int:
	var fetch_sq := collect_radius * collect_radius
	var magnet_sq := _config.magnet_radius * _config.magnet_radius
	var best := -1
	var best_sq := INF
	for i in _count:
		var at := Vector2(_positions[i].x, _positions[i].z)
		var d_sq := at.distance_squared_to(_player_pos)
		if d_sq > fetch_sq or d_sq <= magnet_sq:
			continue
		if _items[i] != null and not _inventory.can_accept(_items[i]):
			continue
		var from_sq := at.distance_squared_to(from)
		if from_sq < best_sq:
			best_sq = from_sq
			best = i
	return best


func _collect(i: int, item: ItemData) -> void:
	if item != null:
		_inventory.add(item)
		picked_up.emit(item)
	elif _talisman[i] != 0:
		var id := _talisman[i] - 1
		_inventory.add_talisman(id)
		picked_up_talisman.emit(id)
	elif _blessed[i] == SHARD:
		_inventory.add_summon_shards(1)
		picked_up_shard.emit()
	elif _blessed[i] != 0:
		_inventory.add_blessed_stones(1)
		picked_up_blessed.emit()
	else:
		var amount := _geon[i]
		_inventory.add_stones(amount)
		picked_up_geon.emit(amount)
	_remove(i)


func _remove(i: int) -> void:
	var last := _count - 1
	_positions[i] = _positions[last]
	_items[i] = _items[last]
	_geon[i] = _geon[last]
	_blessed[i] = _blessed[last]
	_talisman[i] = _talisman[last]
	_items[last] = null
	_geon[last] = 0
	_blessed[last] = 0
	_talisman[last] = 0
	_count = last


func _draw() -> void:
	_gems.begin()
	_beams.begin()
	_coins.begin()
	var s := _config.gem_size
	for i in _count:
		var p: Vector3 = _positions[i]
		var item := _items[i]
		var bob := sin(_time * BOB_SPEED + i) * BOB_HEIGHT
		if item == null and _talisman[i] != 0:
			# A flat charm in its tier's color, spinning, with a thin beam.
			var tier := TalismanRules.tier_of(_talisman[i] - 1)
			var tint := _config.rarity_colors[clampi(tier, 0, _config.rarity_colors.size() - 1)]
			var charm := Basis(Vector3.UP, _time * SPIN_SPEED * 1.5 + i).scaled(Vector3(s * 1.1,
					s * 1.1, s * 0.35))
			_gems.add_basis(Vector3(p.x, 0.7 + bob, p.z), charm, tint)
			var glow := tint
			glow.a = BEAM_ALPHA
			_beams.add(Vector3(p.x, _config.beam_height * 0.4, p.z),
					Vector3(0.1, _config.beam_height * 0.8, 0.1), glow)
			continue
		if item == null and _blessed[i] == SHARD:
			var shard := Basis(Vector3.UP, _time * SPIN_SPEED * 2.0 + i).scaled(Vector3(s * 0.6,
					s * 1.6, s * 0.6))
			_gems.add_basis(Vector3(p.x, 0.75 + bob, p.z), shard, shard_color)
			var aura := shard_color
			aura.a = BEAM_ALPHA
			_beams.add(Vector3(p.x, _config.beam_height * 0.5, p.z),
					Vector3(0.14, _config.beam_height, 0.14), aura)
			continue
		if item == null and _blessed[i] != 0:
			var stone := Basis(Vector3.UP, _time * SPIN_SPEED + i).scaled(Vector3(s, s * 1.4, s))
			_gems.add_basis(Vector3(p.x, 0.6 + bob, p.z), stone, _config.blessed_color)
			var shine := _config.blessed_color
			shine.a = BEAM_ALPHA
			_beams.add(Vector3(p.x, _config.beam_height * 0.5, p.z),
					Vector3(0.16, _config.beam_height, 0.16), shine)
			continue
		if item == null:
			# A short stack of coins, bigger for bigger piles.
			var size := s * clampf(0.8 + _geon[i] * 0.02, 0.8, 1.6)
			var coin := Basis(Vector3.UP, _time * SPIN_SPEED + i).scaled(Vector3(size, size * 0.5,
					size))
			_coins.add_basis(Vector3(p.x, 0.35 + bob * 0.5, p.z), coin, _config.geon_color)
			continue
		var color := _config.rarity_colors[item.rarity]
		var basis := Basis(Vector3.UP, _time * SPIN_SPEED + i).scaled(Vector3(s, s * 1.4, s))
		_gems.add_basis(Vector3(p.x, 0.6 + bob, p.z), basis, color)
		if item.rarity > 0:
			# Epic and better stand out: wider, taller beams.
			var grand := maxi(item.rarity - 2, 0)
			var beam := color
			beam.a = BEAM_ALPHA
			var height := _config.beam_height * (1.0 + 0.35 * grand)
			var width := 0.12 + 0.06 * grand
			_beams.add(Vector3(p.x, height * 0.5, p.z), Vector3(width, height, width), beam)
	_gems.commit()
	_beams.commit()
	_coins.commit()


func _make_gem_mesh() -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	var gem := SphereMesh.new()
	gem.radius = 1.0
	gem.height = 2.0
	gem.radial_segments = GEM_SEGMENTS
	gem.rings = 2
	gem.material = material
	return gem


func _make_coin_mesh() -> Mesh:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.metallic = 0.8
	material.roughness = 0.3
	var coin := CylinderMesh.new()
	coin.top_radius = 1.0
	coin.bottom_radius = 1.0
	coin.height = 1.0
	coin.radial_segments = 10
	coin.rings = 1
	coin.material = material
	return coin


func _make_beam_mesh() -> Mesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := BoxMesh.new()
	beam.size = Vector3.ONE
	beam.material = material
	return beam
