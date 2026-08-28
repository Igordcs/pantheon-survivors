extends Resource
class_name EvolutionRecipe
## Define a receita para evoluir uma arma.

@export var base_weapon: WeaponData
@export var required_relic: RelicData
@export var evolved_weapon: WeaponData
@export var require_max_weapon_level: bool = true
