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
const REQUEST_TIMEOUT = 30.0  # Timeout in seconds for HTTP requests

## Properties
var country: String = "ie"
var language: String = "en"
var cache_dir: String = "res://cache"
var _http_pool: Array[HTTPRequest] = []
var _http_busy: Array[bool] = []

## Constructor
func _init(p_country: String = "ie", p_language: String = "en") -> void:
	country = p_country
	language = p_language

## Lifecycle methods
func _ready() -> void:
	# Initialize HTTP request pool
	for i in range(MAX_HTTP_REQUESTS):
		var req = HTTPRequest.new()
		req.timeout = REQUEST_TIMEOUT  # Set timeout for each request
		add_child(req)
		_http_pool.append(req)
		_http_busy.append(false)
	
	# Validate cache directory is writable
	if not cache_dir.is_empty():
		var test_dir = DirAccess.open(cache_dir)
		if test_dir == null:
			# Try to create the cache directory
			var err = DirAccess.make_dir_recursive_absolute(cache_dir)
			if err != OK:
				push_error("[IkeaApiWrapper] Failed to create or access cache directory: %s (Error: %d)" % [cache_dir, err])
			else:
				print("[IkeaApiWrapper] Cache directory created: %s" % cache_dir)
		else:
			print("[IkeaApiWrapper] Cache directory ready: %s" % cache_dir)

## HTTP Request Pool Management
func _get_http_request() -> int:
	# Find an available HTTPRequest node from the pool
	for i in range(_http_pool.size()):
		if not _http_busy[i]:
			_http_busy[i] = true
			return i
	
	# All requests are busy, return -1 to indicate queuing needed
	push_error("[IkeaApiWrapper] All HTTP request nodes are busy. Consider increasing MAX_HTTP_REQUESTS or waiting for pending requests to complete.")
	return -1

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
	# Validate URL
	if url.is_empty():
		push_error("[IkeaApiWrapper] Cannot make request with empty URL")
		callback.call(PackedByteArray(), "Invalid request: empty URL")
		return
	
	# Get an available HTTPRequest from the pool
	var http_index = _get_http_request()
	if http_index == -1:
		callback.call(PackedByteArray(), "No available HTTP request nodes - all requests are busy")
		return
	
	var http = _http_pool[http_index]
	
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
		query_string = "?" + "&".join(param_array)
	
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
	
	http.request_completed.connect(_on_request_completed.bind(callback, http_index))
	
	# Log the request for debugging
	print("[IkeaApiWrapper] Making request to: %s" % full_url)
	
	# Make the HTTP request
	var err = http.request(full_url, headers_array)
	if err != OK:
		_http_busy[http_index] = false
		var error_msg = "Failed to start HTTP request (Error code: %d)" % err
		push_error("[IkeaApiWrapper] %s for URL: %s" % [error_msg, full_url])
		callback.call(PackedByteArray(), error_msg)

## Handles HTTP request completion
## Validates response code, processes body, and calls the provided callback
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, callback: Callable, http_index: int) -> void:
	# Mark this HTTP request as available again
	_http_busy[http_index] = false
	
	# Disconnect the signal to prevent memory leaks
	var http = _http_pool[http_index]
	if http.request_completed.is_connected(_on_request_completed):
		http.request_completed.disconnect(_on_request_completed)
	
	# Check for network/connection errors with detailed error messages
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = _get_http_error_message(result)
		push_error("[IkeaApiWrapper] HTTP request failed: %s (Result code: %d)" % [error_msg, result])
		callback.call(PackedByteArray(), error_msg)
		return
	
	# Validate response code (200-299 range indicates success)
	if response_code < 200 or response_code >= 300:
		var error_msg = _get_http_status_message(response_code)
		push_error("[IkeaApiWrapper] HTTP request failed with status %d: %s" % [response_code, error_msg])
		callback.call(PackedByteArray(), "HTTP %d: %s" % [response_code, error_msg])
		return
	
	# Success - pass the response body to the callback
	callback.call(body, "")

