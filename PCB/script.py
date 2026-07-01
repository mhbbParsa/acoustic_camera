import pcbnew
import math

board = pcbnew.GetBoard()

N = 30
Rarr = 0.045
ga = math.pi * (3 - math.sqrt(5))

i_vals = range(N)
r_vals = [Rarr * math.sqrt((i + 0.5) / N) for i in i_vals]
th_vals = [i * ga for i in i_vals]
X = [r * math.cos(th) for r, th in zip(r_vals, th_vals)]
Y = [r * math.sin(th) for r, th in zip(r_vals, th_vals)]

cx, cy = 65.0, 65.0

for fp in board.GetFootprints():
    ref = fp.GetReference()
    if not ref.startswith("MK"):
        continue
    try:
        idx = int(ref[2:])
    except ValueError:
        continue
    if idx >= N:
        continue

    x_mm = cx + X[idx] * 1000
    y_mm = cy + Y[idx] * 1000

    fp.SetPosition(pcbnew.VECTOR2I(pcbnew.FromMM(x_mm),pcbnew.FromMM(y_mm)))
    #if idx % 2 == 1:
    #    fp.SetOrientationDegrees(180)
    print(f"{ref}: ({x_mm:.2f}, {y_mm:.2f}) mm")

pcbnew.Refresh()
