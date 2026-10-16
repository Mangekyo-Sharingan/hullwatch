## Deterministic procedural placeholder audio. No asset files; all PCM is generated with a fixed-seed RNG.
class_name ProcAudio
extends RefCounted

const MIX_RATE: int = 22050
const _RNG_SEED: int = 20240617
const _LOOP_CROSSFADE_SECONDS: float = 0.05


static func make_hum(seconds: float = 1.0) -> AudioStreamWAV:
	var total: int = _sample_count(seconds) + _crossfade_samples(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED
	var samples := PackedFloat32Array()
	samples.resize(total)
	var freq_a: float = _snap_freq(55.0, total)
	var freq_b: float = _snap_freq(55.7, total)
	var noise: float = 0.0
	for i: int in total:
		var t: float = float(i) / float(MIX_RATE)
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.02)
		samples[i] = 0.30 * sin(TAU * freq_a * t) + 0.24 * sin(TAU * freq_b * t) + 0.04 * noise
	return _to_wav(_crossfade_loop(samples, _LOOP_CROSSFADE_SECONDS), true)


static func make_fan_loop(seconds: float = 1.0) -> AudioStreamWAV:
	var total: int = _sample_count(seconds) + _crossfade_samples(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED + 1
	var samples := PackedFloat32Array()
	samples.resize(total)
	var freq: float = _snap_freq(118.0, total)
	var filtered: float = 0.0
	for i: int in total:
		var t: float = float(i) / float(MIX_RATE)
		var white: float = rng.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, white, 0.10)
		var hiss: float = white - filtered
		samples[i] = 0.28 * filtered + 0.08 * hiss + 0.10 * sin(TAU * freq * t)
	return _to_wav(_crossfade_loop(samples, _LOOP_CROSSFADE_SECONDS), true)


static func make_click(seconds: float = 0.08) -> AudioStreamWAV:
	var sample_count: int = _sample_count(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED + 2
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var filtered: float = 0.0
	for i: int in sample_count:
		var progress: float = float(i) / float(maxi(sample_count - 1, 1))
		var decay: float = exp(-progress * 9.0)
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.65)
		samples[i] = filtered * decay * 0.7
	return _to_wav(samples, false)


static func make_beep(frequency_hz: float = 880.0, seconds: float = 0.12) -> AudioStreamWAV:
	var sample_count: int = _sample_count(seconds)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var freq: float = _snap_freq(frequency_hz, sample_count)
	for i: int in sample_count:
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(maxi(sample_count - 1, 1))
		samples[i] = 0.35 * sin(TAU * freq * t) * sin(PI * progress)
	return _to_wav(samples, false)


