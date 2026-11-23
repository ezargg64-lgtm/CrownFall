extends CharacterBody2D

## Shared base class for Wild Frontier enemies: HP, hit-flash, stun, knockback, floating popups, and loot drops.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/FloatingText.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/entities/Projectile.tscn")

@export var max_hp: int = 40
@export var gold_drop: int = 10
@export var monster_shard_drop: int = 1
@export var blight_shard_drop: int = 0
@export var bounce_bonus_shard: bool = false

@onready var visual_pivot: Node2D = $VisualPivot
@onready var body_sprite: Sprite2D = $VisualPivot/BodySprite
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var hp_bar_fill: ColorRect = $HPBarBG/HPBarFill

var hp: int = 40
var stun_timer: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _walk_time: float = 0.0
var _base_modulate: Color = Color.WHITE
var _dead: bool = false


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_base_modulate = body_sprite.modulate
	hp_bar_bg.visible = false
	_update_hp_bar()


func take_damage(
	amount: int,
	from_pos: Vector2,
	knockback_strength: float = 120.0,
	was_bounced: bool = false,
	stun_duration: float = 0.0
) -> void:
	if _dead:
		return

	hp = max(0, hp - amount)
	_update_hp_bar()
	AudioManager.play_hit()

	var push_dir: Vector2 = (global_position - from_pos).normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.UP
	_knockback_vel = push_dir * knockback_strength

	if stun_duration > 0.0:
		stun_timer = maxf(stun_timer, stun_duration)
		spawn_floating_text("STUNNED!", Color(1.0, 0.9, 0.25, 1.0), 0.95)

	body_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(body_sprite, "modulate", _base_modulate, 0.14)

	var dmg_color: Color = Color(1.0, 0.88, 0.25, 1.0) if was_bounced else Color(1.0, 0.95, 0.95, 1.0)
	spawn_floating_text("%d" % amount, dmg_color, 1.05 if was_bounced else 0.95)

	if hp <= 0:
		_die(was_bounced)


func _tick_common(delta: float, move_vel: Vector2) -> bool:
	_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 600.0 * delta)

	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		velocity = _knockback_vel
		move_and_slide()
		visual_pivot.position.x = sin(Time.get_ticks_msec() * 0.05) * 1.5
		body_sprite.modulate = Color(1.2, 1.1, 0.5, 1.0)
		if stun_timer <= 0.0:
			visual_pivot.position.x = 0.0
			body_sprite.modulate = _base_modulate
		return true

	velocity = move_vel + _knockback_vel
	move_and_slide()

	if move_vel.length_squared() > 4.0:
		_walk_time += delta * 12.0
		var bob: float = absf(sin(_walk_time))
		visual_pivot.position.y = -bob * 2.0
		if absf(move_vel.x) > 3.0:
			body_sprite.flip_h = move_vel.x < 0.0
	else:
		visual_pivot.position.y = lerpf(visual_pivot.position.y, 0.0, minf(1.0, delta * 12.0))
	return false


func _get_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _fire_projectile(dir: Vector2, spd: float, dmg: int, orb_color: Color) -> void:
	if get_parent() == null:
		return
	var proj := PROJECTILE_SCENE.instantiate() as Area2D
	get_parent().add_child(proj)
	proj.setup(global_position + dir * 10.0, dir, spd, dmg, orb_color, self)


func _update_hp_bar() -> void:
	hp_bar_bg.visible = hp < max_hp and hp > 0
	var ratio: float = clampf(float(hp) / float(max(1, max_hp)), 0.0, 1.0)
	hp_bar_fill.size.x = 14.0 * ratio


func _die(was_bounced: bool) -> void:
	_dead = true
	var bonus_m: int = 1 if (was_bounced and bounce_bonus_shard and monster_shard_drop > 0) else 0
	var bonus_b: int = 1 if (was_bounced and bounce_bonus_shard and blight_shard_drop > 0) else 0
	var total_m: int = monster_shard_drop + bonus_m
	var total_b: int = blight_shard_drop + bonus_b

	GameState.add_enemy_loot(gold_drop, total_m, total_b)

	var loot_parts: PackedStringArray = ["+%dG" % gold_drop]
	if total_m > 0:
		loot_parts.append("+%d Shard" % total_m if total_m == 1 else "+%d Shards" % total_m)
	if total_b > 0:
		loot_parts.append("+%d Blight" % total_b)
	spawn_floating_text(" ".join(loot_parts), Color(1.0, 0.9, 0.35, 1.0), 0.9)

	_spawn_death_burst()
	queue_free()


func _spawn_death_burst() -> void:
	if get_parent() == null:
		return
	var burst := CPUParticles2D.new()
	burst.global_position = global_position
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.amount = 14
	burst.lifetime = 0.45
	burst.spread = 180.0
	burst.gravity = Vector2(0, 60)
	burst.initial_velocity_min = 24.0
	burst.initial_velocity_max = 52.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.0
	burst.color = Color(0.95, 0.65, 0.45, 1.0)
	get_parent().add_child(burst)
	get_tree().create_timer(0.6).timeout.connect(burst.queue_free)


func spawn_floating_text(txt: String, col: Color, scl: float = 1.0) -> void:
	if get_parent() == null:
		return
	var popup := FLOATING_TEXT_SCENE.instantiate() as Node2D
	popup.global_position = global_position + Vector2(0, -12)
	get_parent().add_child(popup)
	popup.setup(txt, col, scl)
