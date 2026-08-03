DELAY_BETWEEN_REQUESTS = 15  # ← EDIT THIS: seconds between each clip request

# ─── API KEYS ─────────────────────────────────────────────────────────────────
NIM_API_KEY = ""  # Your NVIDIA NIM key — nvapi-...
                  # Note: Cosmos video needs enterprise access (free tier = 404)
                  # App works fully with Hugging Face fallback below ↓

# ─── HUGGING FACE SPACES (free, no key needed) ────────────────────────────────
# These are tried in ORDER — if Space 1 busy/fails → Space 2 → Space 3
HF_SPACES = [
    "THUDM/CogVideoX-5B-Space",     # Best quality, T2V + I2V
    "Tencent/HunyuanVideo",          # Excellent motion quality
    "multimodalart/stable-video-diffusion",  # Fast, image-to-video
]

# ─── VIDEO PROMPTS ────────────────────────────────────────────────────────────
# GOJO vs SUKUNA — Jujutsu Kaisen (9-scene epic fight sequence)
VIDEO_PROMPTS = [
    # Scene 1: Sukuna's Inner Domain & Binding Vow
    "Cinematic anime animation, Ryomen Sukuna sitting atop a giant throne made of animal skulls inside his dark red inner domain, glowing menacing red eyes, dark facial markings, dark red cursed aura floating, sinister lighting, Jujutsu Kaisen anime style, hyper-detailed 8k resolution, dramatic camera angle.",
    # Scene 2: High-Speed Taijutsu & Unmasking Six Eyes
    "Fast-paced anime fight scene, Satoru Gojo pulling down black blindfold to reveal bright glowing cyan Six Eyes, martial arts clash with Ryomen Sukuna, supersonic impact shockwaves, dust particles flying, intense motion blur, dramatic camera dynamic movement, highly detailed.",
    # Scene 3: Domain Expansion Clash
    "Dynamic anime action shot, Satoru Gojo performing Unlimited Void hand sign alongside Sukuna making Malevolent Shrine hand sign, dark red energy slashing waves colliding with cosmic purple infinity space, domain expansion clash, cinematic electric lightning effects, 4k anime masterpiece.",
    # Scene 4: Reversal Red & Black Flash Impact
    "Extreme close-up anime shot, Satoru Gojo firing Cursed Technique Reversal Red, a glowing bright crimson energy orb floating on his index finger, followed by a heavy fist punch surrounded by red and black electric lightning spatial distortion, dramatic lighting, highly detailed combat animation.",
    # Scene 5: Maximum Output Blue & Hollow Purple Collision
    "Epic anime animation, Satoru Gojo chanting with floating dark energy particles, blue and red spherical energies colliding in mid-air to create a massive glowing purple void sphere, space-distorting energy waves, dramatic night sky background, cinematic lighting.",
    # Scene 6: "Nah, I'd Win" Confident Flashback
    "Anime character portrait, Satoru Gojo with spiky white hair, bright glowing blue Six Eyes visible through black blindfold glasses, arrogant confident smirk, clean crisp anime illustration, soft backlight, highly detailed character design, Jujutsu Kaisen style.",
    # Scene 7: Mahoraga's Wheel Adaptation Phase
    "Dark anime scene, Eight-handled adaptation wheel floating behind Sukuna spinning with dark cursed aura, golden metallic wheel texture, ominous shadowy presence, subtle smoke particles, dramatic atmospheric lighting, adaptation process effect, Jujutsu Kaisen style.",
    # Scene 8: World Bisecting Slash (World Cutting Slash)
    "Wide cinematic anime shot, Ryomen Sukuna executing World Cutting Slash, massive invisible spatial distortion cutting through the entire environment and space, reality splitting effect, black and red slash trails, epic destructive shockwave, Jujutsu Kaisen style.",
    # Scene 9: Sukuna's Respectful Aftermath
    "Cinematic anime aftermath scene, Ryomen Sukuna standing victorious amidst smoke, ashes, and battlefield debris, evil yet respectful expression, dark sunset sky, floating embers, intense atmosphere, masterpiece quality animation, Jujutsu Kaisen style.",
]

# ─── GENERATION SETTINGS ─────────────────────────────────────────────────────
VIDEO_WIDTH      = 1280
VIDEO_HEIGHT     = 720
NUM_FRAMES       = 360      # 15 seconds at 24fps (NIM) | HF caps at 49 automatically
GUIDANCE_SCALE   = 6.0
INFERENCE_STEPS  = 50
MAX_RETRIES      = 3        # per clip before switching to HF
OUTPUT_DIR       = "output_clips"
FINAL_VIDEO      = "final_video.mp4"

