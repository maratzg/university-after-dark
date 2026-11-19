#!/usr/bin/env python3
"""Original procedural instrumental music. Requires NumPy only to regenerate assets.

16-bar arrangements with extended minor harmony, band-limited detuned oscillators,
sub bass, FM/plucked synths, pitched drums, filtered noise and circular stereo delay.
All sustained oscillators and modulation are quantized to loop-length frequency bins;
percussion tails and delays wrap around. No samples or third-party compositions.
"""
import json
import math
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'Resources' / 'Audio'
ROOT.mkdir(parents=True, exist_ok=True)
SR = 32000
TAU = 2 * np.pi
TRACKS = [
    ('afterHours', 'menu_01', 'Velvet After Midnight', 72),
    ('afterHours', 'menu_02', 'Empty Corridors', 72),
    ('temptation', 'round1_01', 'Velvet Temptation', 108),
    ('temptation', 'round1_02', 'Low Light', 108),
    ('secrets', 'round2_01', 'Things Left Unsaid', 100),
    ('secrets', 'round2_02', 'Behind Closed Doors', 100),
    ('confessions', 'round3_01', 'Glass Confessions', 116),
    ('confessions', 'round3_02', 'A Quiet Admission', 116),
    ('absoluteChaos', 'round4_01', 'Beautiful Consequences', 92),
    ('absoluteChaos', 'round4_02', 'Last Good Decision', 92),
    ('pointOfNoReturn', 'nuclear_01', 'Point of No Return', 60),
    ('pointOfNoReturn', 'nuclear_02', 'The Room Holds Its Breath', 60),
]


def midi(n): return 440 * 2 ** ((n - 69) / 12)


def colored_noise(rng, count, low, high):
    source = rng.normal(0, 1, count)
    spectrum = np.fft.rfft(source)
    f = np.fft.rfftfreq(count, 1 / SR)
    # Smooth band edges avoid resonant ringing and provide periodic colored textures.
    response = (1 - np.exp(-(f / max(1, low)) ** 4)) * np.exp(-(f / high) ** 4)
    result = np.fft.irfft(spectrum * response, n=count)
    return result / max(1e-9, np.std(result))


def add_event(mix, signal, start, level=1, pan=0):
    indices = (np.arange(len(signal)) + int(round(start * SR))) % len(mix)
    mix[indices, 0] += signal * level * math.sqrt((1 - pan) / 2)
    mix[indices, 1] += signal * level * math.sqrt((1 + pan) / 2)


def pluck(note, duration, rng, metal=False):
    t = np.arange(int(SR * duration)) / SR
    freq = midi(note)
    env = np.minimum(1, t / .006) * np.exp(-t * (3.5 if metal else 5.5)) * np.minimum(1, (duration - t) / .05)
    signal = np.sin(TAU * freq * t + (1.5 if metal else .45) * np.sin(TAU * freq * (2.71 if metal else 2) * t) * np.exp(-t * 4))
    signal += .14 * np.sin(TAU * freq * 3 * t) * np.exp(-t * 9)
    return signal * env


