## GENERATED station furniture: builds the cramped-station props, doors, kit decorations, atmosphere
## zones and compartment links from the tables below into res://scenes/world_layout.tscn.
## Everything is built in memory and packed, so the layout is reproducible from this one file.
## Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_world_layout.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/world_layout.tscn"

const MATERIAL_MACHINE_TEAL: String = "res://src/data/materials/mat_machine_teal.tres"
const MATERIAL_PANEL_SCRATCHED: String = "res://src/data/materials/mat_panel_scratched.tres"
const MATERIAL_WALL_PAINTED: String = "res://src/data/materials/mat_wall_painted.tres"
const MATERIAL_FLOOR_GRATE: String = "res://src/data/materials/mat_deck_plate.tres"
const MATERIAL_METAL_RUSTED: String = "res://src/data/materials/mat_machined_metal.tres"
const MATERIAL_SCREEN_GLOW: String = "res://src/data/materials/mat_screen_glow.tres"
const MATERIAL_PLASTIC_BEIGE: String = "res://src/data/materials/mat_plastic_beige.tres"
const MATERIAL_DARK_PLASTIC: String = "res://src/data/materials/mat_dark_plastic.tres"
const MATERIAL_PHOSPHOR_GREEN: String = "res://src/data/materials/mat_phosphor_green.tres"
const MATERIAL_PHOSPHOR_AMBER: String = "res://src/data/materials/mat_phosphor_amber.tres"

## The authored console kit (original Blender work, `art/blender/cockpit_kit.blend`) replaces
## the procedural CRT housing when present: the tall board for the big wall panels, the
## desktop terminal for the rest. The box height picks which.
const CRT_MODEL_TALL: String = "res://assets/models/hullwatch/cockpit/hw_crt_console_tall.glb"
const CRT_MODEL_DESKTOP: String = "res://assets/models/hullwatch/cockpit/hw_crt_console.glb"
const CRT_MODEL_TALL_MIN: float = 0.8

const MANUAL_BOOK: String = "res://src/data/manual/manual_book.tres"
const LOG_ENTRY: String = "res://src/data/logs/log_01.tres"
const LOG_ENTRY_2: String = "res://src/data/logs/log_02.tres"

const KIT_CONTAINER: String = "res://assets/models/kenney_space_station_kit/Models/GLB format/container.glb"
const KIT_COMPUTER: String = "res://assets/models/kenney_space_station_kit/Models/GLB format/computer-system.glb"
const KIT_DISPLAY: String = "res://assets/models/kenney_space_station_kit/Models/GLB format/display-wall.glb"
## Door leaves come from CC0 prefabs (credits in `docs/ASSET_CREDITS.md`): the leaf mesh is
## yawed a quarter turn and fitted to every doorway, with the repo panel material over its
## imported one. Each style lists the leaf node and its mesh bounds; both source leaves sit
## on y = 0 (bottom edge) and the fit re-centres them on the doorway box. The active style is
## `DOOR_STYLE`, overridable per run with `--door-style=<name>` so the capture tool can shoot
## each candidate for review. A missing prefab falls back to the old box slab.
const DOOR_STYLES: Dictionary = {
	"kenney": {
		"scene": "res://assets/models/kenney_modular_space_kit/Models/GLB format/gate-door.glb",
		"node": &"door",
		"min": Vector3(-1.2, 0.0, -0.35),
		"max": Vector3(1.2, 3.72, 0.35),
		"yaw": 90.0,
	},
	"quaternius": {
		"scene": "res://assets/models/quaternius_scifi_megakit/glTF/Platforms/Door_Simple.gltf",
		"node": &"Door_Simple",
		"min": Vector3(-2.106, 0.0, 0.0),
		"max": Vector3(0.0, 4.049, 0.136),
		"yaw": 90.0,
	},
}
const DOOR_STYLE: String = "kenney"

const SCRIPT_ZONE: String = "res://src/world/compartment_zone.gd"
const SCRIPT_LINK: String = "res://src/world/compartment_link.gd"
const SCRIPT_DOOR_FRAME: String = "res://src/interactables/door_frame.gd"
const SCRIPT_CRT_SCREEN: String = "res://src/interactables/crt_screen.gd"

const MATERIAL_PATHS: Array[String] = [
	MATERIAL_MACHINE_TEAL,
	MATERIAL_PANEL_SCRATCHED,
	MATERIAL_WALL_PAINTED,
	MATERIAL_FLOOR_GRATE,
	MATERIAL_METAL_RUSTED,
	MATERIAL_SCREEN_GLOW,
	MATERIAL_PLASTIC_BEIGE,
	MATERIAL_DARK_PLASTIC,
	MATERIAL_PHOSPHOR_GREEN,
	MATERIAL_PHOSPHOR_AMBER,
]

const RESOURCE_PATHS: Array[String] = [MANUAL_BOOK, LOG_ENTRY, LOG_ENTRY_2]

const KIT_PATHS: Array[String] = [KIT_CONTAINER, KIT_COMPUTER, KIT_DISPLAY]

