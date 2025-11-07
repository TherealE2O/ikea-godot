# Design Document: Godot IKEA Addon

## Overview

The Godot IKEA Addon is a GDScript-based plugin that provides IKEA API integration for the Godot game engine. It enables developers to search for IKEA products, retrieve product metadata, and download 3D models and thumbnails directly within Godot projects. The addon follows Godot's signal-based asynchronous pattern and implements a local caching system to minimize API calls.

## Architecture

### Core Components

1. **IkeaApiWrapper** (Main Class)
   - Central class that manages all API interactions
   - Extends `Node` to leverage Godot's scene tree and signal system
   - Manages HTTPRequest nodes for asynchronous operations
   - Handles caching logic and file I/O

2. **HTTP Request Manager**
   - Pool of HTTPRequest nodes for concurrent requests
   - Handles request queuing and response processing
   - Manages SSL/TLS connections

3. **Cache Manager**
   - File system operations for reading/writing cached data
   - Directory structure management
   - Cache validation and retrieval

4. **Item Number Utilities**
   - Static functions for item number validation and formatting
   - Regular expression pattern matching

### Signal-Based Architecture

The addon uses Godot's signal system for asynchronous operations:

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

## Components and Interfaces

### IkeaApiWrapper Class

**Properties:**
```gdscript
var country: String = "ie"
var language: String = "en"
var cache_dir: String = "res://cache"
var _http_pool: Array[HTTPRequest] = []
var _request_queue: Array = []
```

**Public Methods:**

```gdscript
func _init(p_country: String = "ie", p_language: String = "en") -> void
func search(query: String) -> void
func get_pip(item_no: String) -> void
func get_thumbnail(item_no: String, url: String) -> void
func get_model(item_no: String) -> void
func check_model_exists(item_no: String) -> void

# Utility functions (static)
static func is_item_no(item_no: String) -> bool
static func compact_item_no(item_no: String) -> String
static func format_item_no(item_no: String) -> String
```

**Private Methods:**

```gdscript
func _ready() -> void
func _get_http_request() -> HTTPRequest
func _make_request(url: String, params: Dictionary, headers: Dictionary, callback: Callable) -> void
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, callback: Callable) -> void
func _parse_json(body: PackedByteArray) -> Variant
func _save_to_cache(item_no: String, filename: String, data: PackedByteArray) -> String
func _load_from_cache(item_no: String, filename: String) -> Variant
func _cache_exists(item_no: String, filename: String) -> bool
func _ensure_cache_dir(item_no: String) -> void
```

### HTTPRequest Pool Management

The addon maintains a pool of HTTPRequest nodes to handle multiple concurrent requests efficiently:

```gdscript
const MAX_HTTP_REQUESTS = 4

func _get_http_request() -> HTTPRequest:
    for req in _http_pool:
        if not req.is_busy():
            return req
    
    if _http_pool.size() < MAX_HTTP_REQUESTS:
        var req = HTTPRequest.new()
        add_child(req)
        _http_pool.append(req)
        return req
    
    return null  # Queue the request
```

## Data Models

### Search Result Item

```gdscript
{
    "itemNo": String,        # e.g., "00346735"
    "name": String,          # Product name
    "mainImageUrl": String,  # URL to product image
    "mainImageAlt": String,  # Alt text for image
    "pipUrl": String         # Product page URL
}
```

### PIP Data

The PIP (Product Information Page) data structure follows IKEA's JSON schema. Key fields include:
- Product details (name, description, measurements)
- Pricing information
- Availability data
- Image URLs
- Related products

### Model Metadata

```gdscript
{
    "exists": bool,
    "modelUrl": String  # URL to GLB file
}
```

## Error Handling

### Error Types

1. **Network Errors**
   - Connection timeout
   - DNS resolution failure
   - SSL/TLS errors

2. **HTTP Errors**
   - 4xx client errors (invalid request, not found)
   - 5xx server errors (API unavailable)

3. **Data Errors**
   - JSON parsing failures
   - Invalid item number format
   - Missing required fields

### Error Handling Strategy

```gdscript
func _handle_error(context: String, error: String) -> void:
    push_error("[IkeaApiWrapper] %s: %s" % [context, error])
    match context:
        "search":
            search_failed.emit(error)
        "pip":
            pip_failed.emit(current_item_no, error)
        "thumbnail":
            thumbnail_failed.emit(current_item_no, error)
        "model":
            model_failed.emit(current_item_no, error)
```

All errors are:
1. Logged to Godot's console using `push_error()`
2. Emitted via appropriate error signals
3. Include descriptive messages for debugging

## Caching Strategy

### Cache Directory Structure

```
res://cache/
├── 00346735/
│   ├── pip.json
│   ├── thumbnail.jpg
│   ├── model.glb
│   └── exists.json
├── 12345678/
│   ├── pip.json
│   └── thumbnail.jpg
└── ...
```

### Cache Operations

1. **Check Cache**: Before making any API request, check if data exists in cache
2. **Read Cache**: If cached data exists and is valid, return it immediately
3. **Write Cache**: After successful API response, save data to cache
4. **Cache Invalidation**: No automatic invalidation (manual deletion required)

### File I/O

