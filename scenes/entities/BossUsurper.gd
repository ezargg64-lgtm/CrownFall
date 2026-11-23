extends CharacterBody2D

## Final Boss: The Usurper (350 HP) — Phase 1 Barrier + Bounce Break, Phase 2 Dead-Man's Volley + Dash Slam.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/FloatingText.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/entities/Projectile.tscn")

enum State { INTRO, IDLE, ORB_WINDUP, DASH_TELEGRAPH, DASH_SLAM, STUNNED, DEFEATED }

@export var max_hp: int = 350

@onready var visual_pivot: Node2D = $VisualPivot
@onready var body_sprite: Sprite2D = $VisualPivot/BodySprite
@onready var staff_sprite: Sprite2D = $VisualPivot/StaffSprite
@onready var barrier_ring: Polygon2D = $VisualPivot/BarrierRing
@onready var telegraph_line: Line2D = $TelegraphLine
@onready var hit_area: Area2D = $HitArea

var hp: int = 350
var phase: int = 1
var barrier_active: bool = true
var _state: State = State.INTRO
var _state_timer: float = 0.0
var _attack_counter: int = 0
var _dash_dir: Vector2 = Vector2.DOWN
var _hit_cooldown: float = 0.0
var _hover_time: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	barrier_active = true
	telegraph_line.visible = false
	hit_area.body_entered.connect(_on_hit_area_body_entered)
	_update_barrier_visual()
	GameState.boss_hp_changed.emit(hp, max_hp, true)


func activate_boss() -> void:
	if _state == State.INTRO:
		_state = State.IDLE
		_state_timer = 1.0


func _physics_process(delta: float) -> void:
	_hover_time += delta * 3.5
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 600.0 * delta)

	if _state == State.INTRO or _state == State.DEFEATED:
		velocity = Vector2.ZERO
		visual_pivot.position.y = sin(_hover_time) * 2.0
		return

	if GameState.is_ui_open or GameState.is_sleeping:
		velocity = Vector2.ZERO
		return

	var player: Node2D = _get_player()
	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var dist: float = to_player.length()
	var dir: Vector2 = to_player.normalized() if dist > 1.0 else Vector2.DOWN

	match _state:
		State.STUNNED:
			_state_timer -= delta
			velocity = _knockback_vel
			move_and_slide()
			visual_pivot.position.x = sin(Time.get_ticks_msec() * 0.05) * 2.0
			body_sprite.modulate = Color(1.3, 1.15, 0.55, 1.0)
			if _state_timer <= 0.0:
				visual_pivot.position.x = 0.0
				body_sprite.modulate = Color.WHITE
				barrier_active = true
				_update_barrier_visual()
				_spawn_floating_text("BARRIER RESTORED!", Color(0.75, 0.45, 1.0, 1.0), 0.95)
				_state = State.IDLE
				_state_timer = 0.85

		State.IDLE:
			_state_timer -= delta
			# Drift gently at medium range from player
			var desired_vel: Vector2 = Vector2.ZERO
			if dist > 135.0:
				desired_vel = dir * 48.0
			elif dist < 75.0:
				desired_vel = -dir * 42.0
			else:
				desired_vel = Vector2(-dir.y, dir.x) * 32.0
			velocity = desired_vel + _knockback_vel
			move_and_slide()
			body_sprite.flip_h = dir.x < 0.0
			visual_pivot.position.y = sin(_hover_time) * 2.0

			if _state_timer <= 0.0:
				_attack_counter += 1
				if phase == 2 and _attack_counter % 2 == 0:
					_state = State.DASH_TELEGRAPH
					_state_timer = 0.60
					_dash_dir = dir
				else:
					_state = State.ORB_WINDUP
					_state_timer = 0.42

		State.ORB_WINDUP:
			_state_timer -= delta
			velocity = _knockback_vel
			move_and_slide()
			body_sprite.flip_h = dir.x < 0.0
			staff_sprite.rotation = lerpf(staff_sprite.rotation, -0.7, minf(1.0, delta * 12.0))
			body_sprite.modulate = Color(1.35, 0.85, 1.65, 1.0)
			if _state_timer <= 0.0:
				body_sprite.modulate = Color.WHITE
				staff_sprite.rotation = 0.25
				_spawn_boss_orb(dir)
				_state = State.IDLE
				_state_timer = 2.0 if phase == 1 else 1.65

		State.DASH_TELEGRAPH:
			_state_timer -= delta
			velocity = _knockback_vel
			move_and_slide()
			_dash_dir = dir
			body_sprite.flip_h = _dash_dir.x < 0.0
			telegraph_line.visible = true
			telegraph_line.points = PackedVector2Array([Vector2.ZERO, _dash_dir * 125.0])
			visual_pivot.scale = Vector2(1.18, 0.84)
			if _state_timer <= 0.0:
				telegraph_line.visible = false
				visual_pivot.scale = Vector2.ONE
				AudioManager.play_dash()
				_state = State.DASH_SLAM
				_state_timer = 0.42

		State.DASH_SLAM:
			_state_timer -= delta
			velocity = _dash_dir * 240.0
			move_and_slide()
			if _state_timer <= 0.0 or is_on_wall():
				GameState.request_camera_shake(3.0, 0.12)
				_state = State.IDLE
				_state_timer = 1.1


