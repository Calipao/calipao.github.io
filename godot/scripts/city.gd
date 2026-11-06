extends Node3D
## The night city seen through the window: low-poly buildings with lit windows
## at real distances behind the wall, so they shift against each other as the
## camera moves, in front of a sky with a moon and a glowing horizon. Some
## windows flicker, switch on or off, or glow like a TV.
##
## Everything out here is unshaded. The buildings are merged into a few meshes
## (one per facade texture plus one for roofs and rooftop details), with
## per-building dimming in vertex colours and window tiling in the UVs.

const STREET_Y := -40.0  # the room is about 13 floors up
const SKY_Z := -280.0
const FACADE_COLS := 8
const FACADE_ROWS := 16
const WINDOW_W := 2.2  # metres per window column
const WINDOW_H := 3.1  # metres per floor
const WALL_Z := -0.62

const LIT_WARM := Color("#f3c96b")
const LIT_COOL := Color("#a9d4ff")
const UNLIT := Color("#141926")
const TV := Color("#7fa6ff")
const DARK := Color("#0c0e16")
const ROOF := Color("#090b12")

var rng := RandomNumberGenerator.new()
var facades: Array[ImageTexture] = []
var batches: Array[Dictionary] = []
var dark := {}
var fronts: Array[Dictionary] = []
var beacons: Array[MeshInstance3D] = []
var panels: Array = []
var flicker: MultiMesh
var started_ms := -1


func _ready() -> void:
	rng.seed = 2024
	_build_sky()
	facades = [
		_facade_texture(1, Color("#0e1322"), 0.32),
		_facade_texture(2, Color("#121625"), 0.22),
		_facade_texture(3, Color("#0b0f1b"), 0.42),
		_facade_texture(4, Color("#151a24"), 0.18),
	]
	for i in facades.size():
		batches.append(_new_batch())
	dark = _new_batch()
	var placed := _build_buildings()
	_build_beacons(placed)
	for i in facades.size():
		_finish(batches[i], facades[i])
	_finish(dark, null)
	_build_flicker()


# ---------- textures ----------

