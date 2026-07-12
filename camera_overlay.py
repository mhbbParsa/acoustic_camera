import queue
import threading
import time
import cv2
import numpy as np
import serial
import serial.tools.list_ports

GRID = 32
FRAME_BYTES = GRID * GRID * 2
DISPLAY_SIZE = 1080
BAUD = 2_000_000
VID = 0x0403
PID = 0x6010
PERSISTENCE_DECAY = 0.60
HEATMAP_MIN_SCALE = 127
FPS_WINDOW = 20


def init_uart(baud=BAUD, vid=VID, pid=PID, timeout=1):
    for p in serial.tools.list_ports.comports():
        if p.vid == vid and p.pid == pid:
            return serial.Serial(p.device, baud, timeout=timeout)
    raise RuntimeError("UART not found")


def uart_thread(ser, out_q, frame_bytes=FRAME_BYTES):
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
        buffer = ser.read(frame_bytes)
        if out_q.empty():
            data_1d = np.frombuffer(buffer, dtype="<u2")
            data_2d = np.reshape(data_1d, (GRID, GRID))
            out_q.put(data_2d)


def data_to_heatmap(data, min_scale=HEATMAP_MIN_SCALE):
    #Black -> blue -> cyan -> yellow -> red

    scale = max(data.max(), min_scale)

    normalized = (data.astype(np.uint32) * 1023 // scale).astype(np.uint16)

    black_to_blue = normalized < 256
    blue_to_cyan = (normalized < 512) & (normalized >= 256)
    cyan_to_yellow = (normalized < 768) & (normalized >= 512)
    yellow_to_red = normalized >= 768

    r = np.zeros_like(normalized, dtype=np.uint8)
    g = np.zeros_like(normalized, dtype=np.uint8)
    b = np.zeros_like(normalized, dtype=np.uint8)

    b[black_to_blue] = normalized[black_to_blue]

    g[blue_to_cyan] = normalized[blue_to_cyan] - 256
    b[blue_to_cyan] = 255

    r[cyan_to_yellow] = normalized[cyan_to_yellow] - 512
    g[cyan_to_yellow] = 255
    b[cyan_to_yellow] = 767 - normalized[cyan_to_yellow]

    r[yellow_to_red] = 255
    g[yellow_to_red] = 1023 - normalized[yellow_to_red]

    rgb = np.stack([b, g, r], axis=-1).astype(np.uint8)
    return rgb, normalized >> 2


def blend_heatmap(frame, heatmap, normalized):
    alpha = normalized

    alpha_resized = cv2.resize(alpha, (frame.shape[1], frame.shape[0]))
    alpha_3ch = np.stack([alpha_resized] * 3, axis=-1)

    blended = (frame.astype(np.uint16) * (255 - alpha_3ch) +
               heatmap.astype(np.uint16) * alpha_3ch) >> 8

    return blended.astype(np.uint8)


def main():
    ser = init_uart()

    q = queue.Queue(maxsize=1)
    t = threading.Thread(target=uart_thread, args=(ser, q), daemon=True)
    t.start()

    cap = cv2.VideoCapture(0)
    ret, frame = cap.read()
    height, width = frame.shape[:2]
    pad = (width - height) // 2

    offset_x, offset_y = 0, 0
    fps = 0
    fps_ctr = 0
    fps_window_start = 0
    key = 0

    persistence = np.zeros((GRID, GRID), dtype=np.float32)
    while True:
        data = q.get()

        if key == ord(" "):
            row, col = np.unravel_index(np.argmax(data), data.shape)
            offset_x = GRID // 2 - col
            offset_y = GRID // 2 - row

        M = np.float32([[1, 0, offset_x], [0, 1, offset_y]])
        data_shifted = cv2.warpAffine(data, M, (GRID, GRID))

        persistence = data_shifted + persistence * PERSISTENCE_DECAY
        heatmap, normalized = data_to_heatmap(persistence)
        heatmap = cv2.resize(heatmap, (DISPLAY_SIZE, DISPLAY_SIZE), interpolation=cv2.INTER_CUBIC)

        ret, frame = cap.read()
        frame = cv2.copyMakeBorder(frame, pad, pad, 0, 0, cv2.BORDER_CONSTANT, value=(0, 0, 0))
        frame = cv2.resize(cv2.flip(frame, 1), (DISPLAY_SIZE, DISPLAY_SIZE), interpolation=cv2.INTER_CUBIC)

        overlay = blend_heatmap(frame, heatmap, normalized)

        fps_ctr += 1
        if fps_ctr == FPS_WINDOW:
            end = time.time()
            fps = FPS_WINDOW / (end - fps_window_start)
            fps_ctr = 0
            fps_window_start = time.time()

        cv2.putText(overlay, f"FPS: {fps:.1f}", (10, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 2)

        cv2.imshow("Heatmap", overlay)

        key = cv2.waitKey(1)
        if key == 27 or cv2.getWindowProperty("Heatmap", cv2.WND_PROP_VISIBLE) < 1:
            break

    cv2.destroyAllWindows()
    ser.close()


if __name__ == "__main__":
    main()