## Returns a descriptive error message for HTTPRequest result codes
func _get_http_error_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
			return "Chunked body size mismatch"
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server - check network connection"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve hostname - check DNS or internet connection"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error occurred"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "SSL/TLS handshake failed - check certificate validity"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "No response from server"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "Response body size limit exceeded"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "Request failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			return "Cannot open download file"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			return "Error writing to download file"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "Too many redirects"
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out after %d seconds - server may be slow or unreachable" % REQUEST_TIMEOUT
		_:
			return "Unknown error (code: %d)" % result

## Returns a descriptive message for HTTP status codes
func _get_http_status_message(status_code: int) -> String:
	match status_code:
		400:
			return "Bad Request - invalid parameters"
		401:
			return "Unauthorized - authentication required"
		403:
			return "Forbidden - access denied"
		404:
			return "Not Found - resource does not exist"
		408:
			return "Request Timeout"
		429:
			return "Too Many Requests - rate limit exceeded"
		500:
			return "Internal Server Error"
		502:
			return "Bad Gateway"
		503:
			return "Service Unavailable - server temporarily down"
		504:
			return "Gateway Timeout"
		_:
			if status_code >= 400 and status_code < 500:
				return "Client Error"
			elif status_code >= 500:
				return "Server Error"
			else:
				return "Unexpected Status Code"

## Safely parses JSON from a PackedByteArray
## Returns the parsed data on success, or null on failure
## Emits descriptive error messages on parse failures
func _parse_json(body: PackedByteArray) -> Variant:
	# Validate input
	if body.size() == 0:
		push_error("[IkeaApiWrapper] Cannot parse JSON from empty response body")
		return null
	
	# Convert PackedByteArray to string
	var json_string = body.get_string_from_utf8()
	
	# Check if conversion was successful
	if json_string.is_empty():
		push_error("[IkeaApiWrapper] Failed to convert response body to UTF-8 string (body size: %d bytes)" % body.size())
		return null
	
	# Create JSON parser
	var json = JSON.new()
	
	# Parse the JSON string
	var parse_result = json.parse(json_string)
	
	# Check for parsing errors
	if parse_result != OK:
		var error_msg = "JSON parsing failed at line %d: %s" % [json.get_error_line(), json.get_error_message()]
		push_error("[IkeaApiWrapper] %s\nFirst 200 chars of response: %s" % [error_msg, json_string.substr(0, 200)])
		return null
	
	# Validate that we got data
	if json.data == null:
		push_error("[IkeaApiWrapper] JSON parsing succeeded but returned null data")
		return null
	
	# Return the parsed data
	return json.data

## Cache Management Functions

## Ensures the cache directory exists for a specific item number
## Creates the directory structure if it doesn't exist
func _ensure_cache_dir(item_no: String) -> bool:
	var compact = compact_item_no(item_no)
	var dir_path = cache_dir.path_join(compact)
	
	# Check if directory already exists
	if DirAccess.dir_exists_absolute(dir_path):
		return true
	
	# Create the directory structure (including parent directories)
	var dir = DirAccess.open(cache_dir)
	if dir == null:
		# Cache root doesn't exist, create it first
		var err = DirAccess.make_dir_recursive_absolute(cache_dir)
		if err != OK:
			push_error("[IkeaApiWrapper] Failed to create cache root directory '%s' (Error: %d)" % [cache_dir, err])
			return false
		dir = DirAccess.open(cache_dir)
		if dir == null:
			push_error("[IkeaApiWrapper] Failed to open cache directory after creation: %s" % cache_dir)
			return false
	
	# Create the item-specific subdirectory
	var err = dir.make_dir(compact)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("[IkeaApiWrapper] Failed to create cache directory for item %s at path '%s' (Error: %d)" % [item_no, dir_path, err])
		return false
	
	return true

## Checks if a cached file exists for a specific item number
## Returns true if the file exists, false otherwise
func _cache_exists(item_no: String, filename: String) -> bool:
	var compact = compact_item_no(item_no)
	var file_path = cache_dir.path_join(compact).path_join(filename)
	return FileAccess.file_exists(file_path)

