#!/usr/bin/env python3
"""Small original synthesized tones. No external media, licenses, or dependencies."""
import math, pathlib, struct, wave
root = pathlib.Path(__file__).resolve().parents[1] / 'Resources'
for name, frequencies, duration in [('reveal', [174.61, 261.63], .48), ('nuclear', [87.31, 130.81, 196], .85), ('transition', [130.81, 174.61], .65), ('selection', [261.63], .16)]:
    samples = []
    for i in range(int(44100 * duration)):
        t = i / 44100
        envelope = min(1, t / .025) * math.exp(-t * 7) * max(0, min(1, (duration-t) / .08))
        value = sum(math.sin(2 * math.pi * f * t) for f in frequencies) / len(frequencies)
        samples.append(struct.pack('<h', int(value * envelope * 6500)))
    with wave.open(str(root / (name + '.wav')), 'w') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(44100); out.writeframes(b''.join(samples))