# Quality words injected into every prompt automatically
QUALITY_BOOST = (
    ", cinematic lighting, ultra-realistic textures, 8k resolution, "
    "highly detailed, hyper-detailed, seamless motion, photorealistic, "
    "no artifacts, no distortion, raw footage style"
)

# ─── DO NOT EDIT BELOW (unless you know what you're doing) ───────────────────
import os
import sys
import time
import json
import base64
import subprocess
import requests
import tempfile
from pathlib import Path
from datetime import datetime

# ── Terminal colors (works on Replit + most terminals) ──
class C:
    CYAN   = "\033[96m"
    GREEN  = "\033[92m"
    YELLOW = "\033[93m"
    RED    = "\033[91m"
    BOLD   = "\033[1m"
    DIM    = "\033[2m"
    RESET  = "\033[0m"

def log(symbol, msg, color=C.RESET):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"{C.DIM}[{ts}]{C.RESET} {color}{symbol} {msg}{C.RESET}")

def ok(msg):    log("✓", msg, C.GREEN)
def info(msg):  log("+", msg, C.CYAN)
def warn(msg):  log("!", msg, C.YELLOW)
def err(msg):   log("✗", msg, C.RED)
def step(msg):  log("▷", msg, C.BOLD)

# ── NIM API ──────────────────────────────────────────────────────────────────
NIM_URL = "https://integrate.api.nvidia.com/v1/video/nvidia/cosmos-1.0-diffusion"

def nim_generate(prompt: str, ref_image_b64: str = None) -> bytes | None:
    """Call NVIDIA NIM Cosmos. Returns raw video bytes or None."""
    if not NIM_API_KEY:
        return None

    headers = {
        "Authorization": f"Bearer {NIM_API_KEY}",
        "Content-Type":  "application/json",
    }
    body = {
        "prompt":               prompt + QUALITY_BOOST,
        "width":                VIDEO_WIDTH,
        "height":               VIDEO_HEIGHT,
        "num_frames":           NUM_FRAMES,
        "fps":                  24,
        "guidance_scale":       GUIDANCE_SCALE,
        "num_inference_steps":  INFERENCE_STEPS,
    }
    if ref_image_b64:
        body["image"] = f"data:image/jpeg;base64,{ref_image_b64}"

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            info(f"NIM attempt {attempt}/{MAX_RETRIES}...")
            r = requests.post(NIM_URL, headers=headers, json=body, timeout=300)

            if r.status_code == 429:
                wait = 5 * (2 ** (attempt - 1))  # 5, 10, 20 seconds
                warn(f"429 Rate limit → waiting {wait}s...")
                time.sleep(wait)
                continue

            if r.status_code == 404:
                warn("NIM Cosmos = enterprise only (404). Switching to Hugging Face...")
                return None

            if r.status_code == 402:
                warn("NIM = payment required. Switching to Hugging Face...")
                return None

            r.raise_for_status()
            data = r.json()

            # Extract video bytes
            b64 = (
                data.get("video")
                or (data.get("artifacts", [{}])[0].get("base64"))
            )
            if b64:
                return base64.b64decode(b64)

            # Download URL response
            url = data.get("download_url") or data.get("url")
            if url:
                resp = requests.get(url, timeout=120)
                return resp.content

        except requests.Timeout:
            warn(f"NIM timeout on attempt {attempt}")
        except Exception as e:
            warn(f"NIM error: {str(e)[:80]}")

    return None


