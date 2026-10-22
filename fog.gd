extends Area2D

# Attach this script to the Fog Area2D.
# The Fog must have a CollisionShape2D child.

@export var player_group: StringName = &"player"
@export var player_death_area_group: StringName = &"player_death_area"

var is_restarting: bool = false


func _ready() -> void:
	monitoring = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


# Detects the player's normal CharacterBody2D collision.
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group):
		_restart_scene()


# Detects a separate Area2D/CollisionShape2D used as a death hitbox.
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(player_death_area_group):
		_restart_scene()
		return

	# This also works when the death Area2D is a direct child of the player.
	var parent_node: Node = area.get_parent()
	if parent_node != null and parent_node.is_in_group(player_group):
		_restart_scene()


func _restart_scene() -> void:
	if is_restarting:
		return

	is_restarting = true
	# Deferred reloading avoids changing scenes during a physics callback.
	get_tree().call_deferred("reload_current_scene")