## Saves binary data to a cache file for a specific item number
## Returns the absolute path to the saved file, or empty string on failure
func _save_to_cache(item_no: String, filename: String, data: PackedByteArray) -> String:
	# Validate inputs
	if filename.is_empty():
		push_error("[IkeaApiWrapper] Cannot save to cache with empty filename for item %s" % item_no)
		return ""
	
	if data.size() == 0:
		push_error("[IkeaApiWrapper] Cannot save empty data to cache file '%s' for item %s" % [filename, item_no])
		return ""
	
	var compact = compact_item_no(item_no)
	
	# Ensure the cache directory exists
	if not _ensure_cache_dir(item_no):
		push_error("[IkeaApiWrapper] Cannot save to cache - directory creation failed for item %s" % item_no)
		return ""
	
	# Build the full file path
	var file_path = cache_dir.path_join(compact).path_join(filename)
	
	# Open file for writing
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var error_code = FileAccess.get_open_error()
		push_error("[IkeaApiWrapper] Failed to open cache file for writing: '%s' (Error: %d)" % [file_path, error_code])
		return ""
	
	# Write the data and close
	file.store_buffer(data)
	var write_error = file.get_error()
	file.close()
	
	if write_error != OK:
		push_error("[IkeaApiWrapper] Error writing data to cache file '%s' (Error: %d)" % [file_path, write_error])
		return ""
	
	print("[IkeaApiWrapper] Cached %d bytes to: %s" % [data.size(), file_path])
	return file_path

## Loads cached data from a file for a specific item number
## Returns the data as PackedByteArray, or null if file doesn't exist or read fails
func _load_from_cache(item_no: String, filename: String) -> Variant:
	# Validate inputs
	if filename.is_empty():
		push_error("[IkeaApiWrapper] Cannot load from cache with empty filename for item %s" % item_no)
		return null
	
	var compact = compact_item_no(item_no)
	var file_path = cache_dir.path_join(compact).path_join(filename)
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		# This is not an error - cache miss is expected
		return null
	
	# Open file for reading
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		var error_code = FileAccess.get_open_error()
		push_error("[IkeaApiWrapper] Failed to open cache file for reading: '%s' (Error: %d)" % [file_path, error_code])
		return null
	
	# Get file size
	var file_size = file.get_length()
	if file_size == 0:
		push_error("[IkeaApiWrapper] Cache file is empty: %s" % file_path)
		file.close()
		return null
	
	# Read all data and close
	var data = file.get_buffer(file_size)
	var read_error = file.get_error()
	file.close()
	
	if read_error != OK:
		push_error("[IkeaApiWrapper] Error reading cache file '%s' (Error: %d)" % [file_path, read_error])
		return null
	
	if data.size() != file_size:
		push_error("[IkeaApiWrapper] Cache file read size mismatch: expected %d bytes, got %d bytes from '%s'" % [file_size, data.size(), file_path])
		return null
	
	print("[IkeaApiWrapper] Loaded %d bytes from cache: %s" % [data.size(), file_path])
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
	
	# Construct query parameters - simplified to avoid 400 errors
	var params = {
		"q": query,
		"types": "PRODUCT"
	}
	
	# If searching by item number, limit results to 1
	if is_item_query:
		params["size"] = 1
	else:
		params["size"] = 24
	
	# Make the HTTP request
	_make_request(url, params, {}, _on_search_completed)

