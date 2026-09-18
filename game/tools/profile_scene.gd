## Frame-cost profiler: measures wall-clock frame time with and without the main scene.
## Note: Performance.TIME_PROCESS is unusable under --headless (reports ~30x wall time),
## so this uses wall-clock deltas and subtracts an empty-scene baseline.
## Run: & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/profile_scene.gd
extends SceneTree

const SAMPLE_FRAMES: int = 240
const SCENE_DELTA_BUDGET_MS: float = 5.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var baseline_ms: float = await _measure_ms()
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var with_scene_ms: float = await _measure_ms()
	var delta_ms: float = with_scene_ms - baseline_ms
	print("PROFILE: frame %.2f ms baseline, %.2f ms with scene (scene cost %.2f ms, headless loop is throttled)" % [baseline_ms, with_scene_ms, delta_ms])
	var within_budget: bool = delta_ms < SCENE_DELTA_BUDGET_MS
	main.free()
	if within_budget:
		print("PASS: profile_scene")
		quit(0)
	else:
		print("FAIL: profile_scene (scene cost %.2f ms exceeds %.1f ms budget)" % [delta_ms, SCENE_DELTA_BUDGET_MS])
		quit(1)


func _measure_ms() -> float:
	for i: int in 30:
		await process_frame
	var total_ms: float = 0.0
	for i: int in SAMPLE_FRAMES:
		var before: int = Time.get_ticks_usec()
		await process_frame
		total_ms += float(Time.get_ticks_usec() - before) / 1000.0
	return total_ms / float(SAMPLE_FRAMES)
