# Convert the Source Mage wordmark PNG into truecolor half-block ANSI art with a transparent background.
import sys
from PIL import Image
src, out, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
im = Image.open(src).convert("RGB")
w, h = im.size
rows_px = max(2, round(h * cols / w))
rows_px += rows_px % 2                      # even number of pixel rows: two per text row
im = im.resize((cols, rows_px), Image.LANCZOS)
px = im.load()

def lum(c): return 0.2126*c[0] + 0.7152*c[1] + 0.0722*c[2]
def opaque(c): return lum(c) > 28           # near-black = the logo's own background -> transparent

lines = []
for y in range(0, rows_px, 2):
    s = ""
    for x in range(cols):
        t, b = px[x, y], px[x, y+1]
        ot, ob = opaque(t), opaque(b)
        if ot and ob:   s += "\x1b[38;2;%d;%d;%dm\x1b[48;2;%d;%d;%dm▀\x1b[0m" % (*t, *b)
        elif ot:        s += "\x1b[38;2;%d;%d;%dm▀\x1b[0m" % t
        elif ob:        s += "\x1b[38;2;%d;%d;%dm▄\x1b[0m" % b
        else:           s += " "
    lines.append(s.rstrip() if False else s)
open(out, "w").write("\n".join(lines) + "\n")
print("rows:", len(lines), "cols:", cols)
