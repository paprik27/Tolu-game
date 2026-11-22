# main.gd
# The fight scene (scenes/main.tscn). This script builds everything in code when the
# scene starts: the map, the camera, both fighters, the health bars, and the win screen.
extends Node2D

const FighterScript = preload("res://scripts/fighter.gd")
const RosterScript = preload("res://scripts/roster.gd")

# ---- Settings (in pixels or seconds) ----
const BAR_WIDTH := 400.0          # width of each health bar at full health
const KO_PAUSE := 1.0             # time to watch the knocked-out fighter fall before the win screen
const WIN_SCREEN_TIME := 3.0      # how long the win screen stays before returning to select
const SCREEN_W := 1152.0          # the game's screen width
const SCREEN_H := 648.0           # the game's screen height
const CLASSIC_WORLD_W := 1800.0   # width of the classic arena (wider than the screen, so the camera moves)
const ENDLESS_LIMIT := 10000000   # a camera limit so large it means "no limit" (endless map)
const KILL_Y := 720.0             # falling below this height loses the round instantly

# ---- Runtime state ----
var fighters: Array = []          # the two fighter nodes, [player 1, player 2]
var health_fills: Array = []      # the green health bar rectangles, [player 1, player 2]
var round_over := false           # true once someone has lost, so we only do this once
var endless := false              # true on the Thailand map: the map has no edges
var sky_root: Node2D              # holds the sky and sun on the Thailand map, kept at the left edge of the view
var scroll_strips: Array = []     # the scenery copies on the Thailand map that repeat and scroll with the camera
var world_w := SCREEN_W           # how wide the map is (used to limit the camera)
var camera: Camera2D              # the camera that follows the fighters

# Runs once when the fight scene opens
func _ready():
	RosterScript.bind_input()
	# The map and the player picks were saved by the menus before this scene opened
	var map_index: int = RosterScript.map_choice
	endless = map_index == 1
	world_w = CLASSIC_WORLD_W if map_index == 0 else SCREEN_W
	_build_map(map_index)

	# Where each fighter starts, depending on the map
	var xs: Array = [300.0, 850.0]
	if map_index == 0:
		xs = [600.0, 1200.0]  # on either side of the pit
	elif map_index == 2:
		xs = [400.0, 750.0]   # the elevator is narrow

	# Create the two fighters. Each one gets its player number, color, and key names.
	_spawn_fighter(1, Vector2(xs[0], 200), RosterScript.COLORS[RosterScript.p1_choice], {
		"left": "p1_left", "right": "p1_right", "jump": "p1_jump",
		"punch": "p1_punch", "kick": "p1_kick",
	})
	_spawn_fighter(2, Vector2(xs[1], 200), RosterScript.COLORS[RosterScript.p2_choice], {
		"left": "p2_left", "right": "p2_right", "jump": "p2_jump",
		"punch": "p2_punch", "kick": "p2_kick",
	})
	# Each fighter needs to know who the opponent is, so it can face them
	fighters[0].opponent = fighters[1]
	fighters[1].opponent = fighters[0]
	_build_camera()
	_build_hud()

# Runs every frame
func _process(delta):
	# Update each health bar so its width matches the fighter's health
	for i in fighters.size():
		var f = fighters[i]
		health_fills[i].size.x = BAR_WIDTH * f.health / f.max_health

	# Camera follows the middle point between the two fighters
	if fighters.size() == 2:
		var mid_x: float = (fighters[0].global_position.x + fighters[1].global_position.x) / 2.0
		camera.global_position = Vector2(mid_x, SCREEN_H / 2.0)

	# On the Thailand map, keep the scenery moving with the camera
	if endless:
		_update_endless_backdrop()

	# Falling below the screen counts as a knockout
	for f in fighters:
		if not f.dead and f.global_position.y > KILL_Y:
			f.health = 0.0
			f.dead = true
			print("Fell off the map!")

	# The first fighter to be knocked out loses the round
	if not round_over:
		for i in fighters.size():
			if fighters[i].dead:
				round_over = true
				_end_round(1 - i)  # the other fighter wins
				break

# Keeps the sky at the left edge of the view, and makes the scenery repeat with a
# slight parallax (it moves at half the camera's speed), so it always fills the screen
func _update_endless_backdrop():
	var view_left := camera.global_position.x - SCREEN_W / 2.0  # left edge of what the camera sees
	sky_root.position.x = view_left
	# fposmod wraps the number into 0 to SCREEN_W, so the repeat happens seamlessly
	var shift := fposmod(view_left * 0.5, SCREEN_W)
	for i in scroll_strips.size():
		scroll_strips[i].position.x = view_left + i * SCREEN_W - shift

