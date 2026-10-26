class_name SpatialHash
extends RefCounted
## Spatial hash for neighbour queries, rebuilt every tick with a counting sort.
## The world is cut into square cells, and each cell hashes into one of a
## fixed number of buckets, so cost depends on the bucket count, not on map
## size. After build(), the enemies in bucket b are
## sorted_ids[bucket_start[b] .. bucket_start[b + 1]).
##
## Different cells can share a bucket, so queries must check real distance,
## and must skip buckets they already visited: stamp a bucket with
## next_visit() before reading it (see query_circle()). No allocation after _init.

const HASH_X := 92837111
const HASH_Z := 689287499

var cell_size: float
var inv_cell_size: float
## Bucket count minus one; the bucket count is a power of two.
var bucket_mask: int
var bucket_start: PackedInt32Array
var sorted_ids: PackedInt32Array
## Last visit id that read each bucket. See next_visit().
var visit_stamp: PackedInt32Array
var visit_id: int = 0
var _bucket_of: PackedInt32Array


## bucket_count is rounded up to a power of two.
func _init(p_cell_size: float, bucket_count: int, capacity: int) -> void:
	cell_size = p_cell_size
	inv_cell_size = 1.0 / p_cell_size
	var buckets := 1
	while buckets < bucket_count:
		buckets *= 2
	bucket_mask = buckets - 1
	bucket_start.resize(buckets + 1)
	bucket_start.fill(0)
	visit_stamp.resize(buckets)
	visit_stamp.fill(0)
	sorted_ids.resize(capacity)
	_bucket_of.resize(capacity)


static func bucket_of_cell(cx: int, cz: int, mask: int) -> int:
	return ((cx * HASH_X) ^ (cz * HASH_Z)) & mask


func cell_coord(v: float) -> int:
	return floori(v * inv_cell_size)


## Starts a new query: returns an id to stamp visited buckets with.
func next_visit() -> int:
	visit_id += 1
	if visit_id >= 1 << 30:
		visit_stamp.fill(0)
		visit_id = 1
	return visit_id


func build(positions: PackedVector2Array, count: int) -> void:
	var inv := inv_cell_size
	var mask := bucket_mask
	var buckets := mask + 1
	bucket_start.fill(0)

	# Count enemies per bucket.
	for i in count:
		var p: Vector2 = positions[i]
		var b: int = ((floori(p.x * inv) * HASH_X) ^ (floori(p.y * inv) * HASH_Z)) & mask
		_bucket_of[i] = b
		bucket_start[b] += 1

	# Inclusive prefix sum: bucket_start[b] becomes the end of bucket b.
	var running := 0
	for b in buckets:
		running += bucket_start[b]
		bucket_start[b] = running
	bucket_start[buckets] = count

	# Scatter in reverse, walking each bucket's end back to its start.
	for i in range(count - 1, -1, -1):
		var b: int = _bucket_of[i]
		var slot: int = bucket_start[b] - 1
		bucket_start[b] = slot
		sorted_ids[slot] = i


## Appends to out the index of every enemy within radius of center, each
## once. For setup code and tests; hot loops inline the same walk.
func query_circle(positions: PackedVector2Array, center: Vector2, radius: float,
		out: PackedInt32Array) -> void:
	var visit := next_visit()
	var r_sq := radius * radius
	for cz in range(cell_coord(center.y - radius), cell_coord(center.y + radius) + 1):
		for cx in range(cell_coord(center.x - radius), cell_coord(center.x + radius) + 1):
			var b := bucket_of_cell(cx, cz, bucket_mask)
			if visit_stamp[b] == visit:
				continue
			visit_stamp[b] = visit
			for k in range(bucket_start[b], bucket_start[b + 1]):
				var i: int = sorted_ids[k]
				if (positions[i] - center).length_squared() <= r_sq:
					out.append(i)
