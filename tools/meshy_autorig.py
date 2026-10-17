"""Rigs prepared Meshy characters with Meshy's auto-rigger.

    python tools/meshy_autorig.py ish abhi ...     # build/meshy_prep/<id>.glb -> build/meshy_rig/<id>.glb

Each model (slimmed by tools/prep_meshy_body.py) is uploaded as a data URI
with the fighter's height; Meshy fits a humanoid skeleton to it (5 credits)
and the rigged GLB is downloaded. tools/tpose_meshy_rig.py then stands it in
the game's T-pose. The API key is read from MESHY_API_KEY in .env.
"""
import base64, json, os, sys, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.meshy.ai/openapi/v1"
# Heights in metres, as in fighter_models.gd STYLES.
HEIGHTS = {"anug": 1.8, "ish": 1.8, "sab": 1.92, "bib": 1.7, "abhi": 1.85, "sup": 1.8, "anant": 1.85}


def api_key():
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("MESHY_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No MESHY_API_KEY in .env")


def call(key, method, path, body=None):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode() if body is not None else None,
                                 method=method, headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    for attempt in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=300).read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(15)
                continue
            sys.exit("Meshy refused %s %s (%d): %s" % (method, path, e.code, e.read()[:400].decode("utf-8", "ignore")))
        except (ConnectionError, urllib.error.URLError, TimeoutError):
            if attempt == 3:
                raise
            time.sleep(10)


def main():
    key = api_key()
    out_dir = os.path.join(ROOT, "build", "meshy_rig")
    os.makedirs(out_dir, exist_ok=True)
    for fighter in sys.argv[1:]:
        src = os.path.join(ROOT, "build", "meshy_prep", fighter + ".glb")
        with open(src, "rb") as f:
            uri = "data:application/octet-stream;base64," + base64.b64encode(f.read()).decode()
        task = call(key, "POST", "/rigging", {"model_url": uri, "height_meters": HEIGHTS.get(fighter, 1.8)})
        task_id = task.get("result") or task.get("id")
        while True:
            done = call(key, "GET", "/rigging/%s" % task_id)
            if done.get("status") == "SUCCEEDED":
                break
            if done.get("status") in ("FAILED", "CANCELED", "EXPIRED"):
                sys.exit("%s rigging %s: %s" % (fighter, done.get("status"), done.get("task_error")))
            time.sleep(6)
        result = done.get("result", done)
        url = result.get("rigged_character_glb_url")
        path = os.path.join(out_dir, fighter + ".glb")
        with urllib.request.urlopen(url, timeout=300) as r, open(path, "wb") as f:
            f.write(r.read())
        print("rigged", fighter, task_id, os.path.getsize(path), flush=True)


if __name__ == "__main__":
    main()
