extends Node3D
## Builds the interactive desk: room, props, CRT monitor running the terminal,
## project cartridges, camera controls and the on-screen UI.

const Props = preload("res://scripts/props.gd")
const Terminal = preload("res://scripts/terminal.gd")
const TermInput = preload("res://scripts/term_input.gd")

const DESK_Y := 0.75
const SCREEN_SIZE := Vector2(0.44, 0.33)
const TERM_PIXELS := Vector2i(1024, 768)
const ACCENT := Color("#b5e853")
const CART_COLORS := ["#3b6e9e", "#9e3b4f", "#3b9e6a", "#9e7a3b", "#6a3b9e", "#3b8e9e", "#9e5a3b", "#5a5a5a"]

enum Mode { ORBIT, TWEEN, FOCUS }

var data: Dictionary = {}
var font: Font = preload("res://fonts/DejaVuSansMono.ttf")
var mode := Mode.ORBIT

var camera: Camera3D
var orbit_target := Vector3(0, 0.98, -0.05)
var yaw := 0.35
var pitch := 0.5
var dist := 3.6
var want_yaw := 0.0
var want_pitch := 0.23
var want_dist := 1.85
var max_dist := 2.7

var term: Terminal
var screen: MeshInstance3D
var screen_area: Area3D
var monitor_area: Area3D
var picks := {}  # Area3D -> Dictionary describing what it does
var hovered: Area3D = null

var keys: Array[MeshInstance3D] = []
var key_rest: Array[float] = []
var pressed := {}  # key index -> seconds since pressed

# UI
var ui_root: Control
var tooltip: PanelContainer
var tooltip_title: Label
var tooltip_detail: Label
var hint: Label
var term_bar: HFlowContainer
var line_edit: TermInput

var press_pos := Vector2.ZERO
var dragging := false
var hint_hidden := false


func _ready() -> void:
	data = _load_data()
	_build_environment()
	_build_room()
	_build_desk()
	_build_monitor()
	_build_keyboard()
	_build_small_props()
	_build_cartridges()
	_build_notebook()
	_build_contact()
	_build_ui()
	get_viewport().size_changed.connect(_on_resized)
	_on_resized()
	want_dist = _home_distance()


# ---------- data ----------

