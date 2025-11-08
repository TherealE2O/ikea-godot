# IKEABrowserDock.gd
@tool
extends Control

var plugin_ref: EditorPlugin

# UI elements
var search_edit: LineEdit
var status_label: Label
var results_container: GridContainer
var region_label: Label
var prefs_button: Button


func set_plugin(plugin: EditorPlugin) -> void:
    plugin_ref = plugin
    _create_ui()
    update_region_label()


func _create_ui():
    # Clear any existing children
    for child in get_children():
        child.queue_free()
    
    var margin = MarginContainer.new()
    margin.anchor_right = 1.0
    margin.anchor_bottom = 1.0
    margin.offset_right = -16
    margin.offset_bottom = -16
    add_child(margin)
    
    var vbox = VBoxContainer.new()
    margin.add_child(vbox)
    
    # Top row with region info and preferences
    var top_hbox = HBoxContainer.new()
    vbox.add_child(top_hbox)
    
    region_label = Label.new()
    region_label.text = "Region: IE - Language: EN"
    region_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_hbox.add_child(region_label)
    
    var spacer = Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_hbox.add_child(spacer)
    
    prefs_button = Button.new()
    prefs_button.text = "Preferences"
    prefs_button.pressed.connect(_on_preferences_button_pressed)
    top_hbox.add_child(prefs_button)
    
    # Search box
    var search_hbox = HBoxContainer.new()
    vbox.add_child(search_hbox)
    
    search_edit = LineEdit.new()
    search_edit.placeholder_text = "Search IKEA products..."
    search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search_edit.text_changed.connect(_on_search_edit_text_changed)
    search_hbox.add_child(search_edit)
    
    # Status label
    status_label = Label.new()
    status_label.text = "Enter search terms to find IKEA products"
    vbox.add_child(status_label)
    
    # Results area
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(scroll)
    
    results_container = GridContainer.new()
    results_container.columns = 2
    scroll.add_child(results_container)


func update_region_label():
    if plugin_ref and region_label:
        region_label.text = "Region: %s - Language: %s" % [plugin_ref.country.to_upper(), plugin_ref.language.to_upper()]


func _on_search_edit_text_changed(new_text: String):
    if plugin_ref:
        plugin_ref.search_products(new_text)


func update_search_results():
    if not results_container:
        return
        
    # Clear previous results
    for child in results_container.get_children():
        child.queue_free()
    
    if plugin_ref.search_results.is_empty():
        if search_edit.text.length() > 0:
            status_label.text = "No products or 3D model found for: " + search_edit.text
        else:
            status_label.text = "Enter search terms to find IKEA products"
        return
    
    status_label.text = "Found %d products" % plugin_ref.search_results.size()
    
    # Create result items
    for result in plugin_ref.search_results:
        var result_item = _create_result_item(result)
        results_container.add_child(result_item)


func _create_result_item(result: Dictionary) -> Control:
    var panel = PanelContainer.new()
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_right", 4)
    margin.add_theme_constant_override("margin_top", 4)
    margin.add_theme_constant_override("margin_left", 4)
    margin.add_theme_constant_override("margin_bottom", 4)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    
    var name_label = Label.new()
    name_label.text = result.get("mainImageAlt", result.get("name", "Unknown Product"))
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    
    var texture_rect = TextureRect.new()
    texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    texture_rect.custom_minimum_size = Vector2(100, 100)
    
    var import_button = Button.new()
    import_button.text = "Import"
    
    vbox.add_child(name_label)
    vbox.add_child(texture_rect)
    vbox.add_child(import_button)
    margin.add_child(vbox)
    panel.add_child(margin)
    
    # Add some styling
    var style_box = StyleBoxFlat.new()
    style_box.bg_color = Color(0.2, 0.2, 0.2, 0.5)
    style_box.border_width_bottom = 2
    style_box.border_width_top = 2
    style_box.border_width_left = 2
    style_box.border_width_right = 2
    style_box.border_color = Color(0.4, 0.4, 0.4)
    style_box.corner_radius_top_left = 4
    style_box.corner_radius_top_right = 4
    style_box.corner_radius_bottom_left = 4
    style_box.corner_radius_bottom_right = 4
    panel.add_theme_stylebox_override("panel", style_box)
    
    # Load thumbnail
    var item_no = result.get("itemNo", "")
    var image_url = result.get("mainImageUrl", "")
    
    if plugin_ref and item_no and image_url:
        var texture = plugin_ref.get_thumbnail_icon(item_no, image_url)
        if texture:
            texture_rect.texture = texture
    
    # Connect button
    import_button.pressed.connect(_on_import_button_pressed.bind(item_no, result.get("name", "Unknown")))
    
    return panel


func _on_import_button_pressed(item_no: String, item_name: String):
    if plugin_ref:
        plugin_ref.import_model(item_no, item_name)


func _on_preferences_button_pressed():
    # Create preferences dialog
    var dialog = AcceptDialog.new()
    dialog.title = "IKEA Browser Preferences"
    dialog.dialog_hide_on_ok = true
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    
    var grid = GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 4)
    
    var country_label = Label.new()
    country_label.text = "Country:"
    var country_edit = LineEdit.new()
    country_edit.text = plugin_ref.country if plugin_ref else "ie"
    
    var language_label = Label.new()
    language_label.text = "Language:"
    var language_edit = LineEdit.new()
    language_edit.text = plugin_ref.language if plugin_ref else "en"
    
    var debug_check = CheckBox.new()
    debug_check.text = "Debug Mode"
    debug_check.button_pressed = plugin_ref.debug if plugin_ref else false
    
    grid.add_child(country_label)
    grid.add_child(country_edit)
    grid.add_child(language_label)
    grid.add_child(language_edit)
    
    vbox.add_child(grid)
    vbox.add_child(debug_check)
    dialog.add_child(vbox)
    
    # Add to scene tree
    var editor_interface = EditorInterface.get_singleton()
    if editor_interface:
        editor_interface.get_base_control().add_child(dialog)
    else:
        get_tree().root.add_child(dialog)
        
    dialog.popup_centered(Vector2(300, 150))
    
    # Connect using a named method instead of lambda
    dialog.confirmed.connect(_on_preferences_confirmed.bind(dialog, country_edit, language_edit, debug_check))


func _on_preferences_confirmed(dialog: AcceptDialog, country_edit: LineEdit, language_edit: LineEdit, debug_check: CheckBox):
    if plugin_ref:
        plugin_ref.set_preferences(country_edit.text.strip_edges(), language_edit.text.strip_edges(), debug_check.button_pressed)
    dialog.queue_free()