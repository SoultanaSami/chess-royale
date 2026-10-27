#!/usr/bin/env python3
"""Slow, percussion-only battle loop. Uses the menu score's CC0 sample cache."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import pyloudnorm as pyln
from scipy import signal
import soundfile as sf

from compose_crown_theme import (
    Orchestra, REVISION, SR, hall_ir, prepare_samples, sample_manifest,
)

BPM = 64
BARS = 16
HIT_STRIDE_BEATS = 2
DRUM_KEY = 24  # One octave below the CC0 recording's root key.
DRUM_CLIP_SECONDS = 8


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] / "audio/music/battle_drums.ogg")
    parser.add_argument("--cache", type=Path, default=Path.home() / ".cache/schachschlachtfeld/vsco2")
    args = parser.parse_args()
    rng = np.random.default_rng(271027)
    manifest = {part: bank for part, bank in sample_manifest().items() if part == "wardrum"}
    prepare_samples(args.cache, manifest)
    orchestra = Orchestra(args.cache, manifest)
    loop_frames = round(BARS * 4 * 60 / BPM * SR)
    # Keep the final drum and room tails, then wrap them to the start of the loop.
    total = loop_frames + 10 * SR
    dry = np.zeros((total, 2), dtype=np.float32)
    sends = np.zeros_like(dry)
    hits = []
    for bar in range(BARS):
        # A sparse half-time pulse: one low, unlayered war-drum strike every
        # two beats, with no tenor or snare accents competing for the attack.
        rise = 1.0 + .08 * np.sin((bar % 8) / 7 * np.pi)
        pattern = [
            (0, "wardrum", 1.20 * rise),
            (HIT_STRIDE_BEATS, "wardrum", 1.00 * rise),
        ]
        for beat, part, strength in pattern:
            index = len(hits)
            key = DRUM_KEY
            source = orchestra.recording(part, key, "p" if index % 2 == 0 else "rr2").copy()
            source = source[:DRUM_CLIP_SECONDS * SR]
            source[:88] *= np.linspace(0, 1, 88)[:, None]
            tail = min(int(.25 * SR), len(source))
            source[-tail:] *= np.linspace(1, 0, tail)[:, None] ** 2
            mid = source.mean(axis=1)
            side = (source[:, 0] - source[:, 1]) * .18
            pan = 0.0 if part == "wardrum" else (-.18 if bar % 2 else .18)
            source[:, 0] = (mid + side) * np.sqrt(1 - pan)
            source[:, 1] = (mid - side) * np.sqrt(1 + pan)
            source *= strength * rng.uniform(.94, 1.06)
            offset_seconds = (bar * 4 + beat) * 60 / BPM + .045 + rng.uniform(-.012, .012)
            offset = round(offset_seconds * SR)
            dry[offset:offset + len(source)] += source
            sends[offset:offset + len(source)] += source * .20
            hits.append({"seconds": round(offset_seconds, 4), "instrument": part, "strength": strength, "key": key})
    for channel in range(2):
        dry[:, channel] += signal.fftconvolve(sends[:, channel], hall_ir(channel))[:total]
    dry = signal.sosfilt(signal.butter(2, [30, 5000], btype="bandpass", fs=SR, output="sos"), dry, axis=0).astype(np.float32)
    loop = dry[:loop_frames].copy()
    loop[:total - loop_frames] += dry[loop_frames:]
    meter = pyln.Meter(SR)
    magnitude = np.abs(loop)
    limited = magnitude > .65
    loop[limited] = np.sign(loop[limited]) * (.65 + .17 * np.tanh((magnitude[limited] - .65) / .17))
    loop *= 10 ** ((-18.5 - meter.integrated_loudness(loop)) / 20)
    peak = float(np.max(np.abs(loop)))
    loop *= min(1.0, 10 ** (-3.5 / 20) / peak)
    assert np.isfinite(loop).all()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with sf.SoundFile(args.output, mode="w", samplerate=SR, channels=2, format="OGG", subtype="VORBIS") as output:
        for offset in range(0, len(loop), 4096):
            output.write(loop[offset:offset + 4096])
    decoded, _ = sf.read(args.output, dtype="float32", always_2d=True)
    metadata = {
        "title": "Trommeln vor der Schlacht", "bpm": BPM, "meter": "4/4", "bars": BARS,
        "duration_seconds": round(len(decoded) / SR, 3), "instruments": list(manifest),
        "integrated_lufs": round(float(meter.integrated_loudness(decoded)), 2),
        "peak_dbfs": round(float(20 * np.log10(np.abs(decoded).max())), 2),
        "loop_boundary_step": float(np.max(np.abs(decoded[0] - decoded[-1]))),
        "source_revision": REVISION, "hits": hits,
        "recordings": {path: hashlib.sha256((args.cache / path).read_bytes()).hexdigest() for bank in manifest.values() for _, path, _ in bank},
        "output_sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
    }
    args.output.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n")
    print(json.dumps({k: v for k, v in metadata.items() if k not in ("hits", "recordings")}, indent=2))


if __name__ == "__main__":
    main()
