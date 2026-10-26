class_name LootSystem
extends Node3D
## Items lying on the ground. Drops scatter around where a camp was cleared;
## items near the player drift toward it and are picked up on touch. Gems
## bob and spin; magic and rare items also show a light beam. Ground slots
## are a fixed pool drawn with two InstanceBatches.

signal picked_up(item: ItemData)
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
var _count := 0
var _time := 0.0
var _full_warning_in := 0.0
var _gems: InstanceBatch
var _beams: InstanceBatch
var _rng := RandomNumberGenerator.new()


func setup(config: LootConfig, inventory: Inventory, generator: ItemGenerator) -> void:
	_config = config
	_inventory = inventory
	_generator = generator
	_rng.randomize()
	_positions.resize(config.ground_capacity)
	_positions.fill(Vector3.ZERO)
	_items.resize(config.ground_capacity)
	_gems = InstanceBatch.new()
	_gems.name = "Gems"
	_gems.setup(_make_gem_mesh(), config.ground_capacity)
	add_child(_gems)
	_beams = InstanceBatch.new()
	_beams.name = "Beams"
	_beams.setup(_make_beam_mesh(), config.ground_capacity)
	add_child(_beams)


## Rolls and drops `amount` items scattered around a ground position.
func drop(at: Vector2, amount: int, zone_level: int) -> void:
	for _n in amount:
		var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * _config.drop_scatter
		place(_generator.roll(zone_level), at + offset)


## Puts a specific item on the ground. False if the ground pool is full.
func place(item: ItemData, at: Vector2) -> bool:
	if _count >= _config.ground_capacity:
		return false
	_positions[_count] = Vector3(at.x, 0.0, at.y)
	_items[_count] = item
	_count += 1
	return true


func clear() -> void:
	for i in _count:
		_items[i] = null
	_count = 0


func ground_count() -> int:
	return _count


func tick(delta: float, player_pos: Vector2) -> void:
	_time += delta
	_full_warning_in -= delta
	var magnet_sq := _config.magnet_radius * _config.magnet_radius
	var pickup_sq := _config.pickup_radius * _config.pickup_radius
	for i in range(_count - 1, -1, -1):
		var p: Vector3 = _positions[i]
		var to_player := player_pos - Vector2(p.x, p.z)
		var d_sq := to_player.length_squared()
		if d_sq <= pickup_sq:
			if _inventory.add(_items[i]):
				picked_up.emit(_items[i])
				_remove(i)
				continue
			if _full_warning_in <= 0.0:
				_full_warning_in = FULL_WARNING_INTERVAL
				backpack_full.emit()
		elif d_sq <= magnet_sq:
			var step := to_player.normalized() * minf(_config.magnet_speed * delta, sqrt(d_sq))
			_positions[i] = Vector3(p.x + step.x, p.y, p.z + step.y)
	_draw()


func _remove(i: int) -> void:
	var last := _count - 1
	_positions[i] = _positions[last]
	_items[i] = _items[last]
	_items[last] = null
	_count = last


func _draw() -> void:
	_gems.begin()
	_beams.begin()
	var s := _config.gem_size
	for i in _count:
		var p: Vector3 = _positions[i]
		var item := _items[i]
		var color := _config.rarity_colors[item.rarity]
		var bob := sin(_time * BOB_SPEED + i) * BOB_HEIGHT
		var basis := Basis(Vector3.UP, _time * SPIN_SPEED + i).scaled(Vector3(s, s * 1.4, s))
		_gems.add_basis(Vector3(p.x, 0.6 + bob, p.z), basis, color)
		if item.rarity > 0:
			var beam := color
			beam.a = BEAM_ALPHA
			_beams.add(Vector3(p.x, _config.beam_height * 0.5, p.z),
					Vector3(0.12, _config.beam_height, 0.12), beam)
	_gems.commit()
	_beams.commit()


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
