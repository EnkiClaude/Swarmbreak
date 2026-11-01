class_name ArenaAtmosphere
extends RefCounted
## Applies a ZoneTheme's sky (or flat indoor background), ambient light, fog,
## glow and sunlight to the scene's Environment and sun.

const GLOW_THRESHOLD := 0.9
const SKY_FOG_AFFECT := 0.6


static func apply(theme: ZoneTheme, environment: Environment, sun: DirectionalLight3D) -> void:
	if theme.show_sky:
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = theme.sky_top_color
		sky_material.sky_horizon_color = theme.sky_horizon_color
		sky_material.ground_horizon_color = theme.sky_horizon_color
		sky_material.ground_bottom_color = theme.fog_color
		sky_material.sun_angle_max = 20.0
		var sky := Sky.new()
		sky.sky_material = sky_material
		environment.sky = sky
		environment.background_mode = Environment.BG_SKY
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = theme.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = theme.ambient_color
	environment.ambient_light_energy = theme.ambient_energy
	environment.fog_enabled = theme.fog_density > 0.0
	environment.fog_light_color = theme.fog_color
	environment.fog_density = theme.fog_density
	environment.fog_sky_affect = SKY_FOG_AFFECT
	environment.glow_enabled = theme.glow_strength > 0.0
	environment.glow_intensity = theme.glow_strength
	environment.glow_hdr_threshold = GLOW_THRESHOLD
	sun.light_color = theme.sun_color
	sun.light_energy = theme.sun_energy
	sun.rotation = Vector3(-deg_to_rad(theme.sun_elevation), deg_to_rad(theme.sun_azimuth), 0.0)