## Callback for search request completion
## Processes the search API response and emits appropriate signals
func _on_search_completed(body: PackedByteArray, error: String) -> void:
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		push_error("[IkeaApiWrapper] Search request failed: %s" % error)
		search_failed.emit(error)
		return
	
	# Validate body
	if body == null or body.size() == 0:
		push_error("[IkeaApiWrapper] Search returned empty response body")
		search_failed.emit("Empty response from search API")
		return
	
	# Parse JSON response
	var data = _parse_json(body)
	if data == null:
		var error_msg = "Failed to parse search response JSON"
		push_error("[IkeaApiWrapper] %s" % error_msg)
		search_failed.emit(error_msg)
		return
	
	# Validate response structure
	if not data.has("searchResultPage"):
		push_error("[IkeaApiWrapper] Invalid search response: missing 'searchResultPage' field")
		search_failed.emit("Invalid search response structure: missing searchResultPage")
		return
	
	var search_page = data["searchResultPage"]
	if not search_page.has("products"):
		push_error("[IkeaApiWrapper] Invalid search response: missing 'products' field in searchResultPage")
		search_failed.emit("Invalid search response structure: missing products")
		return
	
	var products = search_page["products"]
	if not products.has("main"):
		push_error("[IkeaApiWrapper] Invalid search response: missing 'main' field in products")
		search_failed.emit("Invalid search response structure: missing main products")
		return
	
	var main = products["main"]
	if not main.has("items"):
		push_error("[IkeaApiWrapper] Invalid search response: missing 'items' field in main")
		search_failed.emit("Invalid search response structure: missing items")
		return
	
	# Extract product items
	var items = main["items"]
	if not items is Array:
		push_error("[IkeaApiWrapper] Invalid search response: 'items' is not an array")
		search_failed.emit("Invalid search response structure: items is not an array")
		return
	
	var results: Array = []
	var skipped_count = 0
	
	# Process each product item
	for item in items:
		# Check if this is a product type item
		if not item.has("product") or item.get("type") != "PRODUCT":
			skipped_count += 1
			continue
		
		var product = item["product"]
		
		# Debug: print first product structure
		if results.is_empty():
			print("[IkeaApiWrapper] First product fields: ", product.keys())
		
		# Extract required fields from product
		if not product.has("itemNo") or not product.has("name"):
			skipped_count += 1
			continue
		
		# Build result dictionary
		var result = {
			"itemNo": product["itemNo"],
			"name": product["name"],
			"mainImageUrl": product.get("mainImageUrl", product.get("imageUrl", "")),
			"mainImageAlt": product.get("mainImageAlt", product.get("name", "")),
			"pipUrl": product.get("pipUrl", "")
		}
		
		results.append(result)
	
	if skipped_count > 0:
		print("[IkeaApiWrapper] Skipped %d items with missing required fields" % skipped_count)
	
	print("[IkeaApiWrapper] Search completed: found %d products" % results.size())
	
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
		push_error("[IkeaApiWrapper] PIP request failed for item %s: %s" % [item_no, error])
		pip_failed.emit(compact, error)
		return
	
	# Validate body
	if body == null or body.size() == 0:
		var error_msg = "Empty response from PIP API"
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		pip_failed.emit(compact, error_msg)
		return
	
	# Parse JSON response
	var data = _parse_json(body)
	if data == null:
		var error_msg = "Failed to parse PIP response JSON"
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		pip_failed.emit(compact, error_msg)
		return
	
	# Save to cache
	var cache_path = _save_to_cache(item_no, "pip.json", body)
	if cache_path.is_empty():
		push_error("[IkeaApiWrapper] Failed to cache PIP data for item %s (continuing with uncached data)" % item_no)
		# Continue anyway - we still have the data
	
	print("[IkeaApiWrapper] PIP data loaded for item %s" % compact)
	
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
		push_error("[IkeaApiWrapper] Thumbnail download failed for item %s: %s" % [item_no, error])
		thumbnail_failed.emit(compact, error)
		return
	
	# Validate that we received data
	if body == null or body.size() == 0:
		var error_msg = "Downloaded thumbnail is empty"
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		thumbnail_failed.emit(compact, error_msg)
		return
	
	# Validate minimum image size (should be at least a few hundred bytes for a valid image)
	if body.size() < 100:
		var error_msg = "Downloaded thumbnail is too small (%d bytes) - likely invalid" % body.size()
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		thumbnail_failed.emit(compact, error_msg)
		return
	
	# Save to cache
	var cache_path = _save_to_cache(item_no, "thumbnail.jpg", body)
	if cache_path.is_empty():
		var error_msg = "Failed to save thumbnail to cache"
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		thumbnail_failed.emit(compact, error_msg)
		return
	
	print("[IkeaApiWrapper] Thumbnail downloaded for item %s: %s" % [compact, cache_path])
	
	# Emit success signal with the file path
	thumbnail_downloaded.emit(compact, cache_path)

