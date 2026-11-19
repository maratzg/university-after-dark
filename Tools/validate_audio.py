#!/usr/bin/env python3
"""Independently measure the shipped PCM, rather than trusting render-time metrics."""
import hashlib
import json
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / 'Resources/Audio'
catalog = json.loads((AUDIO / 'catalog.json').read_text())
assert len(catalog) == 12
assert len({track['id'] for track in catalog}) == 12
report, hashes = [], set()
for track in catalog:
    path = AUDIO / track['file']
    with wave.open(str(path)) as source:
        assert source.getnchannels() == 2 and source.getsampwidth() == 2
        rate = source.getframerate()
        samples = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2').reshape(-1, 2).astype(np.float64) / 32767
    seconds = len(samples) / rate
    rms = float(np.sqrt(np.mean(samples ** 2)))
    peak = float(np.max(np.abs(samples)))
    seam = float(np.max(np.abs(samples[0] - samples[-1])))
    assert abs(seconds - 64 * 60 / track['bpm']) < 1 / rate
    assert .103 < rms < .107 and peak < .71 and seam < .012, track['file']
    assert np.std(samples[:, 0] - samples[:, 1]) > .001, track['file']
    # Music includes bass/body and upper textures; it isn't a single isolated oscillator.
    power = np.abs(np.fft.rfft(samples[:, 0])) ** 2
    frequencies = np.fft.rfftfreq(len(samples), 1 / rate)
    bands = [float(power[(frequencies >= lo) & (frequencies < hi)].sum() / power.sum()) for lo,hi in [(20,200),(200,2000),(2000,14000)]]
    assert bands[0] > .05 and bands[1] > .01 and bands[2] > .00001, (track['file'], bands)
    hashes.add(hashlib.sha256(path.read_bytes()).hexdigest())
    report.append(dict(file=track['file'], seconds=round(seconds,3), rms=round(rms,6), peak=round(peak,6), seamDelta=round(seam,6), spectralBandEnergy=bands))
assert len(hashes) == 12
for file in AUDIO.glob('fx_*.wav'):
    with wave.open(str(file)) as source:
        samples = np.frombuffer(source.readframes(source.getnframes()), dtype='<i2')
        assert source.getnchannels() == 2 and len(samples) > 0
        assert np.max(np.abs(samples.astype(np.int32))) < 25000
output = dict(trackCount=12, effectCount=len(list(AUDIO.glob('fx_*.wav'))), totalMusicSeconds=round(sum(item['seconds'] for item in report),3), tracks=report)
(ROOT / 'Documentation/AudioValidation.json').write_text(json.dumps(output,indent=2) + '\n')
print(f"Validated 12 distinct stereo instrumental loops, {output['effectCount']} effects, {output['totalMusicSeconds']} seconds; headroom, loop seams, stereo content, and spectral content passed.")
