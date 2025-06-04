@tool
extends EditorPlugin

var run_button: Button
var pinned_scene_id: int
var last_scene_id: int
var scene_history: Array[int]
var current_scene_id: int

var pin_icon: Texture2D
var save_icon: Texture2D
var missing_icon: Texture2D
var history_icon: Texture2D

signal mouse_exited

func _on_project_settings_changed() -> void:
	_set_persistent_appearance()

func _on_project_scene_changed(scene):
	if scene:
		current_scene_id = ensure_uid(scene.scene_file_path)
	else:
		current_scene_id = 0
	_set_persistent_appearance()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		var playing_scene = EditorInterface.get_playing_scene()
		if playing_scene:
			last_scene_id = ensure_uid(playing_scene)
			scene_history.erase(last_scene_id)
			scene_history.append(last_scene_id)
			_set_persistent_appearance()

func _on_mouse_exited():
	emit_signal("mouse_exited")
	if not (last_scene_id or pinned_scene_id):
		run_button.disabled = true

func ensure_uid(path: String) -> int:
	return ResourceLoader.get_resource_uid(path)

func _set_main_scene(uid: int):
	ProjectSettings.set_setting("application/run/main_scene", ResourceUID.id_to_text(uid))
	ProjectSettings.save()

func run_scene(uid: int = 0):
	if uid:
		pass
	elif pinned_scene_id:
		uid = pinned_scene_id
	elif last_scene_id:
		uid = last_scene_id
	else:
		EditorInterface.play_main_scene()
		return
	get_editor_interface()
	EditorInterface.play_custom_scene(ResourceUID.get_id_path(uid)) # uid:// paths do not work

func _enter_tree():
	
	Engine.register_singleton("Launchpin", self)
	ProjectSettings.connect("settings_changed", _on_project_settings_changed)
	self.connect("scene_changed", _on_project_scene_changed)
	
	var base_control = EditorInterface.get_base_control()
	history_icon = base_control.get_theme_icon("History", "EditorIcons")
	pin_icon = base_control.get_theme_icon("Pin", "EditorIcons")
	save_icon = base_control.get_theme_icon("Save", "EditorIcons")
	missing_icon = base_control.get_theme_icon("Info", "EditorIcons")
	
	var editor_run_bar = _find_run_bar()
	if editor_run_bar:
		var main_hbox = _find_main_hbox(editor_run_bar)
		if main_hbox:
			run_button = Button.new()
			run_button.set_theme_type_variation("RunBarButton")
			run_button.add_theme_constant_override("h_separation", 6)
			run_button.set_focus_mode(Control.FOCUS_NONE)
			run_button.button_mask = 0
			
			run_button.gui_input.connect(_on_gui_input)
			run_button.mouse_exited.connect(_on_mouse_exited)
			
			main_hbox.add_child(run_button)
			main_hbox.move_child(run_button, 0)
			
			_set_persistent_appearance()

func _exit_tree():
	
	Engine.unregister_singleton("Launchpin")
	ProjectSettings.disconnect("settings_changed", _on_project_settings_changed)
	self.disconnect("scene_changed", _on_project_scene_changed)
	
	if run_button:
		run_button.queue_free()
		run_button = null

func _set_temporary_appearance(missing: bool):
	if missing:
		run_button.icon = missing_icon
		run_button.set_tooltip_text("Scene is missing.")
		run_button.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875, 0.5))
		run_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 0.875, 0.5))
		run_button.add_theme_color_override("icon_normal_color", Color(1,1,1,0.4))
		run_button.add_theme_color_override("icon_hover_color", Color(1,1,1,0.4))
	else:
		run_button.icon = save_icon
		run_button.set_tooltip_text("Please save current scene first.")
		run_button.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875, 0.5))
		run_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 0.875, 0.5))
		run_button.add_theme_color_override("icon_normal_color", Color(1,1,1,0.4))
		run_button.add_theme_color_override("icon_hover_color", Color(1,1,1,0.4))
	
	await mouse_exited
	_set_persistent_appearance()

