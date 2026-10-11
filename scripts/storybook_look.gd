extends RefCounted
## The storybook look for a 3D scene: every model repainted in flat washes
## of its own colours (shaders/storybook_paint) with an ink outline around
## it (shaders/storybook_outline), so a story's pictures read as a
## hand-coloured book illustration drawn from the real cast and sets.

const PAINT := preload("res://shaders/storybook_paint.gdshader")
const OUTLINE := preload("res://shaders/storybook_outline.gdshader")
## Mithila style: flat palette colours chosen by hue, no light or shade.
const FLAT := preload("res://shaders/storybook_flat.gdshader")
## Meshes larger than this (metres, longest side) are ground, sky or
## backdrop: painted, but not outlined (a rim around the sky is ink
## everywhere).
const OUTLINE_MAX_SIZE := 30.0

static var _painted := {}

## Repaints every mesh under root, in "wash" (flat washes of the model's
## own colours, lit in two tones) or "mithila" (flat palette colours). Safe
## to call again as actors are added: each material is converted once and
## reused.
static func apply(root: Node, style := "wash") -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var done := str(mesh.get_meta("storybook", ""))
		if mesh.mesh == null or done == style or done == "keep":
			continue
		mesh.set_meta("storybook", style)
		var size := mesh.get_aabb().size * mesh.global_transform.basis.get_scale()
		var outline := maxf(size.x, maxf(size.y, size.z)) < OUTLINE_MAX_SIZE
		if mesh.material_override != null:
			var whole := _paint(_source(mesh.material_override), outline, style)
			if whole != null:
				mesh.material_override = whole
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := _source(mesh.get_active_material(surface))
			var painted := _paint(source, outline, style)
			if painted != null:
				mesh.set_surface_override_material(surface, painted)

## The original material behind one this script already painted.
static func _source(material: Material) -> Material:
	if material != null and material.has_meta("storybook_source"):
		return material.get_meta("storybook_source")
	return material

static func _paint(source: Material, outline: bool, style := "wash") -> Material:
	# The colour and texture to paint with: a standard material's, or the
	# fighters' skin shader's (fighter_animated.gd _finish).
	var colour := Color.WHITE
	var texture: Texture2D = null
	if source is BaseMaterial3D:
		colour = source.albedo_color
		texture = source.albedo_texture
	elif source is ShaderMaterial and source.shader != null and source.shader.resource_path.ends_with("fighter_skin.gdshader"):
		colour = source.get_shader_parameter("albedo_color")
		texture = source.get_shader_parameter("albedo_tex")
	else:
		return null
	var key := [source.get_instance_id(), outline, style]
	if _painted.has(key):
		return _painted[key]
	var paint := ShaderMaterial.new()
	paint.shader = FLAT if style == "mithila" else PAINT
	paint.set_meta("storybook_source", source)
	paint.set_shader_parameter("albedo", colour)
	paint.set_shader_parameter("use_texture", texture != null)
	if texture != null:
		paint.set_shader_parameter("albedo_texture", texture)
	if outline:
		var ink := ShaderMaterial.new()
		ink.shader = OUTLINE
		paint.next_pass = ink
	_painted[key] = paint
	return paint