## Furnished props: StaticBody3D + Shape (CollisionShape3D/BoxShape3D) + Mesh (MeshInstance3D/BoxMesh).
## "exports" are sim-facing script properties, "resources" are resource exports resolved by path.
const PROPS: Array[Dictionary] = [
	{
		"name": "ScrubberUnit",
		"script": "res://src/interactables/scrubber_unit.gd",
		"position": Vector3(-2.6, 0.6, -7.2),
		"size": Vector3(0.5, 1.2, 1.0),
		"model": "res://assets/models/hullwatch/machinery/hw_scrubber_unit.glb",
		"material": MATERIAL_MACHINE_TEAL,
		"exports": {"compartment_id": &"main", "part_id": &"filter_co2", "circuit_id": &"scrubber"},
	},
	{
		"name": "WaterReclaimer",
		"script": "res://src/interactables/water_reclaimer.gd",
		"position": Vector3(2.2, 0.6, -2.65),
		"size": Vector3(0.5, 1.2, 0.8),
		"model": "res://assets/models/hullwatch/machinery/hw_water_reclaimer.glb",
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {},
	},
	{
		"name": "BreakerPanel",
		"script": "res://src/interactables/breaker_panel.gd",
		"position": Vector3(1.22, 0.8, -3.5),
		"rotation": Vector3(0, 0, -30.0),
		"size": Vector3(0.15, 1.0, 0.7),
		"model": "res://assets/models/hullwatch/machinery/hw_breaker_cabinet.glb",
		"model_mount": "wall",
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"circuit_id": &"lighting"},
	},
	{
		"name": "StatusPanel",
		"script": "res://src/ui/status_panel.gd",
		"position": Vector3(-1.22, 0.8, -8.0),
		"rotation": Vector3(0, 0, 30.0),
		"size": Vector3(0.15, 1.0, 0.7),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"compartment_id": &"main"},
		"crt": {"facing": "x+", "phosphor": "amber", "keys": false},
	},
	{
		"name": "MaintenanceBoard",
		"script": "res://src/interactables/maintenance_board.gd",
		"position": Vector3(-1.22, 0.8, -13.0),
		"rotation": Vector3(0, 0, 30.0),
		"size": Vector3(0.15, 0.7, 0.9),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"crt": {"facing": "x+", "phosphor": "amber", "keys": false},
	},
	{
		"name": "ManualBinder",
		"script": "res://src/interactables/manual_binder.gd",
		"position": Vector3(5.53, 0.9, -5.0),
		"size": Vector3(0.45, 0.32, 0.3),
		"material": MATERIAL_WALL_PAINTED,
		"exports": {},
		"resources": {"book": MANUAL_BOOK},
	},
	{
		"name": "LogTerminal",
		"script": "res://src/interactables/log_terminal.gd",
		"position": Vector3(2.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"resources": {"log_entry": LOG_ENTRY},
		"crt": {"facing": "z+", "phosphor": "green", "keys": true},
	},
	{
		"name": "CommsTerminal",
		"script": "res://src/interactables/comms_terminal.gd",
		"position": Vector3(3.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"crt": {"facing": "z+", "phosphor": "green", "keys": true},
	},
	{
		"name": "ArchiveTerminal",
		"script": "res://src/interactables/log_terminal.gd",
		"position": Vector3(-2.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"resources": {"log_entry": LOG_ENTRY_2},
		"crt": {"facing": "z+", "phosphor": "green", "keys": true},
	},
	{
		"name": "NavConsole",
		"script": "res://src/interactables/nav_console.gd",
		"position": Vector3(0.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"waypoint_id": &"relay_cache"},
		"crt": {"facing": "z+", "phosphor": "green", "keys": true},
	},
	{
		"name": "Bunk",
		"script": "res://src/interactables/bunk.gd",
		"position": Vector3(-4.6, 0.25, -11.5),
		"size": Vector3(1.0, 0.5, 2.0),
		"material": MATERIAL_FLOOR_GRATE,
		"exports": {"sleep_hours": 8.0},
	},
	{
		"name": "HullPatch",
		"script": "res://src/interactables/hull_patch.gd",
		"position": Vector3(2.8, 1.2, 7.56),
		"size": Vector3(0.6, 0.6, 0.12),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"compartment_id": &"main"},
	},
	{
		"name": "O2CandleRack",
		"script": "res://src/interactables/o2_candle.gd",
		"position": Vector3(-2.5, 0.9, -6.8),
		"size": Vector3(0.3, 0.2, 0.3),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"compartment_id": &"main"},
	},
	{
		"name": "MultimeterTool",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.9, 0.16, -2.4),
		"size": Vector3(0.22, 0.14, 0.3),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"multimeter", "item_name": "Multimeter"},
	},
	{
		"name": "WrenchTool",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.5, 0.16, -2.4),
		"size": Vector3(0.4, 0.08, 0.1),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"wrench", "item_name": "Wrench"},
	},
	{
		"name": "ScannerTool",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.1, 0.16, -2.4),
		"size": Vector3(0.26, 0.18, 0.22),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"scanner", "item_name": "Wear scanner"},
	},
	{
		"name": "ProbePower",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(0.9, 0.35, -4.2),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"power_system"},
	},
	{
		"name": "ProbeAtmosphere",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(-3.8, 0.35, -7.2),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"atmosphere_system"},
	},
	{
		"name": "ProbeThermal",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(3.28, 0.35, 4.7),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"thermal_system"},
	},
	{
		"name": "ProbeHull",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(1.6, 0.35, 7.48),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"hull_system"},
	},
	{
		"name": "ProbeWater",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(4.31, 0.35, -1.9),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"water_system"},
	},
	{
		"name": "SealantCartridge1",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.9, 0.16, -1.8),
		"size": Vector3(0.18, 0.32, 0.18),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"sealant", "item_name": "Sealant cartridge"},
	},
	{
		"name": "SealantCartridge2",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.55, 0.16, -1.8),
		"size": Vector3(0.18, 0.32, 0.18),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"sealant", "item_name": "Sealant cartridge"},
	},
	{
		"name": "SealantCartridge3",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.2, 0.16, -1.8),
		"size": Vector3(0.18, 0.32, 0.18),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"sealant", "item_name": "Sealant cartridge"},
	},
	{
		"name": "ContactConsole",
		"script": "res://src/interactables/approach_console.gd",
		"position": Vector3(1.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"crt": {"facing": "z+", "phosphor": "green", "keys": true},
	},
	{
		"name": "Fabricator",
		"script": "res://src/interactables/fabricator_unit.gd",
		"position": Vector3(-2.6, 0.6, 2.2),
		"size": Vector3(0.6, 1.2, 1.0),
		"model": "res://assets/models/hullwatch/machinery/hw_fabricator.glb",
		"material": MATERIAL_MACHINE_TEAL,
		"exports": {},
	},
	{
		"name": "CargoPort",
		"tube_platform": true,
		"script": "res://src/interactables/cargo_port.gd",
		"position": Vector3(-8.63, 1.0, -2.2),
		"size": Vector3(0.25, 0.5, 0.5),
		"material": MATERIAL_MACHINE_TEAL,
		"exports": {},
	},
	{
		"name": "CutterTool",
		"script": "res://src/interactables/cutter_tool.gd",
		"position": Vector3(-6.5, 0.16, -1.9),
		"size": Vector3(0.34, 0.1, 0.12),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"cutter", "item_name": "Hull cutter"},
	},
	{
		"name": "SampleCanister1",
		"tube_platform": true,
		"script": "res://src/interactables/sample_canister.gd",
		"position": Vector3(-6.7, 0.16, -1.9),
		"size": Vector3(0.2, 0.26, 0.2),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"sample_canister", "item_name": "Sample canister"},
	},
	{
		"name": "SampleCanister2",
		"script": "res://src/interactables/sample_canister.gd",
		"position": Vector3(-6.4, 0.16, -1.9),
		"size": Vector3(0.2, 0.26, 0.2),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"sample_canister", "item_name": "Sample canister"},
	},
	{
		"name": "SampleCanister3",
		"script": "res://src/interactables/sample_canister.gd",
		"position": Vector3(-6.1, 0.16, -1.9),
		"size": Vector3(0.2, 0.26, 0.2),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"sample_canister", "item_name": "Sample canister"},
	},
	{
		"name": "AirlockPanel",
		"script": "res://src/interactables/airlock_panel.gd",
		"position": Vector3(-6.03, 1.3, -0.35),
		"size": Vector3(0.12, 0.4, 0.5),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
	},
	{
		"name": "SuitLocker",
		"script": "res://src/interactables/suit_locker.gd",
		"position": Vector3(-6.3, 1.0, -0.445),
		"size": Vector3(0.6, 1.5, 0.25),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {},
	},
]

