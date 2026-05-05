extends Node

# D dorian: D E F G A B C D
const NOTE_MAP: Dictionary = {
	&"d": 62,  # D4 — root
	&"f": 65,  # F4 — minor third
	&"a": 69,  # A4 — fifth
	&"c": 72,  # C5 — minor seventh
}

const OSC: int = 0
const NOTE_HOLD: float = 0.6  # seconds before triggering note-off (release tail plays after)

var _amy: Amy = null

func _ready() -> void:
	_amy = Amy.new()
	_amy.startup_bleep = false
	add_child(_amy)
	await get_tree().process_frame
	# Reverb: level, liveness (0-1, higher = longer decay), damping, xover_hz
	_amy.send({"reverb": [0.7, 0.93, 0.15, 2500.0]})
	# Chorus: level, max_delay_samples, lfo_hz, depth
	_amy.send({"chorus": [0.35, 320.0, 0.4, 0.65]})
	Playback.stopped.connect(_on_playback_stopped)

func register_detector(detector: Detector) -> void:
	detector.orb_passed.connect(_on_orb_passed)

func _on_orb_passed(orb_id: StringName, _texture: Texture2D) -> void:
	if not NOTE_MAP.has(orb_id):
		return
	var note: int = NOTE_MAP[orb_id]
	_amy.send({
		"osc": OSC,
		"wave": Amy.TRIANGLE,
		"note": note,
		"vel": 0.75,
		# 4-pole LPF gives a warmer, crunchier roll-off than 2-pole
		"filter_type": Amy.FILTER_LPF24,
		"filter_freq": 700.0,
		"resonance": 4.0,
		# Envelope: [attack_ms, peak, sustain_ms, sustain_level, release_ms, 0]
		# Last pair triggers on note-off
		"bp0": [15, 1.0, 500, 0.6, 1800, 0],
	})
	# Hold the note briefly then release — the 1800ms tail rings out through the reverb
	get_tree().create_timer(NOTE_HOLD).timeout.connect(
		func(): _amy.send({"osc": OSC, "vel": 0})
	)

func _on_playback_stopped() -> void:
	if _amy != null:
		_amy.panic()
