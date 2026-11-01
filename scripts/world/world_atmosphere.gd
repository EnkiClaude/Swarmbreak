class_name WorldAtmosphere
extends RefCounted
## Drives the scene's Environment and sun from ZoneThemes. In the open world
## the sky, fog, ambient light and sunlight ease into the current region's
## over blend_time, so walking across a border never pops; going through a
## gate snaps straight to the new space's look.

const GLOW_THRESHOLD := 0.9
const SKY_FOG_AFFECT := 0.6
const SUN_ANGLE_MAX := 20.0

var blend_time := 2.0
var target: ZoneTheme

var _environment: Environment
var _sun: DirectionalLight3D
var _sky_material: ProceduralSkyMaterial
var _sky_top := Color.BLACK
var _sky_horizon := Color.BLACK
var _fog_color := Color.BLACK
var _fog_density := 0.0
var _ambient_color := Color.BLACK
var _ambient_energy := 0.0
var _sun_color := Color.BLACK
var _sun_energy := 0.0
var _sun_rotation := Vector3.ZERO
var _glow := 0.0


func _init(environment: Environment, sun: DirectionalLight3D) -> void:
	_environment = environment
	_sun = sun
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sun_angle_max = SUN_ANGLE_MAX
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.fog_sky_affect = SKY_FOG_AFFECT
	_environment.glow_hdr_threshold = GLOW_THRESHOLD


## Heads for theme's look; snap jumps there at once.
func set_target(theme: ZoneTheme, snap: bool) -> void:
	if theme == null:
		return
	target = theme
	_environment.background_mode = Environment.BG_SKY if theme.show_sky else Environment.BG_COLOR
	_environment.background_color = theme.background_color
	if snap:
		_blend(1.0)


func tick(delta: float) -> void:
	if target == null:
		return
	# Exponential approach: about 95% of the way there after blend_time.
	_blend(1.0 - exp(-3.0 * delta / maxf(blend_time, 0.001)))


func _blend(weight: float) -> void:
	var t := target
	_sky_top = _sky_top.lerp(t.sky_top_color, weight)
	_sky_horizon = _sky_horizon.lerp(t.sky_horizon_color, weight)
	_fog_color = _fog_color.lerp(t.fog_color, weight)
	_fog_density = lerpf(_fog_density, t.fog_density, weight)
	_ambient_color = _ambient_color.lerp(t.ambient_color, weight)
	_ambient_energy = lerpf(_ambient_energy, t.ambient_energy, weight)
	_sun_color = _sun_color.lerp(t.sun_color, weight)
	_sun_energy = lerpf(_sun_energy, t.sun_energy, weight)
	var goal := Vector3(-deg_to_rad(t.sun_elevation), deg_to_rad(t.sun_azimuth), 0.0)
	_sun_rotation = _sun_rotation.lerp(goal, weight)
	_glow = lerpf(_glow, t.glow_strength, weight)
	_sky_material.sky_top_color = _sky_top
	_sky_material.sky_horizon_color = _sky_horizon
	_sky_material.ground_horizon_color = _sky_horizon
	_sky_material.ground_bottom_color = _fog_color
	_environment.ambient_light_color = _ambient_color
	_environment.ambient_light_energy = _ambient_energy
	_environment.fog_enabled = _fog_density > 0.0001
	_environment.fog_light_color = _fog_color
	_environment.fog_density = _fog_density
	_environment.glow_enabled = _glow > 0.01
	_environment.glow_intensity = _glow
	_sun.light_color = _sun_color
	_sun.light_energy = _sun_energy
	_sun.rotation = _sun_rotation


## How far the current look is from the target's fog (for tests): 0 = there.
func fog_gap() -> float:
	return absf(_fog_density - target.fog_density) if target != null else 0.0
