# fighter.gd
# One fighter. This script handles movement, jumping, punches and kicks, cooldowns,
# blocking, taking hits, and knockouts. main.gd creates two of these, one per player.
#
# It is a CharacterBody2D, which is a physics body that can move and be stopped by floors and walls.
extends CharacterBody2D

const FigureScript = preload("res://scripts/figure.gd")

# ---- Movement and combat settings ----
const SPEED := 300.0            # walking speed in pixels per second
const JUMP_VELOCITY := -600.0   # jump strength (negative = up). Gives about 180 pixels of height.
const HITSTUN_TIME := 0.3       # seconds the fighter is stunned after taking a hit
const KNOCKBACK := 250.0        # how hard a normal hit pushes the fighter back
const BLOCK_PUSHBACK := 60.0    # the smaller push when a hit is blocked
const HURT_LAYER := 2           # the physics layer hurtboxes live on (2 = layer 2, as a bitmask value)

# Every attack the fighter can do. To add or change a move, edit or add an entry here.
#   duration:   how long the whole move lasts, in seconds
#   hit_start:  when the hitbox turns on (seconds from the start of the move)
#   hit_end:    when the hitbox turns off
#   damage:     health taken from the opponent when the hit lands
#   cooldown:   seconds before the same move can be used again, counted from the start
#   offset:     where the hitbox sits relative to the fighter (x is flipped by facing)
#   size:       width and height of the hitbox
const MOVES := {
	"punch": {
		"duration": 0.15, "hit_start": 0.0, "hit_end": 0.15, "damage": 10.0, "cooldown": 0.3,
		"offset": Vector2(45, -20), "size": Vector2(50, 40),
	},
	"kick": {
		"duration": 0.4, "hit_start": 0.1, "hit_end": 0.25, "damage": 15.0, "cooldown": 0.7,
		"offset": Vector2(50, 35), "size": Vector2(60, 30),  # low, at leg height
	},
}

# ---- Per-fighter state ----
var player_id := 1                 # 1 or 2
var body_color := Color.WHITE      # the color used for this fighter's figure
var controls := {}                 # the action names for this player's keys (left, right, jump, punch, kick)
var max_health := 100.0
var health := 100.0
var facing := 1                    # 1 = looking right, -1 = looking left
var dead := false                  # true after a knockout
var opponent: Node2D = null        # the other fighter, set by main.gd

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")  # pulls the fighter down
var hitstun_timer := 0.0           # counts down while stunned from a hit
var blocking := false              # true while the fighter is guarding
var attack := ""                   # the move in progress: "", "punch" or "kick"
var attack_time := 0.0            # how long the current move has been running
var attack_damage := 0.0           # damage the current move will do if it lands
var cooldowns := {"punch": 0.0, "kick": 0.0}  # seconds left before each move can be used again
var hit_targets: Array = []        # opponents already hit by the current move (so one punch hits once)
var hitbox: Area2D = null          # the invisible attack area, only exists during the active window
var figure: Node2D                 # the drawn character (see figure.gd)

# Called by main.gd before the fighter is added to the scene.
# Sets the player number, color, and keys. Player 1 starts facing right, player 2 faces left.
func setup(id: int, color: Color, control_map: Dictionary):
	player_id = id
	body_color = color
	controls = control_map
	facing = 1 if id == 1 else -1

# Runs once when the fighter is added to the scene: builds its collision and visuals
func _ready():
	# Collision box: the physical body that stands on the floor and bumps into the other fighter.
	# It is invisible; the figure below is what you see.
	var body_shape := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(60, 120)
	body_shape.shape = body_rect
	add_child(body_shape)

	# Hurtbox: the area that other fighters' attacks check against.
	# It is on HURT_LAYER and does not push anything itself.
	var hurtbox := Area2D.new()
	hurtbox.collision_layer = HURT_LAYER
	hurtbox.collision_mask = 0
	var hurt_shape := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = body_rect.size
	hurt_shape.shape = hurt_rect
	hurtbox.add_child(hurt_shape)
	add_child(hurtbox)

	# The drawn character, with the animation code from figure.gd
	figure = Node2D.new()
	figure.set_script(FigureScript)
	figure.setup(body_color)
	add_child(figure)

