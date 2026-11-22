# select.gd
# The character select screen (scenes/select.tscn).
# Two players scroll through the 10 fighters and lock in with their punch key.
# When both are locked, the game goes to the map select screen.
extends Node2D

const RosterScript = preload("res://scripts/roster.gd")
const FigureScript = preload("res://scripts/figure.gd")

# ---- Layout settings (in pixels) ----
# Fighter cards along the bottom
const CARD_W := 96.0     # width of one card
const CARD_H := 120.0    # height of one card
const CARD_GAP := 12.0   # space between cards
const CARD_Y := 390.0    # distance from the top of the screen to the cards

# Big preview panels at the top, one for each player
const PREVIEW_Y := 90.0                 # distance from the top to the panels
const PREVIEW_W := 300.0                # width of a panel
const PREVIEW_H := 280.0                # height of a panel
const PREVIEW_X := [150.0, 702.0]       # left edge of the P1 panel and the P2 panel
const PREVIEW_SCALE := 2.0              # how big the preview figure is drawn

# ---- Runtime state ----
var count := 0                # how many fighters there are
var start_x := 0.0            # x position of the first card (cards are centered)
var cursor := [0, 0]          # which fighter P1 and P2 are pointing at
var shown := [-1, -1]         # which fighter each preview is showing right now (-1 = none yet)
var locked := [false, false]  # true when that player has picked their fighter
var markers: Array = []       # the colored bars under the cards that show each player's position
var previews: Array = []      # the holder node of each preview figure (so we can delete it later)
var preview_names: Array = [] # the name label under each preview
var status: Label             # the text at the bottom of the screen
var starting := false         # true once both players are locked, so we don't run twice

# Runs once when the scene opens: builds the screen
func _ready():
	RosterScript.bind_input()
	count = RosterScript.COLORS.size()

	# Title at the top
	var title := Label.new()
	title.text = "PICK YOUR FIGHTER"
	title.position = Vector2(0, 20)
	title.size = Vector2(1152, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)

	_build_previews()
	_build_cards()

	# One marker per player, under the card they are on.
	# Player 1 is blue and player 2 is red.
	markers.append(_marker(Color.CORNFLOWER_BLUE, CARD_Y + CARD_H + 10))
	markers.append(_marker(Color.INDIAN_RED, CARD_Y + CARD_H + 26))

	# Status text at the bottom
	status = Label.new()
	status.position = Vector2(0, 580)
	status.size = Vector2(1152, 40)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 22)
	add_child(status)

	_refresh()

# Creates the two big preview panels, their name labels, and the "VS" text
func _build_previews():
	for p in 2:
		var x: float = PREVIEW_X[p]
		# The dark background box. Later you can replace it with a TextureRect for fighter pictures.
		var panel := ColorRect.new()
		panel.position = Vector2(x, PREVIEW_Y)
		panel.size = Vector2(PREVIEW_W, PREVIEW_H)
		panel.color = Color(0.15, 0.15, 0.18)
		add_child(panel)

		# The fighter name shown at the bottom of the panel
		var name_label := Label.new()
		name_label.position = Vector2(x, PREVIEW_Y + PREVIEW_H - 40)
		name_label.size = Vector2(PREVIEW_W, 36)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 24)
		add_child(name_label)
		preview_names.append(name_label)

		previews.append(null)  # nothing shown yet; _set_preview fills this in

	# The big "VS" between the two panels
	var vs := Label.new()
	vs.text = "VS"
	vs.position = Vector2(450, 170)
	vs.size = Vector2(252, 120)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.add_theme_font_size_override("font_size", 96)
	add_child(vs)

# Creates one colored card per fighter, centered on the screen
func _build_cards():
	# Work out how wide all the cards are together, then find where the first one starts
	var total := count * CARD_W + (count - 1) * CARD_GAP
	start_x = (1152.0 - total) / 2.0
	for i in count:
		var x := start_x + i * (CARD_W + CARD_GAP)
		var card := ColorRect.new()
		card.position = Vector2(x, CARD_Y)
		card.size = Vector2(CARD_W, CARD_H)
		card.color = RosterScript.COLORS[i]
		add_child(card)

		# The name shown at the top of the card
		var name_label := Label.new()
		name_label.text = RosterScript.NAMES[i]
		name_label.position = Vector2(x, CARD_Y + 8)
		name_label.size = Vector2(CARD_W, 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(name_label)

# Creates one player marker bar. It moves under the cards as the player scrolls.
func _marker(color: Color, y: float) -> ColorRect:
	var m := ColorRect.new()
	m.size = Vector2(CARD_W, 10)
	m.position = Vector2(start_x, y)
	m.color = color
	add_child(m)
	return m

# Runs every frame: reads the keyboard and updates the screen
func _process(_delta):
	if starting:
		return  # the fight is already starting, ignore more input
	for p in 2:
		var prefix := "p%d_" % (p + 1)  # "p1_" or "p2_", matching the action names
		if locked[p]:
			# Jump cancels your selection, so you can change your mind
			if Input.is_action_just_pressed(prefix + "jump"):
				locked[p] = false
		else:
			# Move the cursor right or left, wrapping from the last fighter back to the first
			if Input.is_action_just_pressed(prefix + "right"):
				cursor[p] = (cursor[p] + 1) % count
			if Input.is_action_just_pressed(prefix + "left"):
				cursor[p] = (cursor[p] - 1 + count) % count
			# Punch locks in the fighter
			if Input.is_action_just_pressed(prefix + "punch"):
				locked[p] = true
	_refresh()
	# Both players are ready: move on to the map select screen
	if locked[0] and locked[1]:
		_start_map_select()

# Updates the markers, the previews, and the status text to match the current state
func _refresh():
	for p in 2:
		markers[p].position.x = start_x + cursor[p] * (CARD_W + CARD_GAP)
		# A locked player's marker is fully bright, otherwise it is faded
		markers[p].modulate = Color.WHITE if locked[p] else Color(1, 1, 1, 0.4)
		# Only rebuild the preview when the cursor actually moved
		if shown[p] != cursor[p]:
			shown[p] = cursor[p]
			_set_preview(p)
	status.text = "P1: %s %s     P2: %s %s" % [
		RosterScript.NAMES[cursor[0]], "(ready)" if locked[0] else "(press J)",
		RosterScript.NAMES[cursor[1]], "(ready)" if locked[1] else "(press K)",
	]

# Replaces the preview figure in one panel with the currently highlighted fighter
func _set_preview(p: int):
	# Delete the old preview first
	if previews[p] != null:
		previews[p].queue_free()

	# A holder node sets where the figure is and which way it faces.
	# The figure inside is drawn at the holder's origin.
	var holder := Node2D.new()
	holder.position = Vector2(PREVIEW_X[p] + PREVIEW_W / 2.0, PREVIEW_Y + PREVIEW_H / 2.0 - 20)
	# P1 looks right, P2 looks left. A negative x scale mirrors the figure.
	holder.scale = Vector2(PREVIEW_SCALE if p == 0 else -PREVIEW_SCALE, PREVIEW_SCALE)
	var figure := Node2D.new()
	figure.set_script(FigureScript)  # gives the node the drawing and animation code
	figure.setup(RosterScript.COLORS[cursor[p]])
	holder.add_child(figure)
	add_child(holder)
	previews[p] = holder

	preview_names[p].text = RosterScript.NAMES[cursor[p]]

# Saves both choices, waits half a second, then opens the map select screen
func _start_map_select():
	starting = true
	RosterScript.p1_choice = cursor[0]
	RosterScript.p2_choice = cursor[1]
	status.text = "Pick a map..."
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/map_select.tscn")
