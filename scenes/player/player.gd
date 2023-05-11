extends CharacterBody3D

const WORLD_MASK: int = 2
const GRAVITY: float = -9.8
const STOP_FORCE: float = 10
const CAMERA_X_AXIS_CLAMP: float = PI/2

@export var speed: float = 5
@export var mouse_sensitivity: float = 0.003
@export var jump_force: float = 5
@export var no_clip: bool = false:
	set(value):
		_set_no_clip(value)
		no_clip = value
@onready var head := $Head
@onready var camera := $Head/CameraFPS
@onready var camera_top_down := $CameraTop


func _ready():
	capture_cursor_for_camera()
#	set_collision_layer_value(WorldConstants.CollisionLayer.PLAYER, true)
#	set_collision_mask_value(WorldConstants.CollisionLayer.ENVIRONMENT, true)


func _physics_process(delta):
	var requested_velocity: Vector3 = convert_inputs_to_velocity()
	if requested_velocity.length() > 0:
		velocity.x = move_toward(requested_velocity.x, 0, STOP_FORCE * delta)
		velocity.z = move_toward(requested_velocity.z, 0, STOP_FORCE * delta)
		if no_clip:
			velocity.y = move_toward(requested_velocity.y, 0, STOP_FORCE * delta)
	else:
		velocity.x = requested_velocity.x * delta
		velocity.z = requested_velocity.z * delta
		if no_clip:
			velocity.y = requested_velocity.y * delta
		
	# Y axis: gravity and jumping
	process_gravity(delta)
	process_jumping(delta)
	
	process_inputs()
		
	# update transform accordingly
	move_and_slide()


func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(
			head.rotation.x,
			-CAMERA_X_AXIS_CLAMP,
			CAMERA_X_AXIS_CLAMP)


# Checks for any currently-pressed buttons and returns a corresponding velocity
func convert_inputs_to_velocity() -> Vector3:
	var requested_velocity := Vector3.ZERO
	if Input.is_action_pressed("move_right"):
		requested_velocity += Vector3.RIGHT
	if Input.is_action_pressed("move_left"):
		requested_velocity -= Vector3.RIGHT
	if Input.is_action_pressed("move_forward"):
		requested_velocity += Vector3.FORWARD
	if Input.is_action_pressed("move_backward"):
		requested_velocity -= Vector3.FORWARD
	if no_clip:
		if Input.is_action_pressed("noclip_up"):
			requested_velocity += Vector3.UP
		if Input.is_action_pressed("noclip_down"):
			requested_velocity -= Vector3.UP
	
	if requested_velocity.length() > 0:
		# normalize to the correct speed and translate the velocity to "forward"
		requested_velocity = requested_velocity.normalized() * speed
		requested_velocity = requested_velocity.rotated(transform.basis.y.normalized(), rotation.y)
		if no_clip:
			# when no-clipping, vertical movement should match the camera's X axis
			requested_velocity = requested_velocity.rotated(
				transform.basis.x.normalized(),
				head.rotation.x)
	return requested_velocity


# Checks various 1-off inputs, like swapping camera views or enabling no-clip
func process_inputs():
	if Input.is_action_just_pressed("isolate_cursor"):
		isolate_cursor_from_camera()
	if Input.is_action_just_pressed("capture_cursor"):
		capture_cursor_for_camera()
	if Input.is_action_just_pressed("enable_noclip"):
		no_clip = not no_clip
		_set_no_clip(no_clip)
	if Input.is_action_just_pressed("camera_fps"):
		camera.make_current()
	if Input.is_action_just_pressed("camera_top_down"):
		camera_top_down.make_current()


# Modifies the current velocity by gravity
func process_gravity(delta):
	if no_clip:
		return
	velocity.y += delta * GRAVITY


# Modifies the current velocity if the player tried to jump
func process_jumping(_delta):
	if no_clip:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y += jump_force


# Prevents the camera from tracking the mouse, freeing up the cursor for whatever
func isolate_cursor_from_camera():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# Forces the camera to track the cursor, FPS style
func capture_cursor_for_camera():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED) 


func _set_no_clip(enable_no_clip):
	velocity.y = 0
	set_collision_mask_value(WORLD_MASK, not enable_no_clip)
