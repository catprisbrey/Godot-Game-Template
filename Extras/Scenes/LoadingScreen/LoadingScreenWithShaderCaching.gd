extends LoadingScreen

const QUADMESH_PLACEHOLDER = preload("res://Extras/Scenes/LoadingScreen/QuadMeshPlaceholder.tscn")

@export_dir var _spatial_shader_material_dir : String = "res://Extras/Materials/"
@export var _matching_extensions : Array[String] = [".tres", ".material", ".res"]
@export var _ignore_subfolders : Array[String] = [".", ".."]
@export var _cache_spatial_shader : bool = false
@export_file("*.tscn") var _cache_shaders_scene : String

var _caching_progress : float = 0.0 :
	set(value):
		if value <= _caching_progress:
			return
		_caching_progress = value
		update_total_loading_progress()

func is_loading_shader_cache():
	return _cache_spatial_shader and SceneLoader.is_loading_scene(_cache_shaders_scene)

func update_total_loading_progress():
	var partial_total = _scene_loading_progress
	if is_loading_shader_cache():
		partial_total += _caching_progress
		partial_total /= 2
	_total_loading_progress = partial_total

func _load_next_scene():
	if _changing_to_next_scene:
		return
	_changing_to_next_scene = true
	if is_loading_shader_cache():
		_show_all_draw_passes_once()
		await(get_tree().create_timer(0.25).timeout)
	SceneLoader.change_scene_to_resource()

func _show_all_draw_passes_once():
	var all_materials = _traverse_folders(_spatial_shader_material_dir)
	var total_material_count = all_materials.size()
	var cached_material_count = 0
	for material_path in all_materials:
		_load_material(material_path)
		cached_material_count += 1
		_caching_progress = float(cached_material_count) / total_material_count

func _traverse_folders(dir_path:String) -> PackedStringArray:
	var material_list:PackedStringArray = []
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_error("failed to access the path ", dir_path)
		return []
	if dir.list_dir_begin() != OK:
		push_error("failed to access the path ", dir_path)
		return []
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var matches : bool = false
			for extension in _matching_extensions:
				if file_name.ends_with(extension):
					matches = true
					break
			if matches:
				material_list.append(dir_path + file_name)
		else:
			var subfolder_name = file_name
			if not subfolder_name in _ignore_subfolders:
				material_list.append_array(_traverse_folders(dir_path + subfolder_name + "/"))
		file_name = dir.get_next()
	
	return material_list

func _load_material(path:String):
	var material_shower = QUADMESH_PLACEHOLDER.instantiate()
	var material := ResourceLoader.load(path) as Material
	material_shower.set_surface_override_material(0, material)
	%SpatialShaderTypeCaches.add_child(material_shower)
