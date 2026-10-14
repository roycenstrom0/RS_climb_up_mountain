extends CharacterBody2D

@export var body_half_width: float = 8.0
@export var body_half_height: float = 16.0
@export var speed: float = 300.0
@export var acceleration: float = 1800.0
@export var friction: float = 2200.0
@export var climb_speed: float = 150.0
@export var jump_velocity: float = -400.0
@export var wall_jump_push: float = 180.0
@export var max_ledge_reach: float = 40.0
@export var ledge_probe_distance: float = 10.0

# Energy settings
@export var max_energy: float = 100.0
@export var space_energy_cost: float = 10.0 # Energy lost each time the Spacebar is pressed.
@export var climb_energy_drain: float = 15.0 # Energy lost per second while climbing with Up/Down.
@export var hang_energy_drain: float = 15.0 # Energy lost per second while hanging on a ledge.
@export var energy_recharge_rate: float = 40.0 # Energy restored per second when recovering.
@export var normal_recharge_delay: float = 0.6 # Delay before recharging after using energy.
@export var exhausted_recharge_delay: float = 1.5 # Wait time before recharging after hitting 0 energy.
@export var require_floor_to_recharge: bool = false # Set true if you only want to recharge on the ground.
@export var energy_bar: ProgressBar

var is_hanging: bool = false
var ledge_position: Vector2 = Vector2.ZERO
var hang_position: Vector2 = Vector2.ZERO
var hang_direction: int = 1

var current_energy: float = 100.0
var is_exhausted: bool = false
var recharge_timer: float = 0.0


func _ready() -> void:
	current_energy = max_energy
	_setup_energy_bar()
	_update_energy_bar()


