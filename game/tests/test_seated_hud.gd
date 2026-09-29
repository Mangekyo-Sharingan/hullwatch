extends SceneTree

class SeatPlayer extends Node3D:
	var seated: bool = false
	var target: CollisionObject3D

	func _ready() -> void:
		add_to_group(&"player")

	func is_pilot_seated() -> bool:
		return seated

	func get_seated_target() -> CollisionObject3D:
		return target

	func get_pilot_seat() -> PilotChair:
		return null


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var main: Node3D = Node3D.new()
	root.add_child(main)
	var world_layout: Node3D = Node3D.new()
	world_layout.name = "WorldLayout"
	main.add_child(world_layout)
	var props: Node3D = Node3D.new()
	props.name = "Props"
	world_layout.add_child(props)
	var player: SeatPlayer = SeatPlayer.new()
	main.add_child(player)
	var camera: Camera3D = Camera3D.new()
	player.add_child(camera)
	camera.make_current()
	var station: StaticBody3D = StaticBody3D.new()
	station.name = "NavConsole"
	station.position = Vector3(0.0, 0.0, -2.0)
	props.add_child(station)
	var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	var visor: Control = hud.get_node(^"PilotVisor") as Control
	var label: Label = visor.get_node(^"SeatMarker_NavConsole") as Label
	if visor.visible or label.is_visible_in_tree():
		_fail("visor appears while standing")
	player.seated = true
	hud.call("_update_seated_overlay")
	if not visor.visible or not label.visible or label.text != "[ NAVIGATION ]":
		_fail("seat shows projected live station label")
	if label.position.y >= camera.unproject_position(station.global_position).y - 24.0:
		_fail("station label sits above the module readout")
	player.target = station
	hud.call("_update_seated_overlay")
	if label.text != "[E] NAVIGATION":
		_fail("real ray target receives E highlight")
	var hint: Label = visor.get_node(^"SeatHint") as Label
	if not hint.text.contains("[X] LEAVE SEAT"):
		_fail("seat shows exit control")
	player.seated = false
	hud.call("_update_seated_overlay")
	if visor.visible:
		_fail("visor hides after leaving seat")
	hud.free()
	main.free()
	if _failures == 0:
		print("PASS: test_seated_hud")
	quit(0 if _failures == 0 else 1)


var _failures: int = 0


func _fail(message: String) -> void:
	_failures += 1
	print("FAIL: ", message)