func _load_data() -> Dictionary:
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("JSON.stringify((window.parent && window.parent.DESK_DATA) || null)", true)
		if raw is String and raw != "null":
			var parsed: Variant = JSON.parse_string(raw)
			if parsed is Dictionary:
				return parsed
	var f := FileAccess.open("res://sample_data.json", FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			return parsed
	return {"name": "Lin Xin", "role": "", "projects": [], "pages": {"about": "/about/"}, "links": {}}


# ---------- scene ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0c0f0e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6d7f9e")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	camera = Camera3D.new()
	camera.fov = 40.0
	camera.near = 0.02
	camera.far = 30.0
	add_child(camera)
	camera.global_transform = _orbit_transform()
	camera.current = true

	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#9fb7ff")
	moon.light_energy = 0.5
	moon.transform = Transform3D(Basis(), Vector3(1.5, 2.5, 1.5)).looking_at(Vector3.ZERO, Vector3.UP)
	add_child(moon)


func _build_room() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(12, 12)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.material_override = Props.mat(Color("#15181a"), 0.95)
	add_child(floor_node)

	Props.quad(self, Vector2(12, 5), Props.mat(Color("#1f2a26"), 0.95), Vector3(0, 2.5, -0.62))

	# Window with a night skyline.
	var glass := StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = Props.skyline_texture()
	var window := Node3D.new()
	window.position = Vector3(0.95, 1.55, -0.6)
	add_child(window)
	Props.quad(window, Vector2(0.9, 0.7), glass, Vector3.ZERO)
	var frame_mat := Props.mat(Color("#2d2a26"))
	for bar: Array in [[0.98, 0.04, 0.0, 0.37], [0.98, 0.04, 0.0, -0.37], [0.04, 0.78, -0.47, 0.0], [0.04, 0.78, 0.47, 0.0], [0.02, 0.7, 0.0, 0.0], [0.9, 0.02, 0.0, 0.0]]:
		Props.box(window, Vector3(bar[0], bar[1], 0.04), frame_mat, Vector3(bar[2], bar[3], 0.02))

	# Poster.
	var poster := Node3D.new()
	poster.position = Vector3(-0.85, 1.55, -0.6)
	poster.rotation.z = 0.02
	add_child(poster)
	Props.box(poster, Vector3(0.42, 0.56, 0.015), Props.mat(Color("#0b0f0a")), Vector3.ZERO)
	var border := Props.unshaded(ACCENT)
	for b: Array in [[0.38, 0.006, 0.0, 0.255], [0.38, 0.006, 0.0, -0.255], [0.006, 0.51, -0.187, 0.0], [0.006, 0.51, 0.187, 0.0]]:
		Props.box(poster, Vector3(b[0], b[1], 0.002), border, Vector3(b[2], b[3], 0.009))
	var slug := "./" + str(data.get("name", "")).to_lower().replace(" ", "-")
	Props.label(poster, slug, font, ACCENT, Vector3(0, 0.19, 0.009), 0.0006, 48)
	Props.label(poster, "while (alive) {\n  make();\n  play();\n  learn();\n}", font, Color("#6f8f3a"), Vector3(0, 0.0, 0.009), 0.0005, 40)
	Props.label(poster, "PRESS START", font, ACCENT, Vector3(0, -0.2, 0.009), 0.0005, 36)


func _build_desk() -> void:
	var wood := Props.mat(Color("#6b4a31"), 0.65)
	Props.box(self, Vector3(1.9, 0.05, 0.85), wood, Vector3(0, DESK_Y - 0.025, 0))
	var metal := Props.mat(Color("#2a2d30"), 0.4, 0.6)
	for x: float in [-0.88, 0.88]:
		for z: float in [-0.36, 0.36]:
			Props.box(self, Vector3(0.04, DESK_Y - 0.05, 0.04), metal, Vector3(x, (DESK_Y - 0.05) / 2.0, z))


func _build_monitor() -> void:
	var monitor := Node3D.new()
	monitor.position = Vector3(-0.05, DESK_Y, -0.17)
	add_child(monitor)
	var shell := Props.mat(Color("#c9c1a9"), 0.55)
	Props.box(monitor, Vector3(0.3, 0.03, 0.26), shell, Vector3(0, 0.015, 0))
	Props.cylinder(monitor, 0.06, 0.08, 0.04, shell, Vector3(0, 0.05, 0))
	Props.box(monitor, Vector3(0.58, 0.46, 0.4), shell, Vector3(0, 0.3, 0))
	Props.box(monitor, Vector3(0.42, 0.34, 0.24), shell, Vector3(0, 0.3, -0.27))
	Props.box(monitor, Vector3(0.5, 0.38, 0.02), Props.mat(Color("#26282a"), 0.5), Vector3(0, 0.31, 0.2))
	Props.sphere(monitor, 0.006, Props.unshaded(Color("#7dff4a")), Vector3(0.23, 0.095, 0.205))

	# The terminal renders into a SubViewport whose texture is the screen.
	var viewport := SubViewport.new()
	viewport.size = TERM_PIXELS
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	term = Terminal.new()
	viewport.add_child(term)
	term.setup(data, font, Vector2(TERM_PIXELS))
	term.navigate_requested.connect(_navigate)
	term.exit_requested.connect(exit_terminal)
	term.text_view_requested.connect(_text_view)

	var screen_mat := StandardMaterial3D.new()
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_mat.albedo_texture = viewport.get_texture()
	screen = Props.quad(monitor, SCREEN_SIZE, screen_mat, Vector3(0, 0.31, 0.2115))

	var glow := OmniLight3D.new()
	glow.light_color = Color("#9dff6a")
	glow.light_energy = 0.8
	glow.omni_range = 1.4
	glow.position = Vector3(0, 0.26, 0.45)
	monitor.add_child(glow)

	# Sticky note.
	Props.quad(monitor, Vector2(0.062, 0.062), Props.mat(Color("#f4e36b"), 0.9), Vector3(0.252, 0.112, 0.213), Vector3(0, 0, -0.12))
	Props.label(monitor, "click the\nscreen &\ntype help", font, Color("#3a3320"), Vector3(0.252, 0.114, 0.215), 0.00022, 32, 0.0, Vector3(0, 0, -0.12))

	monitor_area = Props.pick_area(monitor, Vector3(0.58, 0.5, 0.42), Vector3(0, 0.27, 0))
	picks[monitor_area] = {"kind": "monitor", "label": "Terminal", "detail": "Click to use it, or just start typing."}
	screen_area = monitor_area


func _build_keyboard() -> void:
	var kb := Node3D.new()
	kb.position = Vector3(-0.05, DESK_Y, 0.2)
	add_child(kb)
	var shell := Props.mat(Color("#c9c1a9"), 0.55)
	Props.box(kb, Vector3(0.46, 0.025, 0.16), shell, Vector3(0, 0.0125, 0))
	var key_mat := Props.mat(Color("#ebe6d6"), 0.5)
	for r in 4:
		for c in 14:
			var k := Props.box(kb, Vector3(0.024, 0.012, 0.024), key_mat, Vector3(-0.195 + c * 0.03 + (r % 2) * 0.008, 0.031, -0.05 + r * 0.03))
			keys.append(k)
			key_rest.append(k.position.y)
	var space := Props.box(kb, Vector3(0.17, 0.012, 0.024), key_mat, Vector3(0, 0.031, 0.072))
	keys.append(space)
	key_rest.append(space.position.y)


func press_key(spacebar: bool = false) -> void:
	var i := keys.size() - 1 if spacebar else randi_range(0, keys.size() - 2)
	pressed[i] = 0.0


func _build_small_props() -> void:
	# Mouse and pad.
	Props.box(self, Vector3(0.22, 0.004, 0.18), Props.mat(Color("#1d3b2c"), 0.95), Vector3(0.36, DESK_Y + 0.002, 0.22))
	Props.sphere(self, 0.03, Props.mat(Color("#c9c1a9"), 0.55), Vector3(0.36, DESK_Y + 0.016, 0.22), Vector3(0.85, 0.45, 1.3))

	# Mug.
	var mug := Node3D.new()
	mug.position = Vector3(-0.6, DESK_Y, 0.08)
	mug.rotation.y = 0.6
	add_child(mug)
	var mug_mat := Props.mat(ACCENT, 0.4)
	Props.cylinder(mug, 0.042, 0.04, 0.1, mug_mat, Vector3(0, 0.05, 0))
	Props.cylinder(mug, 0.035, 0.035, 0.002, Props.mat(Color("#2b1a10"), 0.2), Vector3(0, 0.1, 0))
	Props.torus(mug, 0.018, 0.03, mug_mat, Vector3(0.042, 0.052, 0), Vector3(PI / 2.0, 0, 0))

	# Plant.
	var plant := Node3D.new()
	plant.position = Vector3(-0.78, DESK_Y, -0.27)
	add_child(plant)
	Props.cylinder(plant, 0.07, 0.055, 0.12, Props.mat(Color("#a65a3a")), Vector3(0, 0.06, 0))
	Props.cylinder(plant, 0.065, 0.065, 0.002, Props.mat(Color("#2a1d14")), Vector3(0, 0.115, 0))
	var leaf_mat := Props.mat(Color("#3f8f4a"), 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 9:
		var a := float(i) / 9.0 * TAU
		var tilt := rng.randf_range(0.25, 0.7)
		var leaf := Props.cylinder(plant, 0.0, 0.025, rng.randf_range(0.2, 0.28), leaf_mat, Vector3(cos(a) * 0.03, 0.2, sin(a) * 0.03), Vector3(sin(a) * tilt, 0, -cos(a) * tilt), 4)
		leaf.scale = Vector3(1, 1, 0.35)

	# Desk lamp.
	var lamp := Node3D.new()
	lamp.position = Vector3(0.7, DESK_Y, -0.22)
	add_child(lamp)
	var lamp_mat := Props.mat(Color("#2f3b35"), 0.35, 0.5)
	Props.cylinder(lamp, 0.07, 0.08, 0.02, lamp_mat, Vector3(0, 0.01, 0))
	Props.cylinder(lamp, 0.008, 0.008, 0.4, lamp_mat, Vector3(0, 0.21, 0))
	Props.sphere(lamp, 0.016, lamp_mat, Vector3(0, 0.41, 0))
	Props.cylinder(lamp, 0.008, 0.008, 0.26, lamp_mat, Vector3(-0.11, 0.44, 0), Vector3(0, 0, PI / 2.6))
	Props.cylinder(lamp, 0.02, 0.06, 0.09, lamp_mat, Vector3(-0.23, 0.44, 0), Vector3(0, 0, 0.5))
	Props.sphere(lamp, 0.02, Props.unshaded(Color("#fff3c4")), Vector3(-0.235, 0.41, 0))
	var spot := SpotLight3D.new()
	spot.light_color = Color("#ffd9a0")
	spot.light_energy = 3.0
	spot.spot_range = 3.0
	spot.spot_angle = 42.0
	spot.spot_attenuation = 1.0
	spot.shadow_enabled = true
	var spot_pos := Vector3(0.7 - 0.235, DESK_Y + 0.4, -0.22)
	spot.transform = Transform3D(Basis(), spot_pos).looking_at(Vector3(0.25, DESK_Y, 0.05), Vector3.UP)
	add_child(spot)


func _build_cartridges() -> void:
	var projects: Array = data.get("projects", [])
	var count := clampi(projects.size(), 1, 8)
	var spacing := 0.075
	var rack_x := 0.42
	Props.box(self, Vector3(count * spacing + 0.04, 0.03, 0.1), Props.mat(Color("#26282a")), Vector3(rack_x, DESK_Y + 0.015, -0.02))
	for i in mini(projects.size(), 8):
		var project: Dictionary = projects[i]
		var cart := Node3D.new()
		cart.position = Vector3(rack_x - (count - 1) * spacing / 2.0 + i * spacing, DESK_Y + 0.025, -0.02)
		cart.rotation.y = -0.25
		add_child(cart)
		var shell := Props.mat(Color(CART_COLORS[i % CART_COLORS.size()]), 0.5)
		var sticker := Props.mat(Color("#f2efe4"), 0.6)
		Props.box(cart, Vector3(0.06, 0.08, 0.016), shell, Vector3(0, 0.04, 0))
		Props.box(cart, Vector3(0.06, 0.012, 0.02), shell, Vector3(0, 0.074, 0))
		Props.box(cart, Vector3(0.05, 0.05, 0.002), sticker, Vector3(0, 0.045, 0.008))
		var title := str(project.get("title", "")).trim_prefix("[").trim_suffix("]")
		Props.label(cart, title, font, Color("#1a1a1a"), Vector3(0, 0.05, 0.0095), 0.00009, 64, 500.0)
		Props.label(cart, "%02d" % (i + 1), font, Color("#f2efe4"), Vector3(0, 0.012, 0.0085), 0.00012, 64)
		var area := Props.pick_area(cart, Vector3(0.065, 0.09, 0.03), Vector3(0, 0.045, 0))
		picks[area] = {
			"kind": "link",
			"label": str(project.get("title", "")),
			"detail": str(project.get("summary", "")),
			"href": str(project.get("url", "")),
			"node": cart,
			"base_y": cart.position.y,
			"materials": [shell, sticker],
		}


func _build_notebook() -> void:
	var nb := Node3D.new()
	nb.position = Vector3(-0.43, DESK_Y, 0.2)
	nb.rotation.y = 0.35
	add_child(nb)
	var cover := Props.mat(Color("#24302b"), 0.8)
	Props.box(nb, Vector3(0.17, 0.022, 0.23), cover, Vector3(0, 0.011, 0))
	Props.box(nb, Vector3(0.165, 0.016, 0.225), Props.mat(Color("#efeadb"), 0.9), Vector3(0.004, 0.011, 0))
	var spine := Props.mat(ACCENT, 0.7)
	Props.box(nb, Vector3(0.016, 0.0225, 0.23), spine, Vector3(-0.077, 0.011, 0))
	Props.label(nb, "ABOUT\nME", font, ACCENT, Vector3(0.005, 0.0231, -0.02), 0.0006, 48, 0.0, Vector3(-PI / 2.0, 0, 0))
	Props.label(nb, str(data.get("name", "")), font, Color("#9fb88a"), Vector3(0.005, 0.0231, 0.06), 0.0004, 36, 0.0, Vector3(-PI / 2.0, 0, 0))
	var area := Props.pick_area(nb, Vector3(0.18, 0.04, 0.24), Vector3(0, 0.015, 0))
	var pages: Dictionary = data.get("pages", {})
	picks[area] = {
		"kind": "link",
		"label": "About me",
		"detail": "Experience, education and skills.",
		"href": str(pages.get("about", "/about/")),
		"node": nb,
		"base_y": nb.position.y,
		"materials": [cover, spine],
	}


func _build_contact() -> void:
	var holder := Node3D.new()
	holder.position = Vector3(0.7, DESK_Y, 0.25)
	holder.rotation.y = -0.4
	add_child(holder)
	var holder_mat := Props.mat(Color("#26282a"), 0.4, 0.4)
	var card_mat := Props.mat(Color("#f2efe4"), 0.7)
	Props.box(holder, Vector3(0.1, 0.02, 0.05), holder_mat, Vector3(0, 0.01, 0))
	var card := Node3D.new()
	card.position = Vector3(0, 0.045, -0.005)
	card.rotation.x = -0.35
	holder.add_child(card)
	Props.box(card, Vector3(0.09, 0.052, 0.001), card_mat, Vector3.ZERO)
	Props.label(card, str(data.get("name", "")), font, Color("#1a1a1a"), Vector3(0, 0.012, 0.001), 0.00022, 40)
	Props.label(card, "CONTACT >", font, Color("#3b6e9e"), Vector3(0, -0.012, 0.001), 0.00018, 36)
	var area := Props.pick_area(holder, Vector3(0.1, 0.08, 0.06), Vector3(0, 0.04, 0))
	picks[area] = {
		"kind": "command",
		"command": "contact",
		"label": "Contact",
		"detail": "Email, GitHub and LinkedIn.",
		"node": holder,
		"base_y": holder.position.y,
		"materials": [card_mat, holder_mat],
	}


# ---------- UI ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = Color(0, 0, 0, 0.75)
	button_style.border_color = Color("#3a5a14")
	button_style.set_border_width_all(1)
	button_style.set_content_margin_all(8)
	var button_hover := button_style.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color("#1d2a10")
	for state in ["normal", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", button_style)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_hover)
	theme.set_color("font_color", "Button", ACCENT)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.04, 0.01, 0.92)
	panel_style.border_color = Color("#3a5a14")
	panel_style.set_border_width_all(1)
	panel_style.set_content_margin_all(10)
	theme.set_stylebox("panel", "PanelContainer", panel_style)
	ui_root.theme = theme
	layer.add_child(ui_root)

	# Tooltip.
	tooltip = PanelContainer.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.visible = false
	var tip_box := VBoxContainer.new()
	tip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(tip_box)
	tooltip_title = Label.new()
	tooltip_title.add_theme_color_override("font_color", ACCENT)
	tip_box.add_child(tooltip_title)
	tooltip_detail = Label.new()
	tooltip_detail.add_theme_color_override("font_color", Color("#dddddd"))
	tooltip_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_detail.custom_minimum_size = Vector2(260, 0)
	tip_box.add_child(tooltip_detail)
	ui_root.add_child(tooltip)

	# Bottom area: hint, and command buttons while using the terminal.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	ui_root.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	hint = Label.new()
	var touch := DisplayServer.is_touchscreen_available()
	hint.text = ("Drag to look around · Tap the monitor for the terminal · Tap a cartridge to open a project" if touch
		else "Drag to look around · Click the monitor to use the terminal · Click a cartridge to open a project")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("#cccccc"))
	hint.add_theme_stylebox_override("normal", panel_style)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(hint)

	# Command buttons shown while using the terminal.
	term_bar = HFlowContainer.new()
	term_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	term_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	term_bar.add_theme_constant_override("h_separation", 6)
	term_bar.add_theme_constant_override("v_separation", 6)
	term_bar.visible = false
	for cmd in ["help", "projects", "about", "experience", "contact"]:
		var b := Button.new()
		b.text = cmd
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_command_button.bind(cmd))
		term_bar.add_child(b)
	var exit_button := Button.new()
	exit_button.text = "exit terminal [esc]"
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.add_theme_color_override("font_color", Color("#cccccc"))
	exit_button.pressed.connect(exit_terminal)
	term_bar.add_child(exit_button)
	column.add_child(term_bar)

	# Hidden text field that receives typing (and opens the phone keyboard).
	line_edit = TermInput.new()
	line_edit.modulate = Color(1, 1, 1, 0)
	line_edit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_edit.context_menu_enabled = false
	line_edit.set("keep_editing_on_text_submit", true)
	line_edit.text_changed.connect(_on_text_changed)
	line_edit.text_submitted.connect(_on_text_submitted)
	line_edit.special_key.connect(_on_special_key)
	ui_root.add_child(line_edit)


