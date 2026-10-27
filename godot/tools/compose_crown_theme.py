#!/usr/bin/env python3
"""Glut der alten Krone — original 6/8 violin-led menu score.

Offline production tool, never a runtime dependency. Fetches selected CC0
VSCO 2 CE recordings from a pinned revision into the user's cache. Outputs a
mobile-sized Vorbis master and an editable MIDI performance. See the credits
beside the audio for provenance and the musical form.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from fractions import Fraction
import hashlib
import json
from pathlib import Path
import struct
import urllib.parse
import urllib.request

import numpy as np
import pyloudnorm as pyln
from scipy import signal
import soundfile as sf

SR = 44100
REVISION = "440300901dfe9275fd84e0b7763af1f8443ae62e"
SOURCE = f"https://raw.githubusercontent.com/sgossner/VSCO-2-CE/{REVISION}/"
VOCAL_REVISION = "fac6461ee4c7f498b23246eced644616fa58d2ec"
VOCAL_SOURCE = f"https://raw.githubusercontent.com/sfzinstruments/legato_vocal_tutorial/{VOCAL_REVISION}/"
# The recorded male voice is an octave below the tutorial's note labels.
# These cents corrections come from its original SFZ sample map.
VOCAL_TUNING = {"a3": 25, "c4": 15, "d4": 30, "f4": 30, "g4": 20, "a4": 40, "bb4": 50}
RNG = np.random.default_rng(271026)
NOTES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def pitch(name: str) -> int:
    accidental = (1 if "#" in name else -1 if "b" in name else 0)
    return (int(name[-1]) + 1) * 12 + NOTES[name[0]] + accidental


@dataclass(frozen=True)
class Note:
    instrument: str
    key: int
    start: float  # eighth notes, not seconds
    duration: float
    gain: float


# Named basses and close inner voicings keep the harmony warm and avoid
# parallel block chords jumping around underneath the soloist.
CHORDS = {
    "dm": ("D2", ["A3", "D4", "F4"], ["D3", "A3", "D4", "E4", "F4", "A4"]),
    "bb": ("Bb1", ["Bb3", "D4", "F4"], ["Bb2", "F3", "Bb3", "D4", "F4", "A4"]),
    "fa": ("A1", ["A3", "C4", "F4"], ["A2", "F3", "A3", "C4", "F4", "G4"]),
    "c": ("C2", ["G3", "C4", "E4"], ["C3", "G3", "C4", "D4", "E4", "G4"]),
    "gm": ("G1", ["Bb3", "D4", "G4"], ["G2", "D3", "G3", "Bb3", "D4", "A4"]),
    "df": ("F2", ["A3", "D4", "F4"], ["F3", "A3", "D4", "F4", "A4", "D5"]),
    "as": ("A1", ["A3", "D4", "E4"], ["A2", "E3", "A3", "D4", "E4", "A4"]),
    "a": ("A1", ["A3", "C#4", "E4"], ["A2", "E3", "A3", "C#4", "E4", "A4"]),
    "f": ("F2", ["A3", "C4", "F4"], ["F3", "C4", "F4", "G4", "A4", "C5"]),
    "ce": ("E2", ["G3", "C4", "E4"], ["E3", "G3", "C4", "E4", "G4", "C5"]),
    "ac": ("C#2", ["A3", "C#4", "E4"], ["C#3", "E3", "A3", "C#4", "E4", "A4"]),
    "dopen": ("D2", ["A3", "D4", "E4"], ["D3", "A3", "D4", "E4", "A4", "D5"]),
}
HARMONY = (
    ["dopen", "dm", "bb", "a"]
    + ["dm", "bb", "fa", "c", "gm", "df", "bb", "as",
       "dm", "bb", "f", "ce", "gm", "bb", "a", "dm"]
    + ["bb", "fa", "gm", "dm", "bb", "f", "as", "a"]
    + ["dm", "c", "bb", "gm", "dm", "bb", "as", "a",
       "bb", "c", "dm", "ac", "bb", "gm", "as", "dm"]
    + ["bb", "fa", "gm", "as"]
    + ["dm", "bb", "fa", "c", "gm", "df", "bb", "as",
       "dm", "bb", "f", "ce", "gm", "bb", "a", "dm"]
    + ["bb", "fa", "gm", "dm", "dopen", "dm", "dopen", "dm"]
)
assert len(HARMONY) == 72


def tempo(bar: int) -> float:
    """Dotted-quarter BPM: small phrase breathing and an actual coda ritardando."""
    if bar < 4:
        base = 56.0
    elif bar < 20:
        base = 59.0
    elif bar < 28:
        base = 55.0
    elif bar < 44:
        base = 63.0
    elif bar < 48:
        base = 57.0
    elif bar < 64:
        base = 61.0
    else:
        return [56, 55, 54, 53, 52, 50, 48, 46][bar - 64]
    return base - (1.3 if bar % 8 == 7 else 0.0)


BAR_SECONDS = np.array([120.0 / tempo(b) for b in range(72)])
BAR_STARTS = np.r_[0.0, np.cumsum(BAR_SECONDS)]


def seconds(eighths: float) -> float:
    b = min(71, int(eighths // 6))
    return float(BAR_STARTS[b] + (eighths - b * 6) / 6 * BAR_SECONDS[b])


def score() -> list[Note]:
    notes: list[Note] = []

    def add(part: str, key: str, bar: int, beat: float, length: float, gain: float) -> None:
        notes.append(Note(part, pitch(key), bar * 6 + beat, length, gain))

    # Each row is a composed six-eighth-note phrase, with space to breathe.
    theme = [
        [("D5", 3), ("E5", 1), ("F5", 2)],
        [("A5", 3), ("G5", 1), ("F5", 2)],
        [("E5", 1), ("F5", 2), ("C5", 3)],
        [("D5", 2), ("E5", 1), ("G5", 2), (None, 1)],
        [("D5", 2), ("F5", 1), ("Bb5", 3)],
        [("A5", 3), ("F5", 2), ("E5", 1)],
        [("F5", 3), ("D5", 2), ("C5", 1)],
        [("D5", 2), ("E5", 1), ("A4", 2), (None, 1)],
        [("D5", 2), ("F5", 1), ("A5", 3)],
        [("Bb5", 2), ("A5", 1), ("F5", 3)],
        [("G5", 1), ("A5", 2), ("C6", 3)],
        [("B5", 1), ("G5", 2), ("E5", 2), (None, 1)],
        [("D5", 2), ("F5", 1), ("G5", 3)],
        [("F5", 2), ("D5", 1), ("C5", 2), ("Bb4", 1)],
        [("A4", 2), ("C#5", 1), ("E5", 3)],
        [("D5", 5), (None, 1)],
    ]
    opening = [
        [(None, 3), ("A4", 2), (None, 1)],
        [("D5", 4), ("E5", 1), ("F5", 1)],
        [("F5", 3), ("D5", 2), (None, 1)],
        [("E5", 3), ("A4", 2), (None, 1)],
    ]
    reflection = [
        [("F5", 4), ("D5", 2)], [("C5", 3), ("A4", 3)],
        [("Bb4", 3), ("D5", 3)], [("F5", 3), ("E5", 1), ("D5", 2)],
        [("A4", 3), ("Bb4", 1), ("D5", 2)], [("C5", 5), (None, 1)],
        [("D5", 3), ("E5", 2), (None, 1)], [("C#5", 2), ("E5", 1), ("A5", 2), (None, 1)],
    ]
    summit = [
        [("A5", 3), ("G5", 1), ("F5", 2)],
        [("G5", 3), ("E5", 2), ("G5", 1)],
        [("A5", 3), ("F5", 1), ("E5", 1), ("D5", 1)],
        [("F5", 2), ("A5", 1), ("Bb5", 2), (None, 1)],
        [("C6", 4), ("A5", 2)], [("Bb5", 3), ("A5", 1), ("G5", 2)],
        [("G5", 2), ("E5", 1), ("D5", 2), ("E5", 1)],
        [("G5", 4), ("A5", 1), (None, 1)],
        [("Bb5", 3), ("A5", 1), ("F5", 2)],
        [("G5", 2), ("A5", 1), ("C6", 3)],
        [("D6", 3), ("C6", 1), ("A5", 2)],
        [("G5", 3), ("E5", 2), (None, 1)],
        [("F5", 3), ("D5", 1), ("F5", 2)],
        [("G5", 2), ("F5", 1), ("D5", 3)],
        [("E5", 3), ("D5", 1), ("E5", 2)],
        [("D5", 5), (None, 1)],
    ]
    bridge = [
        [("D5", 5), (None, 1)], [("C5", 3), ("A4", 3)],
        [("Bb4", 2), ("D5", 1), ("G5", 2), (None, 1)],
        [("E5", 3), ("A4", 2), (None, 1)],
    ]
    coda = [
        [("F5", 3), ("D5", 3)], [("C5", 3), ("A4", 2), (None, 1)],
        [("Bb4", 2), ("D5", 1), ("F5", 3)], [("E5", 2), ("D5", 3), (None, 1)],
        [("A4", 3), ("E5", 3)], [("F5", 2), ("E5", 1), ("D5", 3)],
        [("A4", 5), (None, 1)], [("D5", 5), (None, 1)],
    ]
    phrases = opening + theme + reflection + summit + bridge + theme + coda
    for bar, phrase in enumerate(phrases):
        if bar < 4:
            intensity = .42 + bar * .045
        elif bar < 20:
            intensity = .61 + .11 * np.sin((bar - 4) / 15 * np.pi)
        elif bar < 28:
            intensity = .50 + .04 * (bar - 20)
        elif bar < 44:
            intensity = .78 + .16 * np.sin((bar - 28) / 15 * np.pi)
        elif bar < 48:
            intensity = .60
        elif bar < 64:
            intensity = .73 + .06 * np.sin((bar - 48) / 15 * np.pi)
        else:
            intensity = .58 - (bar - 64) * .035
        position = 0.0
        for key, length in phrase:
            if key:
                # Longer notes bloom; short linking notes tuck into the phrase.
                gain = intensity * (1.0 if length >= 2 else .84)
                add("violin", key, bar, position, length - .045, gain)
            position += length
        assert position == 6

    for bar, chord_name in enumerate(HARMONY):
        bass, inner, arpeggio = CHORDS[chord_name]
        energy = .62 if bar < 4 else .76 if bar < 20 else .48 + (bar - 20) * .05 if bar < 28 else 1.0 if bar < 44 else .48 if bar < 48 else .87 if bar < 64 else max(.30, .58 - (bar - 64) * .04)
        cello_key = pitch(bass) + 12
        notes.append(Note("cello", cello_key, bar * 6 + .035, 5.86, .43 * energy))
        for index, key in enumerate(inner[:2]):
            add("viola", key, bar, .08 + index * .045, 5.9, .24 * energy)
        if bar >= 4 and bar < 68:
            for index, key in enumerate(inner[1:]):
                add("strings", key, bar, .11 + index * .08, 5.85, .30 * energy)
        if bar < 68:
            add("bass", bass, bar, .02, 5.9, .31 * energy)

        # The six-eight harp is a soft, unevenly accented cradle, not a click.
        pattern = [0, 2, 3, 1, 4, 3] if bar % 2 == 0 else [0, 3, 2, 1, 4, 5]
        for eighth, index in enumerate(pattern):
            if bar < 64 and eighth not in (0, 3):
                continue
            if (bar < 4 or bar >= 68) and eighth not in (0, 3):
                continue
            if 20 <= bar < 24 and eighth in (2, 5):
                continue
            accent = [1.0, .60, .69, .85, .62, .58][eighth]
            add("harp", arpeggio[index], bar, eighth + .025, 5.0, .10 * energy * accent)

        # Ground the tune in low bow strokes. Two recorded round robins keep
        # the pulse human; the central retreat deliberately drops this layer.
        if 0 <= bar < 20 or 24 <= bar < 44 or 48 <= bar < 68:
            ostinato = [pitch(arpeggio[0]), pitch(arpeggio[1]), pitch(arpeggio[2])]
            while min(ostinato) < 43:
                ostinato = [key + 12 for key in ostinato]
            for eighth, index in enumerate([0, 1, 2, 0, 2, 1]):
                accent = [1.0, .50, .58, .86, .46, .55][eighth]
                notes.append(Note("spiccato", ostinato[index], bar * 6 + eighth, .56, .40 * energy * accent))
            if 28 <= bar < 44 or 48 <= bar < 64:
                for eighth in (2.5, 5.5):
                    notes.append(Note("spiccato", ostinato[1], bar * 6 + eighth, .34, .17 * energy))

        # Dark horn calls at the opening, then harmonic answers to the violin.
        if bar < 20 or 24 <= bar < 44 or 48 <= bar < 64:
            for index in (0, 2):
                notes.append(Note("horn", pitch(inner[index]) - 12, bar * 6 + .14, 5.35, .32 * energy))
            if bar >= 4:
                notes.append(Note("horn", pitch(inner[0]), bar * 6 + .08, 2.1, .27 * energy))
                notes.append(Note("horn", pitch(inner[1]), bar * 6 + 3.02, 2.6, .24 * energy))

        # Wordless male choir appears in waves: a distant opening fifth,
        # a rising pre-chorus and the broad summit, with breathing space after.
        choral_gain = .11 if bar < 2 else .16 if 12 <= bar < 16 else .14 + (bar - 24) * .035 if 24 <= bar < 28 else .32 if 28 <= bar < 44 else .27 if 48 <= bar < 60 else .13 if 64 <= bar < 66 else 0
        if choral_gain:
            for index, key in enumerate(inner):
                if bar < 2 and index == 2:
                    continue
                notes.append(Note("choir", pitch(key) - 12, bar * 6 + .22 + index * .07, 5.3, choral_gain * energy))

        # A second line answers the violin at the emotional summit, rather
        # than doubling every lead note. All notes are chord tones.
        if 28 <= bar < 44 or 52 <= bar < 60:
            add("strings", inner[2], bar, 3.10, 2.75, .30 * energy)
        if bar in (0, 2) or 4 <= bar < 20 or 24 <= bar < 44 or 48 <= bar < 64:
            strong = bar in (0, 4, 12, 28, 36, 48, 56)
            add("drum", "A1", bar, 0, 2.0, (.40 if strong else .23) * energy)
            add("drum", "D2", bar, 3, 1.5, .12 * energy)
            if bar in (11, 27, 35, 47, 55):
                for beat, strength in [(4.5, .09), (5, .13), (5.5, .17)]:
                    add("drum", "A1", bar, beat, .5, strength)
        # Recorded concert bass drums and lower tenor drums form the front
        # of the rhythm section. Audible skin attacks survive small speakers;
        # the modeled low drum above is only a supporting resonance.
        if bar < 68:
            retreat = 20 <= bar < 24 or 44 <= bar < 48
            weight = .42 if retreat else .82 if bar < 4 else 1.0
            hit = .5 if bar == 0 else .025
            add("wardrum", "C2", bar, hit, 2.4, .95 * weight)
            add("wardrum", "C2", bar, 3.0, 2.0, .64 * weight)
            if not retreat:
                for beat, strength in [(2.5, .29), (5.0, .34)]:
                    add("wardrum", "C2", bar, beat, 1.1, strength * weight)
                for beat, strength in [(1.5, .34), (3.0, .47), (4.5, .28), (5.5, .38)]:
                    add("tenor", "A2", bar, beat, .9, strength * weight)
                if bar >= 4:
                    add("snare", "D2", bar, 3.02, .9, .22 if bar < 28 else .30)
                    add("snare", "D2", bar, 5.5, .6, .09)
            if bar in (3, 11, 19, 27, 35, 47, 55, 63):
                for step in range(8):
                    beat = 4 + step * .25
                    add("tenor", "A2" if step % 2 else "C3", bar, beat, .45, .18 + step * .035)
                    add("snare", "D2", bar, beat + .015, .35, .07 + step * .016)
        if bar in (3, 27, 47, 55):
            add("swell", "C4", bar, 2.5, 3.45, .13)
        if bar in (4, 28, 48, 56):
            add("cymbal", "C4", bar, 0, 8, .13)
        if bar in (0, 28, 48, 64):
            add("bell", "D5" if bar in (0, 48) else "F5", bar, .14, 10, .035)
    return sorted(notes, key=lambda n: n.start)


def sample_manifest() -> dict[str, list[tuple[int, str, str]]]:
    result: dict[str, list[tuple[int, str, str]]] = {}
    def bank(part: str, names: list[str], prefix: str, suffix: str, shift: int = 0, layer: str = "p") -> None:
        result.setdefault(part, []).extend((pitch(n) + shift, prefix + n + suffix, layer) for n in names)
    for dynamic in ("p", "f"):
        bank("violin", ["A4", "C5", "E5", "G5", "A5", "C6"], "Strings/Solo Violin/Arco Vib/LLVln_ArcoVib_", f"_{dynamic}.wav", layer=dynamic)
    bank("strings", ["D3", "F#3", "A3", "C4", "E4"], "Strings/Violin Section/susVib/VlnEns_susVib_", "_v1.wav", 12)
    bank("viola", ["G2", "B2", "D3", "F3"], "Strings/Viola Section/susvib/ViolaEns_susvib_", "_v1_1.wav", 12)
    bank("cello", ["G1", "B1", "D2", "F2", "A2"], "Strings/Cello Section/susvib/susvib_", "_v1_1.wav", 12)
    bank("bass", ["G0", "A#0", "D1", "F#1"], "Strings/Solo Contrabass/SusNV/BKCtbss_SusNV_", "_v1_rr1.wav", 12)
    bank("harp", ["C3", "E3", "G3", "D4", "F4", "A4", "C5"], "Strings/Harp/KSHarp_", "_mf.wav")
    bank("horn", ["A#1", "D2", "F2", "A2", "C3"], "Brass/F Horn/sus/MOHorn_sus_", "_v3_1.wav", 12)
    for rr in (1, 2):
        bank("spiccato", ["G1", "B1", "D2", "F2", "A2", "C3"], "Strings/Cello Section/spic/spic_", f"_v2_RR{rr}.wav", 12, "p" if rr == 1 else "rr2")
    result["choir"] = [(pitch(name[0].upper() + name[1:]) - 12, f"vocal/Samples/vowel_sustain/a/vowel_a_{name}.wav", "p") for name in VOCAL_TUNING]
    for part in ("cymbal", "swell"):
        result[part] = [(60, "Percussion/cymbal-crash1_mp_rr1.wav", "p")]
    result["wardrum"] = [(36, f"Percussion/BDrumNewhit_v6_rr{rr}_Sum.wav", "p" if rr == 1 else "rr2") for rr in (1, 2)]
    result["tenor"] = [(48, f"VSCO 1 Percussion/drums/tenor/tenor_lower/tenor_f_{rr}.wav", "p" if rr == 1 else "rr2") for rr in (1, 2)]
    result["snare"] = [(38, f"Percussion/Snare2-HitSN_v5_rr{rr}_Sum.wav", "p" if rr == 1 else "rr2") for rr in (1, 2)]
    return result


def prepare_samples(cache: Path, manifest: dict) -> None:
    paths = sorted({p for bank in manifest.values() for _, p, _ in bank})
    def fetch(path: str) -> None:
        dest = cache / path
        if dest.exists():
            return
        dest.parent.mkdir(parents=True, exist_ok=True)
        url = VOCAL_SOURCE + urllib.parse.quote(path[6:]) if path.startswith("vocal/") else SOURCE + urllib.parse.quote(path)
        request = urllib.request.Request(url, headers={"User-Agent": "Schachschlachtfeld-score/2.0"})
        with urllib.request.urlopen(request, timeout=45) as response:
            content = response.read()
        if not content.startswith(b"RIFF"):
            raise ValueError(f"Not a WAV recording: {path}")
        dest.write_bytes(content)
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(fetch, paths))
    print(f"Cached {len(paths)} CC0 instrument recordings.", flush=True)


class Orchestra:
    def __init__(self, cache: Path, manifest: dict):
        self.cache = cache
        self.manifest = manifest
        self.sources: dict[str, np.ndarray] = {}
        self.pitched: dict[tuple, np.ndarray] = {}

    def recording(self, part: str, key: int, layer: str = "p") -> np.ndarray:
        token = (part, key, layer)
        if token in self.pitched:
            return self.pitched[token]
        choices = [s for s in self.manifest[part] if s[2] == layer]
        root, path, _ = min(choices, key=lambda s: abs(s[0] - key))
        if path not in self.sources:
            data, rate = sf.read(self.cache / path, dtype="float32", always_2d=True)
            if data.shape[1] == 1:
                data = np.repeat(data, 2, axis=1)
            if rate != SR:
                ratio = Fraction(SR, rate)
                data = signal.resample_poly(data, ratio.numerator, ratio.denominator, axis=0).astype(np.float32)
            # Remove recorded pre-roll but retain the real bow attack.
            energy = np.max(np.abs(data), axis=1)
            audible = np.flatnonzero(energy > float(energy.max()) * .035)
            if len(audible):
                data = data[max(0, int(audible[0]) - int(.018 * SR)):]
            low, high = {"violin": (155, 8200), "strings": (145, 7300), "viola": (110, 6500), "cello": (48, 5700), "bass": (28, 2600), "harp": (95, 8200), "horn": (75, 5600), "spiccato": (60, 6400), "choir": (85, 4900), "cymbal": (400, 7500), "swell": (400, 7500), "wardrum": (32, 6500), "tenor": (70, 6500), "snare": (140, 6500)}[part]
            data = signal.sosfilt(signal.butter(2, [low, high], btype="bandpass", fs=SR, output="sos"), data, axis=0).astype(np.float32)
            if part in ("harp", "spiccato", "cymbal", "swell", "wardrum", "tenor", "snare"):
                target = .82 if part in ("wardrum", "tenor", "snare") else .58
                scale = target / max(.001, float(np.max(np.abs(data))))
            else:
                body = data[int(.35 * SR):int(2.5 * SR)]
                scale = .10 / max(.001, float(np.sqrt(np.mean(body ** 2))))
            self.sources[path] = data * scale
        cents = VOCAL_TUNING[Path(path).stem.split("_")[-1]] if part == "choir" else 0
        ratio = Fraction(2 ** ((root - key) / 12 - cents / 1200)).limit_denominator(1200)
        result = signal.resample_poly(self.sources[path], ratio.numerator, ratio.denominator, axis=0).astype(np.float32)
        self.pitched[token] = result
        return result

    def voice(self, note: Note, length: float) -> np.ndarray:
        release = .58 if note.instrument in ("strings", "viola", "cello", "bass") else .20
        if note.instrument == "harp":
            release = 1.4
        elif note.instrument in ("horn", "choir"):
            release = .48
        elif note.instrument == "spiccato":
            release = .09
        elif note.instrument in ("cymbal", "swell"):
            release = .65
        elif note.instrument in ("wardrum", "tenor", "snare"):
            release = .38
        count = int((length + release) * SR)
        layer = "rr2" if note.instrument in ("spiccato", "wardrum", "tenor", "snare") and round(note.start * 2) % 2 else "p"
        source = self.recording(note.instrument, note.key, layer)
        data = np.zeros((count, 2), np.float32)
        available = min(count, len(source))
        data[:available] = source[:available]
        if note.instrument == "swell":
            body = min(int(length * SR), len(source))
            data[:] = 0
            data[:body] = source[:body][::-1]
        if note.instrument == "choir":
            data[:] = 0
            mono = source.mean(axis=1)
            source_indices = np.arange(len(mono))
            for voice, (detune, pan) in enumerate([(-7, -.8), (4, .65), (0, -.1), (8, .85), (-3, -.55)]):
                indices = np.arange(count) * 2 ** (detune / 1200) + (.06 + voice * .075) * SR
                singer = np.interp(indices, source_indices, mono, left=0, right=0)
                data[:, 0] += singer * np.sqrt(1 - pan) / np.sqrt(5)
                data[:, 1] += singer * np.sqrt(1 + pan) / np.sqrt(5)
        if note.instrument == "violin" and note.gain > .72:
            strong = self.recording("violin", note.key, "f")
            amount = min(.44, (note.gain - .72) * 2)
            data[:min(count, len(strong))] *= 1 - amount
            data[:min(count, len(strong))] += strong[:count] * amount
        # Notes here stay shorter than the recordings: no artificial bow loops.
        t = np.arange(count, dtype=np.float32) / SR
        attack = .002 if note.instrument in ("wardrum", "tenor", "snare") else .012 if note.instrument in ("spiccato", "cymbal") else .025 if note.instrument == "harp" else .065 if note.instrument == "violin" else .45 if note.instrument == "choir" else .19
        envelope = np.minimum(1, t / attack)
        if note.instrument != "harp":
            envelope *= .82 + .18 * np.sin(np.minimum(t / max(length, .1), 1) * np.pi)
        tail = np.clip((t - length) / release, 0, 1)
        envelope *= np.cos(tail * np.pi / 2) ** 2
        data *= (envelope * note.gain * RNG.uniform(.975, 1.025))[:, None]
        return data


def percussion(note: Note) -> np.ndarray:
    """Original modeled skin drum and distant bell; no external percussion files."""
    duration = 2.0 if note.instrument == "drum" else 6.0
    t = np.arange(int(duration * SR), dtype=np.float32) / SR
    fundamental = 440 * 2 ** ((note.key - 69) / 12)
    if note.instrument == "drum":
        x = np.zeros_like(t)
        for ratio, amplitude, decay in [(1, .65, .37), (1.59, .27, .19), (2.14, .13, .10)]:
            x += amplitude * np.sin(2 * np.pi * fundamental * ratio * t) * np.exp(-t / decay)
        noise = signal.sosfilt(signal.butter(2, 1500, fs=SR, output="sos"), RNG.normal(0, 1, len(t)))
        x += .13 * noise * np.exp(-t / .045)
    else:
        x = sum(a * np.sin(2 * np.pi * fundamental * r * t) * np.exp(-t / d) for r, a, d in [(1, .6, 2.2), (2.01, .23, 1.7), (2.76, .08, 1.0)])
    x *= np.minimum(1, t / .008) * note.gain
    x[-int(.10 * SR):] *= np.linspace(1, 0, int(.10 * SR))
    return np.column_stack((x, x)).astype(np.float32)


def hall_ir(channel: int) -> np.ndarray:
    rng = np.random.default_rng(391 + channel)
    t = np.arange(int(3.8 * SR)) / SR
    noise = rng.normal(0, 1, len(t))
    noise = signal.sosfilt(signal.butter(2, [180, 5200], btype="bandpass", fs=SR, output="sos"), noise)
    ir = noise * np.exp(-t * 6.908 / 2.65)
    ir[:int(.027 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    for delay, gain in [(.033, .30), (.061, .22), (.107, .15), (.161, .10)]:
        ir[int((delay + channel * .006) * SR)] += gain
    return ir.astype(np.float32)


def write_midi(notes: list[Note], path: Path) -> None:
    def vlq(value: int) -> bytes:
        parts = [value & 127]
        while value > 127:
            value >>= 7
            parts.insert(0, (value & 127) | 128)
        return bytes(parts)
    def chunk(events: list[tuple[int, bytes]]) -> bytes:
        result = bytearray()
        previous = 0
        for tick, message in sorted(events, key=lambda x: x[0]):
            result.extend(vlq(tick - previous) + message)
            previous = tick
        result.extend(b"\x00\xff\x2f\x00")
        return b"MTrk" + struct.pack(">I", len(result)) + result
    programs = {"violin": 40, "strings": 48, "viola": 41, "cello": 42, "bass": 43, "harp": 46, "drum": 47, "bell": 14, "spiccato": 42, "horn": 60, "choir": 52, "cymbal": 119, "swell": 119, "wardrum": 0, "tenor": 0, "snare": 0}
    percussion_keys = {"drum": 41, "wardrum": 36, "tenor": 45, "snare": 38, "cymbal": 49, "swell": 55}
    melodic_channels = iter(c for c in range(16) if c != 9)
    conductor = [(0, b"\xff\x58\x04\x06\x03\x24\x08")]
    for bar in range(72):
        micros = round(60_000_000 / (tempo(bar) * 1.5))
        conductor.append((bar * 1440, b"\xff\x51\x03" + micros.to_bytes(3, "big")))
    tracks = [chunk(conductor)]
    for name, program in programs.items():
        channel = 9 if name in percussion_keys else next(melodic_channels)
        events = [(0, b"\xff\x03" + vlq(len(name)) + name.encode())]
        if name not in percussion_keys:
            events.append((0, bytes([0xC0 + channel, program])))
        for n in notes:
            if n.instrument != name:
                continue
            key = percussion_keys.get(name, n.key)
            events.append((round(n.start * 240), bytes([0x90 + channel, key, max(1, min(110, round(n.gain * 100)))])))
            events.append((round((n.start + n.duration) * 240), bytes([0x80 + channel, key, 0])))
        tracks.append(chunk(events))
    path.write_bytes(b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), 480) + b"".join(tracks))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "audio/music/ashen_crown.ogg")
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/schachschlachtfeld/vsco2")
    parser.add_argument("--wav", type=Path, help="Optional uncompressed listening/editing master")
    args = parser.parse_args()
    manifest = sample_manifest()
    prepare_samples(args.cache, manifest)
    orchestra = Orchestra(args.cache, manifest)
    notes = score()
    total = int((BAR_STARTS[-1] + 6.0) * SR)
    dry = np.zeros((total, 2), np.float32)
    sends = np.zeros_like(dry)
    placement = {"violin": (-.12, .30, .22), "strings": (.26, .95, .32), "viola": (-.30, .65, .26), "cello": (.14, .55, .24), "bass": (0, .25, .18), "harp": (.35, .7, .29), "drum": (-.1, .35, .22), "bell": (-.45, .6, .45), "spiccato": (-.25, .72, .18), "horn": (.15, .8, .30), "choir": (0, 1.0, .52), "cymbal": (.32, .85, .25), "swell": (-.32, .85, .30)}
    placement.update({"wardrum": (0, .55, .24), "tenor": (-.25, .65, .20), "snare": (.25, .65, .22)})
    for part, (pan, width, send) in placement.items():
        stem = np.zeros_like(dry)
        for note in notes:
            if note.instrument != part:
                continue
            start = seconds(note.start)
            duration = seconds(note.start + note.duration) - start
            voice = percussion(note) if part in ("drum", "bell") else orchestra.voice(note, duration)
            offset = max(0, int((start + RNG.uniform(-.009, .013)) * SR))
            size = min(len(voice), total - offset)
            stem[offset:offset + size] += voice[:size]
        mid = stem.mean(axis=1)
        side = (stem[:, 0] - stem[:, 1]) * .5 * width
        stem[:, 0] = (mid + side) * np.sqrt(1 - pan)
        stem[:, 1] = (mid - side) * np.sqrt(1 + pan)
        dry += stem
        sends += stem * send
        print(f"Rendered {part}: {sum(n.instrument == part for n in notes)} notes.", flush=True)
    for channel in range(2):
        source = .8 * sends[:, channel] + .2 * sends[:, 1 - channel]
        dry[:, channel] += signal.fftconvolve(source, hall_ir(channel))[:total]
    dry = signal.sosfilt(signal.butter(2, 30, btype="highpass", fs=SR, output="sos"), dry, axis=0).astype(np.float32)
    fade_in = int(.08 * SR)
    fade_out = int(4 * SR)
    dry[:fade_in] *= np.sin(np.linspace(0, np.pi / 2, fade_in))[:, None] ** 2
    dry[-fade_out:] *= np.cos(np.linspace(0, np.pi / 2, fade_out))[:, None] ** 2
    meter = pyln.Meter(SR)
    loudness = meter.integrated_loudness(dry)
    dry *= 10 ** ((-17.5 - loudness) / 20)
    # Catch only the strongest drum transients with a smooth knee. A single
    # bass-drum hit must not force the entire orchestral bed several dB down.
    magnitude = np.abs(dry)
    limited = magnitude > .65
    limited_fraction = float(np.mean(limited))
    dry[limited] = np.sign(dry[limited]) * (.65 + .17 * np.tanh((magnitude[limited] - .65) / .17))
    assert np.isfinite(dry).all() and float(np.max(np.abs(dry))) < .99
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.wav:
        sf.write(args.wav, dry, SR, subtype="PCM_24")
    # Bounded writes avoid a libsndfile/Vorbis crash with one multi-minute
    # buffer on macOS, and make encoder memory independent of song duration.
    with sf.SoundFile(args.output, mode="w", samplerate=SR, channels=2, format="OGG", subtype="VORBIS") as encoded:
        for offset in range(0, len(dry), 4096):
            encoded.write(dry[offset:offset + 4096])
    write_midi(notes, args.output.with_suffix(".mid"))
    metadata = {
        "title": "Glut der alten Krone", "arrangement_revision": 3, "duration_seconds": round(total / SR, 3),
        "bars": 72, "meter": "6/8", "tonality": "D minor / F major", "notes": len(notes),
        "integrated_lufs_before_encoding": round(float(meter.integrated_loudness(dry)), 2),
        "peak_dbfs_before_encoding": round(20 * np.log10(float(np.max(np.abs(dry)))), 2),
        "soft_limited_sample_fraction": round(limited_fraction, 6),
        "source_revision": REVISION, "output_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "vocal_source_revision": VOCAL_REVISION,
        "instrument_note_counts": {part: sum(n.instrument == part for n in notes) for part in placement},
        "recordings": {p: hashlib.sha256((args.cache / p).read_bytes()).hexdigest() for bank in manifest.values() for _, p, _ in bank},
    }
    args.output.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps({k: v for k, v in metadata.items() if k != "recordings"}, indent=2), flush=True)


if __name__ == "__main__":
    main()
