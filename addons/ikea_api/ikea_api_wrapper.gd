extends Node
class_name IkeaApiWrapper

## Signals for asynchronous operations
signal search_completed(results: Array)
signal search_failed(error: String)
signal pip_loaded(item_no: String, data: Dictionary)
signal pip_failed(item_no: String, error: String)
signal thumbnail_downloaded(item_no: String, path: String)
signal thumbnail_failed(item_no: String, error: String)
signal model_downloaded(item_no: String, path: String)
signal model_failed(item_no: String, error: String)
signal model_exists_checked(item_no: String, exists: bool)

## Constants
const MAX_HTTP_REQUESTS = 4
const CLIENT_ID = "4863e7d2-1428-4324-890b-ae5dede24fc6"
const USER_AGENT = "Godot IKEA Addon"

## Properties
var country: String = "ie"
var language: String = "en"
var cache_dir: String = "res://cache"
var _http_pool: Array[HTTPRequest] = []

## Constructor
func _init(p_country: String = "ie", p_language: String = "en") -> void:
	country = p_country
	language = p_language

## Lifecycle methods
func _ready() -> void:
	# Initialize HTTP request pool
	for i in range(MAX_HTTP_REQUESTS):
		var req = HTTPRequest.new()
		add_child(req)
		_http_pool.append(req)

## HTTP Request Pool Management
func _get_http_request() -> HTTPRequest:
	# Find an available HTTPRequest node from the pool
	for req in _http_pool:
		if not req.is_busy():
			return req
	
	# All requests are busy, return null to indicate queuing needed
	return null

## Item Number Utility Functions
## Validates if a string matches the IKEA item number pattern
## Accepts both formatted (XXX.XXX.XX) and compact (XXXXXXXX) formats
static func is_item_no(item_no: String) -> bool:
	if item_no.is_empty():
		return false
	
	# Regex pattern for XXX.XXX.XX format or 8 consecutive digits
	var regex = RegEx.new()
	regex.compile("^\\d{3}\\.\\d{3}\\.\\d{2}$|^\\d{8}$")
	
	return regex.search(item_no) != null

## Removes formatting characters from item number to return compact 8-digit format
## Example: "123.456.78" -> "12345678"
static func compact_item_no(item_no: String) -> String:
	# Remove all dots and other non-digit characters
	var compact = ""
	for c in item_no:
		if c.is_valid_int():
			compact += c
	
	return compact

## Formats a compact item number into XXX.XXX.XX format
## Example: "12345678" -> "123.456.78"
static func format_item_no(item_no: String) -> String:
	# First get compact version to handle any input format
	var compact = compact_item_no(item_no)
	
	# Validate we have exactly 8 digits
	if compact.length() != 8:
		push_error("[IkeaApiWrapper] Invalid item number length: " + item_no)
		return item_no
	
	# Format as XXX.XXX.XX
	return compact.substr(0, 3) + "." + compact.substr(3, 3) + "." + compact.substr(6, 2)

## HTTP Request Handling

## Makes an HTTP request with the given URL, parameters, headers, and callback
## Handles URL encoding, header building, and signal connection
func _make_request(url: String, params: Dictionary, headers: Dictionary, callback: Callable) -> void:
	# Get an available HTTPRequest from the pool
	var http = _get_http_request()
	if http == null:
		push_error("[IkeaApiWrapper] No available HTTP request nodes in pool")
		return
	
	# Build query string from parameters
	var query_string = ""
	if params.size() > 0:
		var param_array: Array[String] = []
		for key in params.keys():
			var value = params[key]
			# URL encode the key and value
			var encoded_key = key.uri_encode()
			var encoded_value = str(value).uri_encode()
			param_array.append(encoded_key + "=" + encoded_value)
		query_string = "?" + "".join(param_array).replace("?", "&").trim_prefix("&")
	
	# Construct full URL with query string
	var full_url = url + query_string
	
	# Build headers array
	var headers_array = PackedStringArray([
		"User-Agent: " + USER_AGENT
	])
	
	# Add X-Client-Id header for web-api.ikea.com requests
	if "web-api.ikea.com" in url:
		headers_array.append("X-Client-Id: " + CLIENT_ID)
	
	# Add any additional headers from the headers dictionary
	for key in headers.keys():
		headers_array.append(key + ": " + str(headers[key]))
	
	# Connect the request_completed signal to our handler with the callback
	# Disconnect any previous connections to avoid duplicates
	if http.request_completed.is_connected(_on_request_completed):
		http.request_completed.disconnect(_on_request_completed)
	
	http.request_completed.connect(_on_request_completed.bind(callback))
	
	# Make the HTTP request
	var err = http.request(full_url, headers_array)
	if err != OK:
		push_error("[IkeaApiWrapper] HTTP request failed to start: " + str(err))
		callback.call(null, "Failed to start HTTP request: " + str(err))

