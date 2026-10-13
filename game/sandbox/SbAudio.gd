extends Node
## Sandbox sound effects. Not beeps and not MIDI: each effect is a short burst
## of filtered noise plus a pitch-swept body tone, rendered once at startup into
## a sample (AudioStreamWAV) and played from a small pool with random pitch.
## Add a sound by adding a row to SOUNDS.

const RATE := 22050
const POOL := 24

# dur seconds | tone_hz0 -> tone_hz1 with tone amp | noise amp, lowpass
# cutoff 0..1 sliding cut0 -> cut1 (hp = keep the highs instead) | decay
# exponent | shape: "fall" (loud start), "bump" (swell), "rise"
const SOUNDS := {
	"shot":      {"dur": 0.11, "t0": 240.0, "t1": 70.0,  "ta": 0.55, "na": 0.9, "c0": 0.65, "c1": 0.12, "decay": 3.0, "shape": "fall", "gap": 0.02, "vol": -9.0},
	"hit":       {"dur": 0.07, "t0": 420.0, "t1": 160.0, "ta": 0.40, "na": 0.5, "c0": 0.50, "c1": 0.20, "decay": 3.0, "shape": "fall", "gap": 0.04, "vol": -14.0},
	"kill":      {"dur": 0.20, "t0": 230.0, "t1": 60.0,  "ta": 0.60, "na": 0.5, "c0": 0.30, "c1": 0.05, "decay": 2.0, "shape": "fall", "gap": 0.04, "vol": -10.0},
	"explosion": {"dur": 0.55, "t0": 95.0,  "t1": 32.0,  "ta": 0.85, "na": 1.0, "c0": 0.35, "c1": 0.03, "decay": 2.0, "shape": "fall", "gap": 0.05, "vol": -8.0},
	"hurt":      {"dur": 0.24, "t0": 150.0, "t1": 55.0,  "ta": 0.90, "na": 0.3, "c0": 0.20, "c1": 0.05, "decay": 2.0, "shape": "fall", "gap": 0.10, "vol": -6.0},
	"click":     {"dur": 0.04, "t0": 0.0,   "t1": 0.0,   "ta": 0.0,  "na": 0.9, "c0": 0.55, "c1": 0.55, "decay": 4.0, "shape": "fall", "gap": 0.05, "vol": -10.0, "hp": true},
	"beam":      {"dur": 0.40, "t0": 1100.0,"t1": 170.0, "ta": 0.50, "na": 0.4, "c0": 0.60, "c1": 0.20, "decay": 1.5, "shape": "fall", "gap": 0.10, "vol": -8.0},
	"whoosh":    {"dur": 0.38, "t0": 0.0,   "t1": 0.0,   "ta": 0.0,  "na": 1.0, "c0": 0.05, "c1": 0.45, "decay": 1.0, "shape": "bump", "gap": 0.10, "vol": -10.0},
	"refund":    {"dur": 0.09, "t0": 520.0, "t1": 950.0, "ta": 0.50, "na": 0.0, "c0": 0.0,  "c1": 0.0,  "decay": 2.0, "shape": "fall", "gap": 0.05, "vol": -14.0},
	"zap":       {"dur": 0.28, "t0": 1600.0,"t1": 280.0, "ta": 0.35, "na": 0.7, "c0": 0.70, "c1": 0.70, "decay": 2.0, "shape": "fall", "gap": 0.08, "vol": -9.0, "hp": true},
	"hatch":     {"dur": 0.11, "t0": 300.0, "t1": 760.0, "ta": 0.55, "na": 0.1, "c0": 0.30, "c1": 0.30, "decay": 2.0, "shape": "fall", "gap": 0.06, "vol": -12.0},
	"charge":    {"dur": 0.30, "t0": 140.0, "t1": 520.0, "ta": 0.40, "na": 0.15,"c0": 0.20, "c1": 0.30, "decay": 1.0, "shape": "rise", "gap": 0.10, "vol": -14.0},
}

var enabled := true
var master_db := 0.0

var _streams := {}
var _players: Array = []
var _next := 0
var _last := {}


func _ready() -> void:
	for name in SOUNDS:
		_streams[name] = _render(SOUNDS[name], hash(name))
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Play a named effect. `vol_db` is added to the sound's own level.
func play(name: String, vol_db: float = 0.0) -> void:
	if not enabled or not _streams.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var def: Dictionary = SOUNDS[name]
	if now - _last.get(name, -10.0) < def["gap"]:
		return
	_last[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[name]
	p.volume_db = def["vol"] + vol_db + master_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


func _render(def: Dictionary, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(RATE * float(def["dur"]))
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var highpass: bool = def.get("hp", false)
	for i in n:
		var k := float(i) / n
		var env: float
		match def["shape"]:
			"bump":
				env = sin(PI * k)
			"rise":
				env = minf(k * 3.0, 1.0) * (1.0 - k * 0.6)
			_:
				env = pow(1.0 - k, float(def["decay"]))
		env *= minf(float(i) / 40.0, 1.0)   # ~2 ms attack, avoids a click
		var s := 0.0
		if float(def["ta"]) > 0.0:
			phase += TAU * lerpf(float(def["t0"]), float(def["t1"]), k) / RATE
			s += sin(phase) * float(def["ta"])
		if float(def["na"]) > 0.0:
			var white := rng.randf_range(-1.0, 1.0)
			lp += (white - lp) * lerpf(float(def["c0"]), float(def["c1"]), k)
			s += (white - lp if highpass else lp * 2.2) * float(def["na"])
		var v := int(clampf(s * env, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