func _layout_ui() -> void:
	var vp := get_viewport().get_visible_rect().size
	hint.custom_minimum_size = Vector2(minf(vp.x - 32.0, 760.0), 0)
	line_edit.position = Vector2(0, vp.y - 40)
	line_edit.size = Vector2(40, 30)


func _hide_hint() -> void:
	if hint_hidden:
		return
	hint_hidden = true
	create_tween().tween_property(hint, "modulate:a", 0.0, 0.6)


# ---------- camera ----------

func _orbit_transform() -> Transform3D:
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	return Transform3D(Basis(), orbit_target + offset).looking_at(orbit_target, Vector3.UP)


func _screen_transform() -> Transform3D:
	var pos := screen.global_position
	var normal := screen.global_basis.z.normalized()
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_v := deg_to_rad(camera.fov) / 2.0
	var d_h := (SCREEN_SIZE.y / 2.0) / tan(half_v)
	var d_w := (SCREEN_SIZE.x / 2.0) / (tan(half_v) * aspect)
	var d := maxf(d_h, d_w) * 1.12 + 0.02
	return Transform3D(Basis(), pos + normal * d).looking_at(pos, Vector3.UP)


func _home_distance() -> float:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0)
	var half_h := atan(tan(deg_to_rad(camera.fov) / 2.0) * aspect)
	return maxf(1.85, 0.8 / tan(half_h) + 0.05)


