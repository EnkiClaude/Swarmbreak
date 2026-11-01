class_name ModelBuilder
extends RefCounted
## Assembles one ArrayMesh from simple parts (boxes, cylinders, cones,
## spheres), each placed by a transform and painted a flat vertex color. UV
## carries the animation rig: UV.x is the part's limb group (Limb) and UV.y
## the height of the joint it swings around, which rig.gdshaderinc reads to
## walk. Built once at load: a whole character is one mesh, so a swarm type
## stays one MultiMesh draw.

## Which way a part moves when walking. Opposite legs and arms swing in
## opposite phase; FLOAT parts drift up and down (wisps, capes).
enum Limb { BODY, LEFT_LEG, RIGHT_LEG, LEFT_ARM, RIGHT_ARM, FLOAT }

const CYLINDER_SEGMENTS := 8
const SPHERE_SEGMENTS := 10
const SPHERE_RINGS := 6

var _tool := SurfaceTool.new()


func _init() -> void:
	_tool.begin(Mesh.PRIMITIVE_TRIANGLES)


## A box of size centered at at, turned by rotation (Euler degrees, YXZ).
func box(at: Vector3, size: Vector3, color: Color, limb: int = Limb.BODY, joint: float = 0.0,
		rotation_degrees: Vector3 = Vector3.ZERO) -> ModelBuilder:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_add(mesh, _transform(at, size, rotation_degrees), color, limb, joint)
	return self


## A cylinder (or cone, with a different top radius) of height, centered at at.
func cylinder(at: Vector3, bottom: float, top: float, height: float, color: Color,
		limb: int = Limb.BODY, joint: float = 0.0,
		rotation_degrees: Vector3 = Vector3.ZERO, segments: int = CYLINDER_SEGMENTS) -> ModelBuilder:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	_add(mesh, _transform(at, Vector3.ONE, rotation_degrees), color, limb, joint)
	return self


## An ellipsoid with the given radii, centered at at.
func sphere(at: Vector3, radii: Vector3, color: Color, limb: int = Limb.BODY,
		joint: float = 0.0, rotation_degrees: Vector3 = Vector3.ZERO) -> ModelBuilder:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = SPHERE_SEGMENTS
	mesh.rings = SPHERE_RINGS
	_add(mesh, _transform(at, radii, rotation_degrees), color, limb, joint)
	return self


## Mirrors a part across X: a left/right pair from one call. limb and
## mirrored_limb are the left and right groups (or both BODY).
func pair(kind: String, at: Vector3, size: Vector3, color: Color, limb: int = Limb.BODY,
		mirrored_limb: int = Limb.BODY, joint: float = 0.0,
		rotation_degrees: Vector3 = Vector3.ZERO) -> ModelBuilder:
	var mirrored_rotation := Vector3(rotation_degrees.x, -rotation_degrees.y, -rotation_degrees.z)
	for side: int in [-1, 1]:
		var p := Vector3(at.x * side, at.y, at.z)
		var r := rotation_degrees if side < 0 else mirrored_rotation
		var l := limb if side < 0 else mirrored_limb
		match kind:
			"box":
				box(p, size, color, l, joint, r)
			"sphere":
				sphere(p, size, color, l, joint, r)
			"cylinder":
				# size: (bottom radius, top radius, height)
				cylinder(p, size.x, size.y, size.z, color, l, joint, r)
	return self


## The finished mesh with material (or none, for a material_override).
func build(material: Material = null) -> ArrayMesh:
	_tool.generate_normals()
	var mesh := _tool.commit()
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh


static func _transform(at: Vector3, scale: Vector3, rotation_degrees: Vector3) -> Transform3D:
	var rotation := Basis.from_euler(rotation_degrees * (PI / 180.0))
	return Transform3D(rotation * Basis.from_scale(scale), at)


func _add(mesh: PrimitiveMesh, xform: Transform3D, color: Color, limb: int, joint: float) -> void:
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var rig := Vector2(limb, joint)
	for index in indices:
		_tool.set_color(color)
		_tool.set_uv(rig)
		_tool.add_vertex(xform * vertices[index])
