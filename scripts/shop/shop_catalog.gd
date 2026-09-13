extends RefCounted
class_name ShopCatalog

const PRODUCTS: Array[ShopItemData] = [
	preload("res://resources/shop/punisher_shop_item.tres"),
	preload("res://resources/shop/anubis_curse_shop_item.tres"),
	preload("res://resources/shop/gungnir_shop_item.tres"),
	preload("res://resources/shop/sumarbrander_shop_item.tres"),
]


static func get_products(category: int) -> Array[ShopItemData]:
	var result: Array[ShopItemData] = []
	for product in PRODUCTS:
		if product.category == category:
			result.append(product)
	return result