```gdscript
func _save_to_cache(item_no: String, filename: String, data: PackedByteArray) -> String:
    var dir_path = cache_dir.path_join(item_no)
    _ensure_cache_dir(item_no)
    
    var file_path = dir_path.path_join(filename)
    var file = FileAccess.open(file_path, FileAccess.WRITE)
    if file:
        file.store_buffer(data)
        file.close()
        return file_path
    else:
        push_error("Failed to write cache file: " + file_path)
        return ""

func _load_from_cache(item_no: String, filename: String) -> Variant:
    var file_path = cache_dir.path_join(item_no).path_join(filename)
    if FileAccess.file_exists(file_path):
        var file = FileAccess.open(file_path, FileAccess.READ)
        if file:
            var data = file.get_buffer(file.get_length())
            file.close()
            return data
    return null
```

## API Integration

### IKEA API Endpoints

1. **Search API**
   - URL: `https://sik.search.blue.cdtapps.com/{country}/{language}/search-result-page`
   - Method: GET
   - Parameters: `types`, `q`, `size`, `c`, `v`, `autocorrect`, `subcategories-style`

2. **Product Information (PIP)**
   - URL: `https://www.ikea.com/{country}/{language}/products/{last_3_digits}/{item_no}.json`
   - Method: GET

3. **Model Exists Check**
   - URL: `https://web-api.ikea.com/{country}/{language}/rotera/data/exists/{item_no}/`
   - Method: GET
   - Headers: `X-Client-Id`

4. **Model Metadata**
   - URL: `https://web-api.ikea.com/{country}/{language}/rotera/data/model/{item_no}/`
   - Method: GET
   - Headers: `X-Client-Id`

### Request Headers

```gdscript
const CLIENT_ID = "4863e7d2-1428-4324-890b-ae5dede24fc6"
const USER_AGENT = "Godot IKEA Addon"

func _build_headers(url: String) -> PackedStringArray:
    var headers = PackedStringArray([
        "User-Agent: " + USER_AGENT
    ])
    
    if "web-api.ikea.com" in url:
        headers.append("X-Client-Id: " + CLIENT_ID)
    
    return headers
```

## Testing Strategy

### Unit Tests

1. **Item Number Utilities**
   - Test `is_item_no()` with valid and invalid formats
   - Test `compact_item_no()` with various input formats
   - Test `format_item_no()` output format

2. **Cache Operations**
   - Test cache directory creation
   - Test file writing and reading
   - Test cache existence checks

### Integration Tests

1. **API Search**
   - Test search with product name
   - Test search with item number
   - Test search with no results
   - Test search error handling

2. **Data Download**
   - Test PIP data retrieval
   - Test thumbnail download
   - Test model download
   - Test model existence check

3. **Cache Behavior**
   - Test cache hit (data returned from cache)
   - Test cache miss (data fetched from API)
   - Test cache persistence across sessions

### Manual Testing

1. Create a test scene with IkeaApiWrapper node
2. Connect to signals and print results
3. Test various search queries
4. Verify downloaded files in cache directory
5. Test with different country/language settings

### Test Scene Example

```gdscript
extends Node

@onready var ikea = IkeaApiWrapper.new("ie", "en")

func _ready():
    add_child(ikea)
    
    ikea.search_completed.connect(_on_search_completed)
    ikea.search_failed.connect(_on_search_failed)
    ikea.model_downloaded.connect(_on_model_downloaded)
    
    ikea.search("billy bookcase")

func _on_search_completed(results: Array):
    print("Found %d products" % results.size())
    for item in results:
        print("  - %s (%s)" % [item.name, item.itemNo])
        ikea.get_model(item.itemNo)

func _on_search_failed(error: String):
    print("Search failed: " + error)

func _on_model_downloaded(item_no: String, path: String):
    print("Model downloaded: " + path)
```

## Plugin Structure

### Addon Files

```
addons/ikea_api/
├── plugin.cfg
├── ikea_api_wrapper.gd
├── icon.png
└── README.md
```

### plugin.cfg

```ini
[plugin]
name="IKEA API Wrapper"
description="Search and download IKEA products and 3D models"
author="Your Name"
version="1.0.0"
script="ikea_api_wrapper.gd"
```

### Installation

1. Copy `addons/ikea_api/` to project
2. Enable plugin in Project Settings → Plugins
3. Add IkeaApiWrapper node to scene or create via script

### Usage Example

```gdscript
var ikea = IkeaApiWrapper.new("us", "en")
add_child(ikea)

ikea.search_completed.connect(func(results):
    for item in results:
        print(item.name)
)

ikea.search("desk")
```

## Performance Considerations

1. **Concurrent Requests**: Limit to 4 simultaneous HTTP requests to avoid overwhelming the API
2. **Cache First**: Always check cache before making network requests
3. **Async Operations**: All network operations are asynchronous to prevent blocking
4. **Memory Management**: HTTPRequest nodes are reused from a pool
5. **File I/O**: Use buffered reads/writes for efficient file operations

## Security Considerations

1. **SSL/TLS**: All HTTPS requests use Godot's built-in SSL validation
2. **Input Validation**: Item numbers are validated before API requests
3. **Path Traversal**: Cache paths are sanitized to prevent directory traversal attacks
4. **API Keys**: CLIENT_ID is embedded (as it appears to be public in IKEA's website source)

## Future Enhancements

1. **Cache Expiration**: Implement time-based cache invalidation
2. **Batch Operations**: Support downloading multiple models in sequence
3. **Progress Reporting**: Emit signals with download progress percentage
4. **Model Import**: Automatically import GLB files into Godot scenes
5. **Editor Integration**: Create custom editor dock for browsing IKEA catalog
6. **Localization**: Support for all IKEA regions and languages
