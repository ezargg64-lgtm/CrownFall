extends "res://scenes/entities/EnemyBase.gd"

## Day melee charger: telegraphs charge with red warning line; self-stuns if parried by Bounce Shield.

enum State { CHASE, TELEGRAPH, CHARGE, RECOVER }

@export var charge_damage: int = 10

@onready var telegraph_line: Line2D = $TelegraphLine
@onready var hit_area: Area2D = $HitArea

var _state: State = State.CHASE
var _state_timer: float = 0.0
var _charge_dir: Vector2 = Vector2.DOWN
var _hit_cooldown: float = 0.0


func _ready() -> void:
	max_hp = 45
	gold_drop = 10
	monster_shard_drop = 1
	blight_shard_drop = 0
	bounce_bonus_shard = false
	super._ready()
	telegraph_line.visible = false
	hit_area.body_entered.connect(_on_hit_area_body_entered)


func _physics_process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	var player: Node2D = _get_player()
	if player == null:
		_tick_common(delta, Vector2.ZERO)
		return

	if stun_timer > 0.0:
		telegraph_line.visible = false
		_state = State.RECOVER
		_state_timer = 0.35
		_tick_common(delta, Vector2.ZERO)
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var move_vel: Vector2 = Vector2.ZERO

	match _state:
		State.CHASE:
			telegraph_line.visible = false
			if dist <= 92.0:
				_state = State.TELEGRAPH
				_state_timer = 0.55
				_charge_dir = to_player.normalized() if dist > 1.0 else Vector2.DOWN
				body_sprite.flip_h = _charge_dir.x < 0.0
			elif dist <= 220.0:
				move_vel = to_player.normalized() * 48.0
		State.TELEGRAPH:
			_state_timer -= delta
			_charge_dir = to_player.normalized() if dist > 1.0 else _charge_dir
			body_sprite.flip_h = _charge_dir.x < 0.0
			telegraph_line.visible = true
			telegraph_line.points = PackedVector2Array([Vector2.ZERO, _charge_dir * 78.0])
			visual_pivot.scale = Vector2(1.12, 0.86)
			if _state_timer <= 0.0:
				telegraph_line.visible = false
				visual_pivot.scale = Vector2.ONE
				_state = State.CHARGE
				_state_timer = 0.45
		State.CHARGE:
			_state_timer -= delta
			move_vel = _charge_dir * 185.0
			if _state_timer <= 0.0 or is_on_wall():
				_state = State.RECOVER
				_state_timer = 0.75
		State.RECOVER:
			_state_timer -= delta
			if _state_timer <= 0.0:
				_state = State.CHASE

	_tick_common(delta, move_vel)


func _on_hit_area_body_entered(body: Node2D) -> void:
	if _dead or stun_timer > 0.0 or _hit_cooldown > 0.0:
		return
	if not body.is_in_group("player"):
		return

	_hit_cooldown = 0.45
	if body.has_method("is_parry_active") and body.is_parry_active():
		_state = State.RECOVER
		_state_timer = 0.5
		if body.has_method("on_parry_success"):
			body.on_parry_success()
		GameState.add_royal_gauge(25.0)
		AudioManager.play_parry_bounce()
		GameState.trigger_hit_stop(0.05)
		GameState.request_camera_shake(4.5, 0.14)
		spawn_floating_text("BOUNCE BACK!", Color(1.0, 0.92, 0.25, 1.0), 1.05)
		take_damage(15, body.global_position, 175.0, true, 1.5)
		return

	if body.has_method("is_block_active") and body.is_block_active():
		_state = State.RECOVER
		_state_timer = 0.6
		AudioManager.play_shield_block()
		_knockback_vel = (global_position - body.global_position).normalized() * 115.0
		spawn_floating_text("BLOCK", Color(0.65, 0.85, 1.0, 1.0), 0.95)
		return

	if body.has_method("take_damage"):
		body.take_damage(charge_damage, global_position)
