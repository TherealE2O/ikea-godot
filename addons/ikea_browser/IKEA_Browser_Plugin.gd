# IKEA_Browser_Plugin.gd
@tool
extends EditorPlugin

const IKEA_API_WRAPPER_GDS = preload("res://addons/ikea_browser/IkeaApiWrapper.gd")

var ikea_browser_dock: Control
var ikea_api: RefCounted
var search_results: Array = []
var thumbnails: Dictionary = {}
var last_item_no: String = ""
var last_pip: Dictionary = {}

# Preferences
var country: String = "ie"
var language: String = "en"
var debug: bool = false


func _enter_tree():
    # Initialize API wrapper
    ikea_api = IKEA_API_WRAPPER_GDS.new()
    
    # Load or set preferences
    _load_preferences()
    _initialize_api()
    
    # Create the dock
    ikea_browser_dock = preload("res://addons/ikea_browser/IKEABrowserDock.gd").new()
    
    # Set up references
    if ikea_browser_dock.has_method("set_plugin"):
        ikea_browser_dock.set_plugin(self)
    
    # Add the dock to the editor
    add_control_to_dock(DOCK_SLOT_RIGHT_BL, ikea_browser_dock)


func _exit_tree():
    # Remove the dock
    if ikea_browser_dock:
        remove_control_from_docks(ikea_browser_dock)
        ikea_browser_dock.queue_free()


func _load_preferences():
    var config = ConfigFile.new()
    var err = config.load("res://addons/ikea_browser/ikea_browser.cfg")
    if err == OK:
        country = config.get_value("preferences", "country", "ie")
        language = config.get_value("preferences", "language", "en")
        debug = config.get_value("preferences", "debug", false)


func _save_preferences():
    var config = ConfigFile.new()
    config.set_value("preferences", "country", country)
    config.set_value("preferences", "language", language)
    config.set_value("preferences", "debug", debug)
    
    # Ensure the directory exists
    var dir = DirAccess.open("res://addons/ikea_browser/")
    if not dir:
        DirAccess.make_dir_recursive_absolute("res://addons/ikea_browser/")
    
    config.save("res://addons/ikea_browser/ikea_browser.cfg")


func _initialize_api():
    if ikea_api:
        ikea_api.country = country
        ikea_api.language = language
        ikea_api.debug = debug
        ikea_api.cache_dir = "user://ikea_cache"


func set_preferences(new_country: String, new_language: String, new_debug: bool):
    country = new_country
    language = new_language
    debug = new_debug
    _save_preferences()
    _initialize_api()
    
    if ikea_browser_dock and ikea_browser_dock.has_method("update_region_label"):
        ikea_browser_dock.update_region_label()


func get_thumbnail_icon(item_no: String, url: String) -> Texture2D:
    if thumbnails.has(item_no):
        return thumbnails[item_no]
    
    # Load or download thumbnail
    var texture = ikea_api.get_thumbnail(item_no, url)
    if texture:
        thumbnails[item_no] = texture
    
    return texture


func import_model(item_no: String, item_name: String) -> void:
    var scene = ikea_api.get_model(item_no)
    if scene:
        # Add the scene to the current scene
        var instance = scene.instantiate()
        var editor_interface = get_editor_interface()
        var scene_tree = editor_interface.get_edited_scene_root()
        
        if scene_tree:
            scene_tree.add_child(instance)
            instance.owner = scene_tree
            
            # Set IKEA metadata
            instance.set_meta("ikea_item_no", item_no)
            instance.set_meta("ikea_item_name", item_name)
            instance.name = item_name + "_" + ikea_api.format_item_no(item_no)
            
            # Position at view center
            var viewport = editor_interface.get_editor_viewport_3d(0)
            if viewport:
                var camera = viewport.get_camera_3d()
                if camera:
                    var forward = -camera.global_transform.basis.z
                    instance.global_position = camera.global_position + forward * 5.0


func search_products(query: String) -> void:
    if query.length() > 0:
        # Call search directly - no async handling needed for mock data
        search_results = ikea_api.search(query)
    else:
        search_results = []
    
    # Update the UI
    if ikea_browser_dock and ikea_browser_dock.has_method("update_search_results"):
        ikea_browser_dock.update_search_results()


func get_product_info(item_no: String) -> Dictionary:
    if item_no == last_item_no and not last_pip.is_empty():
        return last_pip
    
    last_pip = ikea_api.get_pip(item_no)
    last_item_no = item_no
    return last_pip