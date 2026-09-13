extends Resource
class_name ShopItemData

enum Category { CHARACTER, WEAPON, ITEM }

@export var id: StringName
@export var category: Category = Category.CHARACTER
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(0, 999999, 1) var price: int
@export var content: Resource