# Runs every physics step (a fixed rate, good for movement and collisions)
func _physics_process(delta):
	_update_facing()

	# Count down every move's cooldown, never going below zero
	for move in cooldowns:
		cooldowns[move] = max(cooldowns[move] - delta, 0.0)

	# Gravity: pull down while in the air
	if not is_on_floor():
		velocity.y += gravity * delta

	# The fighter can only act when alive and not stunned
	var can_act := not dead and hitstun_timer <= 0
	if hitstun_timer > 0:
		hitstun_timer -= delta

	var dir := 0.0  # -1 = pressing left, 0 = nothing, 1 = pressing right
	if can_act:
		# Walking: the sign of the input decides the direction. Facing toward the opponent
		# means right is forward; facing away means right is backward.
		dir = Input.get_axis(controls["left"], controls["right"])
		velocity.x = dir * SPEED
		# Jump only when standing on the floor
		if Input.is_action_just_pressed(controls["jump"]) and is_on_floor():
			velocity.y = JUMP_VELOCITY
		# Start a move only if no move is already running and its cooldown is over
		if attack == "":
			if Input.is_action_just_pressed(controls["punch"]) and cooldowns["punch"] <= 0:
				_start_attack("punch")
			elif Input.is_action_just_pressed(controls["kick"]) and cooldowns["kick"] <= 0:
				_start_attack("kick")
	else:
		# Stunned or knocked out: slide to a stop instead of stopping instantly
		velocity.x = move_toward(velocity.x, 0, 800 * delta)

	# Move the current attack along its timeline
	_update_attack(delta)

	# Blocking: standing still or walking backward while on the floor, and not attacking.
	# dir * facing is positive when walking forward, so "<= 0" means not walking forward.
	blocking = can_act and attack == "" and is_on_floor() and dir * facing <= 0

	# Visuals: face the right way, pick the right animation, and flash red when hit
	figure.scale.x = float(facing)
	figure.set_state(_pick_state())
	figure.modulate = Color(1, 0.5, 0.5) if (hitstun_timer > 0 and not dead) else Color.WHITE

	move_and_slide()  # moves the fighter using its velocity and stops it on walls and floors

# Always face the opponent. Swapping sides flips facing automatically.
func _update_facing():
	if opponent == null:
		return
	var diff: float = opponent.global_position.x - global_position.x
	# Only turn when the opponent is clearly on one side, so the facing doesn't flicker
	if abs(diff) > 1.0:
		facing = 1 if diff > 0 else -1

# Decides which animation to show. The first matching rule wins, so the order matters.
func _pick_state() -> String:
	if dead:
		return "ko"
	if hitstun_timer > 0:
		return "hit"
	if attack == "punch":
		return "punch"
	if attack == "kick":
		# Split the kick into wind-up, swing, and recovery based on how far along it is
		if attack_time < 0.1:
			return "kick_wind"
		if attack_time < 0.25:
			return "kick"
		return "kick_recover"
	if blocking:
		return "block"
	if not is_on_floor():
		return "jump"
	if abs(velocity.x) > 10.0:
		return "walk"
	return "idle"

# Begins a move: remember which one, reset its timer, set its damage and cooldown
func _start_attack(move: String):
	attack = move
	attack_time = 0.0
	attack_damage = MOVES[move]["damage"]
	cooldowns[move] = MOVES[move]["cooldown"]
	hit_targets.clear()  # forget who was hit by the previous move

# Runs the move's timeline. The hitbox only exists during its active window.
func _update_attack(delta: float):
	if attack == "":
		return
	var m: Dictionary = MOVES[attack]
	attack_time += delta
	var active: bool = attack_time >= m["hit_start"] and attack_time < m["hit_end"]
	# Turn the hitbox on when the active window starts, and off when it ends
	if active and hitbox == null:
		_make_hitbox(m)
	elif not active and hitbox != null:
		_remove_hitbox()
	# Keep the hitbox in front of the fighter. The x offset flips with facing.
	if hitbox:
		var off: Vector2 = m["offset"]
		hitbox.position = Vector2(off.x * facing, off.y)
	# The move is over
	if attack_time >= m["duration"]:
		attack = ""
		_remove_hitbox()

# Creates the attack area for the current move
func _make_hitbox(m: Dictionary):
	var sz: Vector2 = m["size"]
	hitbox = Area2D.new()
	hitbox.collision_layer = 0          # the hitbox itself isn't something others collide with
	hitbox.collision_mask = HURT_LAYER  # it only looks for hurtboxes
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = sz
	shape.shape = rect
	hitbox.add_child(shape)
	# Runs when a hurtbox overlaps this hitbox
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	add_child(hitbox)

# Deletes the attack area
func _remove_hitbox():
	if hitbox:
		hitbox.queue_free()  # deletes the node safely at the end of the frame
		hitbox = null

# Runs when the attack touches something
func _on_hitbox_area_entered(area: Area2D):
	# The hurtbox's parent is the fighter it belongs to
	var target = area.get_parent()
	if target == self or hit_targets.has(target):
		return  # ignore ourselves, and never hit the same fighter twice with one move
	if not target.has_method("take_hit"):
		return  # ignore anything that cannot be hit
	hit_targets.append(target)
	target.take_hit(attack_damage, facing)

# Called by the opponent's attack when it lands on this fighter
func take_hit(damage: float, from_dir: int):
	if dead:
		return
	# Blocking: no damage, just a small shove
	if blocking:
		velocity.x = from_dir * BLOCK_PUSHBACK
		print("Player ", player_id, " blocked!")
		return
	# Normal hit: lose health, get knocked back, and get stunned
	health = max(health - damage, 0.0)
	velocity.x = from_dir * KNOCKBACK
	velocity.y = -150.0  # a small hop
	hitstun_timer = HITSTUN_TIME
	# Getting hit cancels whatever attack you were doing
	attack = ""
	_remove_hitbox()
	print("Player ", player_id, " hit! Health: ", health)
	if health <= 0:
		dead = true  # main.gd sees this and ends the round
		print("K.O.! Player ", player_id, " lost")
