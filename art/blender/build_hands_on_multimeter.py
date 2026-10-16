"""Multimeter model (the reference for the hands-on pass; see hw_kit.py).

Run headless from the repo root (writes game/assets/models/hullwatch/tools/hw_multimeter.glb):
    blender --background --factory-startup --python art/blender/build_hands_on_multimeter.py
Set HW_MODELS_DIR to redirect output while iterating.

The tool keeps the footprint of the model it replaces (hw_kit.REFERENCE_BOUNDS) and ships one
`use_multimeter` action (24 frames at 24 fps) that Carriable.play_use_animation() plays once when
the sim says the tool did its job.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import hw_kit as kit  # noqa: E402

SEGMENTS = {  # seven-segment layout: name -> (x, z, horizontal?)
    "a": (0.0, 1.0, True), "b": (0.5, 0.5, False), "c": (0.5, -0.5, False),
    "d": (0.0, -1.0, True), "e": (-0.5, -0.5, False), "f": (-0.5, 0.5, False), "g": (0.0, 0.0, True),
}
DIGITS = {"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc", "5": "afgcd", "8": "abcdefg"}


def seven_segment(b: kit.Builder, text: str, centre_x: float, y: float, z: float, height: float, mat: str) -> None:
    """Dark segments on a lit LCD; `height` is the digit's full height."""
    half = height / 2
    thick = height * 0.12
    advance = height * 0.62
    start = centre_x - advance * (len(text) - 1) / 2
    for i, ch in enumerate(text):
        cx = start + advance * i
        for seg in DIGITS[ch]:
            sx, sz, horizontal = SEGMENTS[seg]
            size = (height * 0.34, 0.0006, thick) if horizontal else (thick, 0.0006, height * 0.40)
            b.box(size, (cx + sx * height * 0.40, y, z + sz * half * 0.82), mat, part="digits")