func _on_resized() -> void:
	max_dist = maxf(2.7, _home_distance() + 0.5)
	want_dist = clampf(want_dist, 0.7, max_dist)
	_layout_ui()
	if mode == Mode.FOCUS:
		camera.global_transform = _screen_transform()


func enter_terminal() -> void:
	if mode == Mode.FOCUS:
		line_edit.grab_focus()
		return
	if mode == Mode.TWEEN:
		return
	_hide_hint()
	_set_hover(null)
	mode = Mode.TWEEN
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_transform", _screen_transform(), 0.9)
	tw.finished.connect(func() -> void: mode = Mode.FOCUS)
	term_bar.visible = true
	hint.visible = false
	line_edit.text = term.input_text
	line_edit.grab_focus()
	line_edit.caret_column = line_edit.text.length()


func exit_terminal() -> void:
	if mode != Mode.FOCUS:
		return
	mode = Mode.TWEEN
	term_bar.visible = false
	line_edit.release_focus()
	yaw = want_yaw
	pitch = want_pitch
	dist = want_dist
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_transform", _orbit_transform(), 0.9)
	tw.finished.connect(func() -> void: mode = Mode.ORBIT)


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				press_pos = mb.position
				dragging = mode == Mode.ORBIT
			else:
				dragging = false
				if mb.position.distance_to(press_pos) < 6.0:
					_click(mb.position)
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var up := mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if mode == Mode.ORBIT:
				want_dist = clampf(want_dist * (0.92 if up else 1.08), 0.7, max_dist)
			elif mode == Mode.FOCUS:
				term.scroll_by(3 if up else -3)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if dragging and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if mm.position.distance_to(press_pos) > 6.0:
				_hide_hint()
				_set_hover(null)
			want_yaw = clampf(want_yaw - mm.relative.x * 0.005, -0.9, 0.9)
			want_pitch = clampf(want_pitch + mm.relative.y * 0.004, 0.02, 1.0)
		elif mode == Mode.ORBIT:
			_hover(mm.position)
	elif event is InputEventKey and mode == Mode.ORBIT:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.unicode >= 32 and not (key.ctrl_pressed or key.meta_pressed or key.alt_pressed):
			# Start typing anywhere to jump into the terminal.
			enter_terminal()
			line_edit.text = term.input_text + char(key.unicode)
			line_edit.caret_column = line_edit.text.length()
			_on_text_changed(line_edit.text)
			get_viewport().set_input_as_handled()


