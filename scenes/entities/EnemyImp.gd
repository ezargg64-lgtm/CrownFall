extends "res://scenes/entities/EnemyBase.gd"

## Day ranged attacker: keeps distance and shoots bounceable fireballs (drops 2 Shards on bounced kill).

@export var fireball_damage: int = 12

var _fire_cd: float = 1.4
var _windup_timer: float = 0.0
var _strafe_sign: float = 1.0


func _ready() -> void:
	max_hp = 35
	gold_drop = 15
	monster_shard_drop = 1
	blight_shard_drop = 0
	bounce_bonus_shard = true
	super._ready()
	_strafe_sign = 1.0 if randf() > 0.5 else -1.0


func _physics_process(delta: float) -> void:
	var player: Node2D = _get_player()
	if player == null:
		_tick_common(delta, Vector2.ZERO)
		return

	if stun_timer > 0.0:
		_windup_timer = 0.0
		_tick_common(delta, Vector2.ZERO)
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if dist > 1.0 else Vector2.DOWN
	var move_vel: Vector2 = Vector2.ZERO

	if _windup_timer > 0.0:
		_windup_timer -= delta
		body_sprite.modulate = Color(1.5, 0.95, 0.65, 1.0)
		if _windup_timer <= 0.0:
			body_sprite.modulate = _base_modulate
			_fire_projectile(dir, 115.0, fireball_damage, Color(1.0, 0.45, 0.15, 1.0))
			_fire_cd = 2.1
	else:
		if dist > 230.0:
			move_vel = Vector2.ZERO
		elif dist > 125.0:
			move_vel = dir * 44.0
		elif dist < 68.0:
			move_vel = -dir * 46.0
		else:
			move_vel = Vector2(-dir.y, dir.x) * 28.0 * _strafe_sign

		_fire_cd -= delta
		if _fire_cd <= 0.0 and dist <= 210.0:
			_windup_timer = 0.30

	body_sprite.flip_h = dir.x < 0.0
	_tick_common(delta, move_vel)
