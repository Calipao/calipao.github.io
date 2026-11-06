extends LineEdit
## Hidden text field that collects typing for the terminal. It also brings up
## the on-screen keyboard on phones. Keys the terminal handles itself are passed
## on through `special_key` instead of being used by the LineEdit.

signal special_key(key: Key)

const SPECIAL_KEYS := [KEY_UP, KEY_DOWN, KEY_TAB, KEY_PAGEUP, KEY_PAGEDOWN, KEY_ESCAPE]


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and key.keycode in SPECIAL_KEYS:
		special_key.emit(key.keycode)
		accept_event()