func _raycast(screen_pos: Vector2) -> Dictionary:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 20.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	return get_world_3d().direct_space_state.intersect_ray(query)


func _hover(screen_pos: Vector2) -> void:
	var hit := _raycast(screen_pos)
	var area: Area3D = hit.get("collider") as Area3D if not hit.is_empty() else null
	if area != null and not picks.has(area):
		area = null
	_set_hover(area)
	if hovered != null:
		var info: Dictionary = picks[hovered]
		tooltip_title.text = str(info.get("label", ""))
		tooltip_detail.text = str(info.get("detail", ""))
		tooltip_detail.visible = tooltip_detail.text != ""
		tooltip.visible = true
		tooltip.reset_size()
		var vp := get_viewport().get_visible_rect().size
		var tip := tooltip.get_combined_minimum_size()
		tooltip.position = Vector2(minf(screen_pos.x + 16.0, vp.x - tip.x - 8.0), minf(screen_pos.y + 16.0, vp.y - tip.y - 8.0))
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		tooltip.visible = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _set_hover(area: Area3D) -> void:
	if hovered == area:
		return
	if hovered != null:
		_highlight(picks[hovered], false)
	hovered = area
	if hovered != null:
		_highlight(picks[hovered], true)
	else:
		tooltip.visible = false


