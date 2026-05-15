extends AudioStreamPlayer

const STREAM_1: AudioStream = preload("res://core/assets/audio/background/measure_pad_1.wav")
const STREAM_2: AudioStream = preload("res://core/assets/audio/background/measure_pad_2.wav")
const STREAM_3: AudioStream = preload("res://core/assets/audio/background/measure_pad_3.wav")
const STREAM_4: AudioStream = preload("res://core/assets/audio/background/measure_pad_4.wav")

var is_playing: bool = false

func _ready() -> void:
	var randomizer := stream as AudioStreamRandomizer
	if randomizer != null:
		for i: int in range(randomizer.streams_count):
			randomizer.get_stream(i)
	Playback.started.connect(_on_playback_started)
	Playback.stopped.connect(_on_playback_stopped)
	Playback.tick_advanced.connect(_on_tick_advanced)

func _process(delta: float) -> void:
	if not is_playing and volume_db > -64.0:
		volume_db -= 0.2

func _on_playback_started() -> void:
	volume_db = -18.0
	await get_tree().process_frame
	play()
	is_playing = true

func _on_playback_stopped() -> void:
	is_playing = false

func _on_tick_advanced(tick: int) -> void:
	if tick == 0:
		play()
