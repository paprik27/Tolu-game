# map_select.gd
# The map select screen (scenes/map_select.tscn).
# Either player scrolls between the three maps, and either player's punch key picks one.
# Then the fight starts (scenes/main.tscn).
extends Node2D

const RosterScript = preload("res://scripts/roster.gd")

# ---- Layout settings (in pixels) ----
const CARD_W := 300.0   # width of one map card
const CARD_H := 300.0   # height of one map card
const CARD_GAP := 40.0  # space between cards
const CARD_Y := 200.0   # distance from the top of the screen to the cards

# The background color of each map card, as a quick preview of the map
const MAP_COLORS := [
	Color(0.3, 0.3, 0.33),   # classic: dark grey, like the arena floor
	Color(0.98, 0.7, 0.45),  # Thailand: sunset orange
	Color(0.18, 0.2, 0.23),  # elevator: dark steel
]

# ---- Runtime state ----
var count := 0            # how many maps there are
var cursor := 0           # which map is highlighted
var highlights: Array = [] # the white frame behind each card (only the highlighted one is shown)
var status: Label         # the text at the bottom of the screen
var confirmed := false    # true once a map is picked, so we don't run twice

# Runs once when the scene opens: builds the screen
func _ready():
	RosterScript.bind_input()
	count = RosterScript.MAP_NAMES.size()

	# Title at the top
	var title := Label.new()
	title.text = "PICK A MAP"
	title.position = Vector2(0, 80)
	title.size = Vector2(1152, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	add_child(title)

	# Work out where the first card starts so all the cards are centered
	var total := count * CARD_W + (count - 1) * CARD_GAP
	var start_x := (1152.0 - total) / 2.0
	for i in count:
		var x := start_x + i * (CARD_W + CARD_GAP)

		# White frame behind the card, shown only on the highlighted map
		var frame := ColorRect.new()
		frame.position = Vector2(x - 8, CARD_Y - 8)
		frame.size = Vector2(CARD_W + 16, CARD_H + 16)
		frame.color = Color.WHITE
		add_child(frame)
		highlights.append(frame)

		# The colored card itself
		var card := ColorRect.new()
		card.position = Vector2(x, CARD_Y)
		card.size = Vector2(CARD_W, CARD_H)
		card.color = MAP_COLORS[i]
		add_child(card)

		# Map name at the top of the card
		var name_label := Label.new()
		name_label.text = RosterScript.MAP_NAMES[i]
		name_label.position = Vector2(x, CARD_Y + 20)
		name_label.size = Vector2(CARD_W, 40)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 26)
		add_child(name_label)

		# Short description near the bottom of the card, wrapped onto two lines if needed
		var desc_label := Label.new()
		desc_label.text = RosterScript.MAP_DESCRIPTIONS[i]
		desc_label.position = Vector2(x + 10, CARD_Y + CARD_H - 60)
		desc_label.size = Vector2(CARD_W - 20, 50)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		add_child(desc_label)

	# Status text at the bottom
	status = Label.new()
	status.position = Vector2(0, 560)
	status.size = Vector2(1152, 40)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	add_child(status)

	_refresh()

# Runs every frame: reads the keyboard
func _process(_delta):
	if confirmed:
		return  # a map is already picked, ignore more input
	# Either player can move right or left (wrapping around at the ends)
	if Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right"):
		cursor = (cursor + 1) % count
	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left"):
		cursor = (cursor - 1 + count) % count
	# Either player's punch key picks the highlighted map
	if Input.is_action_just_pressed("p1_punch") or Input.is_action_just_pressed("p2_punch"):
		_confirm()
	_refresh()

# Escape goes back to fighter select
func _input(event):
	if event.is_action_pressed("ui_cancel") and not confirmed:
		get_tree().change_scene_to_file("res://scenes/select.tscn")

# Shows the white frame only on the highlighted map and updates the status text
func _refresh():
	for i in count:
		highlights[i].visible = (i == cursor)
	status.text = "Map: %s   (A/D or arrows to scroll, J or K to choose)" % RosterScript.MAP_NAMES[cursor]

# Saves the chosen map, waits half a second, then starts the fight
func _confirm():
	confirmed = true
	RosterScript.map_choice = cursor
	status.text = "FIGHT!"
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/main.tscn")