# Escape goes back to the fighter select screen (but not during the win screen)
func _input(event):
	if event.is_action_pressed("ui_cancel") and not round_over:
		get_tree().change_scene_to_file("res://scenes/select.tscn")

# Waits for the knockout to play, shows the winner, then goes back to character select
func _end_round(winner_index: int):
	await get_tree().create_timer(KO_PAUSE).timeout
	_show_win_screen(winner_index)
	await get_tree().create_timer(WIN_SCREEN_TIME).timeout
	get_tree().change_scene_to_file("res://scenes/select.tscn")

# Shows a dark overlay with the winner's player number and fighter name
func _show_win_screen(winner_index: int):
	# Pick the name of the winner's fighter
	var winner_name: String = RosterScript.NAMES[RosterScript.p1_choice if winner_index == 0 else RosterScript.p2_choice]

	# A CanvasLayer draws on top of the game and does not move with the camera
	var layer := CanvasLayer.new()
	add_child(layer)

	# Dark, see-through cover over the whole screen
	var dim := ColorRect.new()
	dim.size = Vector2(SCREEN_W, SCREEN_H)
	dim.color = Color(0, 0, 0, 0.6)
	layer.add_child(dim)

	# "PLAYER 1 WINS!" text
	var player_label := Label.new()
	player_label.text = "PLAYER %d WINS!" % (winner_index + 1)
	player_label.position = Vector2(0, 220)
	player_label.size = Vector2(SCREEN_W, 60)
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.add_theme_font_size_override("font_size", 48)
	layer.add_child(player_label)

	# The winner's fighter name, below the text
	var name_label := Label.new()
	name_label.text = winner_name
	name_label.position = Vector2(0, 300)
	name_label.size = Vector2(SCREEN_W, 60)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 40)
	layer.add_child(name_label)

# ---- Camera ----------------------------------------------------------------

# Creates the camera and sets its limits for the current map
func _build_camera():
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true   # the camera glides instead of snapping
	camera.position_smoothing_speed = 5.0      # higher = snappier, lower = smoother
	if endless:
		# No side limits: the map goes on forever
		camera.limit_left = -ENDLESS_LIMIT
		camera.limit_right = ENDLESS_LIMIT
	else:
		# Keep the view inside the map so we never show empty space past the edges
		camera.limit_left = 0
		camera.limit_right = int(world_w)
	camera.limit_top = 0
	camera.limit_bottom = int(SCREEN_H)
	add_child(camera)
	camera.make_current()  # makes this the camera the game actually uses

# ---- Maps -----------------------------------------------------------------

# Calls the right builder for the chosen map (0 = classic, 1 = Thailand, 2 = elevator)
func _build_map(index: int):
	match index:
		1:
			_build_thailand()
		2:
			_build_elevator()
		_:
			_build_classic()

# Classic arena: two floor pieces with a pit in the middle
func _build_classic():
	# The dark red pit visual, drawn behind the floor
	_add_poly(self, _rect_pts(820, 580, 160, 200), Color(0.08, 0.02, 0.02))
	# Left and right floor pieces. The gap between them (x 820 to 980) is the pit.
	_add_solid(Vector2(410, 600), Vector2(820, 40), Color.DARK_GRAY)
	_add_solid(Vector2(1390, 600), Vector2(820, 40), Color.DARK_GRAY)

# Endless Thailand: sunset sky, scrolling temples and hills, and a floor that never ends
func _build_thailand():
	# Sky and sun. They move with the camera (see _update_endless_backdrop).
	sky_root = Node2D.new()
	add_child(sky_root)
	_add_poly(sky_root, _rect_pts(0, 0, SCREEN_W, SCREEN_H), Color(0.98, 0.7, 0.45))
	_add_poly(sky_root, _circle_pts(Vector2(900, 150), 70), Color(1, 0.9, 0.5))

	# Three copies of the same scenery. They are repositioned every frame, so there
	# is always a copy covering the view.
	for i in 3:
		var strip := Node2D.new()
		add_child(strip)
		_fill_scenery(strip)
		scroll_strips.append(strip)

	# A floor so wide it is effectively endless in both directions
	_add_solid(Vector2(0, 600), Vector2(200000, 40), Color(0.55, 0.35, 0.25))