func _facade_texture(seed_value: int, wall: Color, lit: float) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var w := 256
	var h := 512
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(wall)
	var cw := w / FACADE_COLS
	var ch := h / FACADE_ROWS
	for y in FACADE_ROWS:
		for x in FACADE_COLS:
			var roll := r.randf()
			var c := Color("#141926")
			if roll < lit * 0.8:
				c = LIT_WARM
			elif roll < lit:
				c = LIT_COOL
			elif roll < lit + 0.08:
				c = Color("#2a2f3d")
			img.fill_rect(Rect2i(x * cw + int(cw * 0.18), y * ch + int(ch * 0.2), int(cw * 0.64), int(ch * 0.55)), c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _sky_texture() -> ImageTexture:
	var size := 512
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var stops := [
		[0.0, Color("#03050d")], [0.45, Color("#0b1226")], [0.62, Color("#24294a")],
		[0.7, Color("#4a3b52")], [0.78, Color("#1a1a2a")], [1.0, Color("#0a0b12")],
	]
	for y in size:
		var t := float(y) / size
		var c: Color = stops[0][1]
		for i in stops.size() - 1:
			if t >= stops[i][0] and t <= stops[i + 1][0]:
				var k: float = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
				var from: Color = stops[i][1]
				c = from.lerp(stops[i + 1][1], k)
		img.fill_rect(Rect2i(0, y, size, 1), c)
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for i in 260:
		var y := r.randi_range(0, int(size * 0.55))
		var a := 0.25 + r.randf() * 0.65 * (1.0 - y / (size * 0.55))
		var x := r.randi_range(0, size - 2)
		var star := img.get_pixel(x, y).lerp(Color.WHITE, a)
		img.set_pixel(x, y, star)
		if r.randf() > 0.94:
			img.set_pixel(x + 1, y, star)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _moon_texture() -> ImageTexture:
	var size := 128
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	var craters := [[Vector2(-5, -4), 4.5], [Vector2(6, 3), 3.5], [Vector2(-1, 7), 2.5], [Vector2(7, -7), 2.0]]
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(center)
			var c := Color(0.93, 0.94, 0.86, 0.0)
			if d < 18.0:
				c.a = 1.0
				for cr in craters:
					if Vector2(x, y).distance_to(center + cr[0]) < cr[1]:
						c = Color(0.78, 0.79, 0.73, 1.0)
			else:
				c.a = clampf(0.35 * (1.0 - (d - 18.0) / (size / 2.0 - 18.0)), 0.0, 0.35)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _unshaded(texture: Texture2D = null, color: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	if texture != null:
		m.albedo_texture = texture
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _quad(size: Vector2, material: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_sky() -> void:
	_quad(Vector2(900, 360), _unshaded(_sky_texture()), Vector3(100, 40, SKY_Z))
	var moon_mat := _unshaded(_moon_texture())
	moon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_quad(Vector2(34, 34), moon_mat, Vector3(135, 36, SKY_Z + 2))
	# A dark ground far below so gaps between buildings never show the sky.
	var ground := _quad(Vector2(900, 280), _unshaded(null, Color("#07080d")), Vector3(100, STREET_Y, -140))
	ground.rotation.x = -PI / 2.0


# ---------- merged geometry ----------

func _new_batch() -> Dictionary:
	# Plain Arrays (shared by reference) while building; packed in _finish().
	return {"pos": [], "uv": [], "col": []}


func _quad_tris(batch: Dictionary, corners: Array, uvs: Array, color: Color) -> void:
	# corners/uvs: [bottom-left, bottom-right, top-right, top-left]
	for i in [0, 1, 2, 0, 2, 3]:
		batch["pos"].append(corners[i])
		batch["uv"].append(uvs[i])
		batch["col"].append(color)


## Adds a box: walls go to a facade batch with tiled window UVs, the top goes
## to the dark batch. Facade UVs: U runs across the face in tiles; T runs down
## it in tiles (image rows go top to bottom).
func _add_box(tex: int, w: float, h: float, d: float, c: Vector3, tint: Color, distance: float) -> void:
	var x0 := c.x - w / 2.0
	var x1 := c.x + w / 2.0
	var y0 := c.y - h / 2.0
	var y1 := c.y + h / 2.0
	var z0 := c.z - d / 2.0
	var z1 := c.z + d / 2.0
	var ry := h / (FACADE_ROWS * WINDOW_H)
	var faces := [
		# [corners bottom-left, bottom-right, top-right, top-left] as seen from outside, span
		[[Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], w, true],   # +z (street-facing)
		[[Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)], w, false],  # -z
		[[Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1)], d, false],  # +x
		[[Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], d, false],  # -x
	]
	for face in faces:
		var rx: float = face[1] / (FACADE_COLS * WINDOW_W)
		var ox := float(rng.randi_range(0, FACADE_COLS - 1)) / FACADE_COLS
		var oy := float(rng.randi_range(0, FACADE_ROWS - 1)) / FACADE_ROWS
		var uvs := [Vector2(ox, oy + ry), Vector2(ox + rx, oy + ry), Vector2(ox + rx, oy), Vector2(ox, oy)]
		_quad_tris(batches[tex], face[0], uvs, tint)
		if face[2]:
			fronts.append({"x0": x0, "y0": y0, "w": w, "h": h, "z": z1, "rx": rx, "ry": ry, "ox": ox, "oy": oy, "tint": tint, "distance": distance})
	var zero := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	_quad_tris(dark, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], zero, ROOF)


