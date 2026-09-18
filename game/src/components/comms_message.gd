## One piece of comms traffic: scripted inbound traffic or a player-sendable outbound report.
class_name CommsMessage
extends Resource

@export var id: StringName = &""
@export var sender: String = ""
@export var date_text: String = ""
@export_multiline var body: String = ""
@export var direction: StringName = &"in"
@export var arrival_day: int = 1
@export var reply_id: StringName = &""
@export var reply_delay_days: float = 8.0