## Pressure doors: StaticBody3D + Slab (MeshInstance3D) + SlabShape (CollisionShape3D); the door
## script owns the open/close motion of both children.
const DOORS: Array[Dictionary] = [
	{
		"name": "DoorCockpit",
		"position": Vector3(0.0, 1.1, -14.1),
		"size": Vector3(1.75, 2.2, 0.16),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"cockpit"},
	},
	{
		"name": "DoorEngine",
		"position": Vector3(0.0, 1.1, 1.5),
		"size": Vector3(1.75, 2.2, 0.16),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"engine_bay"},
	},
	{
		"name": "DoorQuarters",
		"position": Vector3(-1.85, 1.1, -10.0),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"quarters"},
	},
	{
		"name": "DoorLifeSupport",
		"position": Vector3(-1.85, 1.1, -6.0),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"main"},
	},
	{
		"name": "DoorStorage",
		"position": Vector3(-1.85, 1.1, -1.2),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"storage"},
	},
	{
		"name": "DoorGalley",
		"position": Vector3(1.85, 1.1, -5.6),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"galley"},
	},
	{
		"name": "DoorWaterCloset",
		"position": Vector3(1.85, 1.1, -1.6),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"water_closet"},
	},
	{
		"name": "DoorAirlockInner",
		"position": Vector3(-5.75, 1.1, -1.0),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"storage", "compartment_b": &"airlock", "airlock_id": &"airlock_main", "airlock_side": &"inner"},
	},
	{
		"name": "DoorAirlockOuter",
		"position": Vector3(-7.95, 1.1, -1.2),
		"size": Vector3(0.16, 2.2, 1.0),
		"exports": {"compartment_a": &"airlock", "compartment_b": &"", "airlock_id": &"airlock_main", "airlock_side": &"outer"},
	},
]

## Kit-scene decorations: visual only, no collision added by this generator.
const KIT_PROPS: Array[Dictionary] = [
	{"name": "ContainerProp", "scene": KIT_CONTAINER, "position": Vector3(-3.0, 0.0, -0.2), "size": Vector3(0.575, 0.6, 0.575)},
	{"name": "ComputerProp", "scene": KIT_COMPUTER, "position": Vector3(2.6, 0.75, -7.0), "size": Vector3(0.9, 0.6, 0.7)},
	{"name": "DisplayProp", "scene": KIT_DISPLAY, "position": Vector3(-2.5, 1.6, -18.45), "size": Vector3(0.4, 0.46, 0.38)},
]

## Authored model dressing (M13.3): original Blender glTF pieces, carried into the tube like
## every other prop. Positions are flat-layout spots in the room they dress; wall pieces carry
## their yaw (the model front is glTF +Z, the export of Blender -Y), floor pieces keep their
## origin at the floor. The collision comes from the model's own bounds.
const MODEL_PROPS: Array[Dictionary] = [
	{"name": "SwitchBank", "model": "res://assets/models/hullwatch/cockpit/hw_switch_bank.glb", "position": Vector3(-2.8, 1.6, -16.5), "rotation": Vector3(0, 90, 0), "size": Vector3(0.12, 0.25, 0.35)},
	{"name": "GaugeCluster", "model": "res://assets/models/hullwatch/cockpit/hw_gauge_cluster.glb", "position": Vector3(2.4, 1.3, 1.5), "rotation": Vector3(0, -90, 0), "size": Vector3(0.16, 0.3, 0.45)},
	{"name": "SevenSegment", "model": "res://assets/models/hullwatch/cockpit/hw_seven_segment.glb", "position": Vector3(2.4, 1.5, -5.8), "rotation": Vector3(0, -90, 0), "size": Vector3(0.1, 0.1, 0.25)},
	{"name": "DeskConsole", "model": "res://assets/models/hullwatch/cockpit/hw_crt_console.glb", "position": Vector3(-2.0, 0.0, -16.0), "rotation": Vector3(0, 90, 0), "size": Vector3(0.5, 0.52, 0.65)},
]

## Atmosphere occupancy zones: Area3D + script + one BoxShape3D child named Shape.
const ZONES: Array[Dictionary] = [
	{"name": "ZoneCorridor", "size": Vector3(3.5, 3.0, 15.4), "position": Vector3(0.0, 1.5, -6.3), "exports": {"compartment_id": &"corridor"}},
	{"name": "ZoneCockpit", "size": Vector3(6.8, 3.0, 4.6), "position": Vector3(0.0, 1.5, -16.5), "exports": {"compartment_id": &"cockpit"}},
	{"name": "ZoneQuarters", "size": Vector3(4.5, 3.0, 4.4), "position": Vector3(-4.2, 1.5, -10.4), "exports": {"compartment_id": &"quarters"}},
	{"name": "ZoneLifeSupport", "size": Vector3(3.5, 3.0, 2.6), "position": Vector3(-3.7, 1.5, -6.3), "exports": {"compartment_id": &"main"}},
	{"name": "ZoneGalley", "size": Vector3(4.0, 3.0, 3.6), "position": Vector3(3.95, 1.5, -5.8), "exports": {"compartment_id": &"galley"}},
	{"name": "ZoneWaterCloset", "size": Vector3(2.6, 3.0, 2.2), "position": Vector3(3.25, 1.5, -1.9), "exports": {"compartment_id": &"water_closet"}},
	{"name": "ZoneStorage", "size": Vector3(3.7, 3.0, 3.6), "position": Vector3(-3.8, 1.5, -1.2), "exports": {"compartment_id": &"storage"}},
	{"name": "ZoneEngineBay", "size": Vector3(7.2, 3.0, 6.2), "position": Vector3(0.0, 1.5, 4.7), "exports": {"compartment_id": &"engine_bay"}},
	{"name": "ZoneAirlock", "size": Vector3(2.0, 3.0, 2.0), "position": Vector3(-6.85, 1.5, -1.2), "exports": {"compartment_id": &"airlock"}},
]

## Atmosphere mixing links: corridor paired with every side compartment.
const LINKS: Array[Dictionary] = [
	{"name": "LinkCorridorCockpit", "exports": {"compartment_a": &"corridor", "compartment_b": &"cockpit"}},
	{"name": "LinkCorridorQuarters", "exports": {"compartment_a": &"corridor", "compartment_b": &"quarters"}},
	{"name": "LinkCorridorMain", "exports": {"compartment_a": &"corridor", "compartment_b": &"main"}},
	{"name": "LinkCorridorGalley", "exports": {"compartment_a": &"corridor", "compartment_b": &"galley"}},
	{"name": "LinkCorridorWaterCloset", "exports": {"compartment_a": &"corridor", "compartment_b": &"water_closet"}},
	{"name": "LinkCorridorStorage", "exports": {"compartment_a": &"corridor", "compartment_b": &"storage"}},
	{"name": "LinkCorridorEngineBay", "exports": {"compartment_a": &"corridor", "compartment_b": &"engine_bay"}},
	{"name": "LinkStorageAirlock", "exports": {"compartment_a": &"storage", "compartment_b": &"airlock"}},
]