## Adds a primitive mesh, moved to `at`, to the dark batch.
func _add_dark(mesh: PrimitiveMesh, at: Vector3) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for v in verts:
			dark["pos"].append(v + at)
			dark["uv"].append(Vector2.ZERO)
			dark["col"].append(DARK)
	else:
		for i in indices:
			dark["pos"].append(verts[i] + at)
			dark["uv"].append(Vector2.ZERO)
			dark["col"].append(DARK)


func _finish(batch: Dictionary, texture: Texture2D) -> void:
	var pos: Array = batch["pos"]
	if pos.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(pos)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(batch["uv"])
	arrays[Mesh.ARRAY_COLOR] = PackedColorArray(batch["col"])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := _unshaded(texture)
	mat.vertex_color_use_as_albedo = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------- buildings ----------

func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _building(x: float, z: float, w: float, d: float, top_y: float, distance: float) -> Dictionary:
	var h := top_y - STREET_Y
	# Farther buildings are dimmer and slightly bluer.
	var k := smoothstep(40.0, 225.0, distance)
	var tint := Color(1.0 - k * 0.55, 1.0 - k * 0.5, 1.0 - k * 0.38)
	var tex := rng.randi_range(0, facades.size() - 1)
	_add_box(tex, w, h, d, Vector3(x, STREET_Y + h / 2.0, z), tint, distance)
	var roof_y := top_y
	var roll := rng.randf()
	if roll < 0.25 and w > 16.0:
		# Setback: a narrower block on top.
		var sw := w * (0.5 + rng.randf() * 0.2)
		var sd := d * (0.5 + rng.randf() * 0.2)
		var sh := 8.0 + rng.randf() * 14.0
		_add_box(tex, sw, sh, sd, Vector3(x + (rng.randf() - 0.5) * (w - sw), top_y + sh / 2.0, z), tint, distance)
		roof_y = top_y + sh
	elif roll < 0.55:
		# Water tank on legs.
		var tx := x + (rng.randf() - 0.5) * w * 0.5
		var tz := z + (rng.randf() - 0.5) * d * 0.5
		_add_dark(_cylinder(2.4, 2.4, 4.5, 10), Vector3(tx, top_y + 5.5, tz))
		_add_dark(_cylinder(0.0, 2.6, 1.8, 10), Vector3(tx, top_y + 8.6, tz))
		_add_dark(_box(Vector3(3.4, 3.3, 3.4)), Vector3(tx, top_y + 1.65, tz))
	elif roll < 0.7:
		# Rooftop unit.
		_add_dark(_box(Vector3(w * 0.3, 3.0, d * 0.3)), Vector3(x + (rng.randf() - 0.5) * w * 0.4, top_y + 1.5, z))
	return {"x": x, "z": z, "roof_y": roof_y}


## Rows of buildings at increasing distance behind the window. From the
## default camera the line of sight through the window drifts right with
## distance, so the lane kept low for a clear view follows it.
func _build_buildings() -> Array[Dictionary]:
	var placed: Array[Dictionary] = []
	for dist: float in [45.0, 62.0, 85.0, 110.0, 140.0, 175.0, 215.0]:
		var z := WALL_Z - dist
		var view_x := 0.95 + dist * 0.37
		var span := 15.0 + dist * 1.05
		var x := view_x - span + rng.randf() * 8.0
		while x < view_x + span:
			var w := 12.0 + rng.randf() * 18.0
			var d := 12.0 + rng.randf() * 14.0
			# The eye is level with the middle of the window (about y = 1.4), so
			# most roofs sit a little above or below that line. A few towers
			# break the skyline.
			var lo := STREET_Y + 12.0 + dist * 0.1
			var hi := 1.4 + dist * 0.3 if rng.randf() < 0.12 else 1.4 + dist * 0.09
			var in_lane := x < view_x + dist * 0.3 and x + w > view_x - dist * 0.3
			if dist < 100.0 and in_lane:
				hi = minf(hi, 0.5 - dist * 0.15)
			var top_y := lo + rng.randf() * maxf(2.0, hi - lo)
			placed.append(_building(x + w / 2.0, z - rng.randf() * 8.0, w, d, top_y, dist))
			x += w + 3.0 + rng.randf() * 9.0
	return placed


