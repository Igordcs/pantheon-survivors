extends Node
class_name LootManager

enum Source { REGULAR_ENEMY, BOSS }

@export_range(0.0, 1.0, 0.001) var regular_drop_chance: float = 0.015
@export_range(0.0, 1.0, 0.001) var boss_drop_chance: float = 0.12
@export_range(1, 100, 1) var regular_coin_amount: int = 1
@export_range(1, 100, 1) var boss_coin_min: int = 2
@export_range(1, 100, 1) var boss_coin_max: int = 4
@export var coin_scene: PackedScene = preload("res://scenes/pickups/coin_pickup.tscn")

var rng := RandomNumberGenerator.new()
var _coin_pool: Array[Area2D] = []


func _ready() -> void:
	rng.randomize()


func set_seed(value: int) -> void:
	rng.seed = value


func roll_drop(source: Source) -> int:
	var chance := regular_drop_chance if source == Source.REGULAR_ENEMY else boss_drop_chance
	if rng.randf() >= chance:
		return 0
	if source == Source.REGULAR_ENEMY:
		return regular_coin_amount
	return rng.randi_range(mini(boss_coin_min, boss_coin_max), maxi(boss_coin_min, boss_coin_max))


func handle_defeat(position: Vector2, source: Source) -> int:
	var amount := roll_drop(source)
	if amount <= 0 or not coin_scene:
		return 0
	var coin := _get_coin()
	if coin.has_method("setup"):
		coin.call("setup", position, amount)
	return amount


func get_pool_size() -> int:
	return _coin_pool.size()


func _get_coin() -> Area2D:
	for coin in _coin_pool:
		if is_instance_valid(coin) \
				and coin.has_method("is_available_for_reuse") \
				and bool(coin.call("is_available_for_reuse")):
			return coin
	var coin := coin_scene.instantiate() as Area2D
	_coin_pool.append(coin)
	var container := get_tree().current_scene.get_node_or_null("World/Items")
	(container if container else get_tree().current_scene).add_child(coin)
	return coin
