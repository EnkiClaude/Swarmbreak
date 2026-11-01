class_name HudMinimap
extends RefCounted
## Draws the round minimap: the area around the player turned so the
## camera's view points up, the space's outer walls as a dotted line, camps
## in range as dots, gates as diamonds (pinned to the rim when out of range,
## so a dungeon is easy to find), the player as an arrow, a faint view cone,
## and a bronze rim with a marker for north.

const WALL_DOT_SPACING := 4.0
const RIM_WIDTH := 6.0
const VIEW_CONE_DEGREES := 30.0
const NORTH_PLATE_RADIUS := 10.0
const FONT_SIZE := 14
const GATE_SIZE := 5.0


## yaw is the camera's (CameraRig.yaw()); facing the player's ground direction.
static func draw(canvas: CanvasItem, center: Vector2, config: HudConfig, world: WorldDirector,
		player_pos: Vector2, facing: Vector2, yaw: float) -> void:
	var r := config.minimap_radius
	var scale_factor := r / config.minimap_range
	canvas.draw_circle(center, r, config.minimap_back_color)
	_draw_view_cone(canvas, center, r, config.minimap_player_color)
	if world != null:
		_draw_walls(canvas, center, r, scale_factor, player_pos, yaw,
				world.map.half_extent(world.space), config.minimap_wall_color)
		var sites := world.camps.sites
		var site_count := sites.size() if sites != null else 0
		for camp in site_count:
			if sites.alive[camp] <= 0:
				continue
			var at := to_map(sites.centers[camp], player_pos, yaw, scale_factor)
			var dot := clampf(sqrt(float(sites.alive[camp])) * 0.7, 2.0, 6.0)
			if at.length() > r - dot - 2.0:
				continue
			var color := config.minimap_awake_color if sites.awake[camp] != 0 \
					else config.minimap_camp_color
			canvas.draw_circle(center + at, dot, color)
		for gate in world.gate_positions():
			var at := to_map(gate, player_pos, yaw, scale_factor)
			if at.length() > r - 7.0:
				at = at.normalized() * (r - 7.0)
			_draw_gate(canvas, center + at, config.frame_color)
	_draw_player(canvas, center, facing.rotated(yaw), config.minimap_player_color)
	canvas.draw_arc(center, r, 0.0, TAU, 64, config.minimap_ring_color, RIM_WIDTH, true)
	canvas.draw_arc(center, r + RIM_WIDTH * 0.5, 0.0, TAU, 64, config.frame_color, 1.5, true)
	var north := center + Vector2(0.0, -1.0).rotated(yaw) * r
	canvas.draw_circle(north, NORTH_PLATE_RADIUS, config.minimap_ring_color)
	canvas.draw_arc(north, NORTH_PLATE_RADIUS, 0.0, TAU, 24, config.frame_color, 1.5, true)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	canvas.draw_string(font, north + Vector2(-w * 0.5, FONT_SIZE * 0.35), "N",
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 0.92, 0.75))


## Minimap offset (pixels from its center) of a ground position.
static func to_map(ground: Vector2, player_pos: Vector2, yaw: float, scale_factor: float) -> Vector2:
	return (ground - player_pos).rotated(yaw) * scale_factor


static func _draw_view_cone(canvas: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var half := deg_to_rad(VIEW_CONE_DEGREES)
	var tint := color
	tint.a = 0.12
	var points := PackedVector2Array([center,
			center + Vector2(0.0, -r).rotated(-half),
			center + Vector2(0.0, -r),
			center + Vector2(0.0, -r).rotated(half)])
	canvas.draw_colored_polygon(points, tint)


static func _draw_walls(canvas: CanvasItem, center: Vector2, r: float, scale_factor: float,
		player_pos: Vector2, yaw: float, half_extent: float, color: Color) -> void:
	var steps := ceili(half_extent * 2.0 / WALL_DOT_SPACING)
	for k in steps + 1:
		var along := -half_extent + k * WALL_DOT_SPACING
		for wall: Vector2 in [Vector2(along, -half_extent), Vector2(along, half_extent),
				Vector2(-half_extent, along), Vector2(half_extent, along)]:
			var at := to_map(wall, player_pos, yaw, scale_factor)
			if at.length() < r - 3.0:
				canvas.draw_circle(center + at, 1.2, color)


static func _draw_gate(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	var s := GATE_SIZE
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -s), at + Vector2(s, 0.0),
			at + Vector2(0.0, s), at + Vector2(-s, 0.0)]), color)
	canvas.draw_polyline(PackedVector2Array([at + Vector2(0.0, -s), at + Vector2(s, 0.0),
			at + Vector2(0.0, s), at + Vector2(-s, 0.0), at + Vector2(0.0, -s)]), Color.BLACK, 1.0)


static func _draw_player(canvas: CanvasItem, center: Vector2, dir: Vector2, color: Color) -> void:
	if dir.length_squared() < 0.0001:
		dir = Vector2.UP
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array([center + dir * 8.0, center - dir * 5.0 + side * 5.0,
			center - dir * 2.5, center - dir * 5.0 - side * 5.0])
	canvas.draw_colored_polygon(points, color)
