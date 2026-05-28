@tool
extends EditorPlugin
const debugging:bool = false
var interface = load("res://addons/ShaderToTab/Interface/Interface.tscn").instantiate()
var container:Control
var tab_title = "Shader Editor"
var last_selected_dock:String = "2D"
var settings_data:Dictionary = {
	"plugins/ShaderToTab/file_explorer":           "opt_filesSystem",
	"plugins/ShaderToTab/reveal_ingnore_addons":   "opt_ignore_addn",
	"plugins/ShaderToTab/reveal_in_file_explorer": "opt_reveal_file",
	"plugins/ShaderToTab/switch_pannels":          "opt_switch_pannels",
	"plugins/ShaderToTab/hide_editor_side_panel":  "opt_hide_side_panel",
}
var toolbar_button:Button # The button be hidden
var toolbar_values:Dictionary = { "posix": 0 }

var shader_editor # EditorDock only in 4.6
var shader_editor_container:Control

func _init() -> void: # Track screen changes
	# Create and add dock holder
	container = Control.new();
	container.name = tab_title
	#container.visible = false # Required to toggle visibility_changed
	container.visible = true # Required to toggle visibility_changed

#func _enter_tree() -> void:
func _install() -> void:
	await get_tree().create_timer(1).timeout

	var fileSystem := EditorInterface.get_resource_filesystem()
	if fileSystem.is_connected("filesystem_changed", _install):
		fileSystem.disconnect("filesystem_changed", _install)

	var settings:Dictionary = {}
	var editor_settings:EditorSettings = get_editor_interface().get_editor_settings()
	for key in settings_data.keys():
		if editor_settings.has_setting(key):
			settings[ key ] = {
				"button_var": settings_data[ key ],
				"value": editor_settings.get_setting(key)
			}

	var last_position:DockSlot = DockSlot.DOCK_SLOT_LEFT_UL
	if editor_settings.has_setting("plugins/ScriptToTab/dock_last_position"):
		var pos_value = editor_settings.get_setting("plugins/ScriptToTab/dock_last_position")
		if pos_value is int and pos_value > -1:
			last_position = pos_value as DockSlot
		

	#connect("main_screen_changed", on_scene_change)
	add_control_to_dock(last_position, container)
	var editor_interface = get_editor_interface()
	interface.settings = settings
	container.add_child(interface) # Move the script editor to holder
	shader_editor_container = MarginContainer.new()
	for child in shader_editor.get_children():
		child.reparent(shader_editor_container)
	interface.ScriptEdit = shader_editor_container
	interface.FileSystem = editor_interface.get_file_system_dock()
	interface._install()
	interface.size = container.size
	interface.connect('settings_changed', save_settings)

func focus_on_tab() -> void:
	if container and container.get_parent():
		container.get_parent().current_tab = container.get_parent().get_tab_idx_from_control(container)
	else:
		print("no parent")

func get_toolbar():
	# Find button in classic editor container
	var TopControl = get_editor_interface().get_base_control().get_child(0).get_child(0)
	var bar = null
	for toolbar in TopControl.get_children():
		if bar: break
		for child in toolbar.get_children():
			if child.name and child.name == "Script":
				bar = toolbar; break
	return bar


func save_settings():
	var editor_settings:EditorSettings = get_editor_interface().get_editor_settings()
	for key:String in settings_data.keys():
		editor_settings.set_setting(key, interface.options_buttons[ settings_data[key] ].button_pressed)

func _exit_tree() -> void:
	if debugging: return

	for child in shader_editor_container.get_children():
		child.reparent(shader_editor)

	interface.disconnect('settings_changed', save_settings)
	var dock_slot:DockSlot = get_dock_enum(container.get_parent()) as DockSlot
	var editor_settings:EditorSettings = get_editor_interface().get_editor_settings()
	editor_settings.set_setting("plugins/ScriptToTab/dock_last_position", dock_slot)
	interface._uninstall()
	container.remove_child(interface)
	remove_control_from_docks(container)

func get_dock_enum(node:Node) -> int:
	var dock_slot_map: Dictionary = {
		"DockSlotLeftUL": EditorPlugin.DOCK_SLOT_LEFT_UL,
		"DockSlotLeftBL": EditorPlugin.DOCK_SLOT_LEFT_BL,
		"DockSlotLeftUR": EditorPlugin.DOCK_SLOT_LEFT_UR,
		"DockSlotLeftBR": EditorPlugin.DOCK_SLOT_LEFT_BR,
		"DockSlotRightUL": EditorPlugin.DOCK_SLOT_RIGHT_UL,
		"DockSlotRightBL": EditorPlugin.DOCK_SLOT_RIGHT_BL,
		"DockSlotRightUR": EditorPlugin.DOCK_SLOT_RIGHT_UR,
		"DockSlotRightBR": EditorPlugin.DOCK_SLOT_RIGHT_BR
	}
	if dock_slot_map.has(node.name):
		return dock_slot_map[node.name]
	return -1

func get_shader_editor():
	var base := get_editor_interface().get_base_control()
	#print(get_editor_interface().get_base_control().get_children())
	var version_info = Engine.get_version_info()
	var v = str(version_info.major) + "." + str(version_info.minor)
	if v == "4.6": return _find_node_recursive(base, "Shader Editor")
	return _find_node_recursive(base, "ShaderEditor", true)

func _find_node_recursive(root: Node, target: String, partial:bool = false) -> Node:
	if partial and root.name.to_lower().find(target.to_lower()) > -1:
		return root
	if root.name == target:
		return root
	for c in root.get_children():
		var found = _find_node_recursive(c, target, partial)
		if found: return found
	return null

func _ready():
	shader_editor = get_shader_editor()
	print(shader_editor)
	if debugging: return
	var fileSystem := EditorInterface.get_resource_filesystem()
	if fileSystem.is_scanning():
		fileSystem.connect("filesystem_changed", _install)
	else:
		_install()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_T and Input.is_key_pressed(KEY_CTRL) and !Input.is_key_pressed(KEY_SHIFT) and event.pressed:
		container.get_parent().visible = !container.get_parent().visible
