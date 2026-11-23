extends CharacterBody2D

## Humbled King 2D rig: 8-way movement, context interaction, Zelda sword/shield/roll/spin combat, and camera shake.

@export var move_speed: float = 92.0

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/FloatingText.tscn")

const SWORD_TEXTURES: Dictionary = {
	1: preload("res://assets/ui/tiny_dungeon_tile_0103.png"),
	2: preload("res://assets/ui/tiny_dungeon_tile_0104.png"),
	3: preload("res://assets/ui/tiny_dungeon_tile_0107.png"),
}

const SHIELD_BASIC_TEX: Texture2D = preload("res://assets/ui/tiny_dungeon_tile_0101.png")
const SHIELD_UPGRADED_TEX: Texture2D = preload("res://assets/ui/tiny_dungeon_tile_0102.png")

@onready var visual_pivot: Node2D = $VisualPivot
@onready var body_sprite: Sprite2D = $VisualPivot/BodySprite
@onready var weapon_pivot: Node2D = $VisualPivot/WeaponPivot
@onready var weapon_sprite: Sprite2D = $VisualPivot/WeaponPivot/WeaponSprite
@onready var shield_pivot: Node2D = $VisualPivot/ShieldPivot
@onready var shield_sprite: Sprite2D = $VisualPivot/ShieldPivot/ShieldSprite
@onready var parry_ring: Polygon2D = $VisualPivot/ParryRing
@onready var slash_arc: Line2D = $VisualPivot/SlashArc
@onready var dash_particles: CPUParticles2D = $DashParticles
@onready var interact_area: Area2D = $InteractArea
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var spin_hitbox: Area2D = $SpinHitbox
@onready var parry_area: Area2D = $ParryArea
@onready var prompt_label: Label = $PromptLabel
@onready var camera_2d: Camera2D = $Camera2D

var facing_dir: Vector2 = Vector2.DOWN
var facing_left: bool = false
var _walk_time: float = 0.0
var _current_interactable: Node = null

var _attack_timer: float = 0.0
var _attack_cd: float = 0.0
var _attack_base_angle: float = 0.0
var _sword_hit_ids: Array[int] = []

var _parry_timer: float = 0.0
var _block_timer: float = 0.0
var _parry_cd: float = 0.0

var _dash_timer: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.DOWN

var _spin_timer: float = 0.0
var _spin_cd: float = 0.0
var _spin_hit_ids: Array[int] = []

var _invuln_timer: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _footstep_timer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	GameState.stats_changed.connect(_refresh_equipment_visuals)
	GameState.camera_shake_requested.connect(_on_camera_shake_requested)
	_refresh_equipment_visuals()
	_update_facing_visuals()
	prompt_label.visible = false
	parry_ring.visible = false
	slash_arc.visible = false
	sword_hitbox.monitoring = false
	spin_hitbox.monitoring = false


func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer = maxf(0.0, _shake_timer - delta)
		camera_2d.offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	else:
		camera_2d.offset = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_tick_combat_timers(delta)

	if GameState.is_sleeping or GameState.is_ui_open:
		velocity = Vector2.ZERO
		_animate_movement(Vector2.ZERO, delta)
		_refresh_nearest_interactable()
		return

	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	_refresh_nearest_interactable()

	var interacted_this_frame: bool = false
	if Input.is_action_just_pressed("interact") and _current_interactable != null:
		if _current_interactable.has_method("interact"):
			_current_interactable.interact(self)
			_refresh_nearest_interactable()
			interacted_this_frame = true

	if Input.is_action_just_pressed("use_potion"):
		_try_use_potion()

	if not GameState.is_safe_zone:
		if Input.is_action_just_pressed("parry_bounce"):
			_try_parry_bounce()
		if Input.is_action_just_pressed("attack"):
			_try_attack()
		if Input.is_action_just_pressed("skill_spin"):
			_try_spin_slash()
		if Input.is_action_just_pressed("dash") and not interacted_this_frame:
			_try_dash(input_vec)

	if _dash_timer > 0.0:
		velocity = _dash_dir * 235.0
	else:
		var speed_mult: float = GameState.get_speed_multiplier()
		if _parry_timer > 0.0 or _block_timer > 0.0:
			speed_mult *= 0.45
		velocity = input_vec * move_speed * speed_mult + _knockback_vel
		_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 650.0 * delta)

	move_and_slide()

	if input_vec.length_squared() > 0.01 and _dash_timer <= 0.0 and _attack_timer <= 0.0:
		facing_dir = input_vec.normalized()
		if absf(input_vec.x) > 0.15:
			facing_left = input_vec.x < 0.0
			_update_facing_visuals()

	_process_active_hitboxes(delta)
	_animate_movement(input_vec, delta)


