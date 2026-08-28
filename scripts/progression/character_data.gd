extends Resource
class_name CharacterData
## Dados de um personagem desbloqueável/selecionável.

@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var starting_weapon: Resource # WeaponData
@export var base_health: float = 100.0
@export var base_speed: float = 200.0
@export var passive_description: String = ""