# Draws the hills and temples inside one scenery copy
func _fill_scenery(strip: Node2D):
	# The hills' outline. The first and last points are at the same height,
	# so two copies placed side by side join without a visible seam.
	var hills := PackedVector2Array([
		Vector2(0, 480), Vector2(150, 400), Vector2(300, 450), Vector2(500, 380),
		Vector2(700, 440), Vector2(900, 390), Vector2(SCREEN_W, 480),
		Vector2(SCREEN_W, SCREEN_H), Vector2(0, SCREEN_H),
	])
	_add_poly(strip, hills, Color(0.2, 0.5, 0.3))
	# Three temples at these x positions
	for tx in [150.0, 560.0, 930.0]:
		_add_temple(strip, tx)

# Draws one temple: a red body with a gold roof, centered at x
func _add_temple(parent: Node2D, x: float):
	_add_poly(parent, _rect_pts(x - 40, 390, 80, 80), Color(0.8, 0.25, 0.2))
	_add_poly(parent, PackedVector2Array([
		Vector2(x - 55, 390), Vector2(x, 340), Vector2(x + 55, 390),
	]), Color(0.95, 0.75, 0.2))

# Elevator: a small dark room with a floor, a ceiling, and two walls
func _build_elevator():
	# Dark room background
	_add_poly(self, _rect_pts(0, 0, SCREEN_W, SCREEN_H), Color(0.18, 0.2, 0.23))
	# Floor, ceiling, and the two walls
	_add_solid(Vector2(576, 600), Vector2(500, 40), Color(0.35, 0.36, 0.4))
	_add_solid(Vector2(576, 180), Vector2(520, 30), Color(0.3, 0.31, 0.34))
	_add_solid(Vector2(326, 390), Vector2(20, 420), Color(0.5, 0.52, 0.56))
	_add_solid(Vector2(826, 390), Vector2(20, 420), Color(0.5, 0.52, 0.56))

# Creates a solid block that fighters can stand on and bump into.
# center is the middle of the block, size is its width and height, color is how it looks.
func _add_solid(center: Vector2, size: Vector2, color: Color):
	# StaticBody2D is a wall or floor that does not move
	var body := StaticBody2D.new()
	body.position = center
	# The invisible collision shape (what the fighters hit)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	# The visible colored box. It is centered on the body, so it is offset by half its size.
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = color
	body.add_child(visual)
	add_child(body)

# Adds a colored shape (no collision) to a parent node
func _add_poly(parent: Node, pts: PackedVector2Array, color: Color):
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	parent.add_child(p)

# The four corners of a rectangle, starting at (x, y) with the given width and height
func _rect_pts(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)
	])

# Points around a circle, so it can be drawn as a shape
func _circle_pts(center: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:  # 32 points make a smooth-looking circle
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts

# ---- Fighters and HUD ------------------------------------------------------

# Creates one fighter, gives it its settings, and adds it to the scene
func _spawn_fighter(id: int, pos: Vector2, color: Color, controls: Dictionary):
	var f := CharacterBody2D.new()
	f.set_script(FighterScript)  # gives the node the fighter behavior from fighter.gd
	f.setup(id, color, controls)
	f.position = pos
	add_child(f)
	fighters.append(f)

# Creates the health bars at the top: player 1 on the left, player 2 on the right
func _build_hud():
	# A CanvasLayer keeps the HUD fixed on the screen while the camera moves
	var layer := CanvasLayer.new()
	add_child(layer)
	for i in fighters.size():
		# Player 1 bar starts on the left edge, player 2 bar ends at the right edge
		var x := 20.0 if i == 0 else SCREEN_W - 20.0 - BAR_WIDTH
		# Dark grey background bar
		var bg := ColorRect.new()
		bg.position = Vector2(x, 20)
		bg.size = Vector2(BAR_WIDTH, 24)
		bg.color = Color(0.2, 0.2, 0.2)
		layer.add_child(bg)
		# Green health bar on top. Its width is updated in _process.
		var fill := ColorRect.new()
		fill.position = Vector2(x, 20)
		fill.size = Vector2(BAR_WIDTH, 24)
		fill.color = Color.LIME_GREEN
		layer.add_child(fill)
		health_fills.append(fill)
