"""Fetches fighting animations from Meshy's animation library for the whole
roster.

Meshy animates a rigged character; the game only needs the motion, which
fighter_animated.gd retargets onto every fighter (Meshy's skeleton is mapped
by MESHY_BONES, as for Anug's set). So one humanoid is rigged once (its task
id is remembered in assets/fighters/meshy/rig.json) and each animation is
saved as assets/fighters/meshy/<name>.fbx (kept local, like the Mixamo files).

  python tools/fetch_meshy_animations.py --list fighting     # browse the library (free)
  MESHY_FORMAT=glb python tools/fetch_meshy_animations.py    # fetch WANTED not yet saved (GLB: use this)
  python tools/fetch_meshy_animations.py Jumping_Punch Leg_Sweep

Costs: rigging 5 credits (once), 3 credits per animation. The API key is
read from MESHY_API_KEY in the git-ignored .env and never printed.
"""
import base64, json, os, sys, time, urllib.error, urllib.parse, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fighters", "meshy")
API = "https://api.meshy.ai/openapi/v1"
# The humanoid Meshy rigs and animates: a model Meshy made itself, standing
# in its A-pose (the slimmed Nepali Master, tools/prep_meshy_body.py). Only
# its motion is used, but the rig must fit cleanly: rigged from a game body
# already bound in a fisted T-pose, every clip came out hunched over.
RIG_MODEL = os.path.join(ROOT, "build", "meshy_prep", "anant.glb")
# What the game wants first: saved name -> Meshy library action_id
# (python tools/fetch_meshy_animations.py --list <words> finds more).
WANTED = {
    "Jumping_Punch": 457, "Flying_Fist_Kick": 94,      # jump attacks
    "Leg_Sweep": 213, "Sweeping_Kick": 217,            # sweeps
    "Knock_Down": 187, "Stand_Up_1": 344, "Stand_Up_2": 345,  # knockdown, get-up
    "Chest_Pound_Taunt": 88, "Victory_Cheer": 59,      # Mahabali's taunt, a win
    "Left_Uppercut_from_Guard": 196,
    # Ananta's own set: a master's guard and footwork, guard-stance hands,
    # the kung fu punch, three kicks, a dodge-and-counter finisher, his
    # sweep, a guard, reactions and bows.
    "Fight_Idle": 250, "Walk_Fight_Forward": 21, "Walk_Fight_Back": 20, "Stand_Dodge": 156,
    "Left_Jab_from_Guard": 191, "Right_Jab_from_Guard": 192, "Left_Hook_from_Guard": 193,
    "Right_Upper_Hook_from_Guard": 195, "Kung_Fu_Punch": 96,
    "Roundhouse_Kick": 207, "Spartan_Kick": 206, "Lunge_Spin_Kick": 216,
    "Dodge_and_Counter": 93, "Sweep_Kick": 455, "Block1": 138,
    "Face_Punch_Reaction": 174, "Face_Punch_Reaction_2": 176, "Hit_Reaction_to_Waist": 171,
    "Hit_Reaction": 178, "Formal_Bow": 41, "Gentlemans_Bow": 42, "Step_in_High_Kick": 218,
}

def api_key():
    with open(os.path.join(ROOT, ".env"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("MESHY_API_KEY="):
                return line.split("=", 1)[1].strip()
    sys.exit("No MESHY_API_KEY in .env")


def call(key, method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method,
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    for attempt in range(4):
        try:
            return json.loads(urllib.request.urlopen(req, timeout=120).read() or b"{}")
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(15)
                continue
            sys.exit("Meshy refused %s %s (%d): %s" % (method, path, e.code, e.read()[:400].decode("utf-8", "ignore")))
        except (ConnectionError, urllib.error.URLError, TimeoutError):
            if attempt == 3:
                raise
            time.sleep(10)


def wait(key, path):
    """Polls a task until it finishes; returns the task."""
    while True:
        task = call(key, "GET", path)
        status = task.get("status", "")
        if status == "SUCCEEDED":
            return task
        if status in ("FAILED", "CANCELED", "EXPIRED"):
            sys.exit("Meshy task %s %s: %s" % (path, status, json.dumps(task.get("task_error", task))[:300]))
        print("  ...%s %s%%" % (status.lower(), task.get("progress", "?")), flush=True)
        time.sleep(6)


def rig_id(key):
    """The rigging task every animation is made on (rigged once)."""
    memo = os.path.join(OUT, "rig.json")
    if os.path.exists(memo):
        return json.load(open(memo, encoding="utf-8"))["rig_task_id"]
    with open(RIG_MODEL, "rb") as f:
        uri = "data:application/octet-stream;base64," + base64.b64encode(f.read()).decode()
    task = call(key, "POST", "/rigging", {"model_url": uri, "height_meters": 1.85})
    task_id = task.get("result") or task.get("id")
    print("rigging", task_id)
    wait(key, "/rigging/%s" % task_id)
    json.dump({"rig_task_id": task_id}, open(memo, "w", encoding="utf-8"))
    return task_id


def library(key, search=""):
    query = "?" + urllib.parse.urlencode({"search": search}) if search else ""
    found = call(key, "GET", "/animations/library" + query)
    return found if isinstance(found, list) else found.get("result", found.get("data", []))


def download(url, path):
    with urllib.request.urlopen(url, timeout=300) as r, open(path, "wb") as f:
        f.write(r.read())


def main():
    key = api_key()
    os.makedirs(OUT, exist_ok=True)
    args = sys.argv[1:]
    if args[:1] == ["--list"]:
        for item in library(key, args[1] if len(args) > 1 else ""):
            print(item.get("action_id"), item.get("name"), "|", item.get("category"), "/", item.get("sub_category"))
        return
    ext = ".glb" if os.environ.get("MESHY_FORMAT") == "glb" else ".fbx"
    names = args or [n for n in WANTED if not os.path.exists(os.path.join(OUT, n + ext))]
    if not names:
        print("all saved")
        return
    ids = {}
    for name in names:
        if name in WANTED:
            ids[name] = WANTED[name]
            continue
        for item in library(key, name.replace("_", " ")):
            if item.get("name", "").lower().replace(" ", "_") == name.lower():
                ids[name] = item["action_id"]
        if name not in ids:
            print("not in the library:", name)
    rig = rig_id(key)
    # One task per action keeps each download a single clip.
    for name, action in ids.items():
        task = call(key, "POST", "/animations", {"rig_task_id": rig, "action_id": action,
                                                  "post_process": {"operation_type": "change_fps", "fps": 30}})
        task_id = task.get("result") or task.get("id")
        done = wait(key, "/animations/%s" % task_id)
        result = done.get("result", done)
        if os.environ.get("MESHY_FORMAT") == "glb":
            download(result.get("animation_glb_url"), os.path.join(OUT, name + ".glb"))
        else:
            url = result.get("processed_animation_fps_fbx_url") or result.get("animation_fbx_url")
            download(url, os.path.join(OUT, name + ".fbx"))
        print("saved", name)


if __name__ == "__main__":
    main()