## Handles HTTP request completion
## Validates response code, processes body, and calls the provided callback
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, callback: Callable) -> void:
	# Disconnect the signal to prevent memory leaks
	var http = callback.get_object() as HTTPRequest
	if http != null and http.request_completed.is_connected(_on_request_completed):
		http.request_completed.disconnect(_on_request_completed)
	
	# Check for network/connection errors
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "HTTP request failed with result code: " + str(result)
		push_error("[IkeaApiWrapper] " + error_msg)
		callback.call(null, error_msg)
		return
	
	# Validate response code (200-299 range indicates success)
	if response_code < 200 or response_code >= 300:
		var error_msg = "HTTP request failed with status code: " + str(response_code)
		push_error("[IkeaApiWrapper] " + error_msg)
		callback.call(null, error_msg)
		return
	
	# Success - pass the response body to the callback
	callback.call(body, null)

## Safely parses JSON from a PackedByteArray
## Returns the parsed data on success, or null on failure
## Emits descriptive error messages on parse failures
func _parse_json(body: PackedByteArray) -> Variant:
	# Convert PackedByteArray to string
	var json_string = body.get_string_from_utf8()
	
	# Check if conversion was successful
	if json_string.is_empty() and body.size() > 0:
		push_error("[IkeaApiWrapper] Failed to convert response body to UTF-8 string")
		return null
	
	# Create JSON parser
	var json = JSON.new()
	
	# Parse the JSON string
	var parse_result = json.parse(json_string)
	
	# Check for parsing errors
	if parse_result != OK:
		var error_msg = "JSON parsing failed at line " + str(json.get_error_line()) + ": " + json.get_error_message()
		push_error("[IkeaApiWrapper] " + error_msg)
		return null
	
	# Return the parsed data
	return json.data

## Cache Management Functions

## Ensures the cache directory exists for a specific item number
## Creates the directory structure if it doesn't exist
func _ensure_cache_dir(item_no: String) -> void:
	var compact = compact_item_no(item_no)
	var dir_path = cache_dir.path_join(compact)
	
	# Check if directory already exists
	if DirAccess.dir_exists_absolute(dir_path):
		return
	
	# Create the directory structure (including parent directories)
	var dir = DirAccess.open(cache_dir)
	if dir == null:
		# Cache root doesn't exist, create it first
		var err = DirAccess.make_dir_recursive_absolute(cache_dir)
		if err != OK:
			push_error("[IkeaApiWrapper] Failed to create cache root directory: " + cache_dir)
			return
		dir = DirAccess.open(cache_dir)
	
	# Create the item-specific subdirectory
	var err = dir.make_dir(compact)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("[IkeaApiWrapper] Failed to create cache directory for item " + item_no + ": " + str(err))

## Checks if a cached file exists for a specific item number
## Returns true if the file exists, false otherwise
func _cache_exists(item_no: String, filename: String) -> bool:
	var compact = compact_item_no(item_no)
	var file_path = cache_dir.path_join(compact).path_join(filename)
	return FileAccess.file_exists(file_path)

## Saves binary data to a cache file for a specific item number
## Returns the absolute path to the saved file, or empty string on failure
func _save_to_cache(item_no: String, filename: String, data: PackedByteArray) -> String:
	var compact = compact_item_no(item_no)
	
	# Ensure the cache directory exists
	_ensure_cache_dir(item_no)
	
	# Build the full file path
	var file_path = cache_dir.path_join(compact).path_join(filename)
	
	# Open file for writing
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("[IkeaApiWrapper] Failed to write cache file: " + file_path + " (Error: " + str(FileAccess.get_open_error()) + ")")
		return ""
	
	# Write the data and close
	file.store_buffer(data)
	file.close()
	
	return file_path

