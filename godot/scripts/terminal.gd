class_name DeskTerminal
extends Control
## A small terminal drawn with _draw(). It lives in a SubViewport whose texture
## is shown on the desk monitor. main.gd feeds it text and keystrokes.

signal navigate_requested(url: String)
signal exit_requested
signal text_view_requested

const PROMPT := "lin@desk:~$ "
const C_TEXT := Color("#d6f5b0")
const C_GREEN := Color("#b5e853")
const C_DIM := Color("#6f8f3a")
const C_LINK := Color("#63c0f5")
const C_ERROR := Color("#ff7b6b")
const C_WHITE := Color("#f2f2f2")
const C_BG := Color("#050a03")
const MAX_LINES := 400

var data: Dictionary = {}
var font: Font
var font_size := 22
var line_height := 28
var pad := 36
var char_width := 13.0
var cols := 70
var rows := 24

var lines: Array[Dictionary] = []
var queue: Array[Dictionary] = []
var input_text := ""
var history: PackedStringArray = []
var history_index := 0
var scroll := 0
var link_rects: Array[Dictionary] = []
var cursor_on := true
var _blink := 0.0
var _type_timer := 0.0


func setup(p_data: Dictionary, p_font: Font, p_size: Vector2) -> void:
	data = p_data
	font = p_font
	size = p_size
	char_width = font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	cols = int((size.x - pad * 2) / char_width)
	rows = int((size.y - pad * 2) / line_height)
	boot()


func _process(delta: float) -> void:
	var changed := false
	if not queue.is_empty():
		_type_timer += delta
		if _type_timer > 0.022:
			_type_timer = 0.0
			var n := 1
			if queue.size() > 30:
				n = 4
			elif queue.size() > 10:
				n = 2
			for i in n:
				if queue.is_empty():
					break
				lines.append(queue.pop_front())
			_trim()
			scroll = 0
			changed = true
	_blink += delta
	if _blink > 0.53:
		_blink = 0.0
		cursor_on = not cursor_on
		changed = true
	if changed:
		queue_redraw()


# ---------- output ----------

func out(text: String = "", color: Color = C_TEXT, href: String = "") -> void:
	for piece in _wrap(text):
		queue.append({"text": piece, "color": color, "href": href})


