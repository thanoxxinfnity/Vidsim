"""
Cosmos Long-Form Video Generator — Python Backend
Mirrors the Flutter app's pipeline for desktop/server use.

Usage:
  python cosmos_generator.py --prompt "Your video concept" --scenes 20 --title "My Video"
  python cosmos_generator.py --youtube "https://youtube.com/watch?v=..." --title "My Video"

Requirements: pip install -r requirements.txt
Also requires: ffmpeg installed on system PATH
"""

import os
import sys
import time
import base64
import json
import argparse
import subprocess
import tempfile
import requests
from pathlib import Path
from typing import Optional, List
from tqdm import tqdm

# ── Config (set via env vars or args) ─────────────────────────────────────────
NIM_API_KEY: str = os.getenv("NIM_API_KEY", "")
YT_API_KEY:  str = os.getenv("YT_API_KEY", "")
COSMOS_URL    = os.getenv("COSMOS_URL",
    "https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-diffusion")
LLAMA_URL     = "https://integrate.api.nvidia.com/v1/chat/completions"
LLAMA_MODEL   = "meta/llama-3.1-8b-instruct"
OUTPUT_DIR    = Path(os.getenv("OUTPUT_DIR", "./output"))
MAX_RPM       = 40
MIN_INTERVAL  = 60.0 / MAX_RPM  # seconds

QUALITY_BOOST = (
    ", cinematic lighting, ultra-realistic textures, 8k resolution, "
    "highly detailed physics, hyper-detailed, seamless motion blur, "
    "raw footage style, photorealistic, no artifacts, no distortion"
)

# ── Rate limiter ──────────────────────────────────────────────────────────────
_last_call_time = 0.0

def _rate_limit():
    global _last_call_time
    elapsed = time.monotonic() - _last_call_time
    if elapsed < MIN_INTERVAL:
        time.sleep(MIN_INTERVAL - elapsed)
    _last_call_time = time.monotonic()


def _headers():
    return {
        "Authorization": f"Bearer {NIM_API_KEY}",
        "Content-Type": "application/json",
    }


# ── Scene breakdown via LLaMA ─────────────────────────────────────────────────
def breakdown_to_scenes(raw_prompt: str, n: int = 20) -> List[str]:
    print(f"[AI] Breaking prompt into {n} scenes using LLaMA...")
    _rate_limit()

    system = (
        f"You are a video scene planner. Given a video concept, split it into exactly {n} "
        "short (1-2 sentence) cinematic scene descriptions for sequential video generation. "
        "Return ONLY a numbered list (1 to N). No extra text."
    )
    body = {
        "model": LLAMA_MODEL,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user",   "content": raw_prompt},
        ],
        "max_tokens": 1024,
        "temperature": 0.7,
    }

    try:
        r = requests.post(LLAMA_URL, headers=_headers(), json=body, timeout=30)
        r.raise_for_status()
        content = r.json()["choices"][0]["message"]["content"]
        scenes = []
        for line in content.split("\n"):
            clean = line.strip()
            if clean and clean[0].isdigit():
                # Strip "1. " prefix
                parts = clean.split(". ", 1)
                if len(parts) > 1:
                    scenes.append(parts[1].strip())
        if scenes:
            print(f"[AI] Generated {len(scenes)} scenes.")
            return scenes
    except Exception as e:
        print(f"[WARN] LLaMA scene breakdown failed: {e}. Using simple split.")

    # Fallback: split by sentences
    sentences = [s.strip() for s in raw_prompt.replace("\n", " ").split(". ") if len(s.strip()) > 20]
    return sentences[:n] if sentences else [raw_prompt]


# ── YouTube transcript → scenes ────────────────────────────────────────────────
def youtube_to_scenes(url: str, words_per_scene: int = 80) -> List[str]:
    try:
        from youtube_transcript_api import YouTubeTranscriptApi
    except ImportError:
        print("[ERROR] Install youtube-transcript-api: pip install youtube-transcript-api")
        sys.exit(1)

    # Extract video ID
    vid_id = None
    if "v=" in url:
        vid_id = url.split("v=")[1].split("&")[0]
    elif "youtu.be/" in url:
        vid_id = url.split("youtu.be/")[1].split("?")[0]
    if not vid_id:
        print("[ERROR] Could not extract video ID from URL.")
        sys.exit(1)

    print(f"[YT] Fetching transcript for video ID: {vid_id}")
    try:
        transcript = YouTubeTranscriptApi.get_transcript(vid_id)
    except Exception as e:
        print(f"[ERROR] Transcript not available: {e}")
        sys.exit(1)

    # Group into scenes
    scenes, buf, word_count = [], [], 0
    for entry in transcript:
        words = entry["text"].split()
        buf.extend(words)
        word_count += len(words)
        if word_count >= words_per_scene:
            scenes.append(" ".join(buf))
            buf.clear()
            word_count = 0
    if buf:
        scenes.append(" ".join(buf))

    print(f"[YT] Extracted {len(scenes)} scenes from transcript.")
    return scenes


