extends RefCounted
## Tiny synthesised sound effects.
##
## Every sound is rendered once into an AudioStreamWAV at startup, so playing one
## is just handing a pre-built stream to a free AudioStreamPlayer. No audio files
## to ship, and no per-frame work.

const MIX_RATE := 22050

var _players: Array = []
var _streams: Dictionary = {}
var _muted := false


func _init(parent: Node) -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -6.0
		parent.add_child(p)
		_players.append(p)

	_streams["laser"] = _make_tone(0.07, 1400.0, 520.0, 0.22, 0.0)
	_streams["enemy"] = _make_tone(0.10, 520.0, 200.0, 0.20, 0.25)
	_streams["hit"] = _make_tone(0.05, 380.0, 180.0, 0.22, 0.10)
	_streams["boom"] = _make_tone(0.45, 900.0, 90.0, 0.30, 0.95)
	_streams["bigboom"] = _make_tone(0.90, 700.0, 50.0, 0.38, 1.0)
	_streams["hurt"] = _make_tone(0.32, 220.0, 60.0, 0.30, 0.60)
	_streams["wave"] = _make_tone(0.22, 600.0, 1000.0, 0.16, 0.0)
	_streams["over"] = _make_tone(1.00, 300.0, 50.0, 0.30, 0.15)


func play(sound: String) -> void:
	if _muted:
		return
	var stream: AudioStream = _streams.get(sound, null)
	if stream == null:
		return
	for p in _players:
		var player: AudioStreamPlayer = p
		if not player.playing:
			player.stream = stream
			player.play()
			return


func toggle() -> bool:
	_muted = not _muted
	return _muted


func is_muted() -> bool:
	return _muted


## Renders a short one-shot: a tone sweeping f0 -> f1, blended with white noise
## by `noise_mix`, with a squared-off decay envelope.
func _make_tone(dur: float, f0: float, f1: float, amp: float, noise_mix: float) -> AudioStreamWAV:
	var count := int(MIX_RATE * dur)
	if count < 2:
		count = 2

	var data := PackedByteArray()
	data.resize(count * 2)

	var phase := 0.0
	for i in count:
		var u := float(i) / float(count)
		var f := lerpf(f0, f1, u)
		phase += TAU * f / float(MIX_RATE)
		var tone := sin(phase)
		var nz := randf() * 2.0 - 1.0
		var env := (1.0 - u) * (1.0 - u)
		var s := lerpf(tone, nz, noise_mix) * env * amp
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