## Checks if a 3D model exists for a specific item number
## Checks cache first, then queries the IKEA exists API
## Emits model_exists_checked signal with item number and availability status
func check_model_exists(item_no: String) -> void:
	# Validate item number format
	if not is_item_no(item_no):
		push_error("[IkeaApiWrapper] Invalid item number format: " + item_no)
		model_exists_checked.emit(item_no, false)
		return
	
	var compact = compact_item_no(item_no)
	
	# Check cache first
	if _cache_exists(item_no, "exists.json"):
		var cached_data = _load_from_cache(item_no, "exists.json")
		if cached_data != null:
			# Parse the cached JSON data
			var data = _parse_json(cached_data)
			if data != null and data.has("exists"):
				model_exists_checked.emit(compact, data["exists"])
				return
			else:
				push_error("[IkeaApiWrapper] Failed to parse cached exists data for item " + item_no)
				# Continue to fetch from API if cache is corrupted
	
	# Build exists API URL
	# URL format: https://web-api.ikea.com/{country}/{language}/rotera/data/exists/{item_no}/
	var url = "https://web-api.ikea.com/%s/%s/rotera/data/exists/%s/" % [country, language, compact]
	
	# Make the HTTP request (X-Client-Id header will be added automatically by _make_request)
	_make_request(url, {}, {}, _on_model_exists_completed.bind(item_no))

## Callback for model exists check completion
## Processes the exists API response, caches it, and emits appropriate signals
func _on_model_exists_completed(body: PackedByteArray, error: String, item_no: String) -> void:
	var compact = compact_item_no(item_no)
	
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		push_error("[IkeaApiWrapper] Model exists check failed for item %s: %s" % [item_no, error])
		model_exists_checked.emit(compact, false)
		return
	
	# Validate body
	if body == null or body.size() == 0:
		push_error("[IkeaApiWrapper] Empty response from model exists API for item %s" % item_no)
		model_exists_checked.emit(compact, false)
		return
	
	# Parse JSON response
	var data = _parse_json(body)
	if data == null:
		push_error("[IkeaApiWrapper] Failed to parse exists response JSON for item %s" % item_no)
		model_exists_checked.emit(compact, false)
		return
	
	# Validate response structure
	if not data.has("exists"):
		push_error("[IkeaApiWrapper] Invalid exists response: missing 'exists' field for item %s" % item_no)
		model_exists_checked.emit(compact, false)
		return
	
	# Validate exists field type
	var exists = data["exists"]
	if not (exists is bool):
		push_error("[IkeaApiWrapper] Invalid exists response: 'exists' field is not a boolean for item %s (got: %s)" % [item_no, str(exists)])
		model_exists_checked.emit(compact, false)
		return
	
	# Save to cache
	var cache_path = _save_to_cache(item_no, "exists.json", body)
	if cache_path.is_empty():
		push_error("[IkeaApiWrapper] Failed to cache exists data for item %s (continuing with uncached data)" % item_no)
		# Continue anyway - we still have the data
	
	print("[IkeaApiWrapper] Model exists check for item %s: %s" % [compact, "available" if exists else "not available"])
	
	# Emit signal with the exists status
	model_exists_checked.emit(compact, exists)

