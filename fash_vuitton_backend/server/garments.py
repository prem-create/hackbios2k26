"""Garment specs: 'proc:<tee|tank|long>:<hex>[:stripes]' or 'up:<id>' (uploaded transparent PNG)."""
import json, uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import cv2, numpy as np

STYLES = ("tee", "tank", "long")
SLEEVE_TO_STYLE = {"none": "tank", "short": "tee", "long": "long"}
COLORS = ["c2432b", "1f4e79", "2f6b4f", "e0b43a", "2b2b2b", "f2f2ee", "7a4a8c"]
X0, X1, Y0, Y1 = -0.75, 0.75, -0.12, 1.18      # torso units covered by an uploaded front image
DEFAULT = "proc:tee:c2432b"


@dataclass
class Garment:
    id: str
    style: str
    color: tuple                                  # BGR
    pattern: str = "solid"
    texture: Optional[np.ndarray] = None          # BGRA front panel


def _hex_bgr(h):
    h = h.lstrip("#")
    return (int(h[4:6], 16), int(h[2:4], 16), int(h[0:2], 16))


class GarmentLibrary:
    def __init__(self, folder="garments"):
        self.dir = Path(folder); self.dir.mkdir(parents=True, exist_ok=True)
        self._cache = {}

    def list(self):
        ups = [json.loads(p.read_text()) for p in sorted(self.dir.glob("*.json"))]
        return {"styles": list(STYLES), "colors": COLORS, "patterns": ["solid", "stripes"], "uploads": ups}

    def add_upload(self, name, data, sleeve="short"):
        im = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_UNCHANGED)
        if im is None or im.ndim != 3 or im.shape[2] != 4:
            raise ValueError("Upload a PNG/WebP with a transparent background (alpha channel).")
        if (im[..., 3] > 127).mean() < 0.02:
            raise ValueError("The image is almost fully transparent.")
        if max(im.shape[:2]) > 512:
            s = 512 / max(im.shape[:2]); im = cv2.resize(im, None, fx=s, fy=s, interpolation=cv2.INTER_AREA)
        gid = uuid.uuid4().hex[:8]
        cv2.imwrite(str(self.dir / f"{gid}.png"), im)
        sleeve = sleeve if sleeve in SLEEVE_TO_STYLE else "short"
        meta = {"id": gid, "name": name[:60], "sleeve": sleeve}
        (self.dir / f"{gid}.json").write_text(json.dumps(meta))
        return meta

    def resolve(self, spec):
        if spec in self._cache:
            return self._cache[spec]
        g = None
        try:
            kind, *r = spec.split(":")
            if kind == "proc" and r[0] in STYLES:
                g = Garment(spec, r[0], _hex_bgr(r[1]), r[2] if len(r) > 2 and r[2] in ("solid", "stripes") else "solid")
            elif kind == "up":
                meta = json.loads((self.dir / f"{r[0]}.json").read_text())
                im = cv2.imread(str(self.dir / f"{r[0]}.png"), cv2.IMREAD_UNCHANGED)
                px = im[im[..., 3] > 127][:, :3]
                g = Garment(spec, SLEEVE_TO_STYLE[meta["sleeve"]], tuple(int(x) for x in np.median(px, axis=0)), "solid", im)
        except Exception:
            g = None
        if g is None:
            if spec == DEFAULT:
                raise RuntimeError("default garment failed")
            return self.resolve(DEFAULT)
        self._cache[spec] = g
        return g
