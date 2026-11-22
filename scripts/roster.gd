# roster.gd
# Shared settings for the whole game: the list of fighters and maps, what each player
# picked, and the keyboard controls. Every other script loads this file with preload().
#
# "extends RefCounted" means this is a plain data holder. Nothing gets added to the scene.
extends RefCounted

# ---- Fighter list ----------------------------------------------------------
# Names shown on the select screen. The list order must match COLORS below.
# Rename a fighter here and it changes everywhere.
const NAMES := [
	"Fighter 1", "Fighter 2", "Fighter 3", "Fighter 4", "Fighter 5",
	"Fighter 6", "Fighter 7", "Fighter 8", "Fighter 9", "Fighter 10",
]
# The body color of each fighter. All fighters use the same figure, only the color changes.
const COLORS := [
	Color.CORNFLOWER_BLUE, Color.INDIAN_RED, Color.LIME_GREEN, Color.GOLD, Color.MEDIUM_PURPLE,
	Color.ORANGE, Color.TURQUOISE, Color.HOT_PINK, Color.SADDLE_BROWN, Color.SILVER,
]

# ---- Map list --------------------------------------------------------------
# The maps in order. The index numbers used in main.gd are:
# 0 = classic arena, 1 = endless Thailand, 2 = elevator.
const MAP_NAMES := ["Classic Arena", "Endless Thailand", "Elevator"]
const MAP_DESCRIPTIONS := ["The original arena", "A sunset temple that never ends", "A small room with walls"]

# ---- Choices made during the menus -----------------------------------------
# "static var" means the value is shared by the whole game and survives scene changes.
# select.gd writes the fighter choices, map_select.gd writes the map choice,
# and main.gd reads all three when the fight starts.
static var p1_choice := 0   # index into NAMES/COLORS for player 1
static var p2_choice := 1   # index into NAMES/COLORS for player 2
static var map_choice := 0  # index into MAP_NAMES for the map

# Connects the keyboard keys to named "actions" like "p1_punch".
# Other scripts check actions (for example Input.is_action_just_pressed("p1_punch"))
# so changing a key here changes it everywhere in the game.
# Called at the start of every scene, and it is safe to call more than once.
static func bind_input():
	_bind("p1_left", [KEY_A])
	_bind("p1_right", [KEY_D])
	_bind("p1_jump", [KEY_W])
	_bind("p1_punch", [KEY_J])
	_bind("p1_kick", [KEY_N])
	_bind("p2_left", [KEY_LEFT])
	_bind("p2_right", [KEY_RIGHT])
	_bind("p2_jump", [KEY_UP])
	_bind("p2_punch", [KEY_K])
	_bind("p2_kick", [KEY_M])

# Creates an action (if it doesn't exist yet) and gives it the keys in the list.
# It only adds keys when the action has none, so calling it twice doesn't duplicate them.
static func _bind(action: String, keys: Array):
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if InputMap.action_get_events(action).is_empty():
		for key in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = key  # physical_keycode means the key position, not the letter
			InputMap.action_add_event(action, ev)