## Downloads a 3D model (GLB file) for a specific item number
## Checks cache first, verifies model availability, fetches metadata, and downloads the model
## Emits model_downloaded signal with item number and file path on success
## Emits model_failed signal with item number and error message on failure
func get_model(item_no: String) -> void:
	# Validate item number format
	if not is_item_no(item_no):
		var error_msg = "Invalid item number format"
		push_error("[IkeaApiWrapper] %s: %s" % [error_msg, item_no])
		model_failed.emit(item_no, error_msg)
		return
	
	var compact = compact_item_no(item_no)
	
	# Check cache first
	if _cache_exists(item_no, "model.glb"):
		var file_path = cache_dir.path_join(compact).path_join("model.glb")
		print("[IkeaApiWrapper] Model found in cache for item %s: %s" % [compact, file_path])
		model_downloaded.emit(compact, file_path)
		return
	
	print("[IkeaApiWrapper] Model not in cache, checking availability for item %s" % compact)
	
	# Check if model exists before attempting to download
	# We need to wait for the exists check to complete, so we'll connect to the signal
	# First, check if we have cached exists data
	if _cache_exists(item_no, "exists.json"):
		var cached_data = _load_from_cache(item_no, "exists.json")
		if cached_data != null:
			var data = _parse_json(cached_data)
			if data != null and data.has("exists"):
				if data["exists"]:
					# Model exists, proceed to fetch metadata
					print("[IkeaApiWrapper] Model availability confirmed from cache for item %s" % compact)
					_fetch_model_metadata(item_no)
				else:
					# Model doesn't exist
					var error_msg = "No 3D model available for this item"
					push_error("[IkeaApiWrapper] %s: %s" % [error_msg, item_no])
					model_failed.emit(compact, error_msg)
				return
			else:
				push_error("[IkeaApiWrapper] Cached exists data is corrupted for item %s, re-checking" % item_no)
	
	# No cached exists data, need to check
	# Connect to the signal temporarily to handle the response
	var on_exists_checked: Callable = func(checked_item_no: String, exists: bool):
		if checked_item_no == compact:
			if exists:
				# Model exists, proceed to fetch metadata
				print("[IkeaApiWrapper] Model availability confirmed for item %s" % compact)
				_fetch_model_metadata(item_no)
			else:
				# Model doesn't exist
				var error_msg = "No 3D model available for this item"
				push_error("[IkeaApiWrapper] %s: %s" % [error_msg, item_no])
				model_failed.emit(compact, error_msg)
	
	model_exists_checked.connect(on_exists_checked, CONNECT_ONE_SHOT)
	check_model_exists(item_no)

## Internal method to fetch model metadata from the rotera API
## This is called after confirming the model exists
func _fetch_model_metadata(item_no: String) -> void:
	var compact = compact_item_no(item_no)
	
	# Build model metadata API URL
	# URL format: https://web-api.ikea.com/{country}/{language}/rotera/data/model/{item_no}/
	var url = "https://web-api.ikea.com/%s/%s/rotera/data/model/%s/" % [country, language, compact]
	
	# Make the HTTP request (X-Client-Id header will be added automatically by _make_request)
	_make_request(url, {}, {}, _on_model_metadata_completed.bind(item_no))

