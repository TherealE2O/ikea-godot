@tool
extends Control

var ikea: IkeaApiWrapper
var search_results: Array = []

@onready var search_input: LineEdit = %SearchInput
@onready var search_button: Button = %SearchButton
@onready var results_container: VBoxContainer = %ResultsContainer
@onready var status_label: Label = %StatusLabel
@onready var scroll_container: ScrollContainer = %ScrollContainer

func _ready():
	# Create the IKEA API wrapper
	ikea = IkeaApiWrapper.new()
	add_child(ikea)
	
	# Connect signals
	ikea.search_completed.connect(_on_search_completed)
	ikea.search_failed.connect(_on_search_failed)
	ikea.model_downloaded.connect(_on_model_downloaded)
	ikea.model_failed.connect(_on_model_failed)
	ikea.model_exists_checked.connect(_on_model_exists_checked)
	
	# Connect UI signals
	search_button.pressed.connect(_on_search_pressed)
	search_input.text_submitted.connect(_on_search_submitted)
	
	status_label.text = "Ready to search IKEA products"

func _on_search_pressed():
	_perform_search()

func _on_search_submitted(_text: String):
	_perform_search()

func _perform_search():
	var query = search_input.text.strip_edges()
	if query.is_empty():
		status_label.text = "Please enter a search term"
		return
	
	# Clear previous results
	_clear_results()
	status_label.text = "Searching for '%s'..." % query
	search_button.disabled = true
	
	# Perform search
	ikea.search(query)

func _clear_results():
	for child in results_container.get_children():
		child.queue_free()
	search_results.clear()

func _on_search_completed(results: Array):
	search_button.disabled = false
	search_results = results
	
	if results.is_empty():
		status_label.text = "No products found"
		return
	
	status_label.text = "Found %d product%s" % [results.size(), "s" if results.size() != 1 else ""]
	
	# Display results
	for item in results:
		var result_item = _create_result_item(item)
		results_container.add_child(result_item)

func _create_result_item(item: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	
	# Product name and item number
	var header = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = item.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(name_label)
	
	container.add_child(header)
	
	# Item number
	var item_no_label = Label.new()
	item_no_label.text = "Item: %s" % item.itemNo
	item_no_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	container.add_child(item_no_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 4)
	
	# Check model button
	var check_button = Button.new()
	check_button.text = "Check Model"
	check_button.pressed.connect(_on_check_model_pressed.bind(item.itemNo))
	button_container.add_child(check_button)
	
	# Download model button
	var download_button = Button.new()
	download_button.text = "Download Model"
	download_button.disabled = true
	download_button.name = "DownloadButton_%s" % item.itemNo
	download_button.pressed.connect(_on_download_model_pressed.bind(item.itemNo))
	button_container.add_child(download_button)
	
	# Status label for this item
	var item_status = Label.new()
	item_status.name = "Status_%s" % item.itemNo
	item_status.text = ""
	item_status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	button_container.add_child(item_status)
	
	container.add_child(button_container)
	
	# Separator
	var separator = HSeparator.new()
	container.add_child(separator)
	
	return container

func _on_check_model_pressed(item_no: String):
	var status = _find_item_status(item_no)
	if status:
		status.text = "Checking..."
	ikea.check_model_exists(item_no)

func _on_download_model_pressed(item_no: String):
	var status = _find_item_status(item_no)
	if status:
		status.text = "Downloading..."
	
	var download_button = _find_download_button(item_no)
	if download_button:
		download_button.disabled = true
	
	ikea.get_model(item_no)

func _on_model_exists_checked(item_no: String, exists: bool):
	var status = _find_item_status(item_no)
	var download_button = _find_download_button(item_no)
	
	if exists:
		if status:
			status.text = "✓ Model available"
			status.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		if download_button:
			download_button.disabled = false
	else:
		if status:
			status.text = "✗ No model"
			status.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))

func _on_model_downloaded(item_no: String, path: String):
	var status = _find_item_status(item_no)
	if status:
		status.text = "✓ Downloaded: %s" % path.get_file()
		status.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	
	var download_button = _find_download_button(item_no)
	if download_button:
		download_button.disabled = false
		download_button.text = "Re-download"
	
	print("[IKEA Browser] Model downloaded: %s" % path)

func _on_model_failed(item_no: String, error: String):
	var status = _find_item_status(item_no)
	if status:
		status.text = "✗ Failed: %s" % error
		status.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	
	var download_button = _find_download_button(item_no)
	if download_button:
		download_button.disabled = false

func _on_search_failed(error: String):
	search_button.disabled = false
	status_label.text = "Search failed: %s" % error

func _find_item_status(item_no: String) -> Label:
	return results_container.find_child("Status_%s" % item_no, true, false) as Label

func _find_download_button(item_no: String) -> Button:
	return results_container.find_child("DownloadButton_%s" % item_no, true, false) as Button
