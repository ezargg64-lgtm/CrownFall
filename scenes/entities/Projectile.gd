extends Area2D

## Wall-ricochet and shield-bounceable energy orb projectile.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/FloatingText.tscn")

@onready var outer_glow: Polygon2D = $OuterGlow
@onready var core: Polygon2D = $Core
@onready var trail_particles: CPUParticles2D = $TrailParticles

var direction: Vector2 = Vector2.RIGHT
var speed: float = 115.0
var damage: int = 12
var bounces_left: int = 2
var is_reflected: bool = false
var shooter: Node2D = null
var lifetime: float = 6.0
## Dead-Man's Volley: how many times the boss may bat this orb back, and how many times it already has.
var max_volleys: int = 0
var volley_count: int = 0

const MAX_RALLY_SPEED: float = 380.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func setup(start_pos: Vector2, dir: Vector2, spd: float, dmg: int, orb_color: Color, source: Node2D) -> void:
	global_position = start_pos
	direction = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	speed = spd
	damage = dmg
	shooter = source
	is_reflected = false
	collision_mask = 2
	_apply_color(orb_color)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return

	var step: float = speed * delta
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(
		global_position - direction * 2.0,
		global_position + direction * (step + 5.0),
		1
	)
	ray.exclude = [get_rid()]
	var hit: Dictionary = space_state.intersect_ray(ray)

	if not hit.is_empty():
		var hit_normal: Vector2 = hit["normal"]
		if bounces_left > 0:
			bounces_left -= 1
			direction = direction.bounce(hit_normal).normalized()
			global_position = (hit["position"] as Vector2) + hit_normal * 4.5
		else:
			if is_reflected and GameState.shield_upgraded:
				_trigger_aoe_explosion(null)
			queue_free()
		return

	global_position += direction * step


func reflect(parrier: Node2D) -> void:
	if is_reflected:
		return
	is_reflected = true
	if is_instance_valid(shooter):
		var to_shooter: Vector2 = shooter.global_position - global_position
		if to_shooter.length_squared() > 1.0:
			direction = to_shooter.normalized()
		else:
			direction = -direction
	else:
		direction = -direction

	speed = minf(speed * (1.25 if volley_count > 0 else 1.8), MAX_RALLY_SPEED)
	damage = 35
	bounces_left = 2
	lifetime = 4.5
	collision_mask = 8
	_apply_color(Color(1.0, 0.9, 0.25, 1.0))

	GameState.total_projectiles_bounced += 1
	GameState.add_royal_gauge(25.0)
	AudioManager.play_parry_bounce()
	GameState.trigger_hit_stop(0.05)
	GameState.request_camera_shake(4.5, 0.14)

	if parrier != null and parrier.has_method("on_parry_success"):
		parrier.on_parry_success()

	_spawn_floating_text("BOUNCE BACK!", Color(1.0, 0.92, 0.25, 1.0), 1.1)


func _on_body_entered(body: Node2D) -> void:
	if not is_reflected and body.is_in_group("player"):
		if body.has_method("is_parry_active") and body.is_parry_active():
			reflect(body)
			return
		if body.has_method("is_block_active") and body.is_block_active():
			AudioManager.play_shield_block()
			_spawn_floating_text("BLOCK", Color(0.65, 0.85, 1.0, 1.0), 0.95)
			GameState.request_camera_shake(1.5, 0.08)
			queue_free()
			return
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
		return

	if is_reflected and body.is_in_group("enemies"):
		# Bosses decide for themselves: bat the orb back (volley) or take the guard-breaking hit.
		if body.has_method("on_reflected_orb"):
			if body.on_reflected_orb(self):
				return
			if GameState.shield_upgraded:
				_trigger_aoe_explosion(body)
			queue_free()
			return
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position, 140.0, true, 1.0)
		if GameState.shield_upgraded:
			_trigger_aoe_explosion(body)
		queue_free()


## Called by the boss during Dead-Man's Volley: re-aims the orb at the player, faster each rally.
func volley_back(batter: Node2D, rally_dmg: int) -> void:
	is_reflected = false
	volley_count += 1
	shooter = batter
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var target: Node2D = players[0] as Node2D
		var to_player: Vector2 = target.global_position - global_position
		direction = to_player.normalized() if to_player.length_squared() > 1.0 else -direction
	else:
		direction = -direction
	speed = minf(speed * 1.25, MAX_RALLY_SPEED)
	damage = rally_dmg
	bounces_left = 1
	lifetime = 4.5
	collision_mask = 2
	global_position += direction * 6.0
	_apply_color(Color(0.62, 0.22, 0.95, 1.0).lerp(Color(1.0, 0.25, 0.45, 1.0), clampf(float(volley_count) / 3.0, 0.0, 1.0)))
	_spawn_floating_text("VOLLEY x%d!" % volley_count, Color(0.85, 0.5, 1.0, 1.0), 1.0)


func _trigger_aoe_explosion(direct_target: Node2D) -> void:
	var blast := Polygon2D.new()
	blast.polygon = PackedVector2Array([
		Vector2(18, 0), Vector2(13, 13), Vector2(0, 18), Vector2(-13, 13),
		Vector2(-18, 0), Vector2(-13, -13), Vector2(0, -18), Vector2(13, -13),
	])
	blast.color = Color(1.0, 0.82, 0.25, 0.72)
	blast.global_position = global_position
	blast.z_index = 25
	get_parent().add_child(blast)
	var tw: Tween = blast.create_tween()
	tw.set_parallel(true)
	tw.tween_property(blast, "scale", Vector2(2.8, 2.8), 0.22)
	tw.tween_property(blast, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(blast.queue_free)

	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy == direct_target or not is_instance_valid(enemy):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node != null and enemy_node.global_position.distance_to(global_position) <= 50.0:
			if enemy_node.has_method("take_damage"):
				enemy_node.take_damage(15, global_position, 120.0, true, 0.6)


func _apply_color(orb_color: Color) -> void:
	outer_glow.color = Color(orb_color.r, orb_color.g, orb_color.b, 0.55)
	core.color = orb_color.lightened(0.35)
	trail_particles.color = orb_color


func _spawn_floating_text(txt: String, col: Color, scl: float) -> void:
	if get_parent() == null:
		return
	var popup := FLOATING_TEXT_SCENE.instantiate() as Node2D
	popup.global_position = global_position + Vector2(0, -10)
	get_parent().add_child(popup)
	popup.setup(txt, col, scl)
