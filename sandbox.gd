extends Node2D

func _on_boundry_area_entered(_area: Area2D) -> void:
	#Reset the scene when something has entered the area
	get_tree().reload_current_scene()
