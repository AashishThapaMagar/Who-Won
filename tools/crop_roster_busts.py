"""Crops the baked busts (tools/bake_roster_busts.gd) to one framing: the
head at the same place and size on every card, shoulders below."""
from PIL import Image
import glob, os
HERE = os.path.join(os.path.dirname(__file__), "..", "assets", "menu", "busts")
for f in sorted(glob.glob(os.path.join(HERE, "bust_*.png"))):
    im = Image.open(f).convert("RGBA")
    a = im.split()[3].point(lambda v: 255 if v > 40 else 0)
    w, h = im.size
    top = a.getbbox()[1]
    # Head width: the silhouette a little below the crown.
    rows = [a.crop((0, y, w, y + 1)).getbbox() for y in range(top + int(h * 0.04), top + int(h * 0.09))]
    rows = [r for r in rows if r]
    head_w = sum(r[2] - r[0] for r in rows) / len(rows)
    cx = sum(r[0] + r[2] for r in rows) / (2 * len(rows))
    size = head_w * 2.9
    left, up = cx - size * 0.5, top - size * 0.08
    out = im.crop((int(left), int(up), int(left + size), int(up + size))).resize((480, 480), Image.LANCZOS)
    # Soft fade into the card at the bottom, the same on every fighter.
    fade = Image.new("L", (480, 480), 255)
    for y in range(330, 480):
        fade.paste(int(255 * (480 - y) / 150), (0, y, 480, y + 1))
    r, g, b, alpha = out.split()
    out = Image.merge("RGBA", (r, g, b, Image.composite(alpha, Image.new("L", (480, 480), 0), fade)))
    out.save(f)
    print(os.path.basename(f), "head", round(head_w))