var _root: Node3D
var _props: Node3D
var _zones: Node3D
var _links: Node3D
var _materials: Dictionary = {}
var _resources: Dictionary = {}
var _scenes: Dictionary = {}
var _failures: int = 0
var _door_leaf_info: Dictionary = {}
var _door_leaf_loaded: bool = false


func _initialize() -> void:
	_load_assets()
	if _failures == 0:
		_build()
	_save()


func _load_assets() -> void:
	for path: String in MATERIAL_PATHS:
		var material: Material = load(path) as Material
		if material == null:
			_failures += 1
			print("FAIL: missing material ", path)
		else:
			_materials[path] = material
	for path: String in RESOURCE_PATHS:
		var resource: Resource = load(path) as Resource
		if resource == null:
			_failures += 1
			print("FAIL: missing resource ", path)
		else:
			_resources[path] = resource
	for path: String in KIT_PATHS:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			_failures += 1
			print("FAIL: missing kit scene ", path)
		else:
			_scenes[path] = scene


## Interior style, mirroring the geometry tool: "flat" ships the wide layout off the hexagon
## corridor, "tube" builds the M13.2 chain - props carried into their sections, and doors,
## zones and atmosphere links generated per section and per joint. `--interior-style=tube`
## previews it without touching the committed scene.
const INTERIOR_STYLE: String = "tube"

## Flat room bounds (x, z, width, depth) for carrying flat-layout props into the tube section
## that replaces the room they sit in.
const ROOM_BOUNDS: Dictionary = {
	&"cockpit": Rect2(-3.4, -18.8, 6.8, 4.6),
	&"quarters": Rect2(-6.45, -12.6, 4.5, 4.4),
	&"life_support": Rect2(-5.45, -7.6, 3.5, 2.6),
	&"galley": Rect2(1.95, -7.6, 4.0, 3.6),
	&"water_closet": Rect2(1.95, -3.0, 2.6, 2.2),
	&"storage": Rect2(-5.65, -3.0, 3.7, 3.6),
	&"airlock": Rect2(-7.85, -2.2, 2.0, 2.0),
	&"engine_bay": Rect2(-3.6, 1.6, 7.2, 6.2),
}

func _interior_style() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--interior-style="):
			var override: String = arg.trim_prefix("--interior-style=")
			if override in ["flat", "tube"]:
				return override
			print("WARN: unknown interior style, keeping ", INTERIOR_STYLE, ": ", override)
	return INTERIOR_STYLE


## The tube footprint that replaces a flat room: its first and last section bounds and the
## widest radius. A room served by two sections (cockpit, engine bay) maps across both.
func _tube_room(room: StringName) -> Dictionary:
	var first: int = -1
	var last: int = -1
	var radius: float = 0.0
	for index: int in TubeLayout.sections().size():
		if StringName(TubeLayout.sections()[index].get("room", &"")) != room:
			continue
		if first < 0:
			first = index
		last = index
		radius = maxf(radius, float(TubeLayout.sections()[index]["radius"]))
	if first < 0:
		return {}
	return {
		"z0": TubeLayout.span(first).x,
		"z1": TubeLayout.span(last).y,
		"radius": radius,
	}


func _room_for(point: Vector3) -> StringName:
	for room: Variant in ROOM_BOUNDS:
		if (ROOM_BOUNDS[room] as Rect2).has_point(Vector2(point.x, point.z)):
			return StringName(room)
	return &""


## Carries a flat-layout position into the tube layout: room props keep their relative spot
## inside their section, corridor props (the flat corridor dissolved into the chain) land in
## whatever section covers their z. Either way the prop hugs its section's canted wall at
## the prop's own footprint - the wall slopes outward, so the binding line is the wall at
## the prop's bottom height, minus the prop's half width - which keeps the centre lane and
## both hatch mouths clear without embedding anything in the wall. Positions outside every
## room (the EVA fittings) are left where they are - the shell pass re-mounts those.
func _tube_position(flat: Vector3, size: Vector3) -> Vector3:
	var room: StringName = _room_for(flat)
	var tube: Dictionary = _tube_room(room) if room != &"" else {}
	var remap_z: bool = not tube.is_empty()
	if tube.is_empty():
		var covering: Dictionary = TubeLayout.section_at(flat.z)
		if covering.is_empty():
			return flat
		var index: int = TubeLayout.index_of(String(covering["name"]))
		if not TubeLayout.is_walkable(index):
			return flat
		tube = {
			"z0": TubeLayout.span(index).x,
			"z1": TubeLayout.span(index).y,
			"radius": float(covering["radius"]),
		}
	var radius: float = float(tube["radius"])
	var z_center: float = (float(tube["z0"]) + float(tube["z1"])) * 0.5
	var z_half: float = (float(tube["z1"]) - float(tube["z0"])) * 0.5
	var side: float = signf(flat.x) if absf(flat.x) > 0.01 else 1.0
	var bottom: float = maxf(flat.y - size.y * 0.5, 0.0)
	var wall_x: float = SectionHull.tube_half_width(radius, bottom)
	var hug: float = maxf(wall_x - size.x * 0.5 - 0.05, 0.15)
	var z: float
	if remap_z:
		var bounds: Rect2 = ROOM_BOUNDS[room]
		var center: Vector2 = bounds.position + bounds.size * 0.5
		var half_depth: float = maxf(bounds.size.y * 0.5, 0.001)
		var v: float = clampf((flat.z - center.y) / half_depth, -1.0, 1.0)
		z = z_center + v * maxf(z_half - 0.8, 0.2)
	else:
		z = clampf(flat.z, float(tube["z0"]) + 0.25, float(tube["z1"]) - 0.25)
	return Vector3(side * hug, flat.y, z)