## Callback for model metadata request completion
## Extracts the model URL and initiates the GLB file download
func _on_model_metadata_completed(body: PackedByteArray, error: String, item_no: String) -> void:
	var compact = compact_item_no(item_no)
	
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		var error_msg = "Failed to fetch model metadata: %s" % error
		push_error("[IkeaApiWrapper] Model metadata request failed for item %s: %s" % [item_no, error])
		model_failed.emit(compact, error_msg)
		return
	
	# Validate body
	if body == null or body.size() == 0:
		var error_msg = "Empty response from model metadata API"
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		model_failed.emit(compact, error_msg)
		return
	
	# Parse JSON response
	var data = _parse_json(body)
	if data == null:
		var error_msg = "Failed to parse model metadata"
		push_error("[IkeaApiWrapper] Failed to parse model metadata response JSON for item %s" % item_no)
		model_failed.emit(compact, error_msg)
		return
	
	# Debug: print metadata structure
	print("[IkeaApiWrapper] Model metadata keys: ", data.keys())
	
	# Extract modelUrl from the response
	if not data.has("modelUrl"):
		var error_msg = "Model URL not found in metadata"
		push_error("[IkeaApiWrapper] Invalid model metadata response: missing 'modelUrl' field for item %s" % item_no)
		model_failed.emit(compact, error_msg)
		return
	
	var model_url = data["modelUrl"]
	
	# Try to get uncompressed version by replacing draco compressed paths
	# The simple/draco versions use Draco compression which Godot doesn't support by default
	if "/simple/glb_draco/" in model_url:
		# Try replacing with uncompressed version
		var uncompressed_url = model_url.replace("/simple/glb_draco/", "/uncompressed/glb/")
		uncompressed_url = uncompressed_url.replace("-simple+draco.glb", "-uncompressed.glb")
		print("[IkeaApiWrapper] Trying uncompressed URL: %s" % uncompressed_url)
		model_url = uncompressed_url
	elif "/simple/glb/" in model_url:
		var uncompressed_url = model_url.replace("/simple/glb/", "/uncompressed/glb/")
		uncompressed_url = uncompressed_url.replace("-simple.glb", "-uncompressed.glb")
		print("[IkeaApiWrapper] Trying uncompressed URL: %s" % uncompressed_url)
		model_url = uncompressed_url
	if not (model_url is String) or model_url.is_empty():
		var error_msg = "Model URL is empty or invalid"
		push_error("[IkeaApiWrapper] Invalid model URL for item %s: %s" % [item_no, str(model_url)])
		model_failed.emit(compact, error_msg)
		return
	
	# Validate URL format
	if not model_url.begins_with("http://") and not model_url.begins_with("https://"):
		var error_msg = "Model URL has invalid format"
		push_error("[IkeaApiWrapper] Invalid model URL format for item %s: %s" % [item_no, model_url])
		model_failed.emit(compact, error_msg)
		return
	
	print("[IkeaApiWrapper] Downloading model from: %s" % model_url)
	
	# Download the GLB file from the model URL
	_make_request(model_url, {}, {}, _on_model_download_completed.bind(item_no))

## Callback for model GLB file download completion
## Saves the downloaded model to cache and emits appropriate signals
func _on_model_download_completed(body: PackedByteArray, error: String, item_no: String) -> void:
	var compact = compact_item_no(item_no)
	
	# Check for HTTP request errors
	if error != null and not error.is_empty():
		var error_msg = "Failed to download model: %s" % error
		push_error("[IkeaApiWrapper] Model download failed for item %s: %s" % [item_no, error])
		model_failed.emit(compact, error_msg)
		return
	
	# Validate that we received data
	if body == null or body.size() == 0:
		var error_msg = "Downloaded model is empty"
		push_error("[IkeaApiWrapper] Model download returned empty data for item %s" % item_no)
		model_failed.emit(compact, error_msg)
		return
	
	# Validate minimum GLB file size (GLB files have a header and should be at least 1KB)
	if body.size() < 1024:
		var error_msg = "Downloaded model is too small (%d bytes) - likely invalid or corrupted" % body.size()
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		model_failed.emit(compact, error_msg)
		return
	
	# Validate GLB file signature (first 4 bytes should be "glTF" in ASCII: 0x676C5446)
	if body.size() >= 4:
		var magic = body.decode_u32(0)
		if magic != 0x46546C67:  # "glTF" in little-endian
			var error_msg = "Downloaded file is not a valid GLB file (invalid magic number)"
			push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
			model_failed.emit(compact, error_msg)
			return
	
	# Save to cache
	var cache_path = _save_to_cache(item_no, "model.glb", body)
	if cache_path.is_empty():
		var error_msg = "Failed to save model to cache"
		push_error("[IkeaApiWrapper] %s for item %s" % [error_msg, item_no])
		model_failed.emit(compact, error_msg)
		return
	
	print("[IkeaApiWrapper] Model downloaded for item %s (%d bytes): %s" % [compact, body.size(), cache_path])
	
	# Emit success signal with the file path
	model_downloaded.emit(compact, cache_path)