func set_camera_limits(bounds: Rect2i) -> void:
	camera_2d.limit_left = bounds.position.x
	camera_2d.limit_top = bounds.position.y
	camera_2d.limit_right = bounds.end.x
	camera_2d.limit_bottom = bounds.end.y


func is_parry_active() -> bool:
	return _parry_timer > 0.0


func is_block_active() -> bool:
	return _block_timer > 0.0


func on_parry_success() -> void:
	_parry_cd = 0.25
	parry_ring.color = Color(1.0, 0.96, 0.45, 0.9)
	parry_ring.scale = Vector2(1.45, 1.45)


func take_damage(amount: int, from_pos: Vector2) -> void:
	if _invuln_timer > 0.0 or GameState.is_safe_zone or GameState.is_sleeping:
		return

	_invuln_timer = 0.65
	var push_dir: Vector2 = (global_position - from_pos).normalized()
	if push_dir.length_squared() < 0.01:
		push_dir = Vector2.DOWN
	_knockback_vel = push_dir * 165.0

	body_sprite.modulate = Color(3.0, 1.2, 1.2, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(body_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)

	_spawn_floating_text("-%d" % amount, Color(1.0, 0.32, 0.32, 1.0), 1.0)
	AudioManager.play_player_hurt()
	GameState.request_camera_shake(3.5, 0.14)
	GameState.apply_player_damage(amount)


func _tick_combat_timers(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_parry_cd = maxf(0.0, _parry_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_spin_cd = maxf(0.0, _spin_cd - delta)

	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)
		if _dash_timer <= 0.0:
			visual_pivot.modulate.a = 0.55 if int(_invuln_timer * 20.0) % 2 == 0 else 1.0
	else:
		visual_pivot.modulate.a = 1.0

	if _parry_timer > 0.0:
		_parry_timer = maxf(0.0, _parry_timer - delta)
		parry_ring.visible = true
		parry_ring.color = Color(1.0, 0.88, 0.25, 0.55)
		parry_ring.scale = parry_ring.scale.lerp(Vector2.ONE, minf(1.0, delta * 14.0))
		shield_sprite.modulate = Color(1.4, 1.25, 0.6, 1.0)
		if _parry_timer <= 0.0:
			_block_timer = 0.22
	elif _block_timer > 0.0:
		_block_timer = maxf(0.0, _block_timer - delta)
		parry_ring.visible = true
		parry_ring.color = Color(0.55, 0.8, 1.0, 0.3)
		shield_sprite.modulate = Color(0.85, 0.95, 1.25, 1.0)
		if _block_timer <= 0.0:
			parry_ring.visible = false
			shield_sprite.modulate = Color.WHITE
			_update_facing_visuals()
	else:
		if _spin_timer <= 0.0:
			parry_ring.visible = false
		shield_sprite.modulate = Color.WHITE

	if _dash_timer > 0.0:
		_dash_timer = maxf(0.0, _dash_timer - delta)
		if _dash_timer <= 0.0:
			visual_pivot.rotation = 0.0


func _process_active_hitboxes(delta: float) -> void:
	if _parry_timer > 0.0:
		for area: Area2D in parry_area.get_overlapping_areas():
			if area.has_method("reflect"):
				area.reflect(self)

	if _attack_timer > 0.0:
		_attack_timer = maxf(0.0, _attack_timer - delta)
		var progress: float = 1.0 - (_attack_timer / 0.16)
		weapon_pivot.rotation = _attack_base_angle + lerpf(-1.55, 1.55, clampf(progress, 0.0, 1.0))

		for body: Node2D in sword_hitbox.get_overlapping_bodies():
			var eid: int = body.get_instance_id()
			if _sword_hit_ids.has(eid):
				continue
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				_sword_hit_ids.append(eid)
				body.take_damage(GameState.get_sword_damage(), global_position, 120.0, false, 0.0)
				GameState.add_royal_gauge(12.0)

		if _attack_timer <= 0.0:
			sword_hitbox.monitoring = false
			slash_arc.visible = false
			weapon_pivot.rotation = 0.0
			_update_facing_visuals()

	if _spin_timer > 0.0:
		_spin_timer = maxf(0.0, _spin_timer - delta)
		var spin_progress: float = 1.0 - (_spin_timer / 0.22)
		weapon_pivot.rotation = spin_progress * TAU
		parry_ring.visible = true
		parry_ring.color = Color(1.0, 0.85, 0.25, 0.5)
		parry_ring.scale = Vector2(2.3, 2.3)

		var spin_dmg: int = int(round(45.0 * GameState.get_damage_multiplier()))
		for body: Node2D in spin_hitbox.get_overlapping_bodies():
			var eid: int = body.get_instance_id()
			if _spin_hit_ids.has(eid):
				continue
			if body.is_in_group("enemies") and body.has_method("take_damage"):
				_spin_hit_ids.append(eid)
				body.take_damage(spin_dmg, global_position, 210.0, false, 0.0)

		if _spin_timer <= 0.0:
			spin_hitbox.monitoring = false
			parry_ring.visible = false
			parry_ring.scale = Vector2.ONE
			weapon_pivot.rotation = 0.0
			_update_facing_visuals()


func _try_attack() -> void:
	if _attack_cd > 0.0 or _attack_timer > 0.0 or _dash_timer > 0.0 or _spin_timer > 0.0:
		return
	_attack_cd = 0.32
	_attack_timer = 0.16
	_sword_hit_ids.clear()
	_attack_base_angle = facing_dir.angle()

	sword_hitbox.position = facing_dir * 14.0
	sword_hitbox.monitoring = true

	slash_arc.visible = true
	slash_arc.rotation = _attack_base_angle
	slash_arc.default_color = Color(1.0, 0.96, 0.72, 0.9)
	AudioManager.play_slash()


func _try_parry_bounce() -> void:
	if _parry_cd > 0.0 or _parry_timer > 0.0 or _block_timer > 0.0 or _dash_timer > 0.0 or _spin_timer > 0.0:
		return
	_parry_cd = 0.70
	_parry_timer = 0.30
	_block_timer = 0.0
	parry_ring.scale = Vector2(1.25, 1.25)
	shield_pivot.position = facing_dir * 8.0
	AudioManager.play_shield_block()


func _try_dash(input_vec: Vector2) -> void:
	if _dash_cd > 0.0 or _dash_timer > 0.0:
		return
	_dash_cd = 0.90
	_dash_timer = 0.20
	_invuln_timer = maxf(_invuln_timer, 0.25)
	_dash_dir = input_vec.normalized() if input_vec.length_squared() > 0.01 else facing_dir
	dash_particles.restart()
	dash_particles.emitting = true
	AudioManager.play_dash()


func _try_spin_slash() -> void:
	if not GameState.spin_slash_unlocked:
		GameState.show_toast("Rebuild The Forge to unlock Spin Slash!")
		return
	if _spin_cd > 0.0 or _spin_timer > 0.0 or _dash_timer > 0.0:
		return
	if not GameState.spend_royal_gauge(40.0):
		GameState.show_toast("Need 40 Royal Gauge for Spin Slash!")
		return
	_spin_cd = 1.40
	_spin_timer = 0.22
	_spin_hit_ids.clear()
	spin_hitbox.monitoring = true
	AudioManager.play_spin_slash()
	GameState.request_camera_shake(3.0, 0.12)


func _try_use_potion() -> void:
	if GameState.flask_count <= 0:
		GameState.show_toast("No Harvest Flasks left!")
		return
	if GameState.is_safe_zone and GameState.hp >= GameState.max_hp:
		GameState.show_toast("HP is already full!")
		return
	if GameState.consume_flask():
		AudioManager.play_potion()
		_spawn_floating_text("+50 HP & BUFF!", Color(0.45, 1.0, 0.55, 1.0), 1.0)


func _refresh_equipment_visuals() -> void:
	var tex: Texture2D = SWORD_TEXTURES.get(GameState.sword_level, SWORD_TEXTURES[1])
	weapon_sprite.texture = tex
	shield_sprite.texture = SHIELD_UPGRADED_TEX if GameState.shield_upgraded else SHIELD_BASIC_TEX


func _update_facing_visuals() -> void:
	body_sprite.flip_h = facing_left
	if facing_left:
		weapon_pivot.position = Vector2(-6.0, 1.0)
		weapon_sprite.flip_h = true
		weapon_sprite.rotation = -0.25
		if _parry_timer <= 0.0 and _block_timer <= 0.0:
			shield_pivot.position = Vector2(6.0, 2.0)
		shield_sprite.flip_h = true
	else:
		weapon_pivot.position = Vector2(6.0, 1.0)
		weapon_sprite.flip_h = false
		weapon_sprite.rotation = 0.25
		if _parry_timer <= 0.0 and _block_timer <= 0.0:
			shield_pivot.position = Vector2(-6.0, 2.0)
		shield_sprite.flip_h = false


func _animate_movement(input_vec: Vector2, delta: float) -> void:
	if _dash_timer > 0.0:
		var dir_sign: float = -1.0 if _dash_dir.x < 0.0 else 1.0
		visual_pivot.rotation += dir_sign * delta * 28.0
		visual_pivot.scale = Vector2(1.12, 0.88)
		return

	if input_vec.length_squared() > 0.01:
		_walk_time += delta * 14.0
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.26
			AudioManager.play_footstep()
		var bob: float = absf(sin(_walk_time))
		visual_pivot.position.y = -bob * 2.2
		visual_pivot.scale = Vector2(1.0 - bob * 0.06, 1.0 + bob * 0.07)
		visual_pivot.rotation = sin(_walk_time) * 0.06
		if _attack_timer <= 0.0 and _spin_timer <= 0.0:
			weapon_pivot.position.y = 1.0 - bob * 0.8
		if _parry_timer <= 0.0 and _block_timer <= 0.0:
			shield_pivot.position.y = 2.0 + bob * 0.5
	else:
		_walk_time = 0.0
		visual_pivot.position.y = lerpf(visual_pivot.position.y, 0.0, minf(1.0, delta * 18.0))
		visual_pivot.scale = visual_pivot.scale.lerp(Vector2.ONE, minf(1.0, delta * 18.0))
		visual_pivot.rotation = lerpf(visual_pivot.rotation, 0.0, minf(1.0, delta * 18.0))
		if _attack_timer <= 0.0 and _spin_timer <= 0.0:
			weapon_pivot.position.y = 1.0
		if _parry_timer <= 0.0 and _block_timer <= 0.0:
			shield_pivot.position.y = 2.0


func _refresh_nearest_interactable() -> void:
	if GameState.is_sleeping or GameState.is_ui_open:
		_current_interactable = null
		prompt_label.visible = false
		return

	var best_target: Node = null
	var best_dist: float = INF

	for area: Area2D in interact_area.get_overlapping_areas():
		var candidate: Node = _resolve_interactable(area)
		if candidate == null:
			continue
		var prompt: String = str(candidate.get_prompt_text())
		if prompt.is_empty():
			continue
		var dist: float = global_position.distance_squared_to(area.global_position)
		if dist < best_dist:
			best_dist = dist
			best_target = candidate

	_current_interactable = best_target
	if _current_interactable != null:
		prompt_label.text = str(_current_interactable.get_prompt_text())
		prompt_label.visible = true
	else:
		prompt_label.visible = false


func _resolve_interactable(area: Area2D) -> Node:
	if area.has_method("interact") and area.has_method("get_prompt_text"):
		return area
	var parent_node: Node = area.get_parent()
	if parent_node != null and parent_node.has_method("interact") and parent_node.has_method("get_prompt_text"):
		return parent_node
	return null


func _on_camera_shake_requested(intensity: float, duration: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)


func _spawn_floating_text(txt: String, col: Color, scl: float) -> void:
	if get_parent() == null:
		return
	var popup := FLOATING_TEXT_SCENE.instantiate() as Node2D
	popup.global_position = global_position + Vector2(0, -14)
	get_parent().add_child(popup)
	popup.setup(txt, col, scl)
