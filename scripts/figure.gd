# figure.gd
# The character drawn from simple shapes. This is the placeholder "art" for every fighter.
#
# The body is made of pivots: small Node2D nodes placed at the shoulders, hips, and neck.
# Each limb is a shape attached to its pivot, so rotating the pivot swings the limb.
# This script rotates the pivots to make the poses for each state (idle, walk, punch, and so on).
extends Node2D

const SKIN := Color(0.95, 0.8, 0.65)  # the color of the head

var cloth := Color.WHITE          # the body color (set by setup)
var state := "idle"               # the current pose name, set by fighter.gd or select.gd
var t := 0.0                      # running clock, used for smooth back-and-forth motion
var head: Node2D                  # pivot for the head
var torso: Node2D                 # pivot for the torso
var arm_front: Node2D             # the arm on the side the figure faces
var arm_back: Node2D              # the arm on the far side
var leg_front: Node2D             # the leg on the side the figure faces
var leg_back: Node2D              # the leg on the far side

# Sets the body color. Call this before adding the figure to the scene.
func setup(cloth_color: Color):
	cloth = cloth_color

# Changes the pose the figure is showing. Example: set_state("punch").
func set_state(new_state: String):
	state = new_state

# Runs once when the figure is added to the scene: builds all the body parts
func _ready():
	# Back limbs are created first so the torso and front limbs are drawn on top of them.
	# Positions are relative to the fighter's center. Feet are at about y = 60.
	arm_back = _part(Vector2(-6, -26), _rect(-3, 0, 6, 26), cloth.darkened(0.25))
	leg_back = _part(Vector2(-8, 20), _rect(-5, 0, 10, 40), cloth.darkened(0.35))
	torso = _part(Vector2(0, -30), _rect(-14, -10, 28, 60), cloth)
	head = _part(Vector2(0, -50), _rect(-10, -11, 20, 22), SKIN)
	leg_front = _part(Vector2(8, 20), _rect(-5, 0, 10, 40), cloth)
	arm_front = _part(Vector2(6, -26), _rect(-3, 0, 6, 26), cloth)

# Runs every frame: moves each limb toward the angle its current pose wants
func _process(delta):
	t += delta
	var p := _pose(state)  # the target angles for this state
	# How quickly limbs move toward their targets (0 to 1 per frame). Bigger = snappier.
	var k: float = min(1.0, 15.0 * delta)
	arm_front.rotation = lerp_angle(arm_front.rotation, p["af"], k)
	arm_back.rotation = lerp_angle(arm_back.rotation, p["ab"], k)
	leg_front.rotation = lerp_angle(leg_front.rotation, p["lf"], k)
	leg_back.rotation = lerp_angle(leg_back.rotation, p["lb"], k)
	head.rotation = lerp_angle(head.rotation, p["h"], k)
	# Gentle breathing: the torso bobs up and down slightly while idle
	torso.position.y = -30.0 + (sin(t * 3.0) * 1.0 if state == "idle" else 0.0)

	# Death: the whole figure topples backward and settles onto the floor
	var k_slow: float = min(1.0, 6.0 * delta)  # a slower speed so the fall looks heavy
	var target_rot := 0.0
	var target_y := 0.0
	if state == "ko":
		# Falls away from the direction the figure faces, lying flat
		target_rot = -sign(scale.x) * PI / 2.0
		target_y = 46.0  # moves the body down so it rests on the floor
	rotation = lerp_angle(rotation, target_rot, k_slow)
	position.y = lerp(position.y, target_y, k_slow)

# The target angles (in radians) for each limb in each state.
# A positive angle rotates clockwise on screen, a negative angle rotates counterclockwise.
# "af"/"ab" = front/back arm, "lf"/"lb" = front/back leg, "h" = head.
# To change how a move looks, change its numbers here.
func _pose(s: String) -> Dictionary:
	var w := sin(t * 10.0)  # swings between -1 and 1, used for walking
	match s:
		"walk":
			# Arms and legs swing in opposite directions
			return {"af": -w * 0.6, "ab": w * 0.6, "lf": w * 0.5, "lb": -w * 0.5, "h": 0.0}
		"block":
			# Guard: both fists up in front of the face
			return {"af": -1.2, "ab": -1.4, "lf": 0.1, "lb": -0.1, "h": 0.0}
		"jump":
			# Arms up, legs tucked
			return {"af": -2.6, "ab": 2.4, "lf": -0.6, "lb": 0.4, "h": 0.0}
		"punch":
			# Front arm stretched straight out
			return {"af": -PI / 2.0, "ab": 0.5, "lf": 0.25, "lb": -0.25, "h": 0.0}
		# Leg kick: wind up by pulling the front leg back, then swing it forward
		"kick_wind":
			return {"af": 0.3, "ab": -0.3, "lf": 0.6, "lb": -0.3, "h": 0.0}
		"kick":
			# Front leg straight out to the side the figure faces
			return {"af": -0.8, "ab": 0.8, "lf": -PI / 2.0, "lb": 0.0, "h": 0.0}
		"kick_recover":
			return {"af": 0.1, "ab": -0.1, "lf": 0.2, "lb": 0.0, "h": 0.0}
		"hit":
			# Arms flail and the head snaps back
			return {"af": 1.0, "ab": -1.0, "lf": 0.2, "lb": -0.2, "h": 0.3}
		"ko":
			return {"af": 0.3, "ab": -0.3, "lf": 0.1, "lb": -0.1, "h": 0.0}
		_:
			# Idle: arms and legs relaxed, almost straight down
			return {"af": 0.1, "ab": -0.1, "lf": 0.0, "lb": 0.0, "h": 0.0}

# Creates one body part: a pivot at the given position, with a colored shape attached.
# Returns the pivot so we can rotate it later.
func _part(pivot: Vector2, pts: PackedVector2Array, color: Color) -> Node2D:
	var p := Node2D.new()
	p.position = pivot  # the pivot point all rotations happen around
	var poly := Polygon2D.new()
	poly.polygon = pts  # the shape, drawn relative to the pivot
	poly.color = color
	p.add_child(poly)
	add_child(p)
	return p

# The four corners of a rectangle, starting at (x, y). Used for body part shapes.
func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)
	])
