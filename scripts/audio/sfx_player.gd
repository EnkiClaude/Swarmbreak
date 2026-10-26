class_name SfxPlayer
extends Node
## Plays sound effects through a fixed pool of voices, round-robin, so combat
## never creates players. Pitch is randomized slightly so repeats don't drone.

var _config: AudioConfig
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func setup(config: AudioConfig) -> void:
	_config = config
	_rng.randomize()
	for i in config.voices:
		var voice := AudioStreamPlayer.new()
		voice.name = "Voice%d" % i
		add_child(voice)
		_voices.append(voice)


func play(stream: AudioStream, volume_db: float) -> void:
	if _voices.is_empty():
		return
	var voice := _voices[_next]
	_next = (_next + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = volume_db
	voice.pitch_scale = 1.0 + _rng.randf_range(-_config.pitch_variance, _config.pitch_variance)
	voice.play()
