import serial
import serial.tools.list_ports
import queue
import threading
import numpy as np
import cv2
import time

def init_uart(BAUD = 2000000, VID = 0x0403, PID = 0x6010, timeout = 1):
    for p in serial.tools.list_ports.comports():
        if p.vid == VID and p.pid == PID:
            ser = serial.Serial(p.device, BAUD, timeout=timeout)
            return ser
    raise RuntimeError("UART not found")

q = queue.Queue(maxsize=1)
def uart_thread(ser, FRAME_BYTES = 2048):
    while True:
        last = ser.read(1)
        current = ser.read(1)
        miss = 0
        while last != b"\xAA" or current != b"\x55":
            last = current
            current = ser.read(1)
            miss = 1
        if miss:
            print("synchronising uart")
        buffer = ser.read(FRAME_BYTES)
        if q.empty():
            data_1d = np.frombuffer(buffer, dtype="<u2")
            data_2d = np.reshape(data_1d, (32, 32))
            q.put(data_2d)


def heatmap(data, MAX_MIN = 255):
    MAX = max(data.max(), MAX_MIN)

    data = data.astype(np.uint32)
    data = (data * 1023 // MAX).astype(np.uint16)

    black_to_blue = data < 256
    blue_to_cyan = (data < 512) & (data >= 256)
    cyan_to_yellow = (data < 768) & (data >= 512)
    yellow_to_red = data >= 768
    
    r = np.zeros_like(data, dtype=np.uint8)
    g = np.zeros_like(data, dtype=np.uint8)
    b = np.zeros_like(data, dtype=np.uint8)

    #r[black_to_blue] = 0
    #g[black_to_blue] = 0
    b[black_to_blue] = data[black_to_blue]

    #r[blue_to_cyan] = 0
    g[blue_to_cyan] = data[blue_to_cyan] - 256
    b[blue_to_cyan] = 255
    
    r[cyan_to_yellow] = data[cyan_to_yellow] - 512
    g[cyan_to_yellow] = 255
    b[cyan_to_yellow] = 767 - data[cyan_to_yellow]

    r[yellow_to_red] = 255
    g[yellow_to_red] = 1023 - data[yellow_to_red]
    #b[yellow_to_red] = 0

    rgb = np.stack([b, g, r], axis=-1).astype(np.uint8)
    return rgb


ser = init_uart()


t = threading.Thread(target=uart_thread, args=(ser,), daemon=True)
t.start()

fps = 0
start = 0
fps_ctr = 0
while True:
    data = q.get()
    rgb = heatmap(data)
    rgb = cv2.resize(rgb, (640, 640), interpolation=cv2.INTER_CUBIC)


    cv2.putText(
        rgb,
        f"FPS: {fps:.1f}",
        (10, 20),                    # x,y position
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,                           # font scale
        (255, 255, 255),             # colour (B,G,R)
        2                            # thickness
    )
    cv2.imshow("Heatmap", rgb)


    key = cv2.waitKey(1)
    if key == 27 or cv2.getWindowProperty("Heatmap", cv2.WND_PROP_VISIBLE) < 1:
        break

    fps_ctr = fps_ctr + 1
    if fps_ctr == 20:
        end = time.time()
        fps = 20./(end-start)
        fps_ctr = 0
        start = time.time()


cv2.destroyAllWindows()
ser.close()
