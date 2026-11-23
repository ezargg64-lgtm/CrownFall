extends Node

## Pooled SFX manager wired to Kenney RPG Audio .ogg clips without clipping.

const POOL_SIZE: int = 12

const SFX_FOOTSTEPS: Array[AudioStream] = [
	preload("res://assets/audio/footstep00.ogg"),
	preload("res://assets/audio/footstep01.ogg"),
	preload("res://assets/audio/footstep02.ogg"),
	preload("res://assets/audio/footstep03.ogg"),
	preload("res://assets/audio/footstep04.ogg"),
	preload("res://assets/audio/footstep05.ogg"),
	preload("res://assets/audio/footstep06.ogg"),
	preload("res://assets/audio/footstep07.ogg"),
	preload("res://assets/audio/footstep08.ogg"),
	preload("res://assets/audio/footstep09.ogg"),
]

const SFX_SLASH: Array[AudioStream] = [
	preload("res://assets/audio/knifeSlice.ogg"),
	preload("res://assets/audio/knifeSlice2.ogg"),
]

const SFX_SPIN_DRAW: Array[AudioStream] = [
	preload("res://assets/audio/drawKnife1.ogg"),
	preload("res://assets/audio/drawKnife2.ogg"),
]

const SFX_PARRY_RING: Array[AudioStream] = [
	preload("res://assets/audio/metalPot1.ogg"),
	preload("res://assets/audio/metalPot2.ogg"),
	preload("res://assets/audio/metalPot3.ogg"),
]

const SFX_METAL_CLICK: AudioStream = preload("res://assets/audio/metalClick.ogg")
const SFX_METAL_LATCH: AudioStream = preload("res://assets/audio/metalLatch.ogg")

const SFX_DASH: Array[AudioStream] = [
	preload("res://assets/audio/cloth1.ogg"),
	preload("res://assets/audio/cloth2.ogg"),
	preload("res://assets/audio/cloth3.ogg"),
	preload("res://assets/audio/cloth4.ogg"),
]

const SFX_HIT: AudioStream = preload("res://assets/audio/chop.ogg")
const SFX_PLAYER_HURT: AudioStream = preload("res://assets/audio/dropLeather.ogg")
const SFX_PLANT: AudioStream = preload("res://assets/audio/clothBelt.ogg")
const SFX_WATER: AudioStream = preload("res://assets/audio/clothBelt2.ogg")
const SFX_HARVEST: AudioStream = preload("res://assets/audio/handleSmallLeather.ogg")
const SFX_POTION: AudioStream = preload("res://assets/audio/handleSmallLeather2.ogg")

const SFX_COINS: Array[AudioStream] = [
	preload("res://assets/audio/handleCoins.ogg"),
	preload("res://assets/audio/handleCoins2.ogg"),
]

const SFX_CREAK: Array[AudioStream] = [
	preload("res://assets/audio/creak1.ogg"),
	preload("res://assets/audio/creak2.ogg"),
	preload("res://assets/audio/creak3.ogg"),
]

const SFX_GATES: Array[AudioStream] = [
	preload("res://assets/audio/doorOpen_1.ogg"),
	preload("res://assets/audio/doorOpen_2.ogg"),
]

const SFX_UI_OPEN: AudioStream = preload("res://assets/audio/bookOpen.ogg")
const SFX_UI_CLOSE: AudioStream = preload("res://assets/audio/bookClose.ogg")

const SFX_UI_FLIP: Array[AudioStream] = [
	preload("res://assets/audio/bookFlip1.ogg"),
	preload("res://assets/audio/bookFlip2.ogg"),
	preload("res://assets/audio/bookFlip3.ogg"),
]

const SFX_UI_CONFIRM: Array[AudioStream] = [
	preload("res://assets/audio/bookPlace1.ogg"),
	preload("res://assets/audio/bookPlace2.ogg"),
	preload("res://assets/audio/bookPlace3.ogg"),
]

var _pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0


func _ready() -> void:
	# Keep UI SFX audible while the tree is paused (Title / Pause / Victory menus).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_pool.append(player)


func _play(stream: AudioStream, volume_db: float = -6.0, pitch_min: float = 0.95, pitch_max: float = 1.05) -> void:
	if stream == null or _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.play()


func _pick(list: Array[AudioStream]) -> AudioStream:
	if list.is_empty():
		return null
	return list[randi() % list.size()]


func play_footstep() -> void:
	_play(_pick(SFX_FOOTSTEPS), -15.0, 0.92, 1.08)


func play_slash() -> void:
	_play(_pick(SFX_SLASH), -6.0, 0.94, 1.08)


func play_spin_slash() -> void:
	_play(_pick(SFX_SPIN_DRAW), -5.0, 0.96, 1.04)
	_play(SFX_SLASH[1], -5.0, 0.85, 0.92)


func play_parry_bounce() -> void:
	_play(_pick(SFX_PARRY_RING), -3.5, 1.02, 1.12)
	_play(SFX_METAL_CLICK, -6.0, 1.0, 1.08)


func play_shield_block() -> void:
	_play(SFX_METAL_CLICK, -7.0, 0.95, 1.05)


func play_dash() -> void:
	_play(_pick(SFX_DASH), -7.0, 0.95, 1.1)


func play_hit() -> void:
	_play(SFX_HIT, -6.5, 0.9, 1.1)


func play_player_hurt() -> void:
	_play(SFX_PLAYER_HURT, -4.5, 0.92, 1.04)


func play_plant() -> void:
	_play(SFX_PLANT, -7.0, 0.96, 1.06)


func play_water() -> void:
	_play(SFX_WATER, -7.0, 0.96, 1.06)


func play_harvest() -> void:
	_play(SFX_HARVEST, -6.0, 0.98, 1.1)


func play_coins() -> void:
	_play(_pick(SFX_COINS), -5.5, 0.96, 1.06)


func play_rebuild() -> void:
	_play(SFX_HIT, -5.0, 0.9, 1.0)
	_play(_pick(SFX_CREAK), -6.0, 0.95, 1.05)
	_play(SFX_METAL_LATCH, -6.0, 0.95, 1.05)


func play_gate() -> void:
	_play(_pick(SFX_GATES), -7.0, 0.96, 1.04)


func play_ui_open() -> void:
	_play(SFX_UI_OPEN, -6.5, 0.98, 1.04)


func play_ui_close() -> void:
	_play(SFX_UI_CLOSE, -6.5, 0.98, 1.04)


func play_ui_move() -> void:
	_play(_pick(SFX_UI_FLIP), -10.0, 0.98, 1.06)


func play_ui_confirm() -> void:
	_play(_pick(SFX_UI_CONFIRM), -7.5, 0.96, 1.04)


func play_potion() -> void:
	_play(SFX_POTION, -5.0, 0.98, 1.06)
