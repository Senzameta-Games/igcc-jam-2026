extends Node2D

@onready var _pad: AudioStreamPlayer = $MeasurePad
@onready var _drums: AudioStreamPlayer = $MeasureDrums

var _playing: bool = false
var _drums_tween: Tween = null

func _ready() -> void:
	_touch_streams(_pad)
	_touch_streams(_drums)
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	Playback.tick_advanced.connect(_on_tick_advanced)

func _process(_delta: float) -> void:
	if not _playing:
		_fade_out(_pad)
		_fade_out(_drums)

func _touch_streams(player: AudioStreamPlayer) -> void:
	var randomizer := player.stream as AudioStreamRandomizer
	if randomizer != null:
		for i: int in range(randomizer.streams_count):
			randomizer.get_stream(i)

func _fade_out(player: AudioStreamPlayer) -> void:
	if player.volume_db > -64.0:
		player.volume_db -= 0.2

func _on_playback_started() -> void:
	_pad.volume_db = -18.0
	_drums.volume_db = -18.0
	await get_tree().process_frame
	_pad.play()
	_drums.play()
	_playing = true
	if _drums_tween != null and _drums_tween.is_running():
		_drums_tween.kill()
	_drums_tween = create_tween()
	_drums_tween.tween_property(_drums, "volume_db", -8.0, 1.0) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _on_playback_stopped() -> void:
	_playing = false

func _on_tick_advanced(tick: int) -> void:
	if tick == 0:
		_pad.play()
		_drums.play()
