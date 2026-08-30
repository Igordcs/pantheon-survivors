class_name WorldObjectData
extends Resource
## Defines one weighted object that can be placed in a biome.

@export var scene: PackedScene
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(0.0, 256.0, 1.0) var clearance_radius: float = 24.0

