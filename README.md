
extends CharacterBody2D # Use Godot's built-in 2D character movement and collision handling.

# Set these to half the width and height of the player's CollisionShape2D.
@export var body_half_width: float = 8.0 # Half-width used when checking walls and placing the player at a ledge.
@export var body_half_height: float = 16.0 # Half-height used when checking ledges and placing the player.
@export var speed: float = 250.0 # Maximum horizontal walking speed, in pixels per second.
@export var acceleration: float = 1800.0 # How quickly horizontal speed reaches the requested walking speed.
@export var friction: float = 2200.0 # How quickly the player slows down after releasing left or right.
@export var climb_speed: float = 120.0 # Vertical speed while climbing a wall.
@export var jump_velocity: float = -400.0 # Upward jump speed; negative is upward in Godot 2D.
@export var wall_jump_push: float = 180.0 # Horizontal speed applied when jumping away from a wall or ledge.
@export var max_ledge_reach: float = 40.0 # Maximum vertical distance above the player to check for a ledge.
@export var ledge_probe_distance: float = 10.0 # Extra distance beyond the player's side used for ledge checks.

var is_hanging: bool = false # Tracks whether the player is currently attached to a ledge.
var ledge_position: Vector2 = Vector2.ZERO # Stores the point where the top of the grabbed ledge was detected.
var hang_position: Vector2 = Vector2.ZERO # Stores the player's fixed position while hanging.
var hang_direction: int = 1 # Stores whether the ledge is to the player's left (-1) or right (1).


func _physics_process(delta: float) -> void: # Runs the player's movement logic once per physics frame.
	var move_input: float = Input.get_axis("ui_left", "ui_right") # Reads left/right input as -1, 0, or 1.
	var vertical_input: float = Input.get_axis("ui_up", "ui_down") # Reads up/down input for climbing.
	var jump_pressed: bool = Input.is_action_just_pressed("ui_accept") # True only on the frame jump is first pressed.

	if is_hanging: # Use ledge-specific controls instead of normal movement while hanging.
		_handle_hanging(jump_pressed) # Climb up, jump away, or drop from the ledge.
		return # Stop normal movement processing for this frame.

	var wall_jumped: bool = is_on_wall() and not is_on_floor() and jump_pressed # Detect a jump pressed while airborne against a wall.

	if is_on_floor() and jump_pressed: # If grounded and jump was pressed...
		velocity.y = jump_velocity # ...launch the player upward.
	elif wall_jumped: # Otherwise, jump away if airborne against a wall.
		velocity.y = jump_velocity # Apply the upward part of the wall jump.
		velocity.x = get_wall_normal().x * wall_jump_push # Push away from the wall's collision normal.
	elif is_on_wall() and not is_on_floor() and vertical_input != 0.0: # If against a wall, airborne, and pressing up or down...
		velocity.y = vertical_input * climb_speed # Move vertically along the wall.
	elif not is_on_floor(): # If airborne and not actively climbing or jumping...
		velocity += get_gravity() * delta # Apply gravity, scaled by the physics-frame duration.

	if not wall_jumped: # Don't overwrite the outward push on the exact frame of a wall jump.
		if move_input != 0.0: # If left or right is held...
			velocity.x = move_toward(velocity.x, move_input * speed, acceleration * delta) # Accelerate toward the chosen walking speed.
		else: # If neither left nor right is held...
			velocity.x = move_toward(velocity.x, 0.0, friction * delta) # Slow horizontal movement toward a stop.

	# Only try to grab ledges while airborne, falling, and moving toward a side.
	if not is_on_floor() and velocity.y >= 0.0 and move_input != 0.0:
		if _try_grab_ledge(signi(move_input)): # Check for a ledge in the direction the player is moving.
			return # The grab function positioned the player, so skip regular movement this frame.

	move_and_slide() # Move the character and resolve collisions using its velocity.


