extends Node

# Connect this signal to an inventory UI if you add one later.
signal item_added(item_name: String, new_total: int)

# Item counts remain available when you change scenes, because this script
# is added as an Autoload. They reset when the game closes.
var items: Dictionary = {
	"Emergency Kit": 0,
	"Poison Recovery": 0,
	"Adrenaline Shot": 0,
}


func add_item(item_name: String) -> void:
	var new_total: int = int(items.get(item_name, 0)) + 1
	items[item_name] = new_total
	print("You received: %s (total: %d)" % [item_name, new_total])
	item_added.emit(item_name, new_total)


func get_item_count(item_name: String) -> int:
	return int(items.get(item_name, 0))