## Antennas with blinking red beacons on the tallest buildings.
func _build_beacons(placed: Array[Dictionary]) -> void:
	var tallest := placed.duplicate()
	tallest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["roof_y"] > b["roof_y"])
	var beacon_mat := _unshaded(null, Color("#ff3b30"))
	for i in mini(4, tallest.size()):
		var b: Dictionary = tallest[i]
		var mast_h := 10.0 + rng.randf() * 12.0
		_add_dark(_cylinder(0.3, 0.5, mast_h, 6), Vector3(b["x"], b["roof_y"] + mast_h / 2.0, b["z"]))
		var sphere := SphereMesh.new()
		sphere.radius = 1.1
		sphere.height = 2.2
		var beacon := MeshInstance3D.new()
		beacon.mesh = sphere
		beacon.material_override = beacon_mat
		beacon.position = Vector3(b["x"], b["roof_y"] + mast_h + 0.6, b["z"])
		beacon.set_meta("phase", i * 0.37)
		add_child(beacon)
		beacons.append(beacon)


# ---------- flickering windows ----------

## A MultiMesh of small panels laid exactly over real windows on the
## street-facing facades, mostly within the view through the window. Each
## panel is lit or dark and now and then flickers, switches, or glows like a TV.
func _build_flicker() -> void:
	var near: Array[Dictionary] = []
	for f in fronts:
		if f["distance"] <= 150.0 and f["w"] > 4.0 and f["h"] > 6.0:
			near.append(f)
	if near.is_empty():
		return
	var count := 160
	flicker = MultiMesh.new()
	flicker.transform_format = MultiMesh.TRANSFORM_3D
	flicker.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	flicker.mesh = quad
	flicker.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = flicker
	var mat := _unshaded()
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	var panel_scale := Basis.from_scale(Vector3(WINDOW_W * 0.64 * 1.08, WINDOW_H * 0.55 * 1.08, 1.0))
	var hidden := Transform3D(Basis.from_scale(Vector3(0.0001, 0.0001, 0.0001)), Vector3(0, -1000, 0))
	for i in count:
		var want_visible := i < count * 0.8
		var face: Dictionary = {}
		var pos := Vector2.INF
		for attempt in 40:
			face = near[rng.randi_range(0, near.size() - 1)]
			pos = _pick_cell(face)
			if pos == Vector2.INF:
				continue
			if want_visible and not _in_view(pos.x, pos.y, face["z"]):
				pos = Vector2.INF
				continue
			break
		if pos == Vector2.INF:
			flicker.set_instance_transform(i, hidden)
			flicker.set_instance_color(i, UNLIT)
			panels.append(null)
			continue
		flicker.set_instance_transform(i, Transform3D(panel_scale, Vector3(pos.x, pos.y, face["z"] + 0.08)))
		flicker.set_instance_color(i, UNLIT)
		panels.append(_new_panel(face["tint"]))


## Whether a point is inside the view through the window from the default
## camera, widened a little for orbiting.
func _in_view(x: float, y: float, z: float) -> bool:
	var eye := Vector3(0, 1.4, 1.75)
	var t := (eye.z - z) / (eye.z + 0.7)
	return x > eye.x + (0.45 - 0.35) * t and x < eye.x + (1.45 + 0.35) * t \
		and y > eye.y + (1.04 - eye.y) * t and y < eye.y + (1.8 - eye.y) * t


