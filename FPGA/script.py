import numpy as np
from PIL import Image

vals = np.loadtxt(
    "./acoustic_camera.sim/sim_1/behav/xsim/framebuffer.txt",
    dtype=np.uint8
).reshape(32, 32)

# Absolute scaling for unsigned 4-bit values
MAX_4BIT = (1 << 4) - 1  # 15

v = vals.astype(np.float64)
v = np.clip(v, 0, MAX_4BIT)
v = v * 255.0 / MAX_4BIT

img = Image.fromarray(v.astype(np.uint8), mode="L")

# Upscale using nearest-neighbor
scale = 16  # e.g. 32x32 -> 512x512
upscaled = img.resize(
    (img.width * scale, img.height * scale),
    Image.Resampling.NEAREST
)

upscaled.save("beamform.png")