func _wrap(text: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var rest := text
	while rest.length() > cols:
		var cut := rest.rfind(" ", cols)
		if cut <= 0:
			cut = cols
		result.append(rest.substr(0, cut))
		rest = "  " + rest.substr(cut).strip_edges(true, false)
	result.append(rest)
	return result


func flush() -> void:
	lines.append_array(queue)
	queue.clear()
	_trim()
	queue_redraw()


func _trim() -> void:
	while lines.size() > MAX_LINES:
		lines.pop_front()


func is_busy() -> bool:
	return not queue.is_empty()


# ---------- input ----------

func set_input(value: String) -> void:
	input_text = value.replace("\n", "").replace("\r", "").left(cols - PROMPT.length() - 1)
	scroll = 0
	queue_redraw()


func submit() -> void:
	var raw := input_text.strip_edges()
	if is_busy():
		flush()
	lines.append({"text": PROMPT + input_text, "color": C_WHITE, "href": ""})
	input_text = ""
	scroll = 0
	if raw != "":
		history.append(raw)
		history_index = history.size()
		run(raw)
	queue_redraw()


func run_visible(command: String) -> void:
	set_input(command)
	submit()


func history_step(direction: int) -> String:
	if history.is_empty():
		return input_text
	history_index = clampi(history_index + direction, 0, history.size())
	input_text = history[history_index] if history_index < history.size() else ""
	queue_redraw()
	return input_text


func complete() -> String:
	var word := input_text.strip_edges().to_lower()
	if word == "" or word.contains(" "):
		return input_text
	var matches: PackedStringArray = []
	for c in _command_names():
		if c.begins_with(word):
			matches.append(c)
	if matches.size() == 1:
		input_text = matches[0] + " "
	elif matches.size() > 1:
		lines.append({"text": PROMPT + input_text, "color": C_WHITE, "href": ""})
		out("  ".join(matches), C_DIM)
	queue_redraw()
	return input_text


func scroll_by(amount: int) -> void:
	var max_scroll := maxi(0, lines.size() - (rows - 1))
	scroll = clampi(scroll + amount, 0, max_scroll)
	queue_redraw()


# ---------- commands ----------

const HELP := [
	["help", "list commands"],
	["about", "who I am"],
	["projects", "list projects"],
	["open", "open a project, e.g. open 1"],
	["experience", "work history"],
	["education", "where I studied"],
	["skills", "what I work with"],
	["contact", "ways to reach me"],
	["clear", "clear the screen"],
	["text", "switch to the plain text site"],
	["exit", "step back from the desk"],
]


func _command_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for h in HELP:
		names.append(h[0])
	for extra in ["email", "github", "linkedin", "resume"]:
		if _link(extra) != "":
			names.append(extra)
	return names


func _link(key: String) -> String:
	var links: Dictionary = data.get("links", {})
	var value = links.get(key)
	return value if value is String else ""


func run(line: String) -> void:
	var parts := line.split(" ", false)
	var cmd := parts[0].to_lower()
	var arg := " ".join(parts.slice(1))
	match cmd:
		"help":
			_help()
		"about", "whoami":
			_about()
		"projects", "ls":
			_projects()
		"open":
			_open(arg)
		"experience":
			_experience()
		"education":
			_education()
		"skills":
			_skills()
		"contact":
			_contact()
		"email":
			var email := _link("email")
			_go("mailto:" + email if email != "" else "", "email")
		"github", "linkedin", "resume":
			_go(_link(cmd), cmd)
		"clear":
			lines.clear()
			queue.clear()
		"text":
			text_view_requested.emit()
		"exit":
			exit_requested.emit()
		"date":
			out(Time.get_datetime_string_from_system(false, true))
		"echo":
			out(arg)
		"sudo":
			out("Nice try. This incident will be reported.", C_ERROR)
		"cd":
			out("There's nowhere else to go. Try `projects`.", C_DIM)
		_:
			out("command not found: %s. Type `help` for a list." % cmd, C_ERROR)


func boot() -> void:
	out("DESK-OS 1.0  (c) %d %s  [godot build]" % [Time.get_date_dict_from_system().year, data.get("name", "")], C_DIM)
	out("memory check ........ ok", C_DIM)
	out("loading portfolio ... ok", C_DIM)
	out("")
	out("Hi, I'm %s." % data.get("name", ""), C_GREEN)
	out(str(data.get("role", "")))
	if str(data.get("tagline", "")) != "":
		out(str(data.get("tagline", "")))
	out("")
	out("Type `help` to see what you can do, or `projects` to see my work.", C_DIM)
	out("")


func _help() -> void:
	out("Available commands:", C_GREEN)
	for h in HELP:
		out("  %s%s" % [str(h[0]).rpad(12), h[1]])
	var shortcuts: PackedStringArray = []
	for k in ["email", "github", "linkedin", "resume"]:
		if _link(k) != "":
			shortcuts.append(k)
	if not shortcuts.is_empty():
		out("  %s  open that link" % ", ".join(shortcuts))
	out("Tab completes, Up/Down recall history, Esc leaves the terminal.", C_DIM)


func _about() -> void:
	out(str(data.get("name", "")), C_GREEN)
	out(str(data.get("role", "")))
	if str(data.get("tagline", "")) != "":
		out(str(data.get("tagline", "")))
	var current: Array = []
	for job in data.get("experience", []):
		if str(job.get("end", "")).to_lower() == "present":
			current.append(job)
	if not current.is_empty():
		out("")
		out("Currently:", C_GREEN)
		for job in current:
			out("  %s @ %s" % [job.get("role", ""), job.get("org", "")])
	out("")
	out("> read the full about page", C_LINK, _page("about"))


func _page(key: String) -> String:
	var pages: Dictionary = data.get("pages", {})
	return str(pages.get(key, "/"))


func _projects() -> void:
	var list: Array = data.get("projects", [])
	if list.is_empty():
		out("No projects yet.", C_DIM)
		return
	out("Projects (click one, or type `open <number>`):", C_GREEN)
	for i in list.size():
		var p: Dictionary = list[i]
		out("  [%d] %s" % [i + 1, p.get("title", "")], C_LINK, str(p.get("url", "")))
		if str(p.get("summary", "")) != "":
			out("      " + str(p.get("summary", "")), C_DIM)


func _open(arg: String) -> void:
	var list: Array = data.get("projects", [])
	var project = null
	if arg.is_valid_int():
		var n := arg.to_int()
		if n >= 1 and n <= list.size():
			project = list[n - 1]
	elif arg != "":
		for p in list:
			if str(p.get("title", "")).to_lower().contains(arg.to_lower()):
				project = p
				break
	if project == null:
		out("Usage: open <number>. Type `projects` to list them.", C_ERROR)
		return
	_go(str(project.get("url", "")), str(project.get("title", "")))


func _experience() -> void:
	out("Experience:", C_GREEN)
	for job in data.get("experience", []):
		out("  %s — %s" % [job.get("role", ""), job.get("org", "")], C_WHITE)
		out("    %s – %s" % [job.get("start", ""), job.get("end", "")], C_DIM)
		for point in job.get("points", []):
			out("    - " + str(point))


func _education() -> void:
	out("Education:", C_GREEN)
	for e in data.get("education", []):
		out("  " + str(e.get("qualification", "")), C_WHITE)
		out("    %s, %s – %s" % [e.get("school", ""), e.get("start", ""), e.get("end", "")], C_DIM)


func _skills() -> void:
	out("Skills:", C_GREEN)
	for g in data.get("skills", []):
		var items: PackedStringArray = []
		for item in g.get("items", []):
			items.append(str(item))
		out("  %s: %s" % [g.get("group", ""), ", ".join(items)])


func _contact() -> void:
	out("Get in touch (click a line):", C_GREEN)
	var email := _link("email")
	if email != "":
		out("  email     " + email, C_LINK, "mailto:" + email)
	for key in ["github", "linkedin", "website"]:
		var url := _link(key)
		if url != "":
			out("  %s%s" % [key.rpad(10), url.replace("https://", "").replace("http://", "")], C_LINK, url)
	if _link("resume") != "":
		out("  résumé    " + _link("resume"), C_LINK, _link("resume"))


func _go(href: String, label: String) -> void:
	if href == "":
		out("Not available yet.", C_DIM)
		return
	out("opening %s ..." % label, C_DIM)
	flush()
	get_tree().create_timer(0.25).timeout.connect(func() -> void: navigate_requested.emit(href))


# ---------- drawing ----------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	if font == null:
		return
	var show_prompt := not is_busy()
	var visible_rows := rows - (1 if show_prompt else 0)
	var end_i := lines.size() - scroll
	var start_i := maxi(0, end_i - visible_rows)
	var ascent := font.get_ascent(font_size)
	link_rects.clear()
	var y := float(pad)
	for i in range(start_i, end_i):
		var l: Dictionary = lines[i]
		var text: String = l["text"]
		draw_string(font, Vector2(pad, y + ascent), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, l["color"])
		if l["href"] != "":
			link_rects.append({
				"rect": Rect2(pad - 6, y, char_width * text.length() + 12, line_height),
				"href": l["href"],
			})
		y += line_height
	if show_prompt and scroll == 0:
		var t := PROMPT + input_text
		draw_string(font, Vector2(pad, y + ascent), t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, C_GREEN)
		if cursor_on:
			draw_rect(Rect2(pad + char_width * t.length() + 2, y + 2, char_width, font_size), C_GREEN)
	elif scroll > 0:
		draw_string(font, Vector2(pad, y + ascent), "-- scrolled up %d lines --" % scroll, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, C_DIM)
	# CRT scanlines.
	var scan := Color(0, 0, 0, 0.18)
	for sy in range(0, int(size.y), 3):
		draw_rect(Rect2(0, sy, size.x, 1), scan)


## Link under a point in terminal pixels, or "".
func link_at(point: Vector2) -> String:
	for r in link_rects:
		var rect: Rect2 = r["rect"]
		if rect.has_point(point):
			return r["href"]
	return ""