def build_multimeter() -> bpy.types.Object:
    b = kit.Builder("hw_multimeter")
    face = -0.033          # front of the dark face plate
    dial_z = 0.072
    b.pivot("dial", (0.0, -0.0382, dial_z))
    b.pivot("lamp", (0.040, -0.0356, 0.108))

    # Rubber boot: bottom foot, top cap and side bumpers frame the beige shell.
    b.box((0.116, 0.0613, 0.026), (0.0, -0.00235, 0.013), "hw_rubber", bevel=0.004)
    b.box((0.102, 0.0613, 0.010), (0.0, -0.00235, 0.153), "hw_rubber", bevel=0.003)
    for side in (-1, 1):
        b.box((0.009, 0.0613, 0.150), (side * 0.0535, -0.00235, 0.080), "hw_rubber", bevel=0.0025)
    for i in range(5):  # hazard-amber ribs across the foot's front
        b.box((0.0055, 0.0009, 0.014), (-0.040 + i * 0.020, face - 0.0004, 0.013), "hw_hazard_amber", bevel=0.0008, rot=(0, 28, 0))

    # Shell, face plate, display.
    b.box((0.098, 0.0567, 0.126), (0.0, -0.00165, 0.088), "hw_beige", bevel=0.003)
    b.box((0.090, 0.003, 0.116), (0.0, -0.0315, 0.088), "hw_dark", bevel=0.0012)
    b.box((0.076, 0.0032, 0.036), (0.0, -0.0346, 0.1250), "hw_metal", bevel=0.0012)
    b.box((0.066, 0.0012, 0.028), (0.0, -0.0366, 0.1250), "hw_phosphor_green", part="screen")
    seven_segment(b, "420", -0.006, -0.0372, 0.1250, 0.019, "hw_dark")
    b.box((0.0018, 0.0006, 0.0018), (-0.0105, -0.0372, 0.1155), "hw_dark", part="digits")     # decimal point
    b.box((0.012, 0.0006, 0.005), (-0.025, -0.0372, 0.1355), "hw_dark", part="digits")        # battery icon

    # Dial: lit ring, scale ticks over 270 degrees, fluted rubber knob with an amber pointer.
    b.cyl(0.0255, 0.0022, (0.0, -0.0341, dial_z), "hw_metal", axis="y", sides=20, bevel=0.0005)
    for i in range(11):
        a = math.radians(-135 + i * 27)
        r = 0.0305
        b.box((0.0018, 0.0008, 0.0050), (math.sin(a) * r, -0.0338, dial_z + math.cos(a) * r), "hw_beige", rot=(0, math.degrees(a), 0))
    b.fluted(0.0185, 0.0094, (0.0, -0.0379, dial_z), "hw_rubber", flutes=12, depth=0.0016, axis="y", part="dial")
    b.cyl(0.0130, 0.0006, (0.0, -0.0429, dial_z), "hw_metal", axis="y", sides=16, part="dial")
    b.box((0.0030, 0.0008, 0.0120), (0.0, -0.0428, dial_z + 0.0075), "hw_hazard_amber", part="dial")

    # Mode buttons either side of the dial, lamp, input jacks.
    for side in (-1, 1):
        for z in (0.086, 0.062):
            b.box((0.0085, 0.0036, 0.0100), (side * 0.0395, face - 0.0013, z), "hw_steel", bevel=0.0012)
    b.cyl(0.0036, 0.0030, (0.040, -0.0356, 0.108), "hw_phosphor_amber", axis="y", sides=8, part="lamp")
    for x, collar in ((-0.028, "hw_hazard_amber"), (0.0, "hw_beige"), (0.028, "hw_hazard_amber")):
        b.cyl(0.0092, 0.0014, (x, face - 0.0006, 0.039), collar, axis="y", sides=12)
        b.cyl(0.0070, 0.0030, (x, face - 0.0015, 0.039), "hw_metal", axis="y", sides=10)
        b.cyl(0.0034, 0.0012, (x, face - 0.0030, 0.039), "hw_dark", axis="y", sides=8)
    for x in (-0.0415, 0.0415):
        for z in (0.1405, 0.0335):
            b.bolt((x, face, z), "hw_metal", axis="-y", radius=0.0024)

    # Hanging eyelet, kickstand and battery hatch on the back.
    for x in (-0.010, 0.010):
        b.box((0.003, 0.005, 0.0122), (x, -0.00235, 0.1641), "hw_steel", bevel=0.0006)
    b.box((0.023, 0.005, 0.003), (0.0, -0.00235, 0.1687), "hw_steel", bevel=0.0006)
    b.box((0.062, 0.0016, 0.092), (0.0, 0.0275, 0.092), "hw_metal", bevel=0.0012)
    b.box((0.062, 0.0016, 0.006), (0.0, 0.0275, 0.140), "hw_steel", bevel=0.0006)
    b.box((0.034, 0.0012, 0.026), (0.0, 0.0273, 0.060), "hw_dark", bevel=0.001)
    b.bolt((0.0, 0.0279, 0.060), "hw_steel", axis="y", radius=0.0045, height=0.0004)

    root = b.build()
    kit.animate(root, "use_multimeter", [(0, {"rotation": (0, 0, 0)}), (8, {"rotation": (-5, 0, 1.5)}), (24, {"rotation": (0, 0, 0)})])
    kit.animate(b.holders["dial"], "use_multimeter", [(0, {"location": (0.0, -0.0382, dial_z), "rotation": (0, 0, 0)}), (16, {"location": (0.0, -0.0382, dial_z), "rotation": (0, 70, 0)}), (24, {"location": (0.0, -0.0382, dial_z), "rotation": (0, 70, 0)})])
    kit.animate(b.holders["lamp"], "use_multimeter", [(0, {"scale": (1, 1, 1)}), (12, {"scale": (1.4, 1.4, 1.4)}), (24, {"scale": (1, 1, 1)})])
    kit.check_bounds(root, *kit.REFERENCE_BOUNDS["hw_multimeter"])
    return root


def main() -> None:
    kit.reset()
    root = build_multimeter()
    low, high = kit.bounds(root)
    print(f"BUILT {root.name}: {kit.triangles(root)} tris, bounds {tuple(round(v, 4) for v in low)} .. {tuple(round(v, 4) for v in high)}")
    kit.export(root, "tools/hw_multimeter.glb")


main()
