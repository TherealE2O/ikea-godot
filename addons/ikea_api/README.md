# IKEA API Wrapper for Godot

A Godot addon that provides seamless integration with IKEA's product catalog, enabling you to search for products, retrieve product information, download thumbnails, and fetch 3D models (GLB format) directly within your Godot projects.

## Features

- **Product Search**: Search IKEA's catalog by product name or item number
- **Product Information**: Retrieve detailed product metadata (PIP data)
- **Thumbnail Downloads**: Download product images for UI previews
- **3D Model Downloads**: Fetch GLB models for direct import into Godot scenes
- **Smart Caching**: Automatic local caching to minimize API calls and improve performance
- **Async Operations**: Non-blocking HTTP requests using Godot's signal system
- **Multi-Region Support**: Configure country and language for region-specific catalogs
- **Error Handling**: Comprehensive error reporting with descriptive messages

## Installation

1. Copy the `addons/ikea_api/` directory to your Godot project's `addons/` folder
2. Enable the plugin in **Project → Project Settings → Plugins**
3. The `IkeaApiWrapper` class will now be available in your project

## Quick Start

```gdscript
extends Node

var ikea: IkeaApiWrapper

func _ready():
    # Create the wrapper with country and language (defaults to "ie" and "en")
    ikea = IkeaApiWrapper.new("us", "en")
    add_child(ikea)
    
    # Connect to signals
    ikea.search_completed.connect(_on_search_completed)
    ikea.model_downloaded.connect(_on_model_downloaded)
    
    # Search for products
    ikea.search("billy bookcase")

func _on_search_completed(results: Array):
    print("Found %d products" % results.size())
    for item in results:
        print("  - %s (%s)" % [item.name, item.itemNo])
        # Download the 3D model for the first result
        if results.size() > 0:
            ikea.get_model(item.itemNo)

func _on_model_downloaded(item_no: String, path: String):
    print("Model ready at: %s" % path)
    # Load the GLB file into your scene
    var gltf = GLTFDocument.new()
    var state = GLTFState.new()
    gltf.append_from_file(path, state)
    var scene = gltf.generate_scene(state)
    add_child(scene)
```

## Configuration

### Constructor Parameters

```gdscript
IkeaApiWrapper.new(country: String = "ie", language: String = "en")
```

- **country**: Two-letter country code (e.g., "us", "gb", "de", "se")
- **language**: Two-letter language code (e.g., "en", "de", "sv")

### Properties

```gdscript
var country: String = "ie"          # Country code for API requests
var language: String = "en"         # Language code for API requests
var cache_dir: String = "res://cache"  # Directory for cached data
```

You can modify these properties after initialization:

```gdscript
ikea.country = "de"
ikea.language = "de"
ikea.cache_dir = "user://ikea_cache"
```

## API Reference

### Methods

#### `search(query: String) -> void`

Search for IKEA products by name or item number.

```gdscript
ikea.search("desk")
ikea.search("003.467.35")  # Search by item number
```

**Signals emitted:**
- `search_completed(results: Array)` - On success
- `search_failed(error: String)` - On failure

**Result format:**
```gdscript
{
    "itemNo": "00346735",
    "name": "BILLY Bookcase",
    "mainImageUrl": "https://...",
    "mainImageAlt": "BILLY Bookcase, white",
    "pipUrl": "https://..."
}
```

---

#### `get_pip(item_no: String) -> void`

Retrieve Product Information Page (PIP) data for a specific item.

```gdscript
ikea.get_pip("003.467.35")
```

**Signals emitted:**
- `pip_loaded(item_no: String, data: Dictionary)` - On success
- `pip_failed(item_no: String, error: String)` - On failure

---

#### `get_thumbnail(item_no: String, url: String) -> void`

Download a product thumbnail image.

```gdscript
ikea.get_thumbnail("003.467.35", "https://www.ikea.com/path/to/image.jpg")
```

**Signals emitted:**
- `thumbnail_downloaded(item_no: String, path: String)` - On success
- `thumbnail_failed(item_no: String, error: String)` - On failure

---

#### `get_model(item_no: String) -> void`

Download a 3D model (GLB file) for a specific item.

```gdscript
ikea.get_model("003.467.35")
```

**Signals emitted:**
- `model_downloaded(item_no: String, path: String)` - On success
- `model_failed(item_no: String, error: String)` - On failure

---

#### `check_model_exists(item_no: String) -> void`

Check if a 3D model is available for a specific item.

```gdscript
ikea.check_model_exists("003.467.35")
```

**Signals emitted:**
- `model_exists_checked(item_no: String, exists: bool)` - Always emitted

---

### Utility Functions (Static)

#### `is_item_no(item_no: String) -> bool`

Validate if a string matches the IKEA item number pattern.

```gdscript
IkeaApiWrapper.is_item_no("003.467.35")  # true
IkeaApiWrapper.is_item_no("00346735")    # true
IkeaApiWrapper.is_item_no("invalid")     # false
```