# ── Generate video clip ────────────────────────────────────────────────────────
def generate_clip(
    prompt: str,
    output_path: str,
    ref_image_path: Optional[str] = None,
    width: int = 1280,
    height: int = 720,
    num_frames: int = 121,
    fps: int = 24,
    guidance: float = 7.5,
    steps: int = 35,
    retries: int = 3,
) -> bool:
    enhanced = prompt + QUALITY_BOOST
    body = {
        "prompt":               enhanced,
        "width":                width,
        "height":               height,
        "num_frames":           num_frames,
        "fps":                  fps,
        "guidance_scale":       guidance,
        "num_inference_steps":  steps,
    }

    # Image-to-video: embed reference frame
    if ref_image_path and os.path.exists(ref_image_path):
        with open(ref_image_path, "rb") as f:
            img_b64 = base64.b64encode(f.read()).decode()
        body["image"] = f"data:image/jpeg;base64,{img_b64}"
        mode = "img2vid"
    else:
        mode = "txt2vid"

    for attempt in range(1, retries + 1):
        _rate_limit()
        print(f"  [API] {mode} attempt {attempt}/{retries}...")
        try:
            r = requests.post(COSMOS_URL, headers=_headers(), json=body, timeout=600)

            if r.status_code == 429:
                wait = 5 * attempt
                print(f"  [RATE LIMIT] Waiting {wait}s...")
                time.sleep(wait)
                continue

            if r.status_code in (402, 404):
                print(f"  [ERROR] {r.status_code}: {r.text[:200]}")
                print("  Cosmos video generation requires enterprise NIM access.")
                return False

            r.raise_for_status()
            data = r.json()

            # Extract video bytes
            video_b64 = (
                data.get("video")
                or (data.get("artifacts", [{}])[0].get("base64") if data.get("artifacts") else None)
            )

            if video_b64:
                video_bytes = base64.b64decode(video_b64)
                with open(output_path, "wb") as f:
                    f.write(video_bytes)
                return True

            # Async polling
            job_id  = data.get("id") or data.get("job_id")
            poll_url = r.headers.get("Location") or data.get("status_url")
            if job_id and poll_url:
                return _poll_job(job_id, poll_url, output_path)

            print(f"  [WARN] Unknown response: {list(data.keys())}")
            return False

        except requests.Timeout:
            print(f"  [TIMEOUT] attempt {attempt}")
        except requests.HTTPError as e:
            print(f"  [HTTP ERROR] {e.response.status_code}: {e.response.text[:200]}")
            if attempt == retries:
                return False

    return False


def _poll_job(job_id: str, poll_url: str, output_path: str, timeout: int = 1200) -> bool:
    print(f"  [POLL] Async job {job_id}")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        time.sleep(5)
        _rate_limit()
        try:
            r = requests.get(poll_url, headers=_headers(), timeout=30)
            data = r.json()
            status = str(data.get("status", "")).lower()
            if status in ("completed", "succeeded", "success"):
                video_b64 = data.get("video") or (data.get("artifacts", [{}])[0].get("base64") if data.get("artifacts") else None)
                if video_b64:
                    with open(output_path, "wb") as f:
                        f.write(base64.b64decode(video_b64))
                    return True
                url = data.get("download_url") or data.get("url")
                if url:
                    resp = requests.get(url, timeout=120)
                    with open(output_path, "wb") as f:
                        f.write(resp.content)
                    return True
            elif status in ("failed", "error"):
                print(f"  [JOB FAILED] {data.get('error', 'unknown')}")
                return False
        except Exception as e:
            print(f"  [POLL ERROR] {e}")
    print("  [TIMEOUT] Job timed out")
    return False


# ── Extract last frame via FFmpeg ─────────────────────────────────────────────
def extract_last_frame(video_path: str) -> Optional[str]:
    try:
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", video_path],
            capture_output=True, text=True, timeout=30
        )
        duration = float(result.stdout.strip())
        seek_t   = max(0.0, duration - 0.1)

        frame_path = video_path.replace(".mp4", "_last.jpg")
        subprocess.run(
            ["ffmpeg", "-y", "-ss", str(seek_t), "-i", video_path,
             "-vframes", "1", "-q:v", "2", frame_path],
            capture_output=True, timeout=30
        )
        return frame_path if os.path.exists(frame_path) else None
    except Exception as e:
        print(f"  [FFmpeg] Frame extraction failed: {e}")
        return None


