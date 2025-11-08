# ResultItem.gd
@tool
extends PanelContainer

var product_data: Dictionary
var plugin_ref: EditorPlugin

@onready var product_label = $MarginContainer/VBoxContainer/ProductLabel
@onready var thumbnail_texture = $MarginContainer/VBoxContainer/ThumbnailTexture
@onready var import_button = $MarginContainer/VBoxContainer/ImportButton


func set_product_data(data: Dictionary, plugin: EditorPlugin):
    product_data = data
    plugin_ref = plugin
    
    product_label.text = data.get("mainImageAlt", data.get("name", "Unknown Product"))
    
    # Load thumbnail
    var item_no = data.get("itemNo", "")
    var image_url = data.get("mainImageUrl", "")
    
    if plugin_ref and item_no and image_url:
        var texture = plugin_ref.get_thumbnail_icon(item_no, image_url)
        if texture:
            thumbnail_texture.texture = texture


func _on_import_button_pressed():
    if plugin_ref:
        var item_no = product_data.get("itemNo", "")
        var item_name = product_data.get("name", "Unknown")
        plugin_ref.import_model(item_no, item_name)