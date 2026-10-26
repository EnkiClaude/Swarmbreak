class_name SfxBank
extends RefCounted
## Placeholder sound effects synthesized at startup, so the game has sound
## before real assets exist. Each recipe is a few lines of oscillator and
## noise math. Replace with recorded sounds later; SfxPlayer won't change.

const MIX_RATE := 22050

var bolt_fire: AudioStreamWAV
var bolt_burst: AudioStreamWAV
var nova: AudioStreamWAV
var kill: AudioStreamWAV
var lure: AudioStreamWAV
var dodge: AudioStreamWAV
var hurt: AudioStreamWAV
var denied: AudioStreamWAV
var level_up: AudioStreamWAV
var pickup: AudioStreamWAV

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 7
	bolt_fire = _make(_bolt_fire())
	bolt_burst = _make(_bolt_burst())
	nova = _make(_nova())
	kill = _make(_kill())
	lure = _make(_lure())
	dodge = _make(_dodge())
	hurt = _make(_hurt())
	denied = _make(_denied())
	level_up = _make(_level_up())
	pickup = _make(_pickup())


## Short descending zap.
func _bolt_fire() -> PackedFloat32Array:
	var out := _buffer(0.08)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / out.size()
		phase += lerpf(1500.0, 450.0, t) / MIX_RATE
		var square := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		out[i] = square * 0.22 * pow(1.0 - t, 2.0)
	return out


## Noisy pop with a low thump under it.
func _bolt_burst() -> PackedFloat32Array:
	var out := _buffer(0.2)
	var phase := 0.0
	var lowpassed := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		lowpassed = lerpf(lowpassed, _rng.randf_range(-1.0, 1.0), 0.35)
		phase += lerpf(170.0, 55.0, t / 0.2) / MIX_RATE
		out[i] = lowpassed * exp(-t * 28.0) * 0.6 + sin(phase * TAU) * exp(-t * 18.0) * 0.55
	return out


## Deep falling boom with a whoosh of air.
func _nova() -> PackedFloat32Array:
	var length := 0.7
	var out := _buffer(length)
	var phase := 0.0
	var lowpassed := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		phase += lerpf(110.0, 32.0, minf(t / 0.45, 1.0)) / MIX_RATE
		var boom := sin(phase * TAU) * exp(-t * 4.5)
		lowpassed = lerpf(lowpassed, _rng.randf_range(-1.0, 1.0), 0.12)
		var whoosh := lowpassed * sin(PI * t / length) * exp(-t * 3.0)
		var crack := _rng.randf_range(-1.0, 1.0) * exp(-t * 60.0)
		out[i] = clampf(boom * 0.95 + whoosh * 0.9 + crack * 0.5, -1.0, 1.0)
	return out


## Wet crunch for enemies dying.
func _kill() -> PackedFloat32Array:
	var out := _buffer(0.14)
	var lowpassed := 0.0
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		lowpassed = lerpf(lowpassed, _rng.randf_range(-1.0, 1.0), 0.5)
		phase += lerpf(240.0, 90.0, t / 0.14) / MIX_RATE
		var grit := 1.0 if _rng.randf() < 0.5 else -1.0
		out[i] = (lowpassed * 0.6 + grit * 0.15) * exp(-t * 30.0) \
				+ sin(phase * TAU) * exp(-t * 35.0) * 0.5
	return out


## Rising war horn: two detuned saws swelling upward.
func _lure() -> PackedFloat32Array:
	var length := 0.9
	var out := _buffer(length)
	var a := 0.0
	var b := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		var f := lerpf(110.0, 165.0, minf(t / 0.5, 1.0))
		a += f / MIX_RATE
		b += f * 1.505 / MIX_RATE
		var saw := (fmod(a, 1.0) * 2.0 - 1.0) * 0.5 + (fmod(b, 1.0) * 2.0 - 1.0) * 0.35
		var env := minf(t / 0.12, 1.0) * exp(-maxf(t - 0.45, 0.0) * 6.0)
		out[i] = saw * env * 0.55
	return out


## Quick airy whoosh.
func _dodge() -> PackedFloat32Array:
	var length := 0.22
	var out := _buffer(length)
	var lowpassed := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		lowpassed = lerpf(lowpassed, _rng.randf_range(-1.0, 1.0), lerpf(0.05, 0.4, t / length))
		out[i] = lowpassed * sin(PI * t / length) * 0.9
	return out


## Dull body thud.
func _hurt() -> PackedFloat32Array:
	var out := _buffer(0.18)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		phase += lerpf(140.0, 60.0, t / 0.18) / MIX_RATE
		out[i] = sin(phase * TAU) * exp(-t * 22.0) * 0.8 \
				+ _rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.3
	return out


## Two short low blips: "not enough mana".
func _denied() -> PackedFloat32Array:
	var out := _buffer(0.2)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / MIX_RATE
		phase += 180.0 / MIX_RATE
		var gate := 1.0 if fmod(t, 0.1) < 0.06 else 0.0
		out[i] = (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) * gate * 0.18
	return out


## Rising major arpeggio.
func _level_up() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var step := 0.09
	var out := _buffer(step * notes.size() + 0.35)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var sample := 0.0
		for n in notes.size():
			var start: float = n * step
			if t >= start:
				var local := t - start
				sample += sin(TAU * float(notes[n]) * local) * exp(-local * 5.0) * 0.18
		out[i] = sample
	return out


## Bright two-note bling.
func _pickup() -> PackedFloat32Array:
	var out := _buffer(0.22)
	for i in out.size():
		var t := float(i) / MIX_RATE
		var f := 1318.5 if t < 0.06 else 1760.0
		out[i] = sin(TAU * f * t) * exp(-t * 14.0) * 0.3
	return out


func _buffer(seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * MIX_RATE))
	out.fill(0.0)
	return out


static func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