func _try_grab_ledge(direction: int) -> bool: # Checks for a reachable ledge on the specified side.
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state # Get access to physics ray queries for this world.
	var side_offset := Vector2(direction * (body_half_width + ledge_probe_distance), 0.0) # Set the horizontal distance of the wall-check rays.
	var wall_origin := global_position + Vector2(0.0, -body_half_height * 0.2) # Start the wall ray around the player's upper torso.
	var wall_hit: Dictionary = _raycast(space_state, wall_origin, wall_origin + side_offset) # Check whether a wall is beside the player.

	if wall_hit.is_empty(): # If the ray found no wall...
		return false # ...there is no ledge to grab on this side.

	# Check that the upper part of the player's body has room beside the wall.
	var clear_origin := global_position + Vector2(0.0, -body_half_height + 2.0) # Start a second ray near the top of the collision shape.
	var clear_hit: Dictionary = _raycast(space_state, clear_origin, clear_origin + side_offset) # Check whether the space above the wall is clear.
	if not clear_hit.is_empty(): # If the upper ray also hits a wall...
		return false # ...the player does not have room to hang here.

	# Look down just beyond the wall to find the ledge's horizontal top surface.
	var ledge_x: float = wall_hit["position"].x # Use the wall collision's x-coordinate as the ledge edge.
	var probe_x: float = global_position.x + direction * (body_half_width + ledge_probe_distance) # Place the downward ray just beyond the player's side.
	var top_from := Vector2(probe_x, global_position.y - body_half_height - max_ledge_reach) # Start the top-surface ray above the player.
	var top_to := Vector2(probe_x, global_position.y + body_half_height + ledge_probe_distance) # End the top-surface ray below the player's feet.
	var top_hit: Dictionary = _raycast(space_state, top_from, top_to) # Find the surface directly below the probe point.

	if top_hit.is_empty(): # If no surface was found below the probe...
		return false # ...there is no platform top to grab.
	if top_hit["normal"].y > -0.5: # If the hit surface is not facing mostly upward...
		return false # ...do not treat it as a ledge top.

	var top_y: float = top_hit["position"].y # Save the vertical position of the detected ledge top.
	if top_y < global_position.y - body_half_height - max_ledge_reach: # If the ledge is too far above the player...
		return false # ...it is outside the configured reach.
	if top_y > global_position.y + body_half_height: # If the ledge is below the player's feet...
		return false # ...it is too low to grab.

	hang_direction = direction # Remember which way the player is facing the ledge.
	ledge_position = Vector2(ledge_x, top_y) # Store the detected ledge edge and top height.
	hang_position = Vector2( # Calculate where the player's center should sit while hanging.
		ledge_x - direction * (body_half_width + 2.0), # Keep the collision shape just outside the wall.
		top_y + body_half_height * 0.6 # Place the player below the ledge top.
	)
	global_position = hang_position # Snap the player to the calculated hanging position.
	velocity = Vector2.ZERO # Stop all movement while the player is hanging.
	is_hanging = true # Mark the player as hanging so normal movement pauses.
	return true # Tell the physics function that a ledge grab succeeded.


func _handle_hanging(jump_pressed: bool) -> void: # Handles controls while the player is hanging from a ledge.
	velocity = Vector2.ZERO # Keep the player stationary while attached.
	global_position = hang_position # Correct any drift and keep the player at the grab point.

	if Input.is_action_just_pressed("ui_up"): # If up is pressed while hanging...
		global_position = Vector2( # ...move the player onto the platform above.
			ledge_position.x + hang_direction * (body_half_width + 2.0), # Place the player on the platform side of the ledge.
			ledge_position.y - body_half_height # Place the player's feet level with the top surface.
		)
		is_hanging = false # Resume normal movement after climbing up.
	elif jump_pressed: # If jump is pressed instead...
		is_hanging = false # ...release the ledge.
		velocity = Vector2(-hang_direction * wall_jump_push, jump_velocity * 0.7) # Push away and upward from the ledge.
	elif Input.is_action_just_pressed("ui_down"): # If down is pressed instead...
		is_hanging = false # ...release the ledge.
		velocity.y = 80.0 # Start falling downward.


func _raycast( # Helper function that sends a ray through the physics world.
	space_state: PhysicsDirectSpaceState2D, # The physics-world query object used to run the ray.
	from: Vector2, # The ray's starting point in global coordinates.
	to: Vector2 # The ray's ending point in global coordinates.
) -> Dictionary: # Returns hit information, or an empty dictionary if nothing was hit.
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()]) # Build a ray query that uses this player's collision mask and ignores the player itself.
	query.collide_with_areas = false # Only let the ray detect physics bodies, not Area2D nodes.
	query.collide_with_bodies = true # Allow the ray to detect StaticBody2D and other physics bodies.
	return space_state.intersect_ray(query) # Run the ray and return the collision result
