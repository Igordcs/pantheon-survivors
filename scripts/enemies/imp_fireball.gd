extends Area2D
class_name ImpFireball

@export var speed: float = 190.0
@export var impact_damage: float = 6.0
@export var burn_damage_per_tick: float = 3.0
@export var burn_ticks: int = 5          # Quantas vezes toma dano de fogo
@export var burn_interval: float = 0.6    # Intervalo em segundos entre cada dano
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.ZERO
var _has_hit: bool = false


func _ready() -> void:
	top_level = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	get_tree().create_timer(lifetime).timeout.connect(func():
		if not _has_hit and is_instance_valid(self):
			queue_free()
	)


func launch(dir: Vector2) -> void:
	direction = dir.normalized()


func _physics_process(delta: float) -> void:
	if not _has_hit and direction != Vector2.ZERO:
		global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	_check_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_check_hit(area)
	elif area.owner and area.owner.is_in_group("player"):
		_check_hit(area.owner)


func _check_hit(target: Node2D) -> void:
	if _has_hit:
		return

	var health := target.get_node_or_null("HealthComponent") as HealthComponent
	if not health and target.get_parent():
		health = target.get_parent().get_node_or_null("HealthComponent") as HealthComponent

	if health and health.is_alive():
		_has_hit = true
		
		# 1. Desativa visual e colisão do projétil no momento do impacto
		visible = false
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		direction = Vector2.ZERO

		# 2. Dano de impacto inicial
		health.take_damage(impact_damage, global_position)

		# 3. Executa as queimaduras ao longo do tempo antes de libertar a memória
		await _apply_burn(target, health)

		queue_free()


func _apply_burn(target: Node2D, health: HealthComponent) -> void:
	var sprite: CanvasItem = target.get_node_or_null("Sprite2D")
	if not sprite and target.get_parent():
		sprite = target.get_parent().get_node_or_null("Sprite2D")

	for _tick in range(burn_ticks):
		await get_tree().create_timer(burn_interval).timeout
		
		if not is_instance_valid(health) or not health.is_alive():
			break

		# Pisca em tom de fogo/laranja a cada queimadura
		if is_instance_valid(sprite):
			sprite.modulate = Color(2.0, 0.45, 0.1)
			create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)

		health.take_damage(burn_damage_per_tick, global_position)

	if is_instance_valid(sprite):
		sprite.modulate = Color.WHITE
