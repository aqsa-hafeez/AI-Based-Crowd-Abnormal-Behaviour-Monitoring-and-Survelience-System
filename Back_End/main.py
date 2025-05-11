import os
import cv2
import json
import numpy as np
import torch
from PIL import Image
import time
from torchvision import transforms
from collections import OrderedDict
from ultralytics import YOLO
from dotenv import load_dotenv
from google import genai
import matplotlib.pyplot as plt

from core.raft import RAFT
from core.utils.utils import InputPadder

# ───────────────────────────────────────────────────────────── #
# Global setup
# ───────────────────────────────────────────────────────────── #
print("[INFO] Loading environment variables and setting up device...")
load_dotenv()
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
GREEN, RED = (0, 255, 0), (0, 0, 255)
FONT = cv2.FONT_HERSHEY_SIMPLEX

gclient = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))


# ───────────────────────────────────────────────────────────── #
# RAFT Functions
# ───────────────────────────────────────────────────────────── #
def load_raft(model_path, small=False, mixed_precision=False):
    print("[INFO] Loading RAFT model...")
    from argparse import Namespace
    args = Namespace(small=small, mixed_precision=mixed_precision)
    model = RAFT(args)
    checkpoint = torch.load(model_path, map_location=DEVICE)
    if "state_dict" in checkpoint:
        checkpoint = checkpoint["state_dict"]
    new_state = OrderedDict()
    for k, v in checkpoint.items():
        new_key = k[7:] if k.startswith("module.") else k
        new_state[new_key] = v
    model.load_state_dict(new_state)
    model.to(DEVICE).eval()
    return model

def preprocess_raft(img):
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Resize((384, 512), antialias=True),
    ])
    return transform(Image.fromarray(img)).unsqueeze(0).to(DEVICE)

@torch.no_grad()
def compute_raft_flow(model, frame1, frame2):
    print("[INFO] Computing optical flow with RAFT...")
    image1, image2 = preprocess_raft(frame1), preprocess_raft(frame2)
    padder = InputPadder(image1.shape[-2:])
    image1, image2 = padder.pad(image1, image2)
    flow_low, flow_up = model(image1, image2, iters=20, test_mode=True)
    return flow_up[0].permute(1, 2, 0).cpu().numpy()


# ───────────────────────────────────────────────────────────── #
# Other Helper Functions
# ───────────────────────────────────────────────────────────── #
def detect_people(frame, model, conf_thresh):
    print("[INFO] Running YOLO object detection...")
    res = model.predict(frame, conf=conf_thresh, verbose=False)[0]
    boxes = []
    for det in res.boxes:
        if int(det.cls.item()) != 0: continue
        x1, y1, x2, y2 = map(int, det.xyxy[0].cpu().numpy())
        conf = float(det.conf[0].cpu().numpy())
        boxes.append((x1, y1, x2, y2, conf))
    return boxes

def find_abnormal_segments(timestamps, gap):
    print("[INFO] Grouping abnormal event timestamps...")
    if not timestamps: return []
    timestamps.sort()
    segs, s, e = [], timestamps[0], timestamps[0]
    for t in timestamps[1:]:
        if t - e <= gap:
            e = t
        else:
            segs.append((s, e))
            s = e = t
    segs.append((s, e))
    return segs

def export_clip(src_video, start_s, end_s, dst, fps, size):
    print(f"[INFO] Exporting clip: {start_s:.2f}s to {end_s:.2f}s")
    cap = cv2.VideoCapture(src_video)
    cap.set(cv2.CAP_PROP_POS_MSEC, start_s * 1000)
    vw = cv2.VideoWriter(dst, cv2.VideoWriter_fourcc(*"mp4v"), fps, size)
    while True:
        ok, f = cap.read()
        if not ok or (cap.get(cv2.CAP_PROP_POS_MSEC) / 1000.0) > end_s:
            break
        vw.write(f)
    cap.release(), vw.release()

