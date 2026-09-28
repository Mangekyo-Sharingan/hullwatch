#!/usr/bin/env python3
"""
Voice Line Generator for Hullwatch.
Synthesizes voice lines using edge-tts and processes them with ffmpeg to achieve
the iconic Subnautica Alterra PDA robotic vocal style:
  - English (UK) authoritative female synthetic timbre (en-GB-SoniaNeural)
  - Subtle downward pitch detuning (-0.25 semitones)
  - Cascaded flanger comb-filter resonance (Fruity Flangus multi-voice timbre)
  - Stereo doubling & spatial spread chorus
  - Resonant formant & intercom EQ (presence boost at 1.5 kHz and 3.5 kHz)
  - Highpass/lowpass band-limiting (100 Hz to 9.5 kHz)
  - Dynamics compression, punch makeup, and peak limiting

Run with: python3 game/tools/generate_voice_lines.py
"""
import asyncio
import os
import subprocess
import sys

VOICE = os.environ.get("HULLWATCH_VOICE", "en-GB-SoniaNeural")
RATE = os.environ.get("HULLWATCH_VOICE_RATE", "-2%")

LINES = {
    "guide_step_0": "Operator awake. Cycle zero initiated. Access a ship status panel to verify life support and power baseline.",
    "guide_step_1": "Baseline confirmed. Walk rounds to inspect machinery. Note that life support and electrical circuits continuously degrade.",
    "guide_step_2": "Physical systems acknowledged. Diagnostic tools are stowed on tool racks. Multimeter and scanner are needed to trace hidden faults.",
    "guide_step_3": "Tools located. Complete necessary repairs and triage. When your work shift concludes, retire to the quarters bunk to advance the cycle.",
    "guide_conclusion": "Twenty-four hour orientation concluded. Advisory subsystem offline. All ongoing ship diagnosis, maintenance, and triage are the sole responsibility of the operator."
}


def build_filter_chain(include_pitch_shift: bool = True) -> str:
    parts = ["aformat=channel_layouts=stereo"]
    if include_pitch_shift:
        parts.append("rubberband=pitch=0.985:pitchq=quality")

    # Cascaded flanger / comb resonator stack (Subnautica PDA signature)
    parts.extend([
        "flanger=delay=7.0:depth=2.5:regen=25:width=55:speed=0.35:phase=25",
        "flanger=delay=4.7:depth=1.8:regen=28:width=60:speed=0.30:phase=40",
        "flanger=delay=3.5:depth=1.2:regen=26:width=50:speed=0.40:phase=60",
        # Stereo field doubling
        "chorus=0.85:0.75:5|8:0.2|0.25:0.2|0.25:1.5|2.0",
        # Equalizer shaping: presence, body, and intercom clarity
        "equalizer=f=110:t=q:w=1.0:g=1.5",
        "equalizer=f=500:t=q:w=1.0:g=1.2",
        "equalizer=f=1500:t=q:w=1.0:g=2.5",
        "equalizer=f=3500:t=q:w=1.2:g=3.5",
        "equalizer=f=6000:t=q:w=1.0:g=2.0",
        "highpass=f=100",
        "lowpass=f=9500",
        # Dynamics compression, gain staging & limiter
        "acompressor=threshold=-20dB:ratio=3:attack=10:release=80:makeup=6dB",
        "volume=7.5dB",
        "alimiter=limit=-1.5dB",
        "aresample=44100"
    ])
    return ",".join(parts)


async def generate_all() -> None:
    try:
        import edge_tts
    except ImportError:
        print("Error: edge-tts is required. Install with: pip install edge-tts")
        sys.exit(1)

    output_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "voice")
    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating Subnautica PDA-style voice lines with voice='{VOICE}' rate='{RATE}'...")

    # Test if rubberband is supported by ffmpeg
    check_rb = subprocess.run(["ffmpeg", "-filters"], capture_output=True, text=True)
    use_rubberband = "rubberband" in check_rb.stdout
    if not use_rubberband:
        print("  Notice: ffmpeg rubberband filter not detected, omitting pitch shift filter.")

    filtergraph = build_filter_chain(include_pitch_shift=use_rubberband)

    for key, text in LINES.items():
        raw_mp3 = f"/tmp/{key}_raw.mp3"
        out_ogg = os.path.join(output_dir, f"{key}.ogg")
        communicate = edge_tts.Communicate(text, VOICE, rate=RATE)
        await communicate.save(raw_mp3)

        cmd = [
            "ffmpeg", "-y", "-i", raw_mp3,
            "-filter_complex", filtergraph,
            "-c:a", "libvorbis", "-q:a", "5",
            out_ogg
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"  Warning: complex filter failed on {key}, retrying with basic filter...")
            fallback_filter = (
                "aformat=channel_layouts=stereo,"
                "flanger=delay=5.0:depth=2.0:regen=25:width=60:speed=0.35,"
                "chorus=0.8:0.7:6:0.25:0.2:2,"
                "equalizer=f=1500:t=q:w=1.0:g=2.5,"
                "equalizer=f=3500:t=q:w=1.2:g=3.0,"
                "highpass=f=120,lowpass=f=8500,volume=1.8"
            )
            subprocess.run([
                "ffmpeg", "-y", "-i", raw_mp3,
                "-af", fallback_filter,
                "-c:a", "libvorbis", "-q:a", "5",
                out_ogg
            ], check=True)

        size_kb = os.path.getsize(out_ogg) / 1024.0
        print(f"  OK: {key}.ogg ({size_kb:.1f} KB)")
        if os.path.exists(raw_mp3):
            os.remove(raw_mp3)

    print("All voice lines generated successfully with Subnautica PDA effect chain.")


if __name__ == "__main__":
    asyncio.run(generate_all())
