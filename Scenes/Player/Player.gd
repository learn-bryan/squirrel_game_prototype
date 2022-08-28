extends KinematicBody

onready var pivot = $Pivot
onready var cam = $CameraGimbal/InnerGimbal/Camera
onready var chestRay = $Pivot/ChestRay
onready var leftRay = $Pivot/LeftRay
onready var rightRay = $Pivot/RightRay
onready var floorRay = $Pivot/FloorRay

#onready var animate = $"Pivot/Pump Kin/AnimationPlayer"

export var MOVE_SPEED = 8.0
export var JUMP_SPEED = 8.0
export var CLIMB_SPEED = 4.0

var velocity = Vector3()
var look_direction = Vector3()
var move_direction = Vector3()
var climb_direction = Vector3()
var move_weight = 1.0
#var air_move_mult = 0.2

var gravity = 15.0

var grasping : bool = false
var sn = Vector3() # climbing surface normal

var gliding : bool = false

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
	print(get_climb_surface_normal())
	var snap_ground_vec = Vector3.ZERO
	var ground_up_vec = Vector3.UP
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
	
	# Set Velocity
	if is_climbing():
		sn = get_climb_surface_normal()
		look(sn) # look at climbing surface
		get_input() # update climb_direction
		direction = rotate_direction_to_plane(climb_direction, sn)
		velocity = direction * CLIMB_SPEED * move_weight
	else: # not climbing
		direction = rotate_direction_to_plane(direction, get_floor_surface_normal())
		if (not airborne):	# Grounded Movement
			if (jump_pressed):
				velocity.y = JUMP_SPEED
				jump_pressed = false
				jumping = true
			velocity.x = direction.x * MOVE_SPEED * move_weight
			velocity.z = direction.z * MOVE_SPEED * move_weight
#			velocity.y -= gravity * delta
		else: 				# Air Movement
			jump_pressed = false
			if gliding and velocity.y <= 0: # if falling & gliding
				velocity.x = direction.x * MOVE_SPEED * move_weight
				velocity.z = direction.z * MOVE_SPEED * move_weight
#				velocity.y -= (gravity*.3) * delta # reduce gravity (compensate)
				velocity.y = (gravity*-1) * delta # static reduced gravity
				gliding = false
			else: # free fall
				velocity.y -= gravity * delta
				# directional movement in air
				velocity.x = direction.x * MOVE_SPEED * move_weight
				velocity.z = direction.z * MOVE_SPEED * move_weight
		
#		# General Movement
#		velocity.x = direction.x * MOVE_SPEED * move_weight
#		velocity.z = direction.z * MOVE_SPEED * move_weight
#		velocity.y -= gravity * delta
	
	# Apply Movement
	if is_climbing():
		ground_up_vec = sn
		snap_ground_vec = -3*ground_up_vec
		#sn = chestRay.get_collision_normal()
		#velocity = move_and_slide_with_snap(velocity, sn, sn)
		#velocity = move_and_slide_with_snap(velocity, sn, Vector3.UP)
		#velocity = move_and_slide(velocity, sn)
		velocity = move_and_slide_with_snap(velocity, snap_ground_vec, ground_up_vec, false, 4, PI-0.1, false)
	else:
		#velocity = move_and_slide(velocity, Vector3.UP)
		ground_up_vec = Vector3.UP
		snap_ground_vec = Vector3.DOWN # snap to ground by default
		if jumping:
			snap_ground_vec = Vector3.ZERO # disable snap
		if grasping:
			ground_up_vec = get_floor_surface_normal()
			snap_ground_vec = -3*ground_up_vec # snap to standing surface
		
		velocity = move_and_slide_with_snap(velocity, snap_ground_vec, ground_up_vec, true, 4, PI/3, false)
	
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
	#look_direction = Vector3(0.0, 0.0, 0.0) # direction relative to camera
	look_direction = Vector3.ZERO # direction relative to camera
	climb_direction = Vector3.ZERO
	var cam_xform = cam.get_global_transform()
#	var player_xform = pivot.transform
	var player_xform = pivot.get_global_transform()
	var s = 0.0
	var strength = Vector2(0.0, 0.0)
	move_weight = 1.0
	
	# right
	s = Input.get_action_strength("player_right")
	strength.x += s
	look_direction += -cam_xform.basis[0] * s
#	climb_direction += Vector3(1*s,0,0)
	climb_direction += -player_xform.basis[0] * s
	# left
	s = Input.get_action_strength("player_left")
	strength.x += s
	look_direction += cam_xform.basis[0] * s
#	climb_direction += Vector3(-1*s,0,0)
	climb_direction += player_xform.basis[0] * s
	# forward
	s = Input.get_action_strength("player_up")
	strength.y += s
	look_direction += cam_xform.basis[2] * s
#	climb_direction += Vector3(0,0,-1*s)
	climb_direction += player_xform.basis[2] * s
	# backward
	s = Input.get_action_strength("player_down")
	strength.y += s
	look_direction += -cam_xform.basis[2] * s
#	climb_direction += Vector3(0,0,1*s)
	climb_direction += -player_xform.basis[2] * s
	
	# actions
	if Input.is_action_pressed("player_jump"):
		jump_pressed = true
	if Input.is_action_pressed("player_glide"):
		gliding = true
	if Input.get_action_strength("player_grasp") > 0.1:
		grasping = true
	else:
		grasping = false
	
	look_direction.y = 0
	look_direction = look_direction.normalized()
	move_direction = -1 * look_direction
	move_weight = max(abs(strength.x), abs(strength.y))
	climb_direction = climb_direction.normalized()
#	move_direction = climb_direction

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

func get_climb_surface_normal():
	var n = 0
	if chestRay.is_colliding():
		n += 1
	if leftRay.is_colliding():
		n += 1
	if rightRay.is_colliding():
		n += 1
	if n == 0:
		return Vector3.ZERO
	else:
		return (chestRay.get_collision_normal() + leftRay.get_collision_normal() + rightRay.get_collision_normal()) / n

func get_floor_surface_normal():
	if floorRay.is_colliding():
		return floorRay.get_collision_normal()
	else:
		return Vector3.ZERO

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

# TODO: finish
# My attempt to modify 'rotate_direction_to_plane' to match botw controls
func map_movement_to_climbing(vector: Vector3, normal: Vector3):
#	var direction_transform = Transform()
#	direction_transform.basis.y = normal
#	direction_transform.basis.x = -self.transform.basis.z.cross(normal)
#	direction_transform.basis = direction_transform.basis.orthonormalized()
#	#vector = rotation_direction.normalized()
#	vector = direction_transform.xform(vector)

#	var dir = Vector3()
#	dir += self.transform.basis[0]
#	dir += self.transform.basis[2]
#	vector = dir.normalized()
	
	var rotation_direction = Plane(Vector3.UP, 0).project(normal)
	var rotation = Quat.IDENTITY
	var angle = -Vector3.UP.angle_to(normal)
	rotation.set_axis_angle(Vector3.UP, deg2rad(angle))
	rotation_direction = rotation.xform(rotation_direction)
	rotation = Quat.IDENTITY
	rotation.set_axis_angle(rotation_direction.normalized(), angle)
	vector = rotation.xform(vector)
	
	return vector