# ── HUGGING FACE FALLBACK ─────────────────────────────────────────────────────
def hf_generate(prompt: str, space: str, ref_image_path: str = None) -> str | None:
    """
    Call a Hugging Face Gradio space. Returns path to downloaded video or None.
    Uses gradio_client — install: pip install gradio_client
    """
    try:
        from gradio_client import Client, handle_file
    except ImportError:
        err("gradio_client not installed. Run: pip install gradio_client")
        return None

    try:
        info(f"Connecting to HF space: {space}")
        client = Client(space, verbose=False)
        api_info = client.view_api(print_info=False, return_format="dict")

        # Detect API endpoint name
        endpoints = list(api_info.get("named_endpoints", {}).keys())
        api_name = next(
            (e for e in ["/generate_video", "/predict", "/infer", "/run"] if e in endpoints),
            endpoints[0] if endpoints else "/predict"
        )
        info(f"Using endpoint: {api_name}")

        enhanced = prompt + QUALITY_BOOST

        # Build kwargs based on space
        # HF spaces have max frame limits — CogVideoX caps at 49 (~6s), HunyuanVideo at ~8s
        HF_MAX_FRAMES = min(NUM_FRAMES, 49)  # CogVideoX hard limit
        kwargs = {}
        if "CogVideoX" in space:
            kwargs = {
                "prompt":               enhanced,
                "num_inference_steps":  INFERENCE_STEPS,
                "guidance_scale":       GUIDANCE_SCALE,
                "num_frames":           HF_MAX_FRAMES,
            }
            if ref_image_path:
                kwargs["image"]         = handle_file(ref_image_path)
                api_name                = "/generate_video"

        elif "HunyuanVideo" in space or "Tencent" in space:
            kwargs = {
                "prompt":       enhanced,
                "resolution":   "720p",
                "video_length": "8s",   # max supported by HunyuanVideo space
            }

        elif "stable-video" in space.lower():
            # SVD is image-to-video
            if ref_image_path:
                kwargs["image"] = handle_file(ref_image_path)
            else:
                warn(f"SVD needs a reference image — skipping")
                return None
        else:
            kwargs = {"prompt": enhanced}

        info(f"Submitting job to {space}...")
        result = client.predict(**kwargs, api_name=api_name)

        # Result might be a file path, tuple, or dict
        if isinstance(result, (list, tuple)):
            result = result[0]
        if isinstance(result, dict):
            result = result.get("video") or result.get("output") or list(result.values())[0]

        if result and os.path.exists(str(result)):
            return str(result)

        warn(f"HF result format unexpected: {type(result)}")
        return None

    except Exception as e:
        err_msg = str(e)
        if "is currently unavailable" in err_msg or "overloaded" in err_msg.lower():
            warn(f"{space} is busy/overloaded")
        elif "No such endpoint" in err_msg:
            warn(f"Endpoint not found on {space}")
        else:
            warn(f"HF error on {space}: {err_msg[:120]}")
        return None


# ── FFMPEG: extract last frame ─────────────────────────────────────────────────
def extract_last_frame(video_path: str) -> str | None:
    """Extract last frame of a video as JPEG for frame-continuation."""
    try:
        # Get duration
        probe = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", video_path],
            capture_output=True, text=True, timeout=15
        )
        duration = float(probe.stdout.strip())
        seek_t   = max(0.0, duration - 0.15)

        frame_path = video_path.replace(".mp4", "_lastframe.jpg")
        subprocess.run(
            ["ffmpeg", "-y", "-ss", str(seek_t), "-i", video_path,
             "-vframes", "1", "-q:v", "2", frame_path],
            capture_output=True, timeout=20
        )
        if os.path.exists(frame_path):
            ok(f"Last frame extracted → {os.path.basename(frame_path)}")
            return frame_path
    except Exception as e:
        warn(f"Frame extract failed: {e}")
    return None


# ── FFMPEG: concatenate all clips ─────────────────────────────────────────────
def concat_clips(clip_paths: list, output: str) -> bool:
    """Merge all clips into one final MP4 (lossless stream copy)."""
    list_file = output.replace(".mp4", "_list.txt")
    try:
        with open(list_file, "w") as f:
            for p in clip_paths:
                f.write(f"file '{os.path.abspath(p)}'\n")

        step(f"FFmpeg: concatenating {len(clip_paths)} clips...")
        result = subprocess.run(
            ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list_file,
             "-c", "copy", output],  # lossless -c copy (fast)
            capture_output=True, text=True, timeout=600
        )
        os.remove(list_file)

        if result.returncode == 0:
            size_mb = os.path.getsize(output) / (1024 * 1024)
            ok(f"Final video saved! {output} ({size_mb:.1f} MB)")
            return True
        else:
            # Fallback: re-encode if stream copy fails
            warn("Stream copy failed. Trying re-encode...")
            result2 = subprocess.run(
                ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list_file,
                 "-c:v", "libx264", "-preset", "fast", "-crf", "23",
                 "-pix_fmt", "yuv420p", output],
                capture_output=True, timeout=600
            )
            return result2.returncode == 0

    except Exception as e:
        err(f"Concat failed: {e}")
        return False


# ── SAVE video bytes to file ──────────────────────────────────────────────────
def save_clip(data: bytes | str, clip_path: str) -> bool:
    """Save raw bytes or copy a file to clip_path."""
    try:
        if isinstance(data, bytes):
            with open(clip_path, "wb") as f:
                f.write(data)
        else:
            import shutil
            shutil.copy2(data, clip_path)
        size_kb = os.path.getsize(clip_path) / 1024
        ok(f"Clip saved → {os.path.basename(clip_path)} ({size_kb:.0f} KB)")
        return True
    except Exception as e:
        err(f"Save failed: {e}")
        return False


