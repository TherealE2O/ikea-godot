# IkeaApiWrapper.gd
@tool
extends RefCounted

var country: String = "ie"
var language: String = "en"
var debug: bool = false
var cache_dir: String = ""


func _init():
    pass


func search(query: String) -> Array:
    # Implement IKEA search API call
    # This is a placeholder - you'd need to implement the actual HTTP request
    print("Searching IKEA for: ", query)
    
    # Return mock data for testing
    var results = []
    
    # Add different results based on search query
    var query_lower = query.to_lower()
    
    if query_lower.contains("chair") or query_lower.is_empty():
        results.append({
            "itemNo": "123.456.78",
            "name": "Comfort Office Chair",
            "mainImageAlt": "Ergonomic Office Chair with adjustable height",
            "mainImageUrl": "https://via.placeholder.com/150"
        })
    
    if query_lower.contains("table") or query_lower.is_empty():
        results.append({
            "itemNo": "987.654.32",
            "name": "Modern Wooden Table", 
            "mainImageAlt": "Contemporary wooden dining table",
            "mainImageUrl": "https://via.placeholder.com/150"
        })
    
    if query_lower.contains("lamp") or query_lower.is_empty():
        results.append({
            "itemNo": "555.333.11",
            "name": "Desk Lamp",
            "mainImageAlt": "Adjustable LED desk lamp",
            "mainImageUrl": "https://via.placeholder.com/150"
        })
    
    if query_lower.contains("shelf") or query_lower.is_empty():
        results.append({
            "itemNo": "444.222.99",
            "name": "Wall Shelf",
            "mainImageAlt": "Floating wall shelf unit",
            "mainImageUrl": "https://via.placeholder.com/150"
        })
    
    return results


func get_pip(item_no: String) -> Dictionary:
    # Simulate API call
    print("Fetching PIP for: ", item_no)
    
    # Return mock data based on item number
    var product_type = "Furniture"
    var style = "Modern"
    var price = "$99.99"
    
    if "123" in item_no:
        product_type = "Chair"
        style = "Office"
        price = "$149.99"
    elif "987" in item_no:
        product_type = "Table" 
        style = "Contemporary"
        price = "$199.99"
    elif "555" in item_no:
        product_type = "Lamp"
        style = "Minimalist"
        price = "$49.99"
    elif "444" in item_no:
        product_type = "Shelf"
        style = "Industrial"
        price = "$79.99"
    
    return {
        "name": "IKEA " + product_type,
        "price": price,
        "styleGroup": style,
        "typeName": product_type,
        "pipUrl": "https://www.ikea.com/us/en/p/" + item_no.replace(".", "-"),
        "mainImage": {
            "url": "https://via.placeholder.com/150"
        }
    }


func get_thumbnail(item_no: String, url: String) -> Texture2D:
    # Create a placeholder texture with item number displayed
    var image = Image.create(150, 150, false, Image.FORMAT_RGBA8)
    
    # Create a colored background based on item number hash
    var hash_val = item_no.hash()
    var hue = float(abs(hash_val) % 1000) / 1000.0
    var bg_color = Color.from_hsv(hue, 0.3, 0.8)
    image.fill(bg_color)
    
    # Add border
    var border_color = Color.from_hsv(hue, 0.6, 0.6)
    for x in range(150):
        for y in range(150):
            if x < 2 or x >= 148 or y < 2 or y >= 148:
                image.set_pixel(x, y, border_color)
    
    # Create a simple texture
    var texture = ImageTexture.create_from_image(image)
    return texture


func get_model(item_no: String) -> PackedScene:
    print("Creating model for: ", item_no)
    
    # Create a simple 3D scene with appropriate mesh
    var scene = PackedScene.new()
    var spatial = Node3D.new()
    spatial.name = "IKEA_Product_" + item_no.replace(".", "_")
    
    var mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "Mesh"
    
    # Create different meshes based on product type
    var mesh: Mesh
    var material = StandardMaterial3D.new()
    
    if "123" in item_no:  # Chair
        var box_mesh = BoxMesh.new()
        box_mesh.size = Vector3(0.8, 1.2, 0.8)
        mesh = box_mesh
        material.albedo_color = Color(0.2, 0.4, 0.8)  # Blue
    elif "987" in item_no:  # Table
        var box_mesh = BoxMesh.new()
        box_mesh.size = Vector3(2.0, 0.8, 1.0)
        mesh = box_mesh
        material.albedo_color = Color(0.6, 0.4, 0.2)  # Brown
    elif "555" in item_no:  # Lamp
        var cylinder_mesh = CylinderMesh.new()
        cylinder_mesh.top_radius = 0.1
        cylinder_mesh.bottom_radius = 0.1
        cylinder_mesh.height = 1.5
        mesh = cylinder_mesh
        material.albedo_color = Color(0.9, 0.9, 0.1)  # Yellow
    elif "444" in item_no:  # Shelf
        var box_mesh = BoxMesh.new()
        box_mesh.size = Vector3(1.5, 0.1, 0.8)
        mesh = box_mesh
        material.albedo_color = Color(0.7, 0.7, 0.7)  # Gray
    else:  # Default cube
        var box_mesh = BoxMesh.new()
        box_mesh.size = Vector3(1.0, 1.0, 1.0)
        mesh = box_mesh
        material.albedo_color = Color(0.8, 0.8, 0.8)  # Light gray
    
    mesh_instance.mesh = mesh
    mesh_instance.material_override = material
    
    spatial.add_child(mesh_instance)
    mesh_instance.owner = spatial
    
    # Pack the scene
    var error = ResourceSaver.save(scene, "user://temp_ikea_model.tres")
    if error == OK:
        return ResourceLoader.load("user://temp_ikea_model.tres")
    
    return scene


func format_item_no(item_no: String) -> String:
    return item_no.replace(".", "_")