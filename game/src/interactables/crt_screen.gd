## Tints an authored CRT console's screen quad at load. The phosphor material cannot be set
## when the layout is generated: a property override inside an instanced glTF subtree is not
## serialized by `PackedScene`, so the prop carries this small node instead and the override
## happens when it enters the tree.
class_name CrtScreen
extends Node

@export var phosphor_material: Material


func _ready() -> void:
	if phosphor_material == null:
		return
	var screen: MeshInstance3D = get_parent().find_child("Screen", true, false) as MeshInstance3D
	if screen != null:
		screen.material_override = phosphor_material
