class_name GateProp
extends RefCounted
## Builds a gate: two lacquered posts with capitals, a double lintel, a
## glowing doorway between the posts and a floating name. Dungeon entrances
## in the open world and exits inside halls use it. Static scenery, built at load.

const POST_RADIUS := 0.35
const POST_HEIGHT := 4.6
const SPAN := 3.6
const POST_COLOR := Color(0.55, 0.1, 0.07)
const TRIM_COLOR := Color(0.85, 0.64, 0.28)
const LABEL_SIZE := 72
const LABEL_PIXEL := 0.012


## The gate stands at ground position at, its doorway facing +Z (south).
static func build(parent: Node3D, at: Vector2, title: String, glow: Color) -> Node3D:
	var gate := Node3D.new()
	gate.name = "Gate"
	gate.position = Vector3(at.x, 0.0, at.y)
	parent.add_child(gate)
	var lit := ArenaProps.lit_material()
	var posts: Array[Transform3D] = []
	var lintels: Array[Transform3D] = []
	var trims: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var x := side * SPAN * 0.5
		posts.append(Transform3D(Basis.from_scale(Vector3(POST_RADIUS, POST_HEIGHT, POST_RADIUS)),
				Vector3(x, POST_HEIGHT * 0.5, 0.0)))
		trims.append(Transform3D(Basis.from_scale(Vector3(0.95, 0.4, 0.95)),
				Vector3(x, 0.2, 0.0)))
	lintels.append(Transform3D(Basis.from_scale(Vector3(SPAN + 1.6, 0.35, 0.7)),
			Vector3(0.0, POST_HEIGHT + 0.6, 0.0)))
	trims.append(Transform3D(Basis.from_scale(Vector3(SPAN + 0.6, 0.3, 0.55)),
			Vector3(0.0, POST_HEIGHT - 0.1, 0.0)))
	ArenaProps.add_batch(gate, "Posts", ArenaProps.cylinder(1.0, 1.0, 10, lit), posts,
			POST_COLOR, true)
	ArenaProps.add_batch(gate, "Lintel", ArenaProps.box(lit), lintels, POST_COLOR, true)
	ArenaProps.add_batch(gate, "Trims", ArenaProps.box(lit), trims, TRIM_COLOR, true)
	var door := MeshInstance3D.new()
	door.name = "Doorway"
	var quad := QuadMesh.new()
	quad.size = Vector2(SPAN - POST_RADIUS * 2.0, POST_HEIGHT - 0.3)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(glow.r, glow.g, glow.b, 0.75)
	quad.material = material
	door.mesh = quad
	door.position = Vector3(0.0, (POST_HEIGHT - 0.3) * 0.5, 0.0)
	door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(door)
	var label := Label3D.new()
	label.name = "Title"
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = LABEL_SIZE
	label.pixel_size = LABEL_PIXEL
	label.outline_size = 16
	label.modulate = Color(1.0, 0.9, 0.7)
	label.position = Vector3(0.0, POST_HEIGHT + 1.8, 0.0)
	gate.add_child(label)
	return gate