func _spawn_boss_orb(dir: Vector2) -> void:
	if get_parent() == null:
		return
	var proj := PROJECTILE_SCENE.instantiate() as Area2D
	get_parent().add_child(proj)
	var orb_speed: float = 128.0 if phase == 1 else 142.0
	var orb_dmg: int = 16 if phase == 1 else 18
	var orb_color: Color = Color(0.62, 0.22, 0.95, 1.0)
	proj.setup(global_position + dir * 14.0, dir, orb_speed, orb_dmg, orb_color, self)
	proj.max_volleys = 0 if phase == 1 else randi_range(2, 3)


## Called by Projectile.gd when a player-reflected orb hits the Usurper.
## Returns true if the Usurper bats the orb back (Dead-Man's Volley), false if it breaks his guard.
func on_reflected_orb(proj: Area2D) -> bool:
	if _state == State.DEFEATED:
		return false

	if barrier_active and phase == 2 and proj.volley_count < proj.max_volleys:
		AudioManager.play_parry_bounce()
		GameState.trigger_hit_stop(0.04)
		GameState.request_camera_shake(3.0, 0.10)
		staff_sprite.rotation = -1.1
		var tw: Tween = create_tween()
		tw.tween_property(staff_sprite, "rotation", 0.25, 0.18)
		proj.volley_back(self, 18)
		return true

	# Guard shattered!
	var shatter_dmg: int = 40 if phase == 1 else 55
	barrier_active = false
	_update_barrier_visual()
	_enter_stun(3.5)
	_spawn_floating_text("BARRIER SHATTERED!", Color(1.0, 0.9, 0.25, 1.0), 1.15)
	AudioManager.play_rebuild()
	GameState.trigger_hit_stop(0.06)
	GameState.request_camera_shake(5.5, 0.18)
	take_damage(shatter_dmg, proj.global_position, 130.0, true, 3.5)
	return false


func take_damage(
	amount: int,
	from_pos: Vector2,
	knockback_strength: float = 90.0,
	was_bounced: bool = false,
	stun_duration: float = 0.0
) -> void:
	if _state == State.DEFEATED or _state == State.INTRO:
		return

	var final_dmg: int = amount
	if barrier_active and not was_bounced:
		final_dmg = max(1, int(round(float(amount) * 0.30)))
		_spawn_floating_text("BARRIER (%d)" % final_dmg, Color(0.72, 0.52, 1.0, 1.0), 0.85)
	else:
		var col: Color = Color(1.0, 0.88, 0.25, 1.0) if was_bounced else Color(1.0, 0.95, 0.95, 1.0)
		_spawn_floating_text("%d" % final_dmg, col, 1.1 if was_bounced else 1.0)

	hp = max(0, hp - final_dmg)
	AudioManager.play_hit()
	GameState.boss_hp_changed.emit(hp, max_hp, hp > 0)

	var push_dir: Vector2 = (global_position - from_pos).normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.UP
	_knockback_vel = push_dir * (knockback_strength * 0.5)

	body_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(body_sprite, "modulate", Color.WHITE, 0.14)

	if stun_duration > 0.0 and _state != State.STUNNED:
		_enter_stun(stun_duration)

	if hp <= 0:
		_die()
		return

	if phase == 1 and hp <= max_hp / 2:
		_enter_phase_2()


