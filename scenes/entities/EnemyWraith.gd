extends "res://scenes/entities/EnemyBase.gd"

## Night-only floating enemy: ignores wall collision, fires fast dark orbs, drops Blight Shards.

@export var orb_damage: int = 15

var _fire_cd: float = 1.2
var _windup_timer: float = 0.0
var _hover_time: float = 0.0


func _ready() -> void:
	max_hp = 55
	gold_drop = 25
	monster_shard_drop = 0
	blight_shard_drop = 1
	bounce_bonus_shard = true
	super._ready()


func _physics_process(delta: float) -> void:
	_hover_time += delta * 4.0
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
		body_sprite.modulate = Color(1.4, 0.7, 1.8, 0.95)
		if _windup_timer <= 0.0:
			body_sprite.modulate = _base_modulate
			_fire_projectile(dir, 150.0, orb_damage, Color(0.68, 0.25, 0.95, 1.0))
			_fire_cd = 1.8
	else:
		if dist > 86.0:
			move_vel = dir * 52.0
		elif dist < 58.0:
			move_vel = -dir * 38.0
		else:
			move_vel = Vector2(-dir.y, dir.x) * 32.0

		_fire_cd -= delta
		if _fire_cd <= 0.0 and dist <= 230.0:
			_windup_timer = 0.25

	body_sprite.flip_h = dir.x < 0.0
	_tick_common(delta, move_vel)
	visual_pivot.position.y = -3.0 + sin(_hover_time) * 2.5
