## NOTICES: the third-party asset record, readable on any terminal that mounts it.
## Static legal text; no simulator state behind it.
class_name NoticesProgram
extends ComputerProgram

const LINES: PackedStringArray = [
	"THIRD-PARTY ASSETS",
	"",
	"All bundled third-party assets are",
	"CC0 1.0 (public domain): no",
	"attribution required, commercial",
	"use permitted. Licenses were",
	"verified against the source asset",
	"pages at download time.",
	"",
	"TEXTURES - POLY HAVEN",
	"polyhaven.com/textures",
	"Metal Plate, Painted Metal Shutter",
	"and Container Side dress the ship.",
	"Metal Grate Rusty and Rusty Metal",
	"were retired from the vessel and",
	"are kept for derelict wreckage.",
	"",
	"MODELS - KENNEY",
	"kenney.nl/assets",
	"Space Station Kit and Modular Space",
	"Kit supply the container, console",
	"and door-leaf geometry.",
	"",
	"ALL OTHER GEOMETRY, AUDIO AND TEXT:",
	"ORIGINAL WORK, PROJECT-AUTHORED.",
	"",
	"Full record: docs/ASSET_CREDITS.md",
]


func _init() -> void:
	title = "NOTICES"


func build_readout(_terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(LINES)
	lines.append("")
	lines.append("E/ESC: CLOSE")
	return lines
