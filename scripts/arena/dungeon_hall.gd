class_name DungeonHall
extends Node3D
## A dungeon's scenery from its DungeonLayout and ZoneTheme: the floor, a
## ceiling, a wall block on every 2 m cell of wall that borders open floor
## (so the hallway and rooms are walled exactly where monsters and the player
## are stopped), trim along the wall tops, and glowing lanterns on some wall
## faces. Built once at load.

const FLOOR_SHADER := preload("res://shaders/zone_floor.gdshader")
const CELL := 2.0
const LANTERN_EVERY := 5
const LANTERN_HEIGHT := 2.6

var theme: ZoneTheme
var layout: DungeonLayout


func build(p_theme: ZoneTheme, p_layout: DungeonLayout) -> void:
	theme = p_theme
	layout = p_layout
	_build_floor_and_ceiling()
	_build_walls()


func _build_floor_and_ceiling() -> void:
	var size := Vector2(layout.half_x, layout.half_z) * 2.0 + Vector2(CELL, CELL) * 2.0
	var material := ShaderMaterial.new()
	material.shader = FLOOR_SHADER
	material.set_shader_parameter("pattern", int(theme.floor_pattern))
	material.set_shader_parameter("base_color", theme.floor_color)
	material.set_shader_parameter("alt_color", theme.floor_alt_color)
	material.set_shader_parameter("grout_color", theme.grout_color)
	material.set_shader_parameter("inlay_color", theme.inlay_color)
	material.set_shader_parameter("inlay_every", theme.inlay_every)
	material.set_shader_parameter("tile_size", theme.tile_size)
	material.set_shader_parameter("grout_width", theme.grout_width)
	material.set_shader_parameter("noise_amount", theme.floor_noise)
	material.set_shader_parameter("roughness_value", theme.floor_roughness)
	var plane := PlaneMesh.new()
	plane.size = size
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.material_override = material
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
	if theme.ceiling_height > 0.0:
		var roof := PlaneMesh.new()
		roof.size = size
		roof.flip_faces = true
		var roof_material := StandardMaterial3D.new()
		roof_material.albedo_color = theme.ceiling_color
		roof.material = roof_material
		var ceiling := MeshInstance3D.new()
		ceiling.name = "Ceiling"
		ceiling.mesh = roof
		ceiling.position.y = theme.ceiling_height
		ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ceiling)


## Wall blocks on wall cells next to open floor, plus trims and lanterns.
func _build_walls() -> void:
	var height := theme.wall_height
	var cols := ceili(layout.half_x * 2.0 / CELL) + 2
	var rows := ceili(layout.half_z * 2.0 / CELL) + 2
	var origin := Vector2(-cols * CELL * 0.5, -rows * CELL * 0.5)
	var open := PackedByteArray()
	open.resize(cols * rows)
	for z in rows:
		for x in cols:
			var center := origin + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			open[z * cols + x] = 1 if layout.room_at(center) >= 0 else 0
	var blocks: Array[Transform3D] = []
	var trims: Array[Transform3D] = []
	var lanterns: Array[Transform3D] = []
	var faced := 0
	for z in rows:
		for x in cols:
			if open[z * cols + x] != 0:
				continue
			var facing := Vector2.ZERO
			var borders := false
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var nz := z + dz
					if nx < 0 or nz < 0 or nx >= cols or nz >= rows or open[nz * cols + nx] == 0:
						continue
					borders = true
					if dx == 0 or dz == 0:
						facing += Vector2(dx, dz)
			if not borders:
				continue
			var c := origin + Vector2((x + 0.5) * CELL, (z + 0.5) * CELL)
			blocks.append(Transform3D(Basis.from_scale(Vector3(CELL, height, CELL)),
					Vector3(c.x, height * 0.5, c.y)))
			trims.append(Transform3D(Basis.from_scale(Vector3(CELL + 0.1, 0.4, CELL + 0.1)),
					Vector3(c.x, height - 0.2, c.y)))
			if facing != Vector2.ZERO:
				faced += 1
				if faced % LANTERN_EVERY == 0:
					var at := c + facing.normalized() * (CELL * 0.5 + 0.25)
					lanterns.append(Transform3D(Basis.from_scale(Vector3(0.35, 0.6, 0.35)),
							Vector3(at.x, LANTERN_HEIGHT, at.y)))
	var lit := ArenaProps.lit_material()
	ArenaProps.add_batch(self, "Walls", ArenaProps.box(lit), blocks, theme.wall_color, true)
	ArenaProps.add_batch(self, "WallTrims", ArenaProps.box(lit), trims, theme.wall_trim_color,
			false)
	ArenaProps.add_batch(self, "Lanterns", ArenaProps.cylinder(0.8, 1.0, 8,
			ArenaProps.glow_material()), lanterns, theme.lantern_color, false)
