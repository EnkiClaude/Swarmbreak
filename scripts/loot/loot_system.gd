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
## Within this distance of the player, loot is collected at once (a hatched
## pet fetching it). 0: only the normal pickup.
var collect_radius := 0.0
## Walked over an item with a full backpack.
signal backpack_full

const GEM_SEGMENTS := 4
const BOB_HEIGHT := 0.15
const BOB_SPEED := 3.0
const SPIN_SPEED := 2.0
const BEAM_ALPHA := 0.35
const FULL_WARNING_INTERVAL := 2.0

var _config: LootConfig
var _inventory: Inventory
var _generator: ItemGenerator
var _positions: PackedVector3Array = []
var _items: Array[ItemData] = []
## Geon in each ground slot; 0 for an item.
var _geon := PackedInt32Array()
## 1 for a Blessed Stone (no item, no Geon).
var _blessed := PackedByteArray()
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
		geon_multiplier: float = 1.0) -> int:
	var items := 0
	for _n in amount:
		if _rng.randf() < _config.item_drop_chance:
			place(_generator.roll(level, min_rarity), _scatter(at))
			items += 1
		elif _rng.randf() < _config.talisman_drop_chance:
			place(_generator.roll_talisman(level, min_rarity), _scatter(at))
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
	var magnet := maxf(_config.magnet_radius, collect_radius)
	var pickup := maxf(_config.pickup_radius, collect_radius)
	var magnet_sq := magnet * magnet
	var pickup_sq := pickup * pickup
	for i in range(_count - 1, -1, -1):
		var p: Vector3 = _positions[i]
		var to_player := player_pos - Vector2(p.x, p.z)
		var d_sq := to_player.length_squared()
		if d_sq > magnet_sq:
			continue
		var item := _items[i]
		if item != null and not _inventory.can_accept(item):
			# Leave it where it lies; pulling it along would pile items under the player.
			if d_sq <= pickup_sq and _full_warning_in <= 0.0:
				_full_warning_in = FULL_WARNING_INTERVAL
				backpack_full.emit()
			continue
		if d_sq <= pickup_sq:
			if item != null:
				_inventory.add(item)
				picked_up.emit(item)
			elif _blessed[i] != 0:
				_inventory.add_blessed_stones(1)
				picked_up_blessed.emit()
			else:
				var amount := _geon[i]
				_inventory.add_stones(amount)
				picked_up_geon.emit(amount)
			_remove(i)
		else:
			var step := to_player.normalized() * minf(_config.magnet_speed * delta, sqrt(d_sq))
			_positions[i] = Vector3(p.x + step.x, p.y, p.z + step.y)
	_draw()


func _remove(i: int) -> void:
	var last := _count - 1
	_positions[i] = _positions[last]
	_items[i] = _items[last]
	_geon[i] = _geon[last]
	_blessed[i] = _blessed[last]
	_items[last] = null
	_geon[last] = 0
	_blessed[last] = 0
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