## Loads cached data from a file for a specific item number
## Returns the data as PackedByteArray, or null if file doesn't exist or read fails
func _load_from_cache(item_no: String, filename: String) -> Variant:
	var compact = compact_item_no(item_no)
	var file_path = cache_dir.path_join(compact).path_join(filename)
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		return null
	
	# Open file for reading
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[IkeaApiWrapper] Failed to read cache file: " + file_path + " (Error: " + str(FileAccess.get_open_error()) + ")")
		return null
	
	# Read all data and close
	var data = file.get_buffer(file.get_length())
	file.close()
	
	return data

## Public API Methods

## Searches for IKEA products by name or item number
## Emits search_completed signal with results array on success
## Emits search_failed signal with error message on failure
func search(query: String) -> void:
	if query.is_empty():
		push_error("[IkeaApiWrapper] Search query cannot be empty")
		search_failed.emit("Search query cannot be empty")
		return
	
	# Build search API URL
	var url = "https://sik.search.blue.cdtapps.com/%s/%s/search-result-page" % [country, language]
	
	# Detect if query is an item number
	var is_item_query = is_item_no(query)
	
	# Construct query parameters
	var params = {
		"types": "PRODUCT",
		"q": query,
		"c": "lf",
		"v": "20240201",
		"autocorrect": "true",
		"subcategories-style": "tree-navigation"
	}
	
	# If searching by item number, limit results to 1
	if is_item_query:
		params["size"] = "1"
	else:
		params["size"] = "24"
	
	# Make the HTTP request
	_make_request(url, params, {}, _on_search_completed)

## Callback for search request completion
## Processes the search API response and emits appropriate signals
func _on_search_completed(body: PackedByteArray, error: String) -> void:
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		push_error("[IkeaApiWrapper] Search failed: " + error)
		search_failed.emit(error)
		return
	
	# Parse JSON response
	var data = _parse_json(body)
	if data == null:
		search_failed.emit("Failed to parse search response JSON")
		return
	
	# Validate response structure
	if not data.has("searchResultPage"):
		push_error("[IkeaApiWrapper] Invalid search response: missing searchResultPage")
		search_failed.emit("Invalid search response structure")
		return
	
	var search_page = data["searchResultPage"]
	if not search_page.has("products"):
		push_error("[IkeaApiWrapper] Invalid search response: missing products")
		search_failed.emit("Invalid search response structure")
		return
	
	var products = search_page["products"]
	if not products.has("main"):
		push_error("[IkeaApiWrapper] Invalid search response: missing main products")
		search_failed.emit("Invalid search response structure")
		return
	
	var main = products["main"]
	if not main.has("items"):
		push_error("[IkeaApiWrapper] Invalid search response: missing items")
		search_failed.emit("Invalid search response structure")
		return
	
	# Extract product items
	var items = main["items"]
	var results: Array = []
	
	# Process each product item
	for item in items:
		# Validate required fields
		if not item.has("itemNo") or not item.has("name") or not item.has("mainImageUrl") or not item.has("mainImageAlt") or not item.has("pipUrl"):
			# Skip items with missing required fields
			continue
		
		# Check if product has a 3D model available
		# Products without 3D models should be filtered out
		# We check for the presence of contextualImageUrl or other indicators
		# For now, we'll include all products and let the model download handle availability
		# The actual model availability check happens in check_model_exists()
		
		# Build result dictionary
		var result = {
			"itemNo": item["itemNo"],
			"name": item["name"],
			"mainImageUrl": item["mainImageUrl"],
			"mainImageAlt": item["mainImageAlt"],
			"pipUrl": item["pipUrl"]
		}
		
		results.append(result)
	
	# Emit search completed signal with results
	search_completed.emit(results)

