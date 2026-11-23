extends Node2D

## Shipping Crate: sells harvested crops or monster/blight shards for Gold from Day 1.

@onready var crate_sprite: Sprite2D = $CrateSprite
@onready var coin_particles: CPUParticles2D = $CoinParticles

const TEX_CRATE_CLOSED: Texture2D = preload("res://assets/tiles/tiny_dungeon_tile_0089.png")
const TEX_CRATE_OPEN: Texture2D = preload("res://assets/tiles/tiny_dungeon_tile_0091.png")

var _open_timer: float = 0.0


func _process(delta: float) -> void:
	if _open_timer > 0.0:
		_open_timer -= delta
		if _open_timer <= 0.0:
			crate_sprite.texture = TEX_CRATE_CLOSED


func get_prompt_text() -> String:
	var crop_val: int = GameState.get_pending_crop_sale_value()
	if crop_val > 0:
		return "[E] Sell Crops (+%dG)" % crop_val
	var shard_val: int = GameState.get_pending_shard_sale_value()
	if shard_val > 0:
		return "[E] Sell Shards (+%dG)" % shard_val
	return "[E] Shipping Crate"


func interact(_player: Node2D) -> void:
	var result: Dictionary = GameState.sell_goods_at_crate()
	var earned: int = int(result.get("gold", 0))
	if earned <= 0:
		GameState.show_toast("Shipping Crate: Harvest crops or gather shards to sell!")
		return

	crate_sprite.texture = TEX_CRATE_OPEN
	_open_timer = 0.45
	AudioManager.play_coins()
	coin_particles.restart()
	coin_particles.emitting = true

	var kind: String = str(result.get("kind", "crops"))
	var count: int = int(result.get("count", 0))
	GameState.show_toast("Sold %d %s for +%dG!" % [count, kind, earned])
