# Implementation Plan

- [x] 1. Set up addon structure and plugin configuration
  - Create the `addons/ikea_api/` directory structure
  - Write `plugin.cfg` with addon metadata
  - Create placeholder icon.png file
  - _Requirements: 6.1, 6.3_

- [x] 2. Implement core IkeaApiWrapper class structure
  - [x] 2.1 Create ikea_api_wrapper.gd with class definition extending Node
    - Define class properties (country, language, cache_dir, http_pool)
    - Implement _init() constructor with country and language parameters
    - Define all signal declarations for async operations
    - _Requirements: 6.1, 6.2, 6.3, 9.1, 9.2, 9.3, 9.4_
  
  - [x] 2.2 Implement HTTPRequest pool management
    - Write _get_http_request() method to manage pool of HTTPRequest nodes
    - Implement MAX_HTTP_REQUESTS constant and pool size limiting
    - Add HTTPRequest nodes to scene tree in _ready()
    - _Requirements: 9.5_

- [x] 3. Implement item number utility functions
  - [x] 3.1 Create static utility methods for item number handling
    - Write is_item_no() with regex pattern matching for XXX.XXX.XX format
    - Write compact_item_no() to strip formatting characters
    - Write format_item_no() to convert compact format to XXX.XXX.XX
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 4. Implement cache management system
  - [x] 4.1 Create cache directory and file operations
    - Write _ensure_cache_dir() to create item-specific cache directories
    - Write _cache_exists() to check if cached file exists
    - Write _save_to_cache() to save binary data to cache files
    - Write _load_from_cache() to read cached data
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 5. Implement HTTP request handling
  - [x] 5.1 Create generic HTTP request method
    - Write _make_request() method accepting URL, params, headers, and callback
    - Implement URL parameter encoding for query strings
    - Add request header building with CLIENT_ID and USER_AGENT
    - Connect HTTPRequest signals to callback handlers
    - _Requirements: 7.4_
  
  - [x] 5.2 Implement request completion handler
    - Write _on_request_completed() to process HTTP responses
    - Add response code validation (200-299 range)
    - Implement error signal emission for failed requests
    - Parse response body and pass to callback
    - _Requirements: 7.1, 7.2, 7.4_
  
  - [x] 5.3 Add JSON parsing and error handling
    - Write _parse_json() to safely parse JSON from PackedByteArray
    - Implement try-catch equivalent for JSON parsing errors
    - Emit error signals with descriptive messages on parse failures
    - _Requirements: 7.3, 7.5_

- [x] 6. Implement search functionality
  - [x] 6.1 Create search() method
    - Build search API URL with country and language
    - Construct query parameters (types, q, size, c, v, autocorrect)
    - Detect item number queries and adjust parameters accordingly
    - Make HTTP request with search parameters
    - _Requirements: 1.1, 1.3_
  
  - [x] 6.2 Process search results
    - Parse search API JSON response
    - Extract product items from searchResultPage.products.main.items
    - Validate required fields (itemNo, name, mainImageUrl, mainImageAlt, pipUrl)
    - Filter out products without available 3D models
    - Build result array with product dictionaries
    - Emit search_completed signal with results array
    - _Requirements: 1.2, 1.4, 1.5_

- [x] 7. Implement PIP (Product Information Page) retrieval
  - [x] 7.1 Create get_pip() method
    - Check cache for existing pip.json file
    - Return cached data if available
    - Build PIP API URL using item number
    - Make HTTP request to fetch PIP data
    - _Requirements: 2.3_
  
  - [x] 7.2 Process and cache PIP data
    - Parse JSON response from PIP API
    - Save JSON data to cache as pip.json
    - Emit pip_loaded signal with item number and data
    - Handle errors and emit pip_failed signal
    - _Requirements: 2.1, 2.2, 2.4, 2.5_

- [x] 8. Implement thumbnail download functionality
  - [x] 8.1 Create get_thumbnail() method
    - Check cache for existing thumbnail.jpg file
    - Return cached path if thumbnail exists
    - Make HTTP request to download image from provided URL
    - _Requirements: 3.3_
  
  - [x] 8.2 Save and return thumbnail path
    - Save downloaded image data as thumbnail.jpg in cache
    - Return file path to cached thumbnail
    - Emit thumbnail_downloaded signal with item number and path
    - Handle download errors and emit thumbnail_failed signal
    - _Requirements: 3.1, 3.2, 3.4, 3.5_

- [x] 9. Implement 3D model download functionality
  - [x] 9.1 Create check_model_exists() method
    - Check cache for exists.json file
    - Build exists API URL with item number
    - Add X-Client-Id header for web-api.ikea.com requests
    - Make HTTP request to check model availability
    - Parse exists response and cache result
    - Emit model_exists_checked signal
    - _Requirements: 4.1_
  
  - [x] 9.2 Create get_model() method
    - Check cache for existing model.glb file
    - Return cached path if model exists
    - Call check_model_exists() to verify availability
    - Fetch model metadata from rotera API if model exists
    - Extract modelUrl from metadata response
    - Download GLB file from modelUrl
    - _Requirements: 4.1, 4.2, 4.4_
  
  - [x] 9.3 Save model and handle errors
    - Save downloaded GLB data as model.glb in cache
    - Return file path to cached model
    - Emit model_downloaded signal with item number and path
    - Emit model_failed signal if model unavailable or download fails
    - _Requirements: 4.3, 4.5_

- [x] 10. Add error handling and logging
  - [x] 10.1 Implement comprehensive error handling
    - Add push_error() calls for all error conditions
    - Ensure all error paths emit appropriate error signals
    - Add descriptive error messages for debugging
    - Handle network timeouts with timeout detection
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 11. Create README documentation
  - [x] 11.1 Write addon README.md
    - Document installation instructions
    - Provide usage examples with code snippets
    - List all available methods and signals
    - Include configuration options (country, language)
    - Add troubleshooting section
    - _Requirements: All_

- [ ] 12. Integration and end-to-end validation
  - [ ] 12.1 Create test scene for manual testing
    - Build test scene with IkeaApiWrapper node
    - Connect all signals to test handlers
    - Test search with various queries
    - Test PIP retrieval for multiple items
    - Test thumbnail and model downloads
    - Verify cache behavior (hit and miss scenarios)
    - Test error conditions (invalid item numbers, network failures)
    - _Requirements: All_
  
  - [ ]* 12.2 Verify cross-platform compatibility
    - Test on Windows, Linux, and macOS
    - Verify file path handling across platforms
    - Test SSL/TLS connections on all platforms
    - _Requirements: All_