## Retrieves Product Information Page (PIP) data for a specific item number
## Checks cache first, then fetches from API if not cached
## Emits pip_loaded signal with item number and data on success
## Emits pip_failed signal with item number and error message on failure
func get_pip(item_no: String) -> void:
	# Validate item number format
	if not is_item_no(item_no):
		push_error("[IkeaApiWrapper] Invalid item number format: " + item_no)
		pip_failed.emit(item_no, "Invalid item number format")
		return
	
	var compact = compact_item_no(item_no)
	
	# Check cache first
	if _cache_exists(item_no, "pip.json"):
		var cached_data = _load_from_cache(item_no, "pip.json")
		if cached_data != null:
			# Parse the cached JSON data
			var data = _parse_json(cached_data)
			if data != null:
				pip_loaded.emit(compact, data)
				return
			else:
				push_error("[IkeaApiWrapper] Failed to parse cached PIP data for item " + item_no)
				# Continue to fetch from API if cache is corrupted
	
	# Build PIP API URL
	# URL format: https://www.ikea.com/{country}/{language}/products/{last_3_digits}/{item_no}.json
	var last_3_digits = compact.substr(5, 3)  # Get digits 6-8 (0-indexed: 5-7)
	var url = "https://www.ikea.com/%s/%s/products/%s/%s.json" % [country, language, last_3_digits, compact]
	
	# Make the HTTP request
	_make_request(url, {}, {}, _on_pip_completed.bind(item_no))

## Callback for PIP request completion
## Processes the PIP API response, caches it, and emits appropriate signals
func _on_pip_completed(body: PackedByteArray, error: String, item_no: String) -> void:
	var compact = compact_item_no(item_no)
	
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		push_error("[IkeaApiWrapper] PIP request failed for item " + item_no + ": " + error)
		pip_failed.emit(compact, error)
		return
	
	# Parse JSON response
	var data = _parse_json(body)
	if data == null:
		pip_failed.emit(compact, "Failed to parse PIP response JSON")
		return
	
	# Save to cache
	var cache_path = _save_to_cache(item_no, "pip.json", body)
	if cache_path.is_empty():
		push_error("[IkeaApiWrapper] Failed to cache PIP data for item " + item_no)
		# Continue anyway - we still have the data
	
	# Emit success signal with the parsed data
	pip_loaded.emit(compact, data)

## Downloads a thumbnail image for a specific item number
## Checks cache first, then downloads from provided URL if not cached
## Emits thumbnail_downloaded signal with item number and file path on success
## Emits thumbnail_failed signal with item number and error message on failure
func get_thumbnail(item_no: String, url: String) -> void:
	# Validate item number format
	if not is_item_no(item_no):
		push_error("[IkeaApiWrapper] Invalid item number format: " + item_no)
		thumbnail_failed.emit(item_no, "Invalid item number format")
		return
	
	# Validate URL
	if url.is_empty():
		push_error("[IkeaApiWrapper] Thumbnail URL cannot be empty for item " + item_no)
		thumbnail_failed.emit(item_no, "Thumbnail URL cannot be empty")
		return
	
	var compact = compact_item_no(item_no)
	
	# Check cache first
	if _cache_exists(item_no, "thumbnail.jpg"):
		var file_path = cache_dir.path_join(compact).path_join("thumbnail.jpg")
		thumbnail_downloaded.emit(compact, file_path)
		return
	
	# Make HTTP request to download the image
	_make_request(url, {}, {}, _on_thumbnail_completed.bind(item_no))

## Callback for thumbnail download completion
## Saves the downloaded image to cache and emits appropriate signals
func _on_thumbnail_completed(body: PackedByteArray, error: String, item_no: String) -> void:
	var compact = compact_item_no(item_no)
	
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		push_error("[IkeaApiWrapper] Thumbnail download failed for item " + item_no + ": " + error)
		thumbnail_failed.emit(compact, error)
		return
	
	# Validate that we received data
	if body.size() == 0:
		push_error("[IkeaApiWrapper] Thumbnail download returned empty data for item " + item_no)
		thumbnail_failed.emit(compact, "Downloaded thumbnail is empty")
		return
	
	# Save to cache
	var cache_path = _save_to_cache(item_no, "thumbnail.jpg", body)
	if cache_path.is_empty():
		thumbnail_failed.emit(compact, "Failed to save thumbnail to cache")
		return
	
	# Emit success signal with the file path
	thumbnail_downloaded.emit(compact, cache_path)
