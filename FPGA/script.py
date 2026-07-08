import numpy as np
from PIL import Image

vals = np.loadtxt(
    "./acoustic_camera.sim/sim_1/behav/xsim/framebuffer.txt",
    dtype=np.uint8
).reshape(32, 32)

# Unsigned 6-bit values, mapped to the same black -> blue -> cyan -> yellow -> red
# heatmap used by vga_controller.sv
MAX_6BIT = (1 << 6) - 1  # 63
MAX_4BIT = (1 << 4) - 1  # 15

v = np.clip(vals.astype(np.int32), 0, MAX_6BIT)

r = np.zeros_like(v)
g = np.zeros_like(v)
b = np.zeros_like(v)

black_to_blue = v < 16
blue_to_cyan = (v >= 16) & (v < 32)
cyan_to_yellow = (v >= 32) & (v < 48)
yellow_to_red = v >= 48

b[black_to_blue] = v[black_to_blue]

g[blue_to_cyan] = v[blue_to_cyan] - 16
b[blue_to_cyan] = MAX_4BIT

r[cyan_to_yellow] = v[cyan_to_yellow] - 32
g[cyan_to_yellow] = MAX_4BIT
b[cyan_to_yellow] = 47 - v[cyan_to_yellow]

r[yellow_to_red] = MAX_4BIT
g[yellow_to_red] = MAX_6BIT - v[yellow_to_red]

rgb = np.stack([r, g, b], axis=-1)
rgb = (rgb * 255 // MAX_4BIT).astype(np.uint8)

img = Image.fromarray(rgb, mode="RGB")

# Upscale using nearest-neighbor
scale = 16  # e.g. 32x32 -> 512x512
upscaled = img.resize(
    (img.width * scale, img.height * scale),
    Image.Resampling.NEAREST
)

upscaled.save("beamform.png")
