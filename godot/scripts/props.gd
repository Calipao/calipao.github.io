extends RefCounted
## Small helpers for building the desk from primitive meshes.


static func mat(color: Color, roughness: float = 0.75, metallic: float = 0.05) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _add(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, material, pos, rot)


static func cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, segments: int = 20) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add(parent, mesh, material, pos, rot)


static func sphere(parent: Node3D, radius: float, material: Material, pos: Vector3, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := _add(parent, mesh, material, pos, Vector3.ZERO)
	mi.scale = scale
	return mi


static func torus(parent: Node3D, inner: float, outer: float, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	return _add(parent, mesh, material, pos, rot)


static func quad(parent: Node3D, size: Vector2, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := _add(parent, mesh, material, pos, rot)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func label(parent: Node3D, text: String, font: Font, color: Color, pos: Vector3, pixel_size: float, font_size: int = 64, width: float = 0.0, rot: Vector3 = Vector3.ZERO) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = font_size
	l.pixel_size = pixel_size
	l.modulate = color
	l.outline_size = 0
	l.double_sided = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width
	l.position = pos
	l.rotation = rot
	parent.add_child(l)
	return l


## An invisible box used for mouse picking.
static func pick_area(parent: Node3D, size: Vector3, center: Vector3) -> Area3D:
	var area := Area3D.new()
	area.monitoring = false
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = center
	area.add_child(shape)
	parent.add_child(area)
	return area


static func skyline_texture() -> ImageTexture:
	var w := 256
	var h := 200
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / h
		img.fill_rect(Rect2i(0, y, w, 1), Color("#050816").lerp(Color("#1b2440"), t))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 40:
		img.set_pixel(rng.randi_range(0, w - 1), rng.randi_range(0, h / 2), Color(1, 1, 1, rng.randf_range(0.3, 0.9)))
	img.fill_rect(Rect2i(190, 24, 18, 18), Color("#e9edd8"))
	var x := 0
	while x < w:
		var bw := rng.randi_range(15, 40)
		var bh := int(h * rng.randf_range(0.25, 0.75))
		img.fill_rect(Rect2i(x, h - bh, bw, bh), Color("#0b0f1a") if rng.randf() > 0.5 else Color("#10162a"))
		var wy := h - bh + 4
		while wy < h - 3:
			var wx := x + 3
			while wx < x + bw - 3:
				if rng.randf() > 0.68:
					img.fill_rect(Rect2i(wx, wy, 2, 3), Color("#f5d27a") if rng.randf() > 0.2 else Color("#9fd3ff"))
				wx += 5
			wy += 6
		x += bw + 1
	return ImageTexture.create_from_image(img)