## Picks a window cell on a facade and returns its centre (x, y) on the face,
## or Vector2.INF. Texture cells: 8 columns x 16 rows per tile; the lit
## rectangle of a cell spans 18-82% across and 20-75% down.
func _pick_cell(f: Dictionary) -> Vector2:
	var ox: float = f["ox"]
	var oy: float = f["oy"]
	var rx: float = f["rx"]
	var ry: float = f["ry"]
	var col_min := ceili(ox * FACADE_COLS)
	var col_max := floori((ox + rx) * FACADE_COLS) - 1
	var row_min := ceili(oy * FACADE_ROWS)
	var row_max := floori((oy + ry) * FACADE_ROWS) - 2  # skip the street-level row
	if col_max < col_min or row_max < row_min:
		return Vector2.INF
	var col := rng.randi_range(col_min, col_max)
	var row := rng.randi_range(row_min, row_max)
	var u: float = ((col + 0.5) / FACADE_COLS - f["ox"]) / f["rx"]
	var t: float = ((row + 0.475) / FACADE_ROWS - f["oy"]) / f["ry"]  # 0 at the top of the face
	return Vector2(f["x0"] + u * f["w"], f["y0"] + (1.0 - t) * f["h"])


## Kinds: most lights change rarely (a flicker or a switch every 45-150 s),
## a few faulty ones flicker every 6-25 s, and a few windows glow like a TV.
func _new_panel(tint: Color) -> Dictionary:
	var roll := rng.randf()
	var kind := "tv" if roll < 0.07 else ("faulty" if roll < 0.12 else "light")
	var lit := (LIT_WARM if rng.randf() < 0.85 else LIT_COOL) * tint
	return {
		"kind": kind,
		"lit": Color(lit.r, lit.g, lit.b, 1.0),
		"dark": Color(UNLIT.r * tint.r, UNLIT.g * tint.g, UNLIT.b * tint.b, 1.0),
		"tv": Color(TV.r * tint.r, TV.g * tint.g, TV.b * tint.b, 1.0),
		"on": kind == "faulty" or rng.randf() < 0.6,
		"next": _interval(kind) * rng.randf(),  # ms until its first event
		"until": 0.0,  # end of the current flicker burst
		"settle": -1,  # state to switch to after a burst: -1 none, 0 off, 1 on
		"phase": rng.randf() * 1000.0,
		"shown": -1,
	}


func _interval(kind: String) -> float:
	return 6000.0 + rng.randf() * 19000.0 if kind == "faulty" else 45000.0 + rng.randf() * 105000.0


func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec())
	if started_ms < 0:
		started_ms = int(now)
	var t := now - started_ms

	for b in beacons:
		b.visible = fmod(now / 1600.0 + float(b.get_meta("phase")), 1.0) < 0.18

	if flicker == null:
		return
	for i in panels.size():
		var p = panels[i]
		if p == null:
			continue
		if t >= p["next"]:
			if p["kind"] != "tv":
				# A short stutter; for ordinary lights, half the time it ends
				# with the light switched on or off.
				p["until"] = t + 250.0 + rng.randf() * 900.0
				p["settle"] = (0 if p["on"] else 1) if p["kind"] == "light" and rng.randf() < 0.5 else -1
			p["next"] = t + _interval(p["kind"])
		if p["kind"] == "tv":
			var ph: float = t + p["phase"]
			var k := 0.45 + 0.35 * sin(ph / 170.0) * sin(ph / 410.0) + 0.2 * sin(ph / 53.0)
			flicker.set_instance_color(i, (p["dark"] as Color).lerp(p["tv"], clampf(k, 0.0, 1.0)))
			continue
		var on: bool = p["on"]
		var lit_now: bool
		if t < p["until"]:
			var ph: float = t + p["phase"]
			lit_now = (not on) if int(ph / 70.0) % 3 == 0 else on  # stutter
			if sin(ph * 0.9) > 0.6:
				lit_now = not lit_now
		else:
			if p["settle"] != -1:
				p["on"] = p["settle"] == 1
				p["settle"] = -1
			lit_now = p["on"]
		var shown := 1 if lit_now else 0
		if shown != p["shown"]:
			p["shown"] = shown
			flicker.set_instance_color(i, p["lit"] if lit_now else p["dark"])
