@tool
extends EditorPlugin

var dock: Control

func _enter_tree():
	# Create and add the dock
	dock = preload("res://addons/ikea_api/ikea_browser_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree():
	# Remove the dock
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
