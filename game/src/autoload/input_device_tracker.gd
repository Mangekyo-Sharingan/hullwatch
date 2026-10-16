## Keeps InputHints.gamepad_active current so on-screen hints follow the device the player is
## using. On a Steam Deck (Steam sets SteamDeck=1) hints start on gamepad names.
extends Node


func _ready() -> void:
	InputHints.set_gamepad_active(OS.get_environment("SteamDeck") == "1")


func _input(event: InputEvent) -> void:
	InputHints.note_event(event)
