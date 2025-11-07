# Requirements Document

## Introduction

This document specifies the requirements for a Godot addon that provides an IKEA API wrapper functionality equivalent to the Python ikea_lib.py implementation. The addon will enable Godot developers to search for IKEA products, retrieve product information, download thumbnails, and fetch 3D models directly within their Godot projects.

## Glossary

- **Godot Addon**: A plugin or extension for the Godot game engine that adds functionality to the editor or runtime
- **IKEA API**: The web services provided by IKEA for searching products and retrieving product data
- **Item Number**: An 8-digit IKEA product identifier in the format XXX.XXX.XX or XXXXXXXX
- **PIP**: Product Information Page data containing detailed product metadata
- **GLB**: GL Transmission Format Binary file, a 3D model format
- **HTTP Client**: Godot's HTTPRequest node or HTTPClient class for making web requests
- **Cache System**: Local file storage mechanism for downloaded data to avoid redundant API calls
- **GDScript**: The primary scripting language for Godot engine

## Requirements

### Requirement 1

**User Story:** As a Godot developer, I want to search for IKEA products by name or item number, so that I can find and import relevant furniture models into my game or application

#### Acceptance Criteria

1. WHEN the developer provides a search query string, THE Godot Addon SHALL send an HTTP request to the IKEA search API with appropriate parameters
2. WHEN the search API returns results, THE Godot Addon SHALL parse the JSON response and extract product information including item number, name, image URL, and product page URL
3. WHEN the search query is an item number in format XXX.XXX.XX or XXXXXXXX, THE Godot Addon SHALL limit the search results to one item
4. WHEN a product in search results has no available 3D model, THE Godot Addon SHALL exclude that product from the returned results
5. THE Godot Addon SHALL return a list of dictionaries containing itemNo, name, mainImageUrl, mainImageAlt, and pipUrl for each valid product

### Requirement 2

**User Story:** As a Godot developer, I want to retrieve detailed product information for a specific IKEA item, so that I can display metadata or make informed decisions about which products to import

#### Acceptance Criteria

1. WHEN the developer provides a valid item number, THE Godot Addon SHALL fetch the Product Information Page JSON data from the IKEA API
2. WHEN PIP data is successfully retrieved, THE Godot Addon SHALL cache the JSON data locally in the cache directory structure
3. WHEN PIP data exists in the cache, THE Godot Addon SHALL return the cached data without making a new API request
4. IF the API request fails, THEN THE Godot Addon SHALL emit an error signal with a descriptive message
5. THE Godot Addon SHALL validate that the item number matches the pattern of 8 digits before making the request

### Requirement 3

**User Story:** As a Godot developer, I want to download product thumbnail images, so that I can display product previews in my application's UI

#### Acceptance Criteria

1. WHEN the developer requests a thumbnail for a specific item number with an image URL, THE Godot Addon SHALL download the image data via HTTP
2. WHEN the thumbnail is successfully downloaded, THE Godot Addon SHALL save it as a JPEG file in the cache directory under the item number folder
3. WHEN a thumbnail already exists in the cache, THE Godot Addon SHALL return the cached file path without downloading again
4. THE Godot Addon SHALL return the absolute or relative path to the downloaded thumbnail file
5. IF the download fails, THEN THE Godot Addon SHALL emit an error signal with details about the failure

### Requirement 4

**User Story:** As a Godot developer, I want to download 3D models in GLB format, so that I can import IKEA furniture directly into my Godot scenes

#### Acceptance Criteria

1. WHEN the developer requests a model for a specific item number, THE Godot Addon SHALL first check if the model exists via the IKEA exists API endpoint
2. WHEN a model exists, THE Godot Addon SHALL fetch the model metadata from the rotera API to obtain the model download URL
3. WHEN the model URL is obtained, THE Godot Addon SHALL download the GLB file and save it to the cache directory
4. WHEN a model file already exists in the cache, THE Godot Addon SHALL return the cached file path without downloading again
5. IF no model is available for the item number, THEN THE Godot Addon SHALL emit an error signal indicating model unavailability

### Requirement 5

**User Story:** As a Godot developer, I want the addon to cache all downloaded data locally, so that I can reduce API calls and improve performance during development

#### Acceptance Criteria

1. THE Godot Addon SHALL create a cache directory structure organized by item number
2. WHEN any data is downloaded from the IKEA API, THE Godot Addon SHALL store it in the appropriate cache subdirectory
3. WHEN the addon checks for cached data, THE Godot Addon SHALL verify file existence before attempting to read
4. THE Godot Addon SHALL support cache paths relative to the project root directory
5. THE Godot Addon SHALL create necessary parent directories when caching new data

### Requirement 6

**User Story:** As a Godot developer, I want to configure the country and language settings for the IKEA API, so that I can access region-specific product catalogs

#### Acceptance Criteria

1. WHEN the addon is initialized, THE Godot Addon SHALL accept country code and language code parameters
2. THE Godot Addon SHALL use the configured country and language codes in all API requests
3. THE Godot Addon SHALL provide default values of "ie" for country and "en" for language
4. THE Godot Addon SHALL format API URLs using the configured country and language codes
5. THE Godot Addon SHALL allow developers to change country and language settings at runtime

### Requirement 7

**User Story:** As a Godot developer, I want the addon to handle HTTP errors gracefully, so that my application doesn't crash when API requests fail

#### Acceptance Criteria

1. WHEN an HTTP request returns a status code outside the 200-299 range, THE Godot Addon SHALL emit an error signal with the status code and reason
2. WHEN a network timeout occurs, THE Godot Addon SHALL emit an error signal indicating the timeout
3. WHEN JSON parsing fails, THE Godot Addon SHALL emit an error signal with parsing details
4. THE Godot Addon SHALL log debug information for all HTTP requests including URL and headers
5. THE Godot Addon SHALL provide descriptive error messages that help developers diagnose issues

### Requirement 8

**User Story:** As a Godot developer, I want the addon to provide utility functions for item number formatting, so that I can work with item numbers in different formats

#### Acceptance Criteria

1. THE Godot Addon SHALL provide a function to validate if a string matches the item number pattern
2. THE Godot Addon SHALL provide a function to remove formatting characters and return a compact 8-digit item number
3. THE Godot Addon SHALL provide a function to format a compact item number into XXX.XXX.XX format
4. THE Godot Addon SHALL handle item numbers with or without dots correctly
5. THE Godot Addon SHALL use regular expressions or string manipulation to process item numbers

### Requirement 9

**User Story:** As a Godot developer, I want the addon to use Godot signals for asynchronous operations, so that I can respond to completed downloads and errors without blocking the main thread

#### Acceptance Criteria

1. THE Godot Addon SHALL emit a signal when a search operation completes successfully
2. THE Godot Addon SHALL emit a signal when a model download completes successfully
3. THE Godot Addon SHALL emit a signal when a thumbnail download completes successfully
4. THE Godot Addon SHALL emit a signal when any operation encounters an error
5. THE Godot Addon SHALL use HTTPRequest nodes for asynchronous HTTP operations to avoid blocking