---

#### `compact_item_no(item_no: String) -> String`

Remove formatting characters to get the 8-digit compact format.

```gdscript
IkeaApiWrapper.compact_item_no("003.467.35")  # "00346735"
```

---

#### `format_item_no(item_no: String) -> String`

Format a compact item number into XXX.XXX.XX format.

```gdscript
IkeaApiWrapper.format_item_no("00346735")  # "003.467.35"
```

---

### Signals

All operations are asynchronous and use Godot's signal system:

```gdscript
signal search_completed(results: Array)
signal search_failed(error: String)
signal pip_loaded(item_no: String, data: Dictionary)
signal pip_failed(item_no: String, error: String)
signal thumbnail_downloaded(item_no: String, path: String)
signal thumbnail_failed(item_no: String, error: String)
signal model_downloaded(item_no: String, path: String)
signal model_failed(item_no: String, error: String)
signal model_exists_checked(item_no: String, exists: bool)
```

## Usage Examples

### Example 1: Search and Display Results

```gdscript
extends Control

@onready var ikea = IkeaApiWrapper.new()
@onready var results_list = $VBoxContainer/ResultsList

func _ready():
    add_child(ikea)
    ikea.search_completed.connect(_on_search_completed)
    ikea.search("sofa")

func _on_search_completed(results: Array):
    for item in results:
        var label = Label.new()
        label.text = "%s - %s" % [item.itemNo, item.name]
        results_list.add_child(label)
```

### Example 2: Download and Load 3D Model

```gdscript
extends Node3D

var ikea: IkeaApiWrapper

func _ready():
    ikea = IkeaApiWrapper.new("us", "en")
    add_child(ikea)
    
    ikea.search_completed.connect(_on_search_completed)
    ikea.model_downloaded.connect(_on_model_downloaded)
    ikea.model_failed.connect(_on_model_failed)
    
    # Search for a specific item
    ikea.search("BILLY")

func _on_search_completed(results: Array):
    if results.size() > 0:
        var first_item = results[0]
        print("Downloading model for: %s" % first_item.name)
        ikea.get_model(first_item.itemNo)

func _on_model_downloaded(item_no: String, path: String):
    print("Model downloaded: %s" % path)
    
    # Load the GLB file
    var gltf_doc = GLTFDocument.new()
    var gltf_state = GLTFState.new()
    var error = gltf_doc.append_from_file(path, gltf_state)
    
    if error == OK:
        var scene = gltf_doc.generate_scene(gltf_state)
        add_child(scene)
        print("Model loaded successfully!")
    else:
        print("Failed to load GLB file: %d" % error)

func _on_model_failed(item_no: String, error: String):
    print("Model download failed: %s" % error)
```

### Example 3: Product Browser with Thumbnails

```gdscript
extends Control

var ikea: IkeaApiWrapper
@onready var grid = $ScrollContainer/GridContainer

func _ready():
    ikea = IkeaApiWrapper.new()
    add_child(ikea)
    
    ikea.search_completed.connect(_on_search_completed)
    ikea.thumbnail_downloaded.connect(_on_thumbnail_downloaded)
    
    ikea.search("chair")

func _on_search_completed(results: Array):
    for item in results:
        var container = VBoxContainer.new()
        
        # Create placeholder for thumbnail
        var texture_rect = TextureRect.new()
        texture_rect.name = "Thumbnail_%s" % item.itemNo
        texture_rect.custom_minimum_size = Vector2(200, 200)
        texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
        container.add_child(texture_rect)
        
        # Add product name
        var label = Label.new()
        label.text = item.name
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        container.add_child(label)
        
        grid.add_child(container)
        
        # Download thumbnail
        ikea.get_thumbnail(item.itemNo, item.mainImageUrl)

func _on_thumbnail_downloaded(item_no: String, path: String):
    # Find the texture rect for this item
    var texture_rect = grid.find_child("Thumbnail_%s" % item_no, true, false)
    if texture_rect:
        var image = Image.load_from_file(path)
        if image:
            texture_rect.texture = ImageTexture.create_from_image(image)
```

### Example 4: Check Model Availability Before Download

```gdscript
extends Node

var ikea: IkeaApiWrapper

func _ready():
    ikea = IkeaApiWrapper.new()
    add_child(ikea)
    
    ikea.model_exists_checked.connect(_on_model_exists_checked)
    ikea.model_downloaded.connect(_on_model_downloaded)
    
    # Check if model exists before downloading
    ikea.check_model_exists("003.467.35")

func _on_model_exists_checked(item_no: String, exists: bool):
    if exists:
        print("Model available for %s, downloading..." % item_no)
        ikea.get_model(item_no)
    else:
        print("No 3D model available for item %s" % item_no)

func _on_model_downloaded(item_no: String, path: String):
    print("Model downloaded: %s" % path)
```

## Caching

The addon automatically caches all downloaded data to avoid redundant API calls:

### Cache Structure

```
res://cache/
├── 00346735/
│   ├── pip.json          # Product information
│   ├── thumbnail.jpg     # Product image
│   ├── model.glb         # 3D model
│   └── exists.json       # Model availability status
├── 12345678/
│   └── ...
```

### Cache Behavior

- **Automatic**: All API responses are cached automatically
- **Persistent**: Cache persists across sessions
- **Smart**: Cached data is returned immediately without API calls
- **Manual Clearing**: Delete cache files manually to force re-download

### Custom Cache Directory

```gdscript
ikea.cache_dir = "user://my_custom_cache"
```

## Error Handling

All operations emit error signals with descriptive messages:

```gdscript
func _ready():
    ikea.search_failed.connect(_on_search_failed)
    ikea.pip_failed.connect(_on_pip_failed)
    ikea.thumbnail_failed.connect(_on_thumbnail_failed)
    ikea.model_failed.connect(_on_model_failed)

func _on_search_failed(error: String):
    print("Search error: %s" % error)

func _on_pip_failed(item_no: String, error: String):
    print("PIP error for %s: %s" % [item_no, error])

func _on_thumbnail_failed(item_no: String, error: String):
    print("Thumbnail error for %s: %s" % [item_no, error])

func _on_model_failed(item_no: String, error: String):
    print("Model error for %s: %s" % [item_no, error])
```

### Common Error Types

- **Network Errors**: Connection timeout, DNS resolution failure, SSL/TLS errors
- **HTTP Errors**: 404 Not Found, 500 Server Error, rate limiting
- **Data Errors**: JSON parsing failures, invalid item number format, missing fields
- **File Errors**: Cache directory creation failure, file write errors

## Troubleshooting

### Issue: "All HTTP request nodes are busy"

**Cause**: More than 4 concurrent requests are being made.

**Solution**: 
- Wait for pending requests to complete before making new ones
- Increase `MAX_HTTP_REQUESTS` constant in the source code if needed
- Queue your requests or use signals to chain operations

```gdscript
# Good: Chain operations using signals
ikea.search_completed.connect(func(results):
    if results.size() > 0:
        ikea.get_model(results[0].itemNo)
)
ikea.search("desk")

# Bad: Making too many requests at once
for i in range(100):
    ikea.get_model("0034673%d" % i)  # Will fail after 4 requests
```

### Issue: "Failed to create or access cache directory"

**Cause**: Insufficient permissions or invalid cache path.

**Solution**:
- Use `user://` path for user-writable directory: `ikea.cache_dir = "user://ikea_cache"`
- Ensure the path is valid and writable
- Check Godot's file access permissions

### Issue: "No 3D model available for this item"

**Cause**: Not all IKEA products have 3D models.

**Solution**:
- Use `check_model_exists()` before attempting to download
- Handle the `model_failed` signal gracefully
- Filter search results to only show items with models

### Issue: "Request timed out after 30 seconds"

**Cause**: Slow network connection or server issues.

**Solution**:
- Check your internet connection
- Try again later if IKEA's servers are experiencing issues
- Increase `REQUEST_TIMEOUT` constant if needed for slow connections

### Issue: "Invalid item number format"

**Cause**: Item number doesn't match the expected pattern.

**Solution**:
- Use `IkeaApiWrapper.is_item_no()` to validate before making requests
- Ensure item numbers are in format XXX.XXX.XX or XXXXXXXX
- Use `IkeaApiWrapper.format_item_no()` to normalize the format

### Issue: Models not loading in Godot

**Cause**: GLB file may be corrupted or incompatible.

**Solution**:
- Check the console for GLB validation errors
- Try re-downloading by deleting the cached model file
- Verify the file size is reasonable (should be > 1KB)
- Test the GLB file in external viewers to confirm it's valid

## Performance Tips

1. **Batch Operations**: Connect to signals and chain operations rather than making many simultaneous requests
2. **Cache First**: The addon automatically checks cache first, but you can manually check if files exist
3. **Limit Concurrent Requests**: Keep concurrent operations under 4 to avoid blocking
4. **Preload Common Items**: Download frequently used models during loading screens
5. **Use Thumbnails**: Load thumbnails first for UI, then download models on-demand

## Supported Regions

The addon supports all IKEA regions. Common country codes:

- **us**: United States
- **gb**: United Kingdom  
- **de**: Germany
- **fr**: France
- **se**: Sweden
- **ca**: Canada
- **au**: Australia
- **jp**: Japan
- **ie**: Ireland (default)

## License

This addon is provided as-is for use with Godot projects. IKEA® is a registered trademark of Inter IKEA Systems B.V. This addon is not officially affiliated with or endorsed by IKEA.

## Contributing

Contributions are welcome! Please ensure:
- Code follows GDScript style guidelines
- All public methods are documented
- Error handling is comprehensive
- Changes are tested with multiple item numbers

## Support

For issues, questions, or feature requests, please refer to the project repository or documentation.
