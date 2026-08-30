class_name BiomeData
extends Resource
## Data-driven definition shared by biome and world generation systems.

@export var biome_id: StringName = &"grassland"
@export var display_name: String = "Campo"

@export_category("Noise Range")
@export_range(-1.0, 1.0, 0.01) var min_noise_value: float = -0.35
@export_range(-1.0, 1.0, 0.01) var max_noise_value: float = 0.35

@export_category("Ground")
@export var ground_source_id: int = 0
@export var ground_atlas_coordinates: Vector2i = Vector2i(1, 7)
@export var ground_alternative_tile: int = 0
@export var is_navigable: bool = true
@export_range(0.1, 2.0, 0.05) var movement_speed_multiplier: float = 1.0

@export_category("Distribution")
@export_range(0.0, 1.0, 0.01) var decoration_density: float = 0.0
@export_range(0.0, 1.0, 0.01) var obstacle_density: float = 0.08
@export var decoration_source_id: int = 2
@export var decoration_atlas_coordinates: Array[Vector2i] = []
@export var rare_decoration_atlas_coordinates: Array[Vector2i] = []
@export_range(0.0, 1.0, 0.01) var rare_decoration_chance: float = 0.0
@export var obstacle_entries: Array[WorldObjectData] = []
