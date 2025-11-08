# PreferencesDialog.gd
@tool
extends ConfirmationDialog

@onready var country_edit = $VBoxContainer/GridContainer/CountryEdit
@onready var language_edit = $VBoxContainer/GridContainer/LanguageEdit
@onready var debug_check = $VBoxContainer/DebugCheck


func _ready():
    window_title = "IKEA Browser Preferences"


func get_country() -> String:
    return country_edit.text.strip_edges()


func get_language() -> String:
    return language_edit.text.strip_edges()


func get_debug() -> bool:
    return debug_check.button_pressed


func set_values(country: String, language: String, debug: bool):
    country_edit.text = country
    language_edit.text = language
    debug_check.button_pressed = debug