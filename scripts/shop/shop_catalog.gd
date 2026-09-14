extends RefCounted
class_name ShopCatalog

static var PRODUCTS: Array[ShopItemData] = _build_products()


static func get_products(category: int) -> Array[ShopItemData]:
	var result: Array[ShopItemData] = []
	for product in PRODUCTS:
		if product.category == category:
			result.append(product)
	return result

static func _build_products() -> Array[ShopItemData]:
	var result: Array[ShopItemData] = [
		load("res://resources/shop/arthur_shop_item.tres") as ShopItemData,
		load("res://resources/shop/kratos_shop_item.tres") as ShopItemData,
		load("res://resources/shop/punisher_shop_item.tres") as ShopItemData,
		load("res://resources/shop/anubis_curse_shop_item.tres") as ShopItemData,
		load("res://resources/shop/gungnir_shop_item.tres") as ShopItemData,
		load("res://resources/shop/sumarbrander_shop_item.tres") as ShopItemData,
		load("res://resources/shop/leviathan_axe_shop_item.tres") as ShopItemData,
		load("res://resources/shop/horusfeather_shop_item.tres") as ShopItemData,
	]
	for item in ItemCatalog.get_shop_items():
		var product := ShopItemData.new()
		product.id = item.id; product.category = ShopItemData.Category.ITEM
		product.display_name = item.display_name; product.description = "%s — %s" % [item.mythology, item.description]
		product.icon = item.icon; product.price = item.price; product.content = item
		result.append(product)
	return result
