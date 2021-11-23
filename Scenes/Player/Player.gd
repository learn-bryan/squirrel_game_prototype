extends KinematicBody

onready var pivot = $Pivot
onready var cam = $CameraGimbal/InnerGimbal/Camera
onready var chestRay = $Pivot/ChestRay
onready var leftRay = $Pivot/LeftRay
onready var rightRay = $Pivot/RightRay

#onready var animate = $"Pivot/Pump Kin/AnimationPlayer"

export var MOVE_SPEED = 8.0
export var JUMP_SPEED = 8.0

var velocity = Vector3()
var look_direction = Vector3()
var move_direction = Vector3()
var move_weight = 1.0
#var air_move_mult = 0.2

var gravity = 15.0

var grasping = false
var sn = Vector3() # climbing surface normal

var jumping = false
var jump_pressed = false
var airborne = false
var coyote_time_length = 0.3
var coyote_time = coyote_time_length

var hidden = false
var anim_lock = false

func _ready():
	#animate.connect("animation_finished", self, "anim_fin")
	pass

func _physics_process(delta):
	get_input() 
	
	# direct
	if not is_climbing():
		look(look_direction)
	apply_movement(move_direction, delta)

func apply_movement(direction, delta):
	#print(grasping)
	# Check airborne status
	if (not is_on_floor()):
		if (jumping):
			airborne = true
		else: # falling / walked off edge
			coyote_time -= 1 * delta
			if (coyote_time <= 0):
				airborne = true
		
	if (is_on_floor()): # just landed on ground
		airborne = false
		jumping = false
		coyote_time = coyote_time_length
		
		pass
	
	if is_climbing():
		sn = chestRay.get_collision_normal()
		direction = rotate_direction_to_plane(direction, sn)
		velocity = direction * MOVE_SPEED * move_weight
		
		# TODO: When climbing I should turn player to face the climbing surface
		look(sn)
		
#		velocity.x = 0.0
#		velocity.z = 0.0
#		velocity.y = MOVE_SPEED * move_weight

#		velocity.x = direction.x * MOVE_SPEED * move_weight
#		velocity.y = direction.z * MOVE_SPEED * move_weight
#		velocity.z = 0.0

#		velocity.x = direction.x * MOVE_SPEED * move_weight
#		velocity.y = direction.z * MOVE_SPEED * move_weight
#		velocity.z -= 0.0
	else:
		if (not airborne):	# Grounded Movement
			if (jump_pressed):
				velocity.y = JUMP_SPEED
				jump_pressed = false
				jumping = true
		else: 				# Ungrounded Movement
			jump_pressed = false
		
		# General Movement
		velocity.x = direction.x * MOVE_SPEED * move_weight
		velocity.z = direction.z * MOVE_SPEED * move_weight
		velocity.y -= gravity * delta
	
	# Apply Movement
	if is_climbing():
		#sn = chestRay.get_collision_normal()
		#velocity = move_and_slide_with_snap(velocity, sn, sn)
		#velocity = move_and_slide_with_snap(velocity, sn, Vector3.UP)
		velocity = move_and_slide(velocity, sn)
	else:
		velocity = move_and_slide(velocity, Vector3.UP)
	
#	var target = transform.origin + direction * MOVE_SPEED * move_weight * delta
#	# bind position within fense area
#	target.x = clamp(target.x, -71.859, 72.859) # x-axis
#	target.z = clamp(target.z, -326.473, 37.66) # z-axis
#	set_global_position(self, target)

func set_global_position(spatialNode, vector3Position):
	spatialNode.set_global_transform(Transform(spatialNode.get_global_transform().basis,vector3Position))    

func look(direction):
	# rotate around y axis
	if ( direction != Vector3.ZERO ):
		pivot.look_at(transform.origin + direction, Vector3.UP) # movement direction relative to camera
	
	
func get_input():
	look_direction = Vector3(0.0, 0.0, 0.0) # direction relative to camera
	var cam_xform = cam.get_global_transform()
	var s = 0.0
	var strength = Vector2(0.0, 0.0)
	move_weight = 1.0
	
	# right
	s = Input.get_action_strength("player_right")
	strength.x += s
	look_direction += -cam_xform.basis[0] * s
	# left
	s = Input.get_action_strength("player_left")
	strength.x += s
	look_direction += cam_xform.basis[0] * s
	# forward
	s = Input.get_action_strength("player_up")
	strength.y += s
	look_direction += cam_xform.basis[2] * s
	# backward
	s = Input.get_action_strength("player_down")
	strength.y += s
	look_direction += -cam_xform.basis[2] * s
	
	# actions
	if Input.is_action_pressed("player_jump"):
		jump_pressed = true
	if Input.get_action_strength("player_grasp") > 0.1:
		grasping = true
	else:
		grasping = false
	
	look_direction.y = 0
	look_direction = look_direction.normalized()
	move_direction = -1 * look_direction
	move_weight = max(abs(strength.x), abs(strength.y))

#func anim_fin(_anim_name):
#	hidden = !hidden
#	anim_lock = false

func can_climb():
	if chestRay.is_colliding() or leftRay.is_colliding() or rightRay.is_colliding():
		return true
	else:
		return false

func is_climbing():
	if can_climb() and grasping:
		return true
	else:
		return false

# TODO: understand this
# Taken from https://godotengine.org/qa/92293/help-projecting-rotating-input-vector-onto-normal
# "I utilized Quat's to handle the rotation and find the angle and axis need to
# rotate a vector that aligns with the plane being walked on."
func rotate_direction_to_plane(vector: Vector3, normal: Vector3):
	var rotation_direction = Plane(Vector3.UP, 0).project(normal)
	var rotation = Quat.IDENTITY
	rotation.set_axis_angle(Vector3.UP, deg2rad(-90))
	rotation_direction = rotation.xform(rotation_direction)
	var angle = -Vector3.UP.angle_to(normal)
	rotation = Quat.IDENTITY
	rotation.set_axis_angle(rotation_direction.normalized(), angle)
	vector = rotation.xform(vector)
	return vector
