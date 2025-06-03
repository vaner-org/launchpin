@tool
extends EditorPlugin

var run_button: Button
var main_hbox: HBoxContainer
var pinned_scene_id: int

var pin_icon: Texture2D
var save_icon: Texture2D
var missing_icon: Texture2D

func _on_project_settings_changed() -> void:
	_on_mouse_exited()

func _enter_tree():
	
	ProjectSettings.connect("settings_changed", _on_project_settings_changed)
	
	pin_icon = get_editor_interface().get_base_control().get_theme_icon("Pin", "EditorIcons")
	save_icon = get_editor_interface().get_base_control().get_theme_icon("Save", "EditorIcons")
	missing_icon = get_editor_interface().get_base_control().get_theme_icon("Info", "EditorIcons")
	
	var editor_run_bar = _find_run_bar()
	if editor_run_bar:
		main_hbox = _find_main_hbox(editor_run_bar)
		if main_hbox:
			run_button = Button.new()
			run_button.set_theme_type_variation("RunBarButton")
			run_button.set_focus_mode(Control.FOCUS_NONE)
			run_button.button_mask = 0
			_set_persistent_appearance(false)
			
			run_button.add_theme_constant_override("h_separation", 6)
			
			run_button.gui_input.connect(_on_gui_input)
			run_button.mouse_exited.connect(_on_mouse_exited)
			
			main_hbox.add_child(run_button)
			main_hbox.move_child(run_button, 0)

func _exit_tree():
	
	if ProjectSettings.is_connected("settings_changed", _on_project_settings_changed):
		ProjectSettings.disconnect("settings_changed", _on_project_settings_changed)
	
	if run_button:
		run_button.queue_free()
		run_button = null

func _set_main_scene(uid_path: String):
	ProjectSettings.set_setting("application/run/main_scene", uid_path)
	ProjectSettings.save()

func ensure_uid(path: String) -> int:
	return ResourceLoader.get_resource_uid(path)

func on_mouse_entered():
	run_button.disabled = false

func _on_mouse_exited():
	
	if pinned_scene_id:
		_set_persistent_appearance(true)
	else:
		run_button.text = ""
		_set_persistent_appearance(false)

func _on_gui_input(event: InputEvent):
	run_button.disabled = false
	if event is InputEventMouseButton and event.is_released():
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if pinned_scene_id:
					var pinned_scene_path = ResourceUID.id_to_text(pinned_scene_id)
					if FileAccess.file_exists(pinned_scene_path):
						if Input.is_key_label_pressed(KEY_SHIFT):
							_set_main_scene(pinned_scene_path)
							_set_persistent_appearance(true)
						else:
							get_editor_interface().play_custom_scene(ResourceUID.get_id_path(pinned_scene_id))
					else:
						_set_temporary_appearance(true)
						pinned_scene_id = 0
			MOUSE_BUTTON_RIGHT:
				var scene_root = get_tree().edited_scene_root
				if scene_root:
					var current_scene_path = scene_root.scene_file_path
					if FileAccess.file_exists(current_scene_path):
						run_button.text = current_scene_path.get_file().trim_suffix("." + current_scene_path.get_extension())
						pinned_scene_id = ensure_uid(current_scene_path)
						var pinned_scene_path = ResourceUID.id_to_text(pinned_scene_id)
						if Input.is_key_label_pressed(KEY_SHIFT):
							_set_main_scene(pinned_scene_path)
						_set_persistent_appearance(true)
					else:
						_set_temporary_appearance(false)
				else:
					_set_temporary_appearance(false)
			MOUSE_BUTTON_MIDDLE:
				if pinned_scene_id:
					var pinned_scene_path = ResourceUID.id_to_text(pinned_scene_id)
					if FileAccess.file_exists(pinned_scene_path):
						_set_main_scene(pinned_scene_path)
						_set_persistent_appearance(true)

func _set_temporary_appearance(missing: bool):
	if missing:
		run_button.icon = missing_icon
		run_button.set_tooltip_text("Pinned scene is missing.")
		run_button.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875, 0.5))
		run_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 0.875, 0.5))
		run_button.add_theme_color_override("icon_normal_color", Color(1,1,1,0.4))
		run_button.add_theme_color_override("icon_hover_color", Color(1,1,1,0.4))
	else:
		run_button.icon = save_icon
		run_button.set_tooltip_text("Please save current scene first.")

func _set_persistent_appearance(pinned: bool):
	run_button.icon = pin_icon
	if pinned:
		run_button.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875, 1.0))
		run_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 0.875, 1.0))
		if pinned_scene_id == ensure_uid(ProjectSettings.get_setting("application/run/main_scene")):
			run_button.set_tooltip_text("Left-click to run main scene.\nRight-click to pin current scene.")
			var accent_color = run_button.get_theme_color("accent_color", "Editor")
			run_button.add_theme_color_override("icon_normal_color", accent_color)
			run_button.add_theme_color_override("icon_hover_color", accent_color)
		else:
			run_button.set_tooltip_text("Left-click to run pinned scene.\nRight-click to pin current scene.\nShift or middle-click to set main scene.")
			run_button.add_theme_color_override("icon_normal_color", Color.WHITE)
			run_button.add_theme_color_override("icon_hover_color", Color.WHITE)
	else:
		run_button.add_theme_color_override("icon_normal_color", Color.WHITE)
		run_button.add_theme_color_override("icon_hover_color", Color.WHITE)
		run_button.set_tooltip_text("Right-click to pin current scene.")
		run_button.disabled = true

func _find_run_bar():
	var editor_interface = get_editor_interface()
	if editor_interface:
		var base_control = editor_interface.get_base_control()
		return _find_run_bar_in_children(base_control)
	return null

func _find_run_bar_in_children(node: Node) -> Node:
	if node.get_class() == "EditorRunBar":
		return node
	for child in node.get_children():
		var result = _find_run_bar_in_children(child)
		if result:
			return result
	return null

func _find_main_hbox(run_bar: Node) -> HBoxContainer:
	for child in run_bar.get_children():
		if child is HBoxContainer:
			return child
		for grandchild in child.get_children():
			if grandchild is HBoxContainer:
				return grandchild
	return null