func _physics_process(delta: float) -> void:
	var move_input: float = Input.get_axis("ui_left", "ui_right")
	var vertical_input: float = Input.get_axis("ui_up", "ui_down")
	var jump_pressed: bool = Input.is_action_just_pressed("ui_accept")
	var can_use_energy: bool = not is_exhausted and current_energy > 0.0
	var is_using_energy: bool = false

	# Drain energy whenever the Spacebar (ui_accept) is hit and the player has energy.
	if jump_pressed and can_use_energy:
		is_using_energy = true
		_drain_energy(space_energy_cost)

	if is_hanging:
		if hang_energy_drain > 0.0:
			is_using_energy = true
			_drain_energy(hang_energy_drain * delta)
		if is_exhausted:
			is_hanging = false
			velocity.y = 80.0
		else:
			_handle_hanging(jump_pressed)
			if not is_using_energy:
				_recharge_energy(delta)
			_update_energy_bar()
			return

	var touching_wall: bool = _is_next_to_wall()
	var wall_jumped: bool = can_use_energy and is_on_wall() and not is_on_floor() and jump_pressed
	var wants_to_climb: bool = vertical_input < 0.0 or (vertical_input > 0.0 and not is_on_floor())

	if is_on_floor() and jump_pressed and can_use_energy:
		velocity.y = jump_velocity
	elif wall_jumped:
		velocity.y = jump_velocity
		velocity.x = get_wall_normal().x * wall_jump_push
	elif can_use_energy and touching_wall and wants_to_climb:
		velocity.y = vertical_input * climb_speed
		is_using_energy = true
		_drain_energy(climb_energy_drain * delta)
	elif not is_on_floor():
		velocity += get_gravity() * delta

	if not wall_jumped:
		if move_input != 0.0:
			velocity.x = move_toward(velocity.x, move_input * speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if can_use_energy and not is_on_floor() and velocity.y >= 0.0 and move_input != 0.0:
		if _try_grab_ledge(signi(move_input)):
			_update_energy_bar()
			return

	move_and_slide()

	if not is_using_energy:
		_recharge_energy(delta)

	_update_energy_bar()


func _is_next_to_wall() -> bool:
	if is_on_wall():
		return true

	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var check_distance: float = body_half_width + 3.0
	var left_hit: Dictionary = _raycast(space_state, global_position, global_position + Vector2(-check_distance, 0.0))
	if not left_hit.is_empty():
		return true
	var right_hit: Dictionary = _raycast(space_state, global_position, global_position + Vector2(check_distance, 0.0))
	return not right_hit.is_empty()


func _drain_energy(amount: float) -> void:
	current_energy = maxf(current_energy - amount, 0.0)
	recharge_timer = normal_recharge_delay
	if current_energy <= 0.0:
		is_exhausted = true
		recharge_timer = exhausted_recharge_delay


func _recharge_energy(delta: float) -> void:
	if require_floor_to_recharge and not is_on_floor():
		return

	if recharge_timer > 0.0:
		recharge_timer = maxf(recharge_timer - delta, 0.0)
		return

	if current_energy < max_energy:
		current_energy = minf(current_energy + energy_recharge_rate * delta, max_energy)
		if is_exhausted and current_energy >= max_energy:
			is_exhausted = false


func _setup_energy_bar() -> void:
	if energy_bar == null:
		for child in find_children("*", "ProgressBar", true, false):
			energy_bar = child as ProgressBar
			break

	if energy_bar == null:
		energy_bar = ProgressBar.new()
		energy_bar.show_percentage = false
		energy_bar.size = Vector2(32.0, 6.0)
		energy_bar.position = Vector2(-16.0, -body_half_height - 14.0)
		add_child(energy_bar)

	energy_bar.min_value = 0.0
	energy_bar.max_value = max_energy
	energy_bar.step = 0.0
	energy_bar.value = current_energy


func _update_energy_bar() -> void:
	if energy_bar == null:
		return

	energy_bar.max_value = max_energy
	energy_bar.value = current_energy
	energy_bar.modulate = Color(1.0, 0.3, 0.3) if is_exhausted else Color(0.3, 1.0, 0.4)


func _try_grab_ledge(direction: int) -> bool:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var side_offset := Vector2(direction * (body_half_width + ledge_probe_distance), 0.0)
	var wall_origin := global_position + Vector2(0.0, -body_half_height * 0.2)
	var wall_hit: Dictionary = _raycast(space_state, wall_origin, wall_origin + side_offset)

	if wall_hit.is_empty():
		return false

	var clear_origin := global_position + Vector2(0.0, -body_half_height + 2.0)
	var clear_hit: Dictionary = _raycast(space_state, clear_origin, clear_origin + side_offset)
	if not clear_hit.is_empty():
		return false

	var ledge_x: float = wall_hit["position"].x
	var probe_x: float = global_position.x + direction * (body_half_width + ledge_probe_distance)
	var top_from := Vector2(probe_x, global_position.y - body_half_height - max_ledge_reach)
	var top_to := Vector2(probe_x, global_position.y + body_half_height + ledge_probe_distance)
	var top_hit: Dictionary = _raycast(space_state, top_from, top_to)

	if top_hit.is_empty():
		return false
	if top_hit["normal"].y > -0.5:
		return false

	var top_y: float = top_hit["position"].y
	if top_y < global_position.y - body_half_height - max_ledge_reach:
		return false
	if top_y > global_position.y + body_half_height:
		return false

	hang_direction = direction
	ledge_position = Vector2(ledge_x, top_y)
	hang_position = Vector2(
		ledge_x - direction * (body_half_width + 2.0),
		top_y + body_half_height * 0.6
	)
	global_position = hang_position
	velocity = Vector2.ZERO
	is_hanging = true
	return true


func _handle_hanging(jump_pressed: bool) -> void:
	velocity = Vector2.ZERO
	global_position = hang_position

	if Input.is_action_just_pressed("ui_up"):
		_drain_energy(space_energy_cost)
		global_position = Vector2(
			ledge_position.x + hang_direction * (body_half_width + 2.0),
			ledge_position.y - body_half_height
		)
		is_hanging = false
	elif jump_pressed:
		is_hanging = false
		velocity = Vector2(-hang_direction * wall_jump_push, jump_velocity * 0.7)
	elif Input.is_action_just_pressed("ui_down"):
		is_hanging = false
		velocity.y = 80.0


func _raycast(
	space_state: PhysicsDirectSpaceState2D,
	from: Vector2,
	to: Vector2
) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_ray(query)
