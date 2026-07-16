extends Marker2D

# Set your maximum swing angle in degrees (e.g., 90 degrees)
@export var swing_angle_degrees: float = 5
# Higher values make the swing and return snap faster
@export var movement_speed: float = 50

# Store the target angle in radians
var target_rotation: float = 0.0
var default_rotation: float = 0.0

func _ready() -> void:
	# Convert degrees to radians for Godot's rotation system
	swing_angle_degrees = deg_to_rad(swing_angle_degrees)

func _process(delta: float) -> void:
	# 1. Check for quick taps (just_pressed)
	if Input.is_action_just_pressed("hit_left"):
		# Instantly overrides target to counter-clockwise angle
		target_rotation = swing_angle_degrees 
	elif Input.is_action_just_pressed("hit_right"):
		# Instantly overrides target to clockwise angle
		target_rotation = -swing_angle_degrees
		
	# 2. Check if the sword has successfully reached its strike target
	# if it is very close to the swing target, reset target back to default (0)
	if is_equal_approx(rotation, target_rotation) && target_rotation != default_rotation:
		target_rotation = default_rotation

	# 3. Smoothly move towards the target rotation from its CURRENT position
	rotation = lerp_angle(rotation, target_rotation, movement_speed * delta)