func _enter_phase_2() -> void:
	phase = 2
	barrier_active = true
	_update_barrier_visual()
	_state = State.IDLE
	_state_timer = 1.0
	visual_pivot.position.x = 0.0
	body_sprite.modulate = Color.WHITE
	GameState.request_camera_shake(6.0, 0.28)
	AudioManager.play_rebuild()
	_spawn_floating_text("PHASE 2: DEAD-MAN'S VOLLEY!", Color(1.0, 0.35, 0.55, 1.0), 1.15)
	GameState.show_toast("The Usurper enters Phase 2 — rally his dark orbs back!")


func _enter_stun(duration: float) -> void:
	telegraph_line.visible = false
	visual_pivot.scale = Vector2.ONE
	_state = State.STUNNED
	_state_timer = maxf(_state_timer, duration)


func _on_hit_area_body_entered(body: Node2D) -> void:
	if _state == State.DEFEATED or _state == State.STUNNED or _state == State.INTRO or _hit_cooldown > 0.0:
		return
	if not body.is_in_group("player"):
		return

	_hit_cooldown = 0.55
	if _state == State.DASH_SLAM and body.has_method("is_parry_active") and body.is_parry_active():
		if body.has_method("on_parry_success"):
			body.on_parry_success()
		barrier_active = false
		_update_barrier_visual()
		AudioManager.play_parry_bounce()
		GameState.add_royal_gauge(25.0)
		GameState.trigger_hit_stop(0.05)
		GameState.request_camera_shake(5.0, 0.16)
		_spawn_floating_text("BOUNCE BACK!", Color(1.0, 0.92, 0.25, 1.0), 1.15)
		_enter_stun(2.5)
		take_damage(25, body.global_position, 140.0, true, 2.5)
		return

	if body.has_method("is_block_active") and body.is_block_active():
		AudioManager.play_shield_block()
		_spawn_floating_text("BLOCK", Color(0.65, 0.85, 1.0, 1.0), 0.95)
		return

	if body.has_method("take_damage"):
		var dmg: int = 18 if _state == State.DASH_SLAM else 12
		body.take_damage(dmg, global_position)


func _die() -> void:
	_state = State.DEFEATED
	telegraph_line.visible = false
	barrier_active = false
	_update_barrier_visual()
	GameState.boss_defeated = true
	GameState.boss_hp_changed.emit(0, max_hp, false)
	GameState.request_camera_shake(7.0, 0.35)
	AudioManager.play_rebuild()
	_spawn_floating_text("USURPER DEFEATED!", Color(1.0, 0.92, 0.35, 1.0), 1.2)

	var burst := CPUParticles2D.new()
	burst.global_position = global_position
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.amount = 36
	burst.lifetime = 0.9
	burst.spread = 180.0
	burst.gravity = Vector2(0, 40)
	burst.initial_velocity_min = 30.0
	burst.initial_velocity_max = 85.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 4.0
	burst.color = Color(1.0, 0.85, 0.35, 1.0)
	get_parent().add_child(burst)

	GameState.boss_vanquished.emit()
	queue_free()


func _update_barrier_visual() -> void:
	barrier_ring.visible = barrier_active
	if phase == 2:
		barrier_ring.color = Color(0.88, 0.22, 0.55, 0.42)
	else:
		barrier_ring.color = Color(0.55, 0.22, 0.92, 0.38)


func _get_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _spawn_floating_text(txt: String, col: Color, scl: float) -> void:
	if get_parent() == null:
		return
	var popup := FLOATING_TEXT_SCENE.instantiate() as Node2D
	popup.global_position = global_position + Vector2(0, -18)
	get_parent().add_child(popup)
	popup.setup(txt, col, scl)