func _highlight(info: Dictionary, on: bool) -> void:
	for m: StandardMaterial3D in info.get("materials", []):
		m.emission_enabled = on
		m.emission = Color("#3a5a14")
	info["lift"] = 0.02 if on else 0.0


func _click(screen_pos: Vector2) -> void:
	_hide_hint()
	var hit := _raycast(screen_pos)
	var area: Area3D = hit.get("collider") as Area3D if not hit.is_empty() else null

	if mode == Mode.FOCUS:
		if area == monitor_area:
			var link := _screen_link(hit.get("position", Vector3.ZERO))
			if link != "":
				_navigate(link)
			else:
				line_edit.grab_focus()
		else:
			exit_terminal()
		return
	if mode != Mode.ORBIT or area == null or not picks.has(area):
		return
	var info: Dictionary = picks[area]
	match str(info.get("kind", "")):
		"monitor":
			enter_terminal()
		"command":
			enter_terminal()
			term.run_visible(str(info.get("command", "")))
		"link":
			_navigate(str(info.get("href", "")))


## Terminal link under a world-space point on the monitor, if any.
func _screen_link(world_pos: Vector3) -> String:
	var local := screen.to_local(world_pos)
	var u := local.x / SCREEN_SIZE.x + 0.5
	var v := 0.5 - local.y / SCREEN_SIZE.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return ""
	return term.link_at(Vector2(u * TERM_PIXELS.x, v * TERM_PIXELS.y))


