#!/usr/bin/env python3
import os
import cv2
import json
import time
import numpy as np
import torch
from PIL import Image
from collections import OrderedDict
from typing import List
import uvicorn
from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from fastapi.responses import JSONResponse, FileResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from ultralytics import YOLO
from torchvision import transforms
import matplotlib.pyplot as plt
from google import genai
from core.raft import RAFT
from core.utils.utils import InputPadder
import re

# ── Use H.264 in MP4 container for Android compatibility ───────────────────────
FOURCC = cv2.VideoWriter_fourcc(*"mp4v")
EXT    = ".mp4"
# ──────────────────────────────────────────────────────────────────────────────

load_dotenv()
API_KEY = os.getenv("GOOGLE_API_KEY")
if not API_KEY:
    raise RuntimeError("Set GOOGLE_API_KEY in your .env")
gclient = genai.Client(api_key=API_KEY)

app = FastAPI(title="Abnormal-Clip Extractor + Gemini Summary")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Directories (ensure exist at startup)
ORIGINAL_DIR  = "originals"
CLIP_DIR      = "abnormal_clips"
GROUND_TRUTH  = "groundtruth"
FRAME_DIR     = "abnormal_frames"
os.makedirs(ORIGINAL_DIR, exist_ok=True)
os.makedirs(CLIP_DIR, exist_ok=True)
os.makedirs(GROUND_TRUTH, exist_ok=True)
os.makedirs(FRAME_DIR, exist_ok=True)

def clean_dirs(key: str):
    """Wipe out old artifacts before processing a new video."""
    # clips
    for d in (CLIP_DIR, FRAME_DIR, GROUND_TRUTH):
        for f in os.listdir(d):
            os.remove(os.path.join(d, f))
    # any previously produced processed/combined files
    for f in os.listdir():
        if f.startswith(f"processed_{key}") or f.startswith(f"combined_{key}"):
            os.remove(f)

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
FONT   = cv2.FONT_HERSHEY_SIMPLEX

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
    return model.to(DEVICE).eval()

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
    if not timestamps:
        return []
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

def export_clip(src, start_s, end_s, dst, fps, size):
    print(f"[INFO] Exporting clip: {start_s:.2f}s to {end_s:.2f}s")
    cap = cv2.VideoCapture(src)
    cap.set(cv2.CAP_PROP_POS_MSEC, start_s * 1000)
    vw = cv2.VideoWriter(dst, FOURCC, fps, size)
    while True:
        ok, f = cap.read()
        if not ok or (cap.get(cv2.CAP_PROP_POS_MSEC) / 1000.0) > end_s:
            break
        vw.write(f)
    cap.release(); vw.release()

