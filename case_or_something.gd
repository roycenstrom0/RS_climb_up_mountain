extends Area2D

# Emitted once, after the item is added to the inventory.
signal case_opened(item_name: String)

@export var player_group: StringName = &"player"
@export var interact_action: StringName = &"interact"
@export var prompt_text: String = "Press E to open"

# Each item has the same chance of being chosen.
const ITEMS: Array[String] = [
	"Emergency Kit",
	"Poison Recovery",
	"Adrenaline Shot",
]

var opened: bool = false
var player_in_range: Node2D = null

# These nodes are included in loot_case.tscn. They are optional if you use
# this script on your own case: replace them with your own visuals or UI.
@onready var closed_visual := get_node_or_null("Closed") as CanvasItem
@onready var open_visual := get_node_or_null("Open") as CanvasItem
@onready var prompt := get_node_or_null("Prompt") as Label


func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_update_visuals()
	if prompt != null:
		prompt.hide()

	if not InputMap.has_action(interact_action):
		push_warning("Loot case: Add the 'interact' action in Project Settings > Input Map.")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group):
		player_in_range = body
		if prompt != null:
			prompt.text = "Already opened" if opened else prompt_text
			prompt.show()


func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		if prompt != null:
			prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if opened or not is_instance_valid(player_in_range):
		return

	if InputMap.has_action(interact_action) and event.is_action_pressed(interact_action):
		# Prevent a single keypress from opening several overlapping cases.
		get_viewport().set_input_as_handled()
		_open_case()


func _open_case() -> void:
	if opened:
		return

	# Don't open or lose the item if the inventory hasn't been set up.
	var inventory := get_node_or_null("/root/CaseInventory")
	if inventory == null or not inventory.has_method("add_item"):
		push_error("Loot case: Add case_inventory.gd as an Autoload named CaseInventory.")
		if prompt != null:
			prompt.text = "Inventory missing (see Output)"
		return

	var item_name: String = ITEMS[randi_range(0, ITEMS.size() - 1)]
	opened = true
	_update_visuals()
	if prompt != null:
		prompt.text = "You found: %s" % item_name
	inventory.call("add_item", item_name)
	case_opened.emit(item_name)


func _update_visuals() -> void:
	if closed_visual != null:
		closed_visual.visible = not opened
	if open_visual != null:
		open_visual.visible = opened
