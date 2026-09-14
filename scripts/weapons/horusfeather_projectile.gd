extends Area2D

signal hit_enemy(
	enemy: Node2D,
	impact_position: Vector2,
	dealt_damage: float
)

var direction: Vector2 = Vector2.ZERO
var speed: float = 700.0
var damage: float = 14.0
var max_distance: float = 800.0

# 0 = não atravessa
# 1 = atravessa 1 inimigo adicional
# 2 = atravessa 2 inimigos adicionais
# -1 = atravessa infinitos inimigos
var pierce_count: int = 0

var knockback_force: float = 0.0

var _wielder: Node2D
var _distance_traveled: float = 0.0

# Guarda os inimigos que já foram atingidos.
# Isso impede que uma pena dê dano repetidamente
# enquanto permanece sobre o mesmo inimigo.
var _hit_enemies: Dictionary = {}

var _pierce_hits: int = 0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_wielder):
		queue_free()
		return

	var movement := speed * delta
	var new_position := global_position + direction * movement

	# Verifica se saiu da tela.
	var viewport_rect := get_viewport_rect()

	if not viewport_rect.encloses(
		Rect2(new_position, Vector2(10, 10))
	):
		if _distance_traveled > max_distance * 0.5:
			queue_free()
			return

	global_position = new_position
	_distance_traveled += movement

	# Limite máximo da distância do projétil.
	if _distance_traveled >= max_distance:
		queue_free()
		return

	_damage_overlapping_enemies()


func setup(
	wielder: Node2D,
	dir: Vector2,
	spd: float,
	dmg: float,
	max_dist: float = 800.0,
	p_count: int = 0,
	kb_force: float = 0.0
) -> void:
	_wielder = wielder

	direction = dir.normalized()

	speed = spd
	damage = dmg
	max_distance = max_dist

	pierce_count = p_count
	knockback_force = kb_force

	_distance_traveled = 0.0
	_hit_enemies.clear()
	_pierce_hits = 0

	# O sprite da pena foi desenhado apontando para cima.
	# Rotacionamos para que ele aponte na direção do movimento.
	rotation = direction.angle() + PI / 2.0


func _damage_overlapping_enemies() -> void:
	for body in get_overlapping_bodies():

		if not body.is_in_group("enemies"):
			continue

		if not body.visible:
			continue

		var instance_id := body.get_instance_id()

		var health := body.get_node_or_null(
			"HealthComponent"
		) as HealthComponent

		if not health:
			continue

		if not health.is_alive():
			continue

		# Uma pena nunca deve causar dano múltiplas vezes
		# no mesmo inimigo.
		if _hit_enemies.has(instance_id):
			continue

		_hit_enemies[instance_id] = true

		health.take_damage(
			damage,
			global_position
		)

		hit_enemy.emit(
			body,
			global_position,
			damage
		)

		# Knockback.
		if (
			knockback_force > 0.0
			and body.has_method("apply_knockback_from")
		):
			body.apply_knockback_from(
				global_position,
				knockback_force
			)

		# Perfuração infinita:
		# continua voando sem aumentar limite de hits.
		if pierce_count == -1:
			continue

		# Perfuração limitada.
		_pierce_hits += 1

		# pierce_count = 0:
		# primeiro inimigo -> destrói
		#
		# pierce_count = 1:
		# primeiro inimigo -> continua
		# segundo inimigo -> destrói
		if _pierce_hits > pierce_count:
			queue_free()
			return


func get_pierces_remaining() -> int:
	if pierce_count == -1:
		return 999

	return maxf(
		0,
		pierce_count - _pierce_hits
	)