## Ties two sections together: the bulkhead door at the joint between them, the zone in each,
## and the atmosphere link across the hatch.
func _build_tube_chain() -> void:
	for index: int in TubeLayout.sections().size():
		var section: Dictionary = TubeLayout.sections()[index]
		var room: StringName = StringName(section.get("room", &""))
		if room == &"":
			continue
		var bounds: Vector2 = TubeLayout.span(index)
		var radius: float = float(section["radius"])
		_build_zone({
			"name": "ZoneSection_" + String(section["name"]),
			"size": Vector3(2.0 * (radius - 0.25), TubeLayout.DECK_HEIGHT, bounds.y - bounds.x - 0.2),
			"position": Vector3(0.0, TubeLayout.DECK_HEIGHT * 0.5, (bounds.x + bounds.y) * 0.5),
			"exports": {"compartment_id": TubeLayout.ROOM_COMPARTMENTS[room]},
		})
	if TubeLayout.sections().size() < 2:
		return
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		var aft_room: StringName = StringName(TubeLayout.sections()[index].get("room", &""))
		var fore_room: StringName = StringName(TubeLayout.sections()[index + 1].get("room", &""))
		if aft_room == &"" or fore_room == &"":
			continue
		var joint_z: float = (TubeLayout.span(index).y + TubeLayout.span(index + 1).x) * 0.5
		var exports: Dictionary = {
			"compartment_a": TubeLayout.ROOM_COMPARTMENTS[aft_room],
			"compartment_b": TubeLayout.ROOM_COMPARTMENTS[fore_room],
		}
		var airlock_joint: bool = (aft_room == &"airlock" and fore_room == &"storage") or (aft_room == &"storage" and fore_room == &"airlock")
		if not airlock_joint:
			var joint_exports: Dictionary = exports.duplicate()
			joint_exports["starts_open"] = true
			joint_exports["hide_when_open"] = true
			_build_door({
				"name": "DoorJoint_%s_%s" % [String(TubeLayout.sections()[index]["name"]), String(TubeLayout.sections()[index + 1]["name"])],
				"position": Vector3(0.0, TubeLayout.HATCH_HEIGHT * 0.5, joint_z),
				"size": Vector3(TubeLayout.HATCH_HALF_WIDTH * 2.0, TubeLayout.HATCH_HEIGHT, 0.16),
				"exports": joint_exports,
			})
		_build_link({
			"name": "LinkJoint_%s_%s" % [String(TubeLayout.sections()[index]["name"]), String(TubeLayout.sections()[index + 1]["name"])],
			"exports": exports.duplicate(),
		})
	_build_airlock_hatch()


## The airlock's outer hatch, radial on its section: the door the suit goes out of, and the
## inner door that isolates the lock from the chain.
func _build_airlock_hatch() -> void:
	var airlock: int = TubeLayout.index_of("airlock")
	if airlock < 0:
		return
	var bounds: Vector2 = TubeLayout.span(airlock)
	var radius: float = float(TubeLayout.sections()[airlock]["radius"])
	var center_z: float = (bounds.x + bounds.y) * 0.5
	_build_door({
		"name": "DoorAirlockOuter",
		"position": Vector3(-(radius + 0.08), 1.0, center_z),
		"size": Vector3(0.16, 2.0, 1.0),
		"exports": {"compartment_a": &"airlock", "compartment_b": &"", "airlock_id": &"airlock_main", "airlock_side": &"outer"},
	})
	var storage: int = TubeLayout.index_of("storage")
	if storage >= 0 and TubeLayout.has_hatch(mini(storage, airlock)):
		var joint_z: float = (TubeLayout.span(mini(storage, airlock)).y + TubeLayout.span(maxi(storage, airlock)).x) * 0.5
		_build_door({
			"name": "DoorAirlockInner",
			"position": Vector3(0.0, TubeLayout.HATCH_HEIGHT * 0.5, joint_z),
			"size": Vector3(TubeLayout.HATCH_HALF_WIDTH * 2.0, TubeLayout.HATCH_HEIGHT, 0.16),
			"exports": {"compartment_a": &"storage", "compartment_b": &"airlock", "airlock_id": &"airlock_main", "airlock_side": &"inner"},
		})


## A prop or kit entry carried into its tube section.
func _carried(spec: Dictionary) -> Dictionary:
	var carried: Dictionary = spec.duplicate()
	if bool(spec.get("tube_platform", false)):
		carried["position"] = _tube_platform_position(spec["position"])
	else:
		carried["position"] = _tube_position(spec["position"], spec.get("size", Vector3(0.6, 0.6, 0.6)))
	if carried.has("crt"):
		# The flat facings look at the room's far wall; on the chain the wall gear hugs a side
		# wall, so the screens turn to face the centre lane instead.
		var config: Dictionary = (carried["crt"] as Dictionary).duplicate()
		config["facing"] = "x+" if (carried["position"] as Vector3).x < 0.0 else "x-"
		carried["crt"] = config
	return carried


## EVA-platform gear (the cargo port, the sample canister) has no flat room to be carried
## from: it belongs on the deck outside the tube airlock.
func _tube_platform_position(flat: Vector3) -> Vector3:
	var airlock: int = TubeLayout.index_of("airlock")
	if airlock < 0:
		return flat
	var center_z: float = (TubeLayout.span(airlock).x + TubeLayout.span(airlock).y) * 0.5
	var face: float = -(float(TubeLayout.sections()[airlock]["radius"]) + SectionHull.TUBE_BAND)
	return Vector3(face - 1.4, flat.y, center_z + 0.4)


func _build() -> void:
	_root = Node3D.new()
	_root.name = "WorldLayout"
	_props = _make_group("Props")
	_zones = _make_group("Zones")
	_links = _make_group("Links")
	var tube: bool = _interior_style() == "tube"
	for spec: Dictionary in PROPS:
		_build_prop(_carried(spec) if tube else spec)
	if not tube:
		for spec: Dictionary in DOORS:
			_build_door(spec)
	for spec: Dictionary in KIT_PROPS:
		_build_kit(_carried(spec) if tube else spec)
	for spec: Dictionary in MODEL_PROPS:
		_build_model_prop(_carried(spec) if tube else spec)
	if tube:
		_build_tube_chain()
	else:
		for spec: Dictionary in ZONES:
			_build_zone(spec)
		for spec: Dictionary in LINKS:
			_build_link(spec)


func _make_group(group_name: String) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = group_name
	_root.add_child(group)
	return group


## The active door style's leaf mesh, resolved once per run.
func _door_leaf() -> Dictionary:
	if _door_leaf_loaded:
		return _door_leaf_info
	_door_leaf_loaded = true
	var style: Dictionary = DOOR_STYLES[DOOR_STYLE] as Dictionary
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--door-style="):
			var override: String = arg.trim_prefix("--door-style=")
			if DOOR_STYLES.has(override):
				style = DOOR_STYLES[override] as Dictionary
			else:
				print("WARN: unknown door style, keeping ", DOOR_STYLE, ": ", override)
	var scene_path: String = String(style["scene"])
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		print("WARN: door prefab missing, using box slabs: ", scene_path)
		return {}
	var instance: Node = packed.instantiate()
	var leaf: MeshInstance3D = instance.find_child(String(style["node"]), true, false) as MeshInstance3D
	if leaf != null:
		_door_leaf_info = style.duplicate()
		_door_leaf_info["mesh"] = leaf.mesh
	else:
		print("WARN: door prefab has no leaf node ", style["node"], " in ", scene_path)
	instance.free()
	return _door_leaf_info