# ── Concatenate clips ─────────────────────────────────────────────────────────
def concatenate_clips(clip_paths: List[str], output_path: str) -> bool:
    list_file = output_path.replace(".mp4", "_list.txt")
    with open(list_file, "w") as f:
        for p in clip_paths:
            f.write(f"file '{p}'\n")

    print(f"[FFmpeg] Concatenating {len(clip_paths)} clips → {output_path}")
    result = subprocess.run(
        ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list_file,
         "-c:v", "libx264", "-preset", "fast", "-crf", "18",
         "-pix_fmt", "yuv420p", "-movflags", "+faststart", output_path],
        capture_output=True, text=True, timeout=3600
    )
    os.remove(list_file)
    return result.returncode == 0


# ── Main pipeline ─────────────────────────────────────────────────────────────
def run_pipeline(
    scenes: List[str],
    title: str,
    width: int = 1280,
    height: int = 720,
    num_frames: int = 121,
):
    if not NIM_API_KEY:
        print("[ERROR] NIM_API_KEY not set. export NIM_API_KEY=nvapi-...")
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp = tempfile.mkdtemp()

    clip_paths       = []
    last_frame_path  = None

    print(f"\n{'='*60}")
    print(f"  COSMOS — Generating {len(scenes)} clips for '{title}'")
    print(f"  Resolution: {width}x{height} | Frames/clip: {num_frames}")
    print(f"{'='*60}\n")

    with tqdm(total=len(scenes), desc="Generating clips", unit="clip") as pbar:
        for i, scene in enumerate(scenes):
            clip_out = os.path.join(tmp, f"clip_{i:04d}.mp4")
            print(f"\n[{i+1}/{len(scenes)}] {scene[:80]}...")

            ok = generate_clip(
                prompt=         scene,
                output_path=    clip_out,
                ref_image_path= last_frame_path,
                width=          width,
                height=         height,
                num_frames=     num_frames,
            )

            if ok:
                clip_paths.append(clip_out)
                last_frame_path = extract_last_frame(clip_out)
                pbar.set_postfix({"done": len(clip_paths), "last_frame": bool(last_frame_path)})
            else:
                print(f"  [SKIP] Scene {i+1} failed.")

            pbar.update(1)

    if not clip_paths:
        print("\n[ERROR] No clips generated.")
        return

    safe_title = "".join(c for c in title if c.isalnum() or c in " _-").strip().replace(" ", "_")
    ts         = int(time.time())
    final_path = str(OUTPUT_DIR / f"{safe_title}_{ts}.mp4")

    print(f"\n[STITCH] Concatenating {len(clip_paths)} clips...")
    if concatenate_clips(clip_paths, final_path):
        size = os.path.getsize(final_path) / (1024 * 1024)
        print(f"\n✅ Done! Output: {final_path} ({size:.1f} MB)")
    else:
        print("\n[ERROR] Concatenation failed. Individual clips are in:", tmp)


# ── CLI ────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cosmos Long-Form Video Generator")
    parser.add_argument("--prompt",   type=str, help="Video concept / script")
    parser.add_argument("--youtube",  type=str, help="YouTube video URL")
    parser.add_argument("--scenes",   type=int, default=20, help="Number of scenes")
    parser.add_argument("--title",    type=str, default="Cosmos_Video")
    parser.add_argument("--width",    type=int, default=1280)
    parser.add_argument("--height",   type=int, default=720)
    parser.add_argument("--frames",   type=int, default=121)
    parser.add_argument("--nim-key",  type=str, help="NVIDIA NIM API key")
    parser.add_argument("--yt-key",   type=str, help="YouTube API key")
    args = parser.parse_args()

    if args.nim_key: NIM_API_KEY = args.nim_key
    if args.yt_key:  YT_API_KEY  = args.yt_key

    if args.youtube:
        scenes = youtube_to_scenes(args.youtube)
    elif args.prompt:
        scenes = breakdown_to_scenes(args.prompt, n=args.scenes)
    else:
        parser.print_help()
        sys.exit(1)

    run_pipeline(
        scenes=     scenes,
        title=      args.title,
        width=      args.width,
        height=     args.height,
        num_frames= args.frames,
    )