def render(category, track_id, title, bpm, seed):
    rng = np.random.default_rng(seed)
    count = int(round(SR * 64 * 60 / bpm))
    duration = count / SR
    beat = duration / 64
    t = np.arange(count) / SR
    mix = np.zeros((count, 2), np.float64)
    notes = np.zeros_like(mix)
    variant = track_id.endswith('02')
    roots = [38, 34, 41, 36] if not variant else [38, 41, 34, 33]
    intervals = [[0, 3, 7, 10, 14], [0, 4, 7, 11, 14], [0, 4, 7, 11, 14], [0, 5, 7, 10, 13]]
    nuclear = category == 'pointOfNoReturn'
    menu = category == 'afterHours'
    house = category == 'temptation'
    techno = category == 'confessions'
    chaos = category == 'absoluteChaos'

    def periodic_sine(freq, phase=0):
        return np.sin(TAU * round(freq * duration) / duration * t + phase)

    # Four slow, overlapping extended chords, with three detuned voices per note.
    for chord, root in enumerate(roots):
        distance = (t - chord * 16 * beat + duration / 2) % duration - duration / 2
        window = np.where(np.abs(distance) < 12 * beat, .5 + .5 * np.cos(np.pi * distance / (12 * beat)), 0)
        for index, interval in enumerate(intervals[chord]):
            f = midi(root + 12 + interval)
            for channel in range(2):
                pad = np.zeros(count)
                for detune in [-.0018, .0004, .0022]:
                    detuned = f * (1 + detune * (1 if channel == 0 else -1))
                    for harmonic in range(1, 7):
                        pad += periodic_sine(detuned * harmonic, index * .63 + channel * .31) / harmonic ** 1.9
                slow = .82 + .18 * periodic_sine((2 + index % 3) / duration, chord)
                mix[:, channel] += pad * window * slow * (.008 if nuclear else .014)

    # Warm sub drone, centered, and a little breath in the stereo field.
    drone = .037 * periodic_sine(midi(roots[0] - (12 if nuclear else 0)))
    drone += .009 * periodic_sine(midi(roots[0]) * 1.5, 1)
    for channel in range(2):
        air = colored_noise(rng, count, 200, 1800 if nuclear else 4500)
        mix[:, channel] += drone + air * (.006 if nuclear else .002) * (.6 + .4 * periodic_sine(3 / duration, channel))

    # Sub bass phrases and low-pass saw harmonics, with circular release tails.
    for bar in range(16):
        root = roots[bar // 4]
        hits = [(0, 0), (1.75, 0), (2.5, 7), (3.5, 0)] if house else [(0, 0), (2.5, 0)] if not techno else [(0, 0), (1.5, 0), (2.75, 7)]
        if menu or nuclear: hits = [(0, 0)] if bar % 2 == 0 else []
        for offset, interval in hits:
            length = beat * (3 if menu or nuclear else .72)
            bt = np.arange(int(length * SR)) / SR
            f = midi(root + interval)
            env = np.minimum(1, bt / .018) * np.exp(-bt / (length * .4)) * np.minimum(1, (length - bt) / .06)
            signal = (np.sin(TAU * f * bt) + .22 * np.sin(TAU * f * 2 * bt) + .09 * np.sin(TAU * f * 3 * bt)) * env
            add_event(mix, signal, (bar * 4 + offset) * beat, .16 if not nuclear else .11)

    # Hook/arpeggio voice: syncopated sparse plucks, stereo ping-pong and harmonic changes.
    for bar in range(16):
        root = roots[bar // 4]
        offsets = [1.5, 3.25] if house else [0, 1.5, 2.75] if techno else [1, 3.5] if not menu else ([.5] if bar % 2 == 0 else [])
        if nuclear: offsets = [2.5] if bar % 3 == 0 else []
        if chaos: offsets = [0, 1.75, 3.5] if bar % 2 else [.5, 2.5]
        for j, offset in enumerate(offsets):
            choices = [12, 19, 22, 26, 27] if techno else [19, 22, 26, 31]
            note = root + choices[(bar + j * 2 + int(variant)) % len(choices)]
            phrase = pluck(note, 1.5 if nuclear else .9, rng, metal=nuclear or chaos)
            pan = -.45 if (bar + j) % 2 else .45
            level = .038 if menu else .027 if nuclear else .048 if techno else .045
            start = (bar * 4 + offset) * beat
            add_event(notes, phrase, start, level, pan)
            add_event(notes, phrase, start + .75 * beat, level * .3, -pan)
            add_event(notes, phrase, start + 1.5 * beat, level * .12, pan)
    mix += notes

    # Pitched kicks, soft snare/rim and high-passed noise hats; no downloaded drum samples.
    kick_t = np.arange(int(.65 * SR)) / SR
    kick = np.sin(TAU * (47 * kick_t + (105 / 33) * (1 - np.exp(-kick_t * 33)))) * np.exp(-kick_t * 11)
    kick *= np.minimum(1, kick_t / .002) * np.minimum(1, (.65 - kick_t) / .04)
    hat_t = np.arange(int(.15 * SR)) / SR
    hat = colored_noise(rng, len(hat_t), 5000, 11000) * np.exp(-hat_t * 45) * np.minimum(1, hat_t / .001)
    snare_t = np.arange(int(.25 * SR)) / SR
    snare = (colored_noise(rng, len(snare_t), 1200, 6500) * .45 + np.sin(TAU * 184 * snare_t) * .2) * np.exp(-snare_t * 25) * np.minimum(1, snare_t / .003)
    for bar in range(16):
        if menu: continue
        kicks = [0, 1, 2, 3] if house or techno else [0, 1.75, 3] if category == 'secrets' else [0, 2.5] if chaos else ([0] if bar % 2 == 0 else [])
        for offset in kicks: add_event(mix, kick, (4 * bar + offset) * beat, .26 if house else .21 if techno else .18)
        if not nuclear:
            for offset in ([1, 3] if not chaos else [2]): add_event(mix, snare, (4 * bar + offset) * beat, .032 if techno else .048)
            for offset in np.arange(.5, 4, .5 if techno else 1):
                add_event(mix, hat, (4 * bar + offset + (0.035 if variant and offset % 1 else 0)) * beat, .018 if offset % 1 else .009, .3 if bar % 2 else -.3)
        elif bar % 2:
            strike = pluck(52 + bar % 5, 1.5, rng, metal=True)
            add_event(mix, strike, (bar * 4 + 1.75) * beat, .027, .6 if bar % 4 else -.6)

    # Periodic side-chain breathing, gentle saturation and an extremely restrained stereo room.
    if house or techno:
        phase = t / beat % 1
        mix *= (1 - .14 * np.exp(-(np.minimum(phase, 1 - phase) / .12) ** 2))[:, None]
    dry = mix.copy()
    for delay, amount in [(.375 * beat, .09), (.75 * beat, .05), (1.5 * beat, .025)]:
        mix += np.roll(dry[:, ::-1], int(round(delay * SR)), axis=0) * amount
    mix -= np.mean(mix, axis=0)
    mix = np.tanh(mix * 1.35)
    # Fixed loudness target across the collection, with substantial true-peak headroom.
    rms = np.sqrt(np.mean(mix ** 2))
    mix *= min(.105 / max(rms, 1e-9), .70 / np.max(np.abs(mix)))
    path = ROOT / (track_id + '.wav')
    write(path, mix)
    seam = float(np.max(np.abs(mix[0] - mix[-1])))
    return dict(id=track_id, category=category, title=title, file=path.name, bpm=bpm), dict(file=path.name, seconds=round(duration, 4), rms=round(float(np.sqrt(np.mean(mix**2))), 6), peak=round(float(np.max(np.abs(mix))), 6), seamDelta=round(seam, 6))


def write(path, samples):
    if samples.ndim == 1: samples = np.column_stack([samples, samples])
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(2); out.setsampwidth(2); out.setframerate(SR)
        out.writeframes((np.clip(samples, -1, 1) * 32767).astype('<i2').tobytes())


def effects():
    specs = [('truthSelection',.22), ('dareSelection',.26), ('questionReveal',.55), ('roundTransition',.7), ('nuclearActivation',1.5), ('challengeCompletion',.42)]
    for index, (name, duration) in enumerate(specs):
        rng = np.random.default_rng(900 + index)
        t = np.arange(int(duration * SR)) / SR
        env = np.minimum(1, t / .007) * np.minimum(1, (duration - t) / .08)
        if name == 'nuclearActivation':
            signal = np.sin(TAU * (37 * t + 2.5 * (1 - np.exp(-t * 12)))) * np.exp(-t * 4) * .32
            signal += colored_noise(rng, len(t), 50, 850) * np.exp(-t * 12) * .06
        elif name == 'roundTransition':
            signal = colored_noise(rng, len(t), 350, 3500) * np.sin(np.pi * t / duration) ** 2 * .06
            signal += np.sin(TAU * 130.81 * t + .7 * np.sin(TAU * 261.63 * t)) * np.exp(-t * 6) * .07
        else:
            frequency = [293.66, 146.83, 220, 130.81, 37, 349.23][index]
            signal = np.sin(TAU * frequency * t + .6 * np.sin(TAU * frequency * 2 * t) * np.exp(-t * 15)) * np.exp(-t * 10) * .13
            signal += .025 * np.sin(TAU * frequency * 1.5 * t) * np.exp(-t * 7)
        write(ROOT / ('fx_' + name + '.wav'), signal * env)


if __name__ == '__main__':
    catalog, report = [], []
    for index, track in enumerate(TRACKS):
        entry, metrics = render(*track, seed=1024 + index)
        catalog.append(entry); report.append(metrics)
        print(f"Rendered {entry['title']}: {metrics}", flush=True)
    effects()
    (ROOT / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
    (ROOT / 'AudioQuality.json').write_text(json.dumps(report, indent=2) + '\n')