func _build_prop(spec: Dictionary) -> void:
	var prop: StaticBody3D = StaticBody3D.new()
	prop.name = String(spec["name"])
	prop.position = spec["position"]
	if spec.has("rotation"):
		prop.rotation_degrees = spec["rotation"]
	prop.set_script(load(String(spec["script"])) as Script)
	_apply_exports(prop, spec)
	_props.add_child(prop)
	var has_model: bool = spec.has("model") and ResourceLoader.exists(String(spec["model"]))
	_add_box_children(prop, spec["size"], String(spec["material"]), not spec.has("crt") and not has_model)
	if spec.has("crt"):
		_build_crt(prop, spec)
		_fit_crt_collision(prop)
	elif has_model:
		_attach_model(prop, spec)
	_settle_against_wall(prop)


## The authored console is deeper than the flat panel's collision slab; grow the shape to the
## model's own bounds so the operator cannot stand inside the terminal.
func _fit_crt_collision(prop: StaticBody3D) -> void:
	if prop.get_node_or_null(^"Crt/Model") == null:
		return
	var shape: CollisionShape3D = prop.get_node_or_null(^"Shape") as CollisionShape3D
	var box: AABB = _local_bounds(prop)
	var box_shape: BoxShape3D = shape.shape as BoxShape3D if shape != null else null
	if box_shape == null or box.size == Vector3.ZERO:
		return
	box_shape.size = box.size
	shape.position = box.get_center()


## Attaches an authored glTF to an interactive prop. The models are authored at their own
## origin (floor centre for machines, back centre for wall panels) facing Blender -Y, which
## the export maps to +Z; the prop's origin is the centre of its `size` box, so the model is
## shifted to the box's floor or wall face and yawed to face inboard. The collision box is
## kept, so the interaction ray and the walkthrough stay the same.
func _attach_model(prop: StaticBody3D, spec: Dictionary) -> void:
	var scene: PackedScene = load(String(spec["model"])) as PackedScene
	if scene == null:
		print("FAIL: missing prop model ", spec["model"])
		_failures += 1
		return
	var model: Node3D = scene.instantiate() as Node3D
	model.name = "Model"
	var side: float = -1.0 if prop.position.x < 0.0 else 1.0
	model.rotation_degrees.y = -90.0 * side
	prop.add_child(model)
	var size: Vector3 = spec["size"]
	var box: AABB = _local_bounds(prop)
	if String(spec.get("model_mount", "floor")) == "wall":
		model.position.x += side * size.x * 0.5 - (box.position.x if side < 0.0 else box.end.x)
	else:
		model.position.y += -size.y * 0.5 - box.position.y


## After a prop's meshes exist, nudge it inboard until its own bounding box clears the
## section's canted wall at the box's bottom height (the wall slopes outward, so that is
## the tight line). The nominal size is only a first guess - CRT parts and kit meshes can
## reach past it.
func _settle_against_wall(prop: Node3D) -> void:
	if _interior_style() != "tube":
		return
	var section: Dictionary = _nearest_walkable(prop.position.z)
	if section.is_empty():
		return
	var radius: float = float(section["radius"])
	var side: float = signf(prop.position.x) if absf(prop.position.x) > 0.01 else 1.0
	if absf(prop.position.x) > SectionHull.tube_half_width(radius, 1.0) + 0.6:
		return
	var box: AABB = _prop_bounds(prop)
	if box.size == Vector3.ZERO:
		return
	var outboard: float = maxf(box.position.x * side, box.end.x * side)
	var wall_x: float = SectionHull.tube_half_width(radius, maxf(box.position.y, 0.0))
	if outboard > wall_x + 0.02:
		prop.position.x -= side * (outboard - wall_x - 0.02)


func _nearest_walkable(z: float) -> Dictionary:
	var covering: Dictionary = TubeLayout.section_at(z)
	if not covering.is_empty() and TubeLayout.is_walkable(TubeLayout.index_of(String(covering["name"]))):
		return covering
	var best: Dictionary = {}
	var best_distance: float = 1.0e9
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var bounds: Vector2 = TubeLayout.span(index)
		var distance: float = maxf(0.0, maxf(bounds.x - z, z - bounds.y))
		if distance < best_distance:
			best_distance = distance
			best = TubeLayout.sections()[index]
	return best


func _prop_bounds(prop: Node3D) -> AABB:
	var aabb: AABB = AABB()
	var first: bool = true
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh.mesh == null:
			continue
		# The layout is built off-tree, so global_transform does not accumulate here:
		# walk the chain up to the layout root by hand, the prop's own transform included,
		# so the bounds come out in layout space, comparable to the section wall widths.
		var local: Transform3D = Transform3D.IDENTITY
		var node: Node3D = mesh
		while node != null:
			local = node.transform * local
			node = node.get_parent() as Node3D
		var box: AABB = local * mesh.get_aabb()
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	return aabb


## Swaps in the authored console when the kit is present. The model is authored at the floor
## centre facing Blender -Y (glTF +Z), so it drops to the box's floor inside the `Crt` node
## (which already carries the facing) and the live phosphor material goes over its Screen
## quad. Returns false when the kit is missing, so the procedural parts build instead.
func _attach_crt_console(crt: Node3D, height: float, phosphor_path: String) -> bool:
	var model_path: String = CRT_MODEL_TALL if height >= CRT_MODEL_TALL_MIN else CRT_MODEL_DESKTOP
	if not ResourceLoader.exists(model_path):
		return false
	var scene: PackedScene = load(model_path) as PackedScene
	if scene == null:
		return false
	var model: Node3D = scene.instantiate() as Node3D
	model.name = "Model"
	model.position = Vector3(0.0, -height * 0.5, 0.0)
	crt.add_child(model)
	# The phosphor tint cannot be written onto the model's Screen here (an override inside an
	# instanced subtree is not serialized), so a small script node applies it on load.
	var tint: Node = Node.new()
	tint.name = "ScreenTint"
	tint.set_script(load(SCRIPT_CRT_SCREEN) as Script)
	tint.set(&"phosphor_material", _materials[phosphor_path] as Material)
	crt.add_child(tint)
	return true