# ── MAIN PIPELINE ─────────────────────────────────────────────────────────────
def main():
    print()
    print(f"{C.BOLD}{C.CYAN}{'='*48}{C.RESET}")
    print(f"{C.BOLD}{C.CYAN}  COSMOS — Long-Form Video Generator v1.0{C.RESET}")
    print(f"{C.BOLD}{C.CYAN}{'='*48}{C.RESET}")
    print()

    total = len(VIDEO_PROMPTS)
    info(f"Total clips to generate: {total}")
    info(f"Delay between clips:     {DELAY_BETWEEN_REQUESTS}s")
    info(f"NIM API:                 {'Configured' if NIM_API_KEY else 'Not set → HF fallback'}")
    info(f"HF Spaces:               {', '.join(HF_SPACES)}")
    print()

    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    clip_paths      = []
    last_frame_path = None  # Used for image-to-video frame continuation
    last_frame_b64  = None

    for i, prompt in enumerate(VIDEO_PROMPTS, 1):
        step(f"Generating Clip {i}/{total}...")
        info(f"Scene: {prompt[:70]}...")

        clip_out  = os.path.join(OUTPUT_DIR, f"clip_{i:04d}.mp4")
        video_data = None
        source     = "?"

        # ── Try NVIDIA NIM first ────────────────────────────────────────────
        if NIM_API_KEY:
            video_data = nim_generate(prompt, ref_image_b64=last_frame_b64)
            if video_data:
                source = "NIM"

        # ── Hugging Face fallback ──────────────────────────────────────────
        if not video_data:
            if NIM_API_KEY:
                warn("NIM failed → switching to Hugging Face...")
            else:
                info("Using Hugging Face (NIM key not set)...")

            for space in HF_SPACES:
                info(f"Trying HF space: {space}")
                hf_result = hf_generate(prompt, space, ref_image_path=last_frame_path)
                if hf_result:
                    # hf_result is a file path
                    video_data = hf_result
                    source     = f"HF:{space.split('/')[1]}"
                    break
                warn(f"Space {space} failed → trying next...")
                time.sleep(3)

        # ── Save clip ───────────────────────────────────────────────────────
        if video_data:
            if save_clip(video_data, clip_out):
                clip_paths.append(clip_out)
                ok(f"Clip {i}/{total} done via {source}")

                # Extract last frame for next clip (frame continuation)
                lf = extract_last_frame(clip_out)
                if lf:
                    last_frame_path = lf
                    with open(lf, "rb") as fh:
                        last_frame_b64 = base64.b64encode(fh.read()).decode()
            else:
                err(f"Clip {i}/{total} save failed — skipping")
        else:
            err(f"Clip {i}/{total} — ALL sources failed. Skipping.")

        # ── Rate limit delay (skip after last clip) ─────────────────────────
        if i < total:
            info(f"Waiting {DELAY_BETWEEN_REQUESTS}s before next clip...")
            for remaining in range(DELAY_BETWEEN_REQUESTS, 0, -1):
                print(f"\r  ⏱  {remaining}s remaining...  ", end="", flush=True)
                time.sleep(1)
            print()

    # ── Final concatenation ─────────────────────────────────────────────────
    print()
    if len(clip_paths) == 0:
        err("No clips generated. Check your API keys and internet connection.")
        sys.exit(1)

    elif len(clip_paths) == 1:
        import shutil
        shutil.copy2(clip_paths[0], FINAL_VIDEO)
        ok(f"Single clip copied → {FINAL_VIDEO}")

    else:
        step(f"Stitching {len(clip_paths)}/{total} clips into final video...")
        if not concat_clips(clip_paths, FINAL_VIDEO):
            err("FFmpeg concat failed. Clips are in:", OUTPUT_DIR)
            sys.exit(1)

    print()
    print(f"{C.BOLD}{C.GREEN}{'='*48}{C.RESET}")
    print(f"{C.BOLD}{C.GREEN}  ✓ DONE! Final video: {FINAL_VIDEO}{C.RESET}")
    print(f"{C.GREEN}  Clips generated: {len(clip_paths)}/{total}{C.RESET}")
    size = os.path.getsize(FINAL_VIDEO) / (1024 * 1024) if os.path.exists(FINAL_VIDEO) else 0
    print(f"{C.GREEN}  File size: {size:.1f} MB{C.RESET}")
    print(f"{C.BOLD}{C.GREEN}{'='*48}{C.RESET}")
    print()


if __name__ == "__main__":
    main()