static func make_thunk(seconds: float = 0.25) -> AudioStreamWAV:
	var sample_count: int = _sample_count(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED + 3
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var freq: float = _snap_freq(72.0, sample_count)
	for i: int in sample_count:
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(maxi(sample_count - 1, 1))
		var body: float = sin(TAU * freq * t) * exp(-progress * 6.0)
		var knock: float = rng.randf_range(-1.0, 1.0) * exp(-progress * 18.0)
		samples[i] = body * 0.6 + knock * 0.35
	return _to_wav(samples, false)


static func make_buzz(seconds: float = 0.30) -> AudioStreamWAV:
	var sample_count: int = _sample_count(seconds)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var freq: float = _snap_freq(130.0, sample_count)
	for i: int in sample_count:
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(maxi(sample_count - 1, 1))
		var square: float = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		var edge: float = sin(TAU * freq * 3.0 * t) * 0.25
		var attack: float = minf(progress / 0.05, 1.0)
		var release: float = 1.0 - smoothstep(0.72, 1.0, progress)
		var envelope: float = attack * release * exp(-progress * 2.0)
		samples[i] = (square + edge) * envelope * 0.22
	return _to_wav(samples, false)


static func make_alarm(seconds: float = 1.5) -> AudioStreamWAV:
	var period: float = 0.5
	var periods: int = maxi(roundi(seconds / period), 1)
	var sample_count: int = int(roundf(period * float(periods) * float(MIX_RATE)))
	var period_samples: int = maxi(sample_count / periods, 2)
	sample_count = period_samples * periods
	var half_samples: int = maxi(period_samples / 2, 1)
	var tone_a: float = _snap_freq(660.0, half_samples)
	var tone_b: float = _snap_freq(520.0, half_samples)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	for i: int in sample_count:
		var in_period: int = i % period_samples
		var in_half: int = in_period % half_samples
		var local: float = float(in_half) / float(half_samples)
		var freq: float = tone_a if in_period < half_samples else tone_b
		var t: float = float(in_half) / float(MIX_RATE)
		samples[i] = sin(TAU * freq * t) * sin(PI * local) * 0.35
	return _to_wav(samples, true)


static func make_drone(seconds: float = 2.0) -> AudioStreamWAV:
	var total: int = _sample_count(seconds) + _crossfade_samples(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED + 4
	var samples := PackedFloat32Array()
	samples.resize(total)
	var duration: float = float(total) / float(MIX_RATE)
	var freq_a: float = _snap_freq(36.0, total)
	var freq_b: float = _snap_freq(54.0, total)
	var noise: float = 0.0
	for i: int in total:
		var t: float = float(i) / float(MIX_RATE)
		var swell: float = 0.5 - 0.5 * cos(TAU * t / duration)
		noise = lerpf(noise, rng.randf_range(-1.0, 1.0), 0.008)
		var tone: float = 0.30 * sin(TAU * freq_a * t) + 0.14 * sin(TAU * freq_b * t) + 0.05 * noise
		samples[i] = tone * (0.35 + 0.65 * swell)
	return _to_wav(_crossfade_loop(samples, _LOOP_CROSSFADE_SECONDS), true)


static func make_footstep(variant: int = 0) -> AudioStreamWAV:
	var index: int = clampi(variant, 0, 2)
	var sample_count: int = _sample_count(0.12 + 0.02 * float(index))
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED + 10 + index
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var body_freq: float = _snap_freq(86.0 + 15.0 * float(index), sample_count)
	var ring_freq: float = _snap_freq(196.0 + 24.0 * float(index), sample_count)
	var body_decay: float = 26.0 - 4.0 * float(index)
	for i: int in sample_count:
		var t: float = float(i) / float(MIX_RATE)
		var progress: float = float(i) / float(maxi(sample_count - 1, 1))
		var body: float = sin(TAU * body_freq * t) * exp(-progress * body_decay)
		var ring: float = sin(TAU * ring_freq * t) * exp(-progress * body_decay * 1.8)
		var transient: float = rng.randf_range(-1.0, 1.0) * exp(-progress * 60.0)
		samples[i] = body * 0.62 + ring * 0.26 + transient * 0.28
	return _to_wav(samples, false)


static func make_breath_loop(seconds: float = 3.2) -> AudioStreamWAV:
	var total: int = _sample_count(seconds) + _crossfade_samples(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = _RNG_SEED + 5
	var samples := PackedFloat32Array()
	samples.resize(total)
	var duration: float = float(total) / float(MIX_RATE)
	var low: float = 0.0
	var band: float = 0.0
	for i: int in total:
		var t: float = float(i) / float(MIX_RATE)
		var phase: float = t / duration
		var white: float = rng.randf_range(-1.0, 1.0)
		low = lerpf(low, white, 0.05)
		band = lerpf(band, white, 0.30)
		var breath_noise: float = 0.7 * low + 0.45 * (band - low)
		var inhale: float = sin(PI * clampf(phase / 0.5, 0.0, 1.0))
		var exhale: float = sin(PI * clampf((phase - 0.5) / 0.5, 0.0, 1.0))
		var envelope: float = maxf(inhale * 0.7, exhale)
		samples[i] = breath_noise * envelope * 0.55
	return _to_wav(_crossfade_loop(samples, _LOOP_CROSSFADE_SECONDS), true)


static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		var clamped: float = clampf(samples[i], -1.0, 1.0)
		var value: int = clampi(int(roundf(clamped * 32767.0)), -32768, 32767)
		bytes.encode_s16(i * 2, value)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	else:
		wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return wav


static func _sample_count(seconds: float) -> int:
	return maxi(int(float(MIX_RATE) * maxf(seconds, 0.001)), 1)


static func _crossfade_samples(seconds: float) -> int:
	return mini(int(_LOOP_CROSSFADE_SECONDS * float(MIX_RATE)), int(float(_sample_count(seconds)) / 3.0))


static func _snap_freq(freq: float, samples: int) -> float:
	var duration: float = float(samples) / float(MIX_RATE)
	if duration <= 0.0:
		return freq
	return maxf(roundf(freq * duration), 1.0) / duration


static func _crossfade_loop(samples: PackedFloat32Array, fade_seconds: float) -> PackedFloat32Array:
	var total: int = samples.size()
	var fade: int = mini(int(fade_seconds * float(MIX_RATE)), int(float(total) / 3.0))
	if fade <= 0:
		return samples
	var length: int = total - fade
	var out := PackedFloat32Array()
	out.resize(length)
	for i: int in length:
		if i < fade:
			var blend: float = float(i) / float(fade)
			out[i] = lerpf(samples[length + i], samples[i], blend)
		else:
			out[i] = samples[i]
	return out