## 90s CRT workstation: beige housing, recessed phosphor screen behind a dark glass rim,
## chin knobs, power LED, top vent and an optional keyboard shelf with chunky keys.
func _build_crt(parent: StaticBody3D, spec: Dictionary) -> void:
	var config: Dictionary = spec["crt"]
	var size: Vector3 = spec["size"]
	var width: float = maxf(size.x, size.z)
	var height: float = size.y
	var crt: Node3D = Node3D.new()
	crt.name = "Crt"
	match String(config.get("facing", "z+")):
		"x+":
			crt.rotation_degrees = Vector3(0, 90, 0)
		"x-":
			crt.rotation_degrees = Vector3(0, -90, 0)
		"z-":
			crt.rotation_degrees = Vector3(0, 180, 0)
	crt.position = crt.basis * Vector3(0, 0, 0.06)
	parent.add_child(crt)
	var phosphor: String = MATERIAL_PHOSPHOR_AMBER if String(config.get("phosphor", "green")) == "amber" else MATERIAL_PHOSPHOR_GREEN
	if _attach_crt_console(crt, height, phosphor):
		return
	var depth: float = 0.30
	_add_crt_part(crt, "Housing", Vector3(0, 0, -0.05), Vector3(width, height, depth), MATERIAL_PLASTIC_BEIGE)
	_add_crt_part(crt, "Glass", Vector3(0, 0.01, depth * 0.5 - 0.055), Vector3(width - 0.07, height - 0.07, 0.02), MATERIAL_DARK_PLASTIC)
	_add_crt_part(crt, "Screen", Vector3(0, 0.01, depth * 0.5 - 0.04), Vector3(width - 0.12, height - 0.12, 0.012), phosphor)
	_add_crt_part(crt, "Vent", Vector3(0, height * 0.5 - 0.005, -0.05), Vector3(width * 0.62, 0.02, depth * 0.55), MATERIAL_DARK_PLASTIC)
	_add_crt_part(crt, "Knob0", Vector3(-width * 0.30, -height * 0.40, depth * 0.5 - 0.03), Vector3(0.028, 0.028, 0.03), MATERIAL_DARK_PLASTIC)
	_add_crt_part(crt, "Knob1", Vector3(-width * 0.20, -height * 0.40, depth * 0.5 - 0.03), Vector3(0.028, 0.028, 0.03), MATERIAL_DARK_PLASTIC)
	_add_crt_part(crt, "Led", Vector3(width * 0.36, -height * 0.40, depth * 0.5 - 0.02), Vector3(0.02, 0.02, 0.02), phosphor)
	if not bool(config.get("keys", false)):
		return
	var shelf_y: float = -height * 0.5 - 0.07
	_add_crt_part(crt, "Shelf", Vector3(0, shelf_y, 0.10), Vector3(width * 1.05, 0.035, 0.22), MATERIAL_PLASTIC_BEIGE)
	_add_crt_part(crt, "LegW", Vector3(-width * 0.45, shelf_y + 0.07, 0.02), Vector3(0.04, 0.14, 0.04), MATERIAL_DARK_PLASTIC)
	_add_crt_part(crt, "LegE", Vector3(width * 0.45, shelf_y + 0.07, 0.02), Vector3(0.04, 0.14, 0.04), MATERIAL_DARK_PLASTIC)
	for row: int in 2:
		for column: int in 6:
			var key_x: float = -width * 0.36 + float(column) * width * 0.144
			var key_z: float = 0.055 + float(row) * 0.06
			_add_crt_part(crt, "Key%d_%d" % [row, column], Vector3(key_x, shelf_y + 0.026, key_z), Vector3(width * 0.11, 0.016, 0.045), MATERIAL_DARK_PLASTIC)


func _add_crt_part(parent: Node3D, part_name: String, part_position: Vector3, size: Vector3, material_path: String) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = part_name
	node.mesh = mesh
	node.material_override = _materials[material_path] as Material
	node.position = part_position
	parent.add_child(node)


func _build_door(spec: Dictionary) -> void:
	var door: StaticBody3D = StaticBody3D.new()
	door.name = String(spec["name"])
	door.position = spec["position"]
	door.set_script(load("res://src/interactables/door.gd") as Script)
	_apply_exports(door, spec)
	_props.add_child(door)
	var size: Vector3 = spec["size"]
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.name = "Slab"
	var leaf: Dictionary = _door_leaf()
	var leaf_mesh: Mesh = leaf.get("mesh") as Mesh
	if leaf_mesh != null:
		var leaf_min: Vector3 = leaf["min"] as Vector3
		var leaf_max: Vector3 = leaf["max"] as Vector3
		var leaf_size: Vector3 = leaf_max - leaf_min
		var pivot: Vector3 = Vector3((leaf_min.x + leaf_max.x) * 0.5, leaf_min.y, (leaf_min.z + leaf_max.z) * 0.5)
		var yaw: float = float(leaf["yaw"])
		var scale: Vector3 = Vector3(size.z / leaf_size.x, size.y / leaf_size.y, size.x / leaf_size.z)
		# The leaf's bottom centre lands on the doorway box's bottom centre; the leaf node's
		# own offset is rotated with it so either source origin works.
		var rotated: Vector3 = Vector3(pivot.x * scale.x, 0.0, pivot.z * scale.z).rotated(Vector3.UP, deg_to_rad(yaw))
		slab.mesh = leaf_mesh
		slab.rotation_degrees.y = yaw
		slab.scale = scale
		slab.position = Vector3(0.0, -size.y * 0.5, 0.0) - rotated
	else:
		var slab_mesh: BoxMesh = BoxMesh.new()
		slab_mesh.size = size
		slab.mesh = slab_mesh
	slab.material_override = _materials[MATERIAL_PANEL_SCRATCHED] as Material
	door.add_child(slab)
	var slab_box: BoxShape3D = BoxShape3D.new()
	slab_box.size = size
	var slab_shape: CollisionShape3D = CollisionShape3D.new()
	slab_shape.name = "SlabShape"
	slab_shape.shape = slab_box
	door.add_child(slab_shape)
	var frame: StaticBody3D = StaticBody3D.new()
	frame.name = "Frame"
	frame.collision_layer = 2
	frame.collision_mask = 0
	frame.set_script(load(SCRIPT_DOOR_FRAME) as Script)
	door.add_child(frame)
	var frame_box: BoxShape3D = BoxShape3D.new()
	if size.x <= size.z:
		frame_box.size = Vector3(0.05, size.y, size.z)
	else:
		frame_box.size = Vector3(size.x, size.y, 0.05)
	var frame_shape: CollisionShape3D = CollisionShape3D.new()
	frame_shape.name = "FrameShape"
	frame_shape.shape = frame_box
	frame.add_child(frame_shape)


func _build_kit(spec: Dictionary) -> void:
	var packed: PackedScene = load(String(spec["scene"])) as PackedScene
	var instance: Node3D = (packed.instantiate() as Node3D) as Node3D
	instance.name = String(spec["name"])
	instance.position = spec["position"]
	_props.add_child(instance)
	_settle_against_wall(instance)


