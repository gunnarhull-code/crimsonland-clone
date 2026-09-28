extends Node
## Minimal procedural sound cues - no external audio assets, matching the
## "very simple sound" MVP constraint. Self-contained Autoload: only plays
## sound, never reaches into other systems.


func _beep(freq: float, duration: float, volume_db: float = -8.0) -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	add_child(p)
	p.play()
	var playback: AudioStreamGeneratorPlayback = p.get_stream_playback()
	var frames := int(stream.mix_rate * duration)
	for i in frames:
		var t := float(i) / stream.mix_rate
		var envelope := 1.0 - (float(i) / frames)
		var sample := sin(t * freq * TAU) * envelope
		playback.push_frame(Vector2(sample, sample))
	p.finished.connect(p.queue_free)


func play_fire() -> void:
	_beep(520.0, 0.05, -12.0)


func play_hit() -> void:
	_beep(220.0, 0.04, -10.0)


func play_death() -> void:
	_beep(140.0, 0.12, -8.0)


func play_player_hit() -> void:
	_beep(90.0, 0.15, -6.0)


func play_levelup() -> void:
	_beep(880.0, 0.25, -8.0)


func play_nest_destroyed() -> void:
	_beep(160.0, 0.2, -6.0)


func play_pickup() -> void:
	_beep(660.0, 0.06, -10.0)