func _on_text_changed(text: String) -> void:
	term.set_input(text)
	if line_edit.text != term.input_text:
		line_edit.text = term.input_text
		line_edit.caret_column = line_edit.text.length()
	press_key(text.ends_with(" "))


func _on_text_submitted(_text: String) -> void:
	term.submit()
	line_edit.text = ""
	press_key(true)
	if line_edit.has_method("edit"):
		line_edit.call("edit")
	line_edit.grab_focus()


func _on_special_key(key: Key) -> void:
	match key:
		KEY_UP:
			line_edit.text = term.history_step(-1)
		KEY_DOWN:
			line_edit.text = term.history_step(1)
		KEY_TAB:
			line_edit.text = term.complete()
		KEY_PAGEUP:
			term.scroll_by(10)
		KEY_PAGEDOWN:
			term.scroll_by(-10)
		KEY_ESCAPE:
			exit_terminal()
	line_edit.caret_column = line_edit.text.length()


func _on_command_button(cmd: String) -> void:
	term.run_visible(cmd)
	line_edit.text = ""
	press_key(true)
	line_edit.grab_focus()


# ---------- per frame ----------

func _process(delta: float) -> void:
	if mode == Mode.ORBIT:
		var k := 1.0 - exp(-delta * 8.0)
		yaw = lerpf(yaw, want_yaw, k)
		pitch = lerpf(pitch, want_pitch, k)
		dist = lerpf(dist, want_dist, k)
		camera.global_transform = _orbit_transform()

	for info: Dictionary in picks.values():
		var node: Node3D = info.get("node") as Node3D
		if node == null:
			continue
		var target := float(info.get("base_y", 0.0)) + float(info.get("lift", 0.0))
		node.position.y = lerpf(node.position.y, target, 0.2)

	for i: int in pressed.keys():
		var age: float = pressed[i] + delta
		keys[i].position.y = key_rest[i] - (0.006 if age < 0.12 else 0.0)
		if age >= 0.12:
			pressed.erase(i)
		else:
			pressed[i] = age


# ---------- page integration ----------

func _navigate(url: String) -> void:
	if url == "":
		return
	if OS.has_feature("web"):
		var js_url := JSON.stringify(url)
		JavaScriptBridge.eval("window.parent.deskNavigate ? window.parent.deskNavigate(%s) : (window.top.location.href = %s)" % [js_url, js_url])
	else:
		OS.shell_open(url)


func _text_view() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.parent.deskSetView && window.parent.deskSetView('text')")
