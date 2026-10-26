extends Area2D

## Assign the scene for the next world in the Inspector.
## NOTE: this value is stored per-instance in the scene that *owns* this node,
## so every portal placed in every world needs its own assignment.
@export var next_world: PackedScene
@export var player_group: StringName = &"player"

var is_changing_world: bool = false


func _ready() -> void:
	monitoring = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# Fail loudly in the editor/Output the moment the scene loads,
	# instead of only when the player touches the portal.
	if next_world == null:
		push_warning("Portal %s has no Next World assigned — it will not work." % get_path())
	else:
		print("Portal %s -> %s" % [get_path(), next_world.resource_path])


func _on_body_entered(body: Node2D) -> void:
	# Prevent the portal from trying to change scenes more than once.
	if is_changing_world:
		return

	if not body.is_in_group(player_group):
		return

	if next_world == null:
		push_error("Portal: Assign the Next World scene in the Inspector. (%s)" % get_path())
		return

	is_changing_world = true
	set_deferred(&"monitoring", false)  # stop further overlaps while we swap scenes

	# Godot 4 defers the actual switch to the end of the frame, so this is
	# safe to call from a physics callback. It returns an Error we can check.
	var err: Error = get_tree().change_scene_to_packed(next_world)
	if err != OK:
		is_changing_world = false
		set_deferred(&"monitoring", true)
		push_error("Portal: failed to change scene (%s), error %d" % [next_world.resource_path, err])
