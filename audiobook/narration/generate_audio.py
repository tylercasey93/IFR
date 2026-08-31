#!/usr/bin/env python3
"""
Renders tagged chapter text (audiobook/narration/tagged/chNN.txt) to mp3 via
ElevenLabs, one file per chapter, using the single-voice/bracket-tag approach
documented in audiobook/narration/PRODUCTION.md.

Usage:
    export ELEVENLABS_API_KEY=...          # or put the key in narration/.elevenlabs_key (gitignored)
    python3 generate_audio.py              # render every tagged/chNN.txt with no output yet
    python3 generate_audio.py 01 04        # render only chapters 01 and 04

Requires: ffmpeg on PATH.
"""
import os, re, sys, json, time, subprocess, urllib.request, urllib.error

HERE = os.path.dirname(os.path.abspath(__file__))
TAGGED_DIR = os.path.join(HERE, "tagged")
OUTPUT_DIR = os.path.join(HERE, "output")
KEY_FILE = os.path.join(HERE, ".elevenlabs_key")

VOICE_ID = "7S3KNdLDL7aRgBVRQb1z"  # Nathaniel — single voice for the whole book, see PRODUCTION.md
MODEL_ID = "eleven_v3"
MAX_CHUNK = 3800


def get_api_key():
    key = os.environ.get("ELEVENLABS_API_KEY")
    if key:
        return key.strip()
    if os.path.exists(KEY_FILE):
        return open(KEY_FILE).read().strip()
    sys.exit(
        "No ElevenLabs API key found. Set ELEVENLABS_API_KEY, or put the key "
        f"in {KEY_FILE} (gitignored, do not commit it)."
    )


def chunk_scene(scene, max_len=MAX_CHUNK):
    if len(scene) <= max_len:
        return [scene]
    paras = scene.split("\n\n")
    chunks, cur = [], ""
    for p in paras:
        candidate = (cur + "\n\n" + p) if cur else p
        if len(candidate) > max_len and cur:
            chunks.append(cur)
            cur = p
        else:
            cur = candidate
    if cur:
        chunks.append(cur)
    return chunks


def build_chunks(path):
    text = open(path, encoding="utf-8").read().strip()
    scenes = [s.strip() for s in text.split("\n---\n") if s.strip()]
    out = []
    for i, scene in enumerate(scenes):
        for j, c in enumerate(chunk_scene(scene)):
            out.append((c, j == 0 and i > 0))  # True = this chunk opens a new scene (needs a longer pause before it)
    return out


def slugify_title(first_line):
    # first_line looks like "Chapter One: Meridian Five-Fifty."
    title = first_line.split(":", 1)[-1].strip().rstrip(".")
    slug = re.sub(r"[^A-Za-z0-9]+", "-", title).strip("-")
    return slug


def tts_call(key, text, out_path, retries=5):
    if os.path.exists(out_path) and os.path.getsize(out_path) > 500:
        print(f"  [skip, exists] {out_path}")
        return
    payload = {"text": text, "model_id": MODEL_ID, "output_format": "mp3_44100_128"}
    # eleven_v3 does not currently support previous_text/next_text conditioning
    body = json.dumps(payload).encode()
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}"
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(url, data=body, method="POST", headers={
            "xi-api-key": key,
            "Content-Type": "application/json",
        })
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
                with open(out_path, "wb") as f:
                    f.write(data)
                print(f"  [ok] {out_path} ({len(data)} bytes)")
                return
        except urllib.error.HTTPError as e:
            err_body = e.read().decode(errors="replace")
            print(f"  [HTTP {e.code}] attempt {attempt}: {err_body[:300]}")
            if e.code == 429 or e.code >= 500:
                time.sleep(2 * attempt)
                continue
            raise RuntimeError(f"TTS failed: {err_body}")
        except Exception as e:
            print(f"  [error] attempt {attempt}: {e}")
            time.sleep(2 * attempt)
    raise RuntimeError(f"TTS failed after {retries} attempts: {out_path}")


def make_silence(path, seconds):
    if os.path.exists(path):
        return
    subprocess.run([
        "ffmpeg", "-y", "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",
        "-t", str(seconds), "-q:a", "2", path,
    ], check=True, capture_output=True)


def concat_chapter(chunk_paths_with_boundary, out_path):
    scene_silence = os.path.join(OUTPUT_DIR, "_silence_scene.mp3")
    split_silence = os.path.join(OUTPUT_DIR, "_silence_split.mp3")
    make_silence(scene_silence, 1.3)
    make_silence(split_silence, 0.35)
    list_path = out_path + ".concat.txt"
    with open(list_path, "w") as f:
        for i, (path, is_boundary) in enumerate(chunk_paths_with_boundary):
            if i > 0:
                f.write(f"file '{scene_silence if is_boundary else split_silence}'\n")
            f.write(f"file '{path}'\n")
    subprocess.run([
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", list_path,
        "-c:a", "libmp3lame", "-b:a", "128k", out_path,
    ], check=True, capture_output=True)
    print(f"[chapter done] {out_path}")


def main():
    key = get_api_key()
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None

    tagged_files = sorted(f for f in os.listdir(TAGGED_DIR) if re.match(r"ch\d+\.txt$", f))
    for fname in tagged_files:
        num = re.match(r"ch(\d+)\.txt$", fname).group(1)
        if only and num not in only:
            continue
        src = os.path.join(TAGGED_DIR, fname)
        chunks = build_chunks(src)
        first_line = open(src, encoding="utf-8").readline().strip()
        slug = slugify_title(first_line)
        print(f"=== Chapter {num} ({slug}) — {len(chunks)} chunks ===")
        chap_dir = os.path.join(OUTPUT_DIR, f"ch{num}")
        os.makedirs(chap_dir, exist_ok=True)
        chunk_paths = []
        for i, (text, boundary) in enumerate(chunks):
            out_path = os.path.join(chap_dir, f"chunk_{i:03d}.mp3")
            tts_call(key, text, out_path)
            chunk_paths.append((out_path, boundary))
        final_out = os.path.join(OUTPUT_DIR, f"Chapter-{num}-{slug}.mp3")
        concat_chapter(chunk_paths, final_out)


if __name__ == "__main__":
    main()