def create_timestamp_clip(text, size, duration=2, fps=30):
    print(f"[INFO] Creating timestamp clip: {text}")
    w, h = size
    frm = np.zeros((h, w, 3), dtype=np.uint8)
    s = cv2.getTextSize(text, FONT, 1.2, 2)[0]
    org = ((w - s[0]) // 2, (h + s[1]) // 2)
    cv2.putText(frm, text, org, FONT, 1.2, (255, 255, 255), 2)
    tmp = f"ts_{text.replace(' ', '_').replace(':', '-')}.mp4"
    vw = cv2.VideoWriter(tmp, FOURCC, fps, size)
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
    vw = cv2.VideoWriter(out, FOURCC, fps, size)
    for p in parts:
        cap = cv2.VideoCapture(p)
        while True:
            ok, f = cap.read()
            if not ok: break
            vw.write(f)
        cap.release()
    vw.release()
    return out

def plot_and_save_ground_truth_labels(file_path, key):
    print(f"[INFO] Plotting ground truth for key: {key}")
    data = np.load(file_path)
    labels = data[key]
    plt.figure(figsize=(10, 4))
    plt.plot(labels, label="Ground Truth Anomalies")
    plt.title(f"Ground Truth Anomalies - {key}")
    plt.xlabel("Frame"); plt.ylabel("Anomaly Label")
    plt.legend(); plt.grid(True)
    out = os.path.join(GROUND_TRUTH, f"{key}_groundtruth.png")
    plt.savefig(out); plt.close()
    print(f"[INFO] Saved ground truth plot at: {out}")
    return os.path.basename(out)

class ProcessVideoResponse(BaseModel):
    original_video: str
    clips: List[str]
    summary_file: str
    ground_truth_files: List[str]

@app.post("/process_video/", response_model=ProcessVideoResponse)
async def process_video(IN_VIDEO: UploadFile = File(...)):
    key = os.path.splitext(IN_VIDEO.filename)[0]

    # 0) clean out old files for this key
    clean_dirs(key)

    # 1) save the upload
    orig_path = os.path.join(ORIGINAL_DIR, IN_VIDEO.filename)
    with open(orig_path, "wb") as f:
        f.write(await IN_VIDEO.read())

    # 2) ground truth plot
    gt_file = plot_and_save_ground_truth_labels("NWPU_Campus_gt.npz", key)

    # 3) YOLO + RAFT → process video
    YOLO_WEIGHTS = "models/yolov8x.pt"
    RAFT_PATH    = "models/raft-things.pth"
    CONF_T, RAFT_TH, MARGIN_S, GAP_S = 0.50, 0.1, 5.0, 4.0

    OUT_FULL     = f"processed_{key}{EXT}"
    OUT_COMBINED = f"combined_{key}{EXT}"

    yolo       = YOLO(YOLO_WEIGHTS)
    raft_model = load_raft(RAFT_PATH)
    cap        = cv2.VideoCapture(orig_path)
    if not cap.isOpened():
        raise HTTPException(400, "Uploaded file is not a valid video.")

    fps     = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total   = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    vlen    = total / fps
    size    = (1280, 720)
    writer  = cv2.VideoWriter(OUT_FULL, FOURCC, fps, size)

    prev, times, idx = None, [], 0

    print(f"[INFO] Processing {total} frames...")
    while True:
        ok, frm = cap.read()
        if not ok:
            break
        idx += 1
        frm = cv2.resize(frm, size)

        # green box detection
        boxes = detect_people(frm, yolo, CONF_T)
        for x1,y1,x2,y2,_ in boxes:
            cv2.rectangle(frm, (x1,y1), (x2,y2), (0,255,0), 2)

        # optical flow
        if prev is not None:
            flow = compute_raft_flow(raft_model, prev, frm)
            if np.mean(np.linalg.norm(flow, axis=-1)) > RAFT_TH:
                t = idx / fps
                times.append(t)
                for x1,y1,x2,y2,_ in boxes:
                    cv2.rectangle(frm, (x1,y1), (x2,y2), (0,0,255), 2)
                cv2.imwrite(os.path.join(FRAME_DIR, f"frame_{idx:06d}.jpg"), frm)

        writer.write(frm)
        prev = frm.copy()

    cap.release(); writer.release()

    # 4) cut & stitch
    segments  = find_abnormal_segments(times, GAP_S)
    clip_files = []
    for i,(s,e) in enumerate(segments, start=1):
        start = max(0, s - MARGIN_S)
        end   = min(vlen, e + MARGIN_S)
        outfn = os.path.join(CLIP_DIR, f"clip_{i:02d}{EXT}")
        export_clip(OUT_FULL, start, end, outfn, fps, size)
        clip_files.append((outfn,(s,e)))

    # 5) upload & summarize
    if clip_files:
        combined = stitch_clips(
            [p for p,_ in clip_files],
            [seg for _,seg in clip_files],
            OUT_COMBINED, size, fps
        )
        fh = gclient.files.upload(file=combined)
        time.sleep(10)  # give upload a moment

        prompt = """       
        
                You will receive a video input where abnormal events are marked with red bounding boxes. These events should be described in plain, non-technical language, without mentioning any detection methods, models, or technical terms such as "optical flow," "tracking," or specific algorithms.

                Your task is to identify and describe each unusual or abnormal event using everyday language that a general audience can easily understand.

                Instructions:
                1. Use the timestamp or timestamp range provided in the video. Each timestamp marks a separate anomaly and should be addressed individually.

                2. For each timestamp:
                - Clearly describe the behavior or action taking place within the red bounding box.
                - Explain why the behavior appears unusual, unexpected, unsafe, or out of place, based on common sense or typical social/situational norms.
                - Avoid technical explanations. Focus on real-world logic, safety, and everyday expectations.

                3. Tone and style:
                - Keep the language natural, concise, and descriptive, as if writing for a safety or incident report.
                - Avoid introductory or filler statements at all cost.
                - Do not speculate beyond what is visually evident in the video.

                4. Format:
                - Begin each entry with the timestamp or timestamp range in square brackets (e.g., [00:01:12 – 00:01:18]).
                - Follow with a brief paragraph describing what happens and why it is considered abnormal.

                Example Output:
                [00:01:00 – 00:01:05] A person is riding a bicycle while holding an umbrella. This reduces visibility and balance, making it risky and unexpected behavior, especially in a busy area.

                [00:02:14] One individual suddenly sprints through a calm crowd where everyone else is walking slowly. The abrupt motion draws attention and feels out of place in the otherwise steady scene.
                """
        res = gclient.models.generate_content(
            model="models/gemini-2.0-flash",
            contents=[fh, prompt]
        )
        with open("summaries.json","w") as jf:
            json.dump({"response":res.text}, jf, indent=2)
        summary_file = "summaries.json"
    else:
        summary_file = ""
    # summary_file = ""

    return JSONResponse({
        "original_video": IN_VIDEO.filename,
        "clips": [os.path.basename(p) for p,_ in clip_files],
        "summary_file": summary_file,
        "ground_truth_files": [gt_file],
    })

@app.get("/originals/{filename}")
async def get_original(request: Request, filename: str):
    path = os.path.join(ORIGINAL_DIR, filename)
    return await _range_file(request, path, "video/mp4")

@app.get("/clips/{filename}")
async def get_clip(request: Request, filename: str):
    path = os.path.join(CLIP_DIR, filename)
    return await _range_file(request, path, "video/mp4")

@app.get("/summaries")
async def get_summaries():
    if not os.path.exists("summaries.json"):
        raise HTTPException(404, "Not found")
    return FileResponse("summaries.json", media_type="application/json")

@app.get("/groundtruth/{filename}")
async def get_groundtruth(filename: str):
    path = os.path.join(GROUND_TRUTH, filename)
    if not os.path.exists(path):
        raise HTTPException(404, "Not found")
    return FileResponse(path, media_type="image/png")

async def _range_file(request: Request, path: str, media_type: str):
    if not os.path.exists(path):
        raise HTTPException(404, "Not found")
    file_size    = os.path.getsize(path)
    range_header = request.headers.get("range")
    if range_header:
        m = re.match(r"bytes=(\d+)-(\d*)", range_header)
        if m:
            start = int(m.group(1))
            end   = int(m.group(2)) if m.group(2) else file_size - 1
            end   = min(end, file_size - 1)
            length = end - start + 1
            def iterfile():
                with open(path, "rb") as f:
                    f.seek(start)
                    remaining = length
                    while remaining > 0:
                        chunk = f.read(min(1024*1024, remaining))
                        if not chunk:
                            break
                        remaining -= len(chunk)
                        yield chunk
            headers = {
                "Content-Range": f"bytes {start}-{end}/{file_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(length),
            }
            return StreamingResponse(iterfile(), status_code=206, headers=headers, media_type=media_type)
    return FileResponse(path, media_type=media_type)

if __name__ == "__main__":
    
    uvicorn.run(app, host="0.0.0.0", port=8000)