func _set_persistent_appearance():
	
	if pinned_scene_id and ResourceUID.has_id(pinned_scene_id):
		var pinned_scene_path = ResourceUID.get_id_path(pinned_scene_id)
		run_button.disabled = false
		run_button.text = pinned_scene_path.get_file().trim_suffix("." + pinned_scene_path.get_extension())
		run_button.icon = pin_icon
		run_button.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875, 1.0))
		run_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 0.875, 1.0))
		
		var pinned_scene_type = ""
		
		if pinned_scene_id == ensure_uid(ProjectSettings.get_setting("application/run/main_scene")):
			pinned_scene_type = "main"
			var accent_color = run_button.get_theme_color("accent_color", "Editor")
			run_button.add_theme_color_override("icon_normal_color", accent_color)
			run_button.add_theme_color_override("icon_hover_color", accent_color)
		elif pinned_scene_id == current_scene_id:
			pinned_scene_type = "current"
			run_button.add_theme_color_override("icon_normal_color", Color.WHITE)
			run_button.add_theme_color_override("icon_hover_color", Color.WHITE)
		else:
			pinned_scene_type = "pinned"
			run_button.add_theme_color_override("icon_normal_color", Color.WHITE)
			run_button.add_theme_color_override("icon_hover_color", Color.WHITE)
		
		var right_click_action = ""
		var candidate_scene_type = ""
		var addendum = ""
		if pinned_scene_id == current_scene_id:
			right_click_action = "unpin"
			candidate_scene_type = pinned_scene_type
		else:
			right_click_action = "pin"
			candidate_scene_type = "current"
			addendum = " instead"
		var tooltip = "Left-click to run "+pinned_scene_type+" scene.\nRight-click to "+right_click_action+" "+candidate_scene_type+" scene" + addendum + "."
		
		if pinned_scene_type == "current":
			tooltip += "\nShift or middle-click to set main scene."
		run_button.set_tooltip_text(tooltip)
		return
	if last_scene_id and ResourceUID.has_id(last_scene_id):
		pinned_scene_id = 0
		var last_scene_path = ResourceUID.get_id_path(last_scene_id)
		run_button.disabled = false
		run_button.text = last_scene_path.get_file().trim_suffix("." + last_scene_path.get_extension())
		run_button.icon = history_icon
		run_button.add_theme_color_override("font_color", Color(0.875, 0.875, 0.875, 1.0))
		run_button.add_theme_color_override("font_hover_color", Color(0.875, 0.875, 0.875, 1.0))
		var last_scene_type = ""
		var candidate_scene_type = "current"
		if last_scene_id == ensure_uid(ProjectSettings.get_setting("application/run/main_scene")):
			last_scene_type = "main"
			var accent_color = run_button.get_theme_color("accent_color", "Editor")
			run_button.add_theme_color_override("icon_normal_color", accent_color)
			run_button.add_theme_color_override("icon_hover_color", accent_color)
			if last_scene_id == current_scene_id:
				candidate_scene_type = "main"
		else:
			last_scene_type = "last"
			run_button.add_theme_color_override("icon_normal_color", Color.WHITE)
			run_button.add_theme_color_override("icon_hover_color", Color.WHITE)
		var tooltip = "Left-click to run "+last_scene_type+" scene.\nRight-click to pin "+candidate_scene_type+" scene."
		if last_scene_type != "main":
			tooltip += "\nShift or middle-click to set main scene."
		run_button.set_tooltip_text(tooltip)
		return
	elif scene_history.size() > 0:
		scene_history.pop_back()
		last_scene_id = scene_history[scene_history.size()-1]
		_set_persistent_appearance()
		return
	
	pinned_scene_id = 0
	last_scene_id = 0
	run_button.icon = history_icon
	run_button.text = "History"
	run_button.add_theme_color_override("icon_normal_color", Color.WHITE)
	run_button.add_theme_color_override("icon_hover_color", Color.WHITE)
	run_button.set_tooltip_text("Right-click to pin current scene.")
	run_button.disabled = true

func _on_gui_input(event: InputEvent):
	run_button.disabled = false
	if event is InputEventMouseButton and event.is_released():
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var id = pinned_scene_id if pinned_scene_id else last_scene_id
				if id:
					if ResourceUID.has_id(id):
						if Input.is_key_label_pressed(KEY_SHIFT):
							_set_main_scene(id)
							_set_persistent_appearance()
						else:
							run_scene(id)
					else:
						_set_temporary_appearance(true)
			MOUSE_BUTTON_RIGHT:
				var scene_root = get_tree().edited_scene_root
				if scene_root:
					var current_scene_path = scene_root.scene_file_path
					if FileAccess.file_exists(current_scene_path):
						var current_scene_id = ensure_uid(current_scene_path)
						if pinned_scene_id != current_scene_id:
							pinned_scene_id = current_scene_id
							if Input.is_key_label_pressed(KEY_SHIFT):
								_set_main_scene(pinned_scene_id)
						else:
							pinned_scene_id = 0
						_set_persistent_appearance()
					else:
						_set_temporary_appearance(false)
				else:
					_set_temporary_appearance(false)
			MOUSE_BUTTON_MIDDLE: # promote scene to main scene
				var id = pinned_scene_id if pinned_scene_id else last_scene_id
				if id:
					if ResourceUID.has_id(id):
						_set_main_scene(id)
						_set_persistent_appearance()
					else:
						_set_temporary_appearance(true)

func _find_run_bar():
	var base_control = EditorInterface.get_base_control()
	return _find_run_bar_in_children(base_control)

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
