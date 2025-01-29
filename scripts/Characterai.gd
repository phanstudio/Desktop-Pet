extends CharacterBody2D

# Movement exports
@export_group("Movement")
@export var max_speed: float = 120.0
@export var jump_height: float = 40.0
@export var gravity: float = 310.0
@export var gravity_strong: float = 650.0
@export var acceleration: float = 512.0
@export var deceleration: float = 1024.0

# AI specific exports
@export_group("AI Behavior")
@export var patrol_range: float = 100.0  # How far to patrol from start position
@export var chase_range: float = 150.0   # How far to detect and chase player
@export var attack_range: float = 30.0   # How close to get before attacking
@export var edge_check_distance: float = 20.0  # How far ahead to check for edges

# Buffers (kept from player script for smooth movement)
@export_group("Buffers")
@export var air_buffer = 0.1
@export var jump_buffer = 0.07

@export var forms: Array[SpriteFrames]

# Node references
@onready var _Sprite: AnimatedSprite2D = $Sprite
@onready var _EdgeCheck = $EdgeCheck  # Add a RayCast2D for edge detection
@onready var timer: Timer = $Timer

# Movement variables (kept from player script)
var dir: float = 0.0
var jump: bool = false
var target_speed: float = 0.0
var target_accel: float = 0.0
var target_gravity: float = gravity_strong
var air_time = air_buffer
var jump_time = jump_buffer
var on_ground: bool = false
var current_playing = "none"

# AI specific variables
enum AIState { PATROL, CHASE, IDLE}
var current_state = AIState.PATROL
var start_position: Vector2
var patrol_direction: float = 1.0
var player: Node2D = null
var stun_timer: float = 0.0
var flipped = 0

func _ready():
	start_position = global_position
	# Setup edge detection raycast
	_EdgeCheck.target_position = Vector2(0, edge_check_distance)
	_EdgeCheck.enabled = true
	timer.timeout.connect(handel_idle)
	handel_idle()

func _process(_delta):
	# Update sprite direction
	if target_speed < 0.0:
		_Sprite.flip_h = false if flipped else true
	elif target_speed > 0.0:
		_Sprite.flip_h = true if flipped else false
	
	# Animation states (kept from player script)
	if on_ground:
		if target_speed != 0.0:
			travel("walk")
		else:
			travel("idle")
	else:
		if velocity.y >= 0.0:
			travel("idle")

func _physics_process(delta):
	match current_state:
		AIState.PATROL:
			handle_patrol(delta)
		AIState.CHASE:
			handle_chase(delta)
	
	# Vertical movement (kept from player script)
	if velocity.y > 0 or (not jump and jump_time < jump_buffer):
		target_gravity = gravity_strong
	velocity.y += target_gravity * delta
	
	# Horizontal movement (kept from player script)
	target_speed = dir * max_speed
	target_accel = acceleration if dir and sign(dir) == sign(velocity.x) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, target_accel * delta)

	# Apply velocity and update buffers (kept from player script)
	move_and_slide()
	var landed = is_on_floor() and not on_ground

	# Update buffers
	if jump:
		jump_time = 0.0
	on_ground = is_on_floor()
	if on_ground:
		air_time = 0.0
	else:
		air_time = min(air_time + delta, air_buffer)
		jump_time = min(jump_time + delta, jump_buffer)

	# Apply jump / landing
	if jump_time < jump_buffer and air_time < air_buffer:
		do_jump()
	elif landed:
		do_land()

func handle_patrol(_delta):
	# Set patrol movement direction
	dir = patrol_direction
	
	# Check if we need to turn around
	var distance_from_start = global_position.x - start_position.x
	if abs(distance_from_start) > patrol_range or should_turn_around():
		patrol_direction = float(sign(distance_from_start)*-1)
		dir = patrol_direction
	
	# Check for player in range
	if player and is_player_in_range(chase_range):
		current_state = AIState.CHASE

func handle_chase(_delta):
	if !player or !is_player_in_range(chase_range):
		current_state = AIState.PATROL
		return

	# Move towards player
	dir = sign(player.global_position.x - global_position.x)
	
	# Jump if needed to reach player
	if should_jump_to_player():
		jump = true
	else:
		jump = false

func handle_attack(_delta):
	# Stop moving during attack
	dir = 0
	
	# Simple attack pattern: stop briefly then return to chase
	if abs(velocity.x) < 5.0:
		current_state = AIState.CHASE

func handle_stunned(delta):
	dir = 0
	stun_timer -= delta
	if stun_timer <= 0:
		current_state = AIState.PATROL

func should_turn_around() -> bool:
	# Check for walls
	if is_on_wall():
		return true
		
	# Check for edges if we're on the ground
	if on_ground:
		_EdgeCheck.position.x = edge_check_distance * patrol_direction
		return !_EdgeCheck.is_colliding()
	
	return false

func should_jump_to_player() -> bool:
	if !player:
		return false
	
	# Jump if player is above and we're on ground
	var height_diff = player.global_position.y - global_position.y
	return on_ground and height_diff < -jump_height/2

func is_player_in_range(_range: float) -> bool:
	if !player:
		return false
	return global_position.distance_to(player.global_position) < _range

func handel_idle():
	if current_state == AIState.IDLE:
		current_state = AIState.PATROL
		_Sprite.sprite_frames = forms.pick_random()
		match _Sprite.sprite_frames.resource_path.get_file().get_basename():
			"pig":
				flipped = 1
			"chicken":
				flipped = 1
			"slime":
				flipped = 1
			_:
				flipped = 0
		if timer.is_stopped():
			timer.start(20* randf_range(0.3, 1.2))
	else:
		current_state = AIState.IDLE
		if timer.is_stopped():
			timer.start(10* randf_range(0.3, 1.2))

func travel(play):
	if current_playing != play:
		current_playing = play
		@warning_ignore("incompatible_ternary")
		_Sprite.speed_scale = 1 * (0.008 * target_speed) if target_speed != 0.0 else 1
		_Sprite.play(play)

func do_jump():
	velocity.y = -sqrt(jump_height * 2.0 * gravity)
	target_gravity = gravity
	jump_time = jump_buffer
	air_time = air_buffer
	on_ground = false
	travel("idle")

func do_land():
	pass