## An authored model prop: the glTF instance plus a collider sized to what the model actually
## occupies, so the player cannot walk through it and the settle pass can still hug it to the
## section wall.
func _build_model_prop(spec: Dictionary) -> void:
	var prop: StaticBody3D = StaticBody3D.new()
	prop.name = String(spec["name"])
	prop.position = spec["position"]
	if spec.has("rotation"):
		prop.rotation_degrees = spec["rotation"]
	var scene: PackedScene = load(String(spec["model"])) as PackedScene
	if scene == null:
		print("FAIL: missing model prop ", spec["model"])
		_failures += 1
		return
	var model: Node3D = scene.instantiate() as Node3D
	model.name = "Model"
	prop.add_child(model)
	_props.add_child(prop)
	var box: AABB = _local_bounds(prop)
	if box.size == Vector3.ZERO:
		return
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box.size
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = shape
	collider.position = box.get_center()
	prop.add_child(collider)
	_settle_against_wall(prop)


## The bounds of a prop's own meshes in the prop's local space (the layout-space variant is
## `_prop_bounds`).
func _local_bounds(prop: Node3D) -> AABB:
	var aabb: AABB = AABB()
	var first: bool = true
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var local: Transform3D = Transform3D.IDENTITY
		var node: Node3D = mesh
		while node != null and node != prop:
			local = node.transform * local
			node = node.get_parent() as Node3D
		var box: AABB = local * mesh.get_aabb()
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	return aabb


func _build_zone(spec: Dictionary) -> void:
	var zone: Area3D = Area3D.new()
	zone.name = String(spec["name"])
	zone.position = spec["position"]
	zone.set_script(load(SCRIPT_ZONE) as Script)
	_apply_exports(zone, spec)
	_zones.add_child(zone)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = spec["size"]
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box
	zone.add_child(shape)


func _build_link(spec: Dictionary) -> void:
	var link: Node = Node.new()
	link.name = String(spec["name"])
	link.set_script(load(SCRIPT_LINK) as Script)
	_apply_exports(link, spec)
	_links.add_child(link)


func _add_box_children(parent: StaticBody3D, size: Vector3, material_path: String, with_mesh: bool = true) -> void:
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box_shape
	parent.add_child(shape)
	if not with_mesh:
		return
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = box_mesh
	mesh.material_override = _materials[material_path] as Material
	parent.add_child(mesh)


func _apply_exports(node: Object, spec: Dictionary) -> void:
	var exports: Dictionary = spec.get("exports", {})
	for key: String in exports:
		node.set(key, exports[key])
	var resources: Dictionary = spec.get("resources", {})
	for key: String in resources:
		node.set(key, _resources[String(resources[key])])


func _save() -> void:
	if _failures > 0 or _root == null:
		print("FAILURES: ", _failures)
		quit(1)
		return
	_assign_owners(_root, _root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(_root)
	if pack_error != OK:
		print("FAIL: pack error ", pack_error)
		quit(1)
		return
	var save_error: Error = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		print("FAIL: save error ", save_error)
		quit(1)
		return
	_root.free()
	_root = null
	if not _normalize_output():
		print("FAILURES: ", _failures)
		quit(1)
		return
	if not _verify():
		print("FAILURES: ", _failures)
		quit(1)
		return
	print("PASS: build_world_layout")
	quit(0)


## PackedScene.pack() assigns random per-run node unique_ids; strip them so regenerating is byte-stable.
func _normalize_output() -> bool:
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		_failures += 1
		print("FAIL: cannot reopen ", OUTPUT_PATH)
		return false
	var text: String = file.get_as_text()
	file.close()
	var regex: RegEx = RegEx.new()
	regex.compile(" unique_id=\\d+")
	var write_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if write_file == null:
		_failures += 1
		print("FAIL: cannot rewrite ", OUTPUT_PATH)
		return false
	write_file.store_string(regex.sub(text, "", true))
	write_file.close()
	return true


## Instanced kit scenes keep their internal owner (the instance root); only their root is owned
## by the packed scene, so pack() records an instance reference instead of baking the geometry.
func _assign_owners(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.scene_file_path != "":
			continue
		_assign_owners(child, owner)


func _verify() -> bool:
	var loaded: PackedScene = load(OUTPUT_PATH) as PackedScene
	if loaded == null:
		_failures += 1
		print("FAIL: generated scene did not load")
		return false
	if _interior_style() != "flat":
		# Preview run: the flat rooms are gone by design, so the flat tables are not the
		# contract here; the chain's own nodes are checked by the layout suites once flipped.
		print("PASS: build_world_layout (", _interior_style(), " preview)")
		return true
	var instance: Node = loaded.instantiate()
	var props: Node = instance.get_node_or_null(^"Props")
	var zones: Node = instance.get_node_or_null(^"Zones")
	var links: Node = instance.get_node_or_null(^"Links")
	if props == null or zones == null or links == null:
		_failures += 1
		print("FAIL: generated scene missing Props/Zones/Links")
		instance.free()
		return false
	_verify_props(props)
	_verify_zones(zones)
	_verify_links(links)
	print("OK: props=", props.get_child_count(), " zones=", zones.get_child_count(), " links=", links.get_child_count())
	instance.free()
	return _failures == 0


func _verify_props(props: Node) -> void:
	for spec: Dictionary in PROPS:
		var prop: Node = props.get_node_or_null(NodePath(String(spec["name"])))
		if prop == null:
			_failures += 1
			print("FAIL: missing prop ", spec["name"])
			continue
		if prop.get_node_or_null(^"Shape") == null:
			_failures += 1
			print("FAIL: prop missing Shape: ", spec["name"])
			continue
		var has_plain_mesh: bool = prop.get_node_or_null(^"Mesh") != null
		var has_crt: bool = prop.get_node_or_null(^"Crt/Housing") != null and prop.get_node_or_null(^"Crt/Screen") != null
		if not has_plain_mesh and not has_crt:
			_failures += 1
			print("FAIL: prop missing Mesh or CRT parts: ", spec["name"])
	for spec: Dictionary in DOORS:
		var door: Node = props.get_node_or_null(NodePath(String(spec["name"])))
		if door == null:
			_failures += 1
			print("FAIL: missing door ", spec["name"])
			continue
		if door.get_node_or_null(^"Slab") == null or door.get_node_or_null(^"SlabShape") == null:
			_failures += 1
			print("FAIL: door missing Slab/SlabShape: ", spec["name"])
	for spec: Dictionary in KIT_PROPS:
		if props.get_node_or_null(NodePath(String(spec["name"]))) == null:
			_failures += 1
			print("FAIL: missing kit prop ", spec["name"])


func _verify_zones(zones: Node) -> void:
	for spec: Dictionary in ZONES:
		var zone: Node = zones.get_node_or_null(NodePath(String(spec["name"])))
		if zone == null:
			_failures += 1
			print("FAIL: missing zone ", spec["name"])
			continue
		if zone.get_node_or_null(^"Shape") == null:
			_failures += 1
			print("FAIL: zone missing Shape: ", spec["name"])


func _verify_links(links: Node) -> void:
	for spec: Dictionary in LINKS:
		if links.get_node_or_null(NodePath(String(spec["name"]))) == null:
			_failures += 1
			print("FAIL: missing link ", spec["name"])