def create_timestamp_clip(text, size, duration=2, fps=30):
    print(f"[INFO] Creating timestamp clip: {text}")
    w, h = size
    frm = np.zeros((h, w, 3), dtype=np.uint8)
    s = cv2.getTextSize(text, FONT, 1.2, 2)[0]
    org = ((w - s[0]) // 2, (h + s[1]) // 2)
    cv2.putText(frm, text, org, FONT, 1.2, (255, 255, 255), 2)
    tmp = f"ts_{text.replace(' ', '_').replace(':', '-')}.mp4"
    vw = cv2.VideoWriter(tmp, cv2.VideoWriter_fourcc(*"mp4v"), fps, size)
    for _ in range(int(duration * fps)):
        vw.write(frm)
    vw.release()
    return tmp

def stitch_clips(clips, segments, out, size, fps):
    print("[INFO] Stitching clips together with timestamps...")
    parts = []
    for clip, (s, e) in zip(clips, segments):
        parts.append(create_timestamp_clip(f"{s:.1f}s to {e:.1f}s", size, fps=fps))
        parts.append(clip)
    vw = cv2.VideoWriter(out, cv2.VideoWriter_fourcc(*"mp4v"), fps, size)
    for p in parts:
        cap = cv2.VideoCapture(p)
        while True:
            ok, f = cap.read()
            if not ok:
                break
            vw.write(f)
        cap.release()
    vw.release()
    return out

# def plot_and_save_ground_truth_labels(file_path, selected_key):
#     print(f"[INFO] Plotting ground truth for key: {selected_key}")
#     data = np.load(file_path)
#     labels = data[selected_key]
#     plt.figure(figsize=(10, 4))
#     plt.plot(labels, label="Ground Truth Anomalies")
#     plt.title(f"Ground Truth Anomalies - {selected_key}")
#     plt.xlabel("Frame")
#     plt.ylabel("Anomaly Label")
#     plt.legend()
#     plt.grid(True)
#     save_path = os.path.join("groundtruth", f"{selected_key}_groundtruth.png")
#     plt.savefig(save_path)
#     plt.close()
#     print(f"[INFO] Saved ground truth plot at: {save_path}")


# ───────────────────────────────────────────────────────────── #
# Main Routine
# ───────────────────────────────────────────────────────────── #
def main():
    print("[INFO] Starting main pipeline...")

    IN_VIDEO = "D001_03.avi"
    YOLO_WEIGHTS = "models/yolov8x.pt"
    RAFT_PATH = "models/raft-things.pth"
    CONF_T = 0.50
    RAFT_THRESH = 0.4
    MARGIN_S = 5.0
    GAP_S = 4.0
    OUT_FULL = "processed_main.mp4"
    FRAME_DIR = "abnormal_frames"
    CLIP_DIR = "abnormal_clips"
    OUT_COMBINED = "combined_abnormal_clips.mp4"
    OUT_JSON = "summaries.json"

    selected_key = IN_VIDEO.split('.')[0]

    # os.makedirs("groundtruth", exist_ok=True)
    # plot_and_save_ground_truth_labels(file_path="NWPU_Campus_gt.npz", selected_key=selected_key)

    os.makedirs(FRAME_DIR, exist_ok=True)
    os.makedirs(CLIP_DIR, exist_ok=True)

    yolo = YOLO(YOLO_WEIGHTS)
    raft_model = load_raft(RAFT_PATH)

    cap = cv2.VideoCapture(IN_VIDEO)
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    vlen = total / fps
    size = (640, 480)
    outvw = cv2.VideoWriter(OUT_FULL, cv2.VideoWriter_fourcc(*"mp4v"), fps, size)

    prev_frame, times, idx = None, [], 0

    print("[INFO] Starting video processing loop...")
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        idx += 1
        frame = cv2.resize(frame, size)

        boxes = detect_people(frame, yolo, CONF_T)
        for x1, y1, x2, y2, _ in boxes:
            cv2.rectangle(frame, (x1, y1), (x2, y2), GREEN, 2)

        if prev_frame is not None:
            flow = compute_raft_flow(raft_model, prev_frame, frame)
            magnitude = np.linalg.norm(flow, axis=-1)
            if np.mean(magnitude) > RAFT_THRESH:
                ts = idx / fps
                times.append(ts)
                for x1, y1, x2, y2, _ in boxes:
                    cv2.rectangle(frame, (x1, y1), (x2, y2), RED, 2)
                cv2.imwrite(os.path.join(FRAME_DIR, f"frame_{idx:06d}.jpg"), frame)

        outvw.write(frame)
        prev_frame = frame.copy()

    cap.release(), outvw.release()

    print("[INFO] Detecting abnormal segments and exporting clips...")
    segments = find_abnormal_segments(times, GAP_S)
    clip_paths = []
    for i, (s, e) in enumerate(segments, 1):
        start = max(0, s - MARGIN_S)
        end = min(vlen, e + MARGIN_S)
        clip = os.path.join(CLIP_DIR, f"clip_{i:02d}.mp4")
        export_clip(OUT_FULL, start, end, clip, fps, size)
        clip_paths.append((clip, (s, e)))

    if clip_paths:
        combined = stitch_clips([p for p, _ in clip_paths], [s for _, s in clip_paths], OUT_COMBINED, size, fps)
        fh = gclient.files.upload(file=combined)

        time.sleep(10)

        print("[INFO] Generating natural language summary using Gemini...")
        res = gclient.models.generate_content(
            model="models/gemini-2.0-flash",
            contents=[fh, """
                        You will receive video input where abnormal events are highlighted using red bounding boxes. This input is derived from the RAFT-Sintel model, but you must NOT mention or refer to any technical terms or methods (like RAFT, optical flow, motion tracking, etc.) in your output.

                            Your job is to explain what looks unusual or abnormal in the scene in simple, human-friendly language. Treat the viewer as someone with no technical background.

                            Instructions:
                            1. Use the timestamps shown at the beginning of the video and include any additional ones shown later. Each timestamp (or timestamp range) represents a separate anomaly and should be described separately.

                            2. For each anomaly:
                            - Clearly describe what is happening inside the red bounding box.
                            - Explain why this behavior is unusual or out of place in a way that any ordinary person would understand.
                            - Focus on common sense, everyday observations, or safety concerns. For example, “Riding a bike while holding an umbrella can be dangerous because it’s harder to balance.”

                            3. Keep your explanation natural and engaging, like you're telling a story or describing something odd you noticed in a video.

                            4. Format:
                            - Start each section with the timestamp or timestamp range in square brackets.
                            - Then write a short paragraph describing the behavior and why it’s abnormal.

                            5. Do not include any technical terms, system names, or explanation of how the anomaly was detected. Just describe what can be seen and why it’s considered unusual.

                            Example Output:
                            [00:01:00 – 00:01:05] A person is riding a bicycle while holding an umbrella, which makes it harder to see and balance. This is risky and unexpected, especially while moving fast, so it’s marked as unusual.

                            [00:02:14] A person quickly runs across a calm street where everyone else is walking slowly. The sudden movement stands out and feels unexpected in the scene.




                """]
        )
        with open(OUT_JSON, "w") as f:
            json.dump({"response": res.text}, f, indent=2)

    print("✔ Finished.")
    print(f" • Annotated full video : {OUT_FULL}")
    if clip_paths:
        print(f" • Combined clip        : {OUT_COMBINED}")
        print(f" • Summary + quiz JSON  : {OUT_JSON}")
    else:
        print(" • No abnormal segments detected.")

if __name__ == "__main__":
    main()