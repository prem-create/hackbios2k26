import asyncio, json, logging, time
from collections import defaultdict
import cv2, numpy as np
from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse, Response
from server.config import settings
from server.garments import DEFAULT, GarmentLibrary
from server.engine import TryOnSession

logging.basicConfig(
    level=logging.INFO,
    format='{"t":"%(asctime)s","lvl":"%(levelname)s","msg":"%(message)s"}',
)
log = logging.getLogger("tryon")
app = FastAPI(title="Virtual Try-On API", version="2.0")
if settings.cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_methods=["*"],
        allow_headers=["*"],
    )
lib = GarmentLibrary(settings.garment_dir)
M = defaultdict(float)  # tiny in-process metrics
active = 0


def _auth_ok(key):
    return (not settings.api_key) or key == settings.api_key


class Bucket:
    """Per-client token bucket (in-memory; use Redis or your gateway when running several replicas)."""

    def __init__(self, per_min):
        self.cap, self.s = per_min, defaultdict(lambda: [per_min, time.monotonic()])

    def allow(self, who):
        tok, last = self.s[who]
        now = time.monotonic()
        tok = min(self.cap, tok + (now - last) * self.cap / 60)
        self.s[who] = [tok - 1 if tok >= 1 else tok, now]
        return tok >= 1


tryon_limit, upload_limit = Bucket(60), Bucket(10)


def guard(request: Request, bucket: Bucket):
    if not _auth_ok(request.headers.get("x-api-key")):
        raise HTTPException(401, "Invalid or missing API key")
    if not bucket.allow(request.headers.get("x-api-key") or request.client.host):
        raise HTTPException(429, "Too many requests")


def _decode(data):
    if len(data) > settings.max_frame_bytes:
        raise ValueError("Frame too large")
    im = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if im is None:
        raise ValueError("Could not decode image")
    if im.shape[1] > settings.frame_width:
        im = cv2.resize(
            im,
            (
                settings.frame_width,
                int(im.shape[0] * settings.frame_width / im.shape[1]),
            ),
            interpolation=cv2.INTER_AREA,
        )
    return im


def _run(sess, data, cfg):
    out, info = sess.process(
        _decode(data),
        lib.resolve(cfg["garment"]),
        cfg["fit"],
        cfg["length"],
        cfg["mirror"],
        int(cfg["rotate"]),
        cfg.get("fov_ratio"),
    )
    M["frames"] += 1
    M["found"] += info["found"]
    M["ms_total"] += info["ms"]
    return (
        cv2.imencode(".jpg", out, [cv2.IMWRITE_JPEG_QUALITY, int(cfg["quality"])])[
            1
        ].tobytes(),
        info,
    )


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/ready")
def ready():
    s = TryOnSession(static=True)
    s.close()  # fails (500) if the model cannot load
    return {"ready": True}


@app.get("/metrics", response_class=PlainTextResponse)
def metrics():
    f = max(M["frames"], 1)
    return (
        f"tryon_frames_total {M['frames']:.0f}\ntryon_pose_found_ratio {M['found']/f:.3f}\n"
        f"tryon_avg_ms {M['ms_total']/f:.1f}\ntryon_active_streams {active}\n"
    )


@app.get("/garments")
def garments(request: Request):
    guard(request, tryon_limit)
    return lib.list()


@app.post("/garments")
async def upload_garment(
    request: Request,
    file: UploadFile = File(...),
    name: str = Form("My garment"),
    sleeve: str = Form("short"),
):
    guard(request, upload_limit)
    data = await file.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(413, "File too large")
    try:
        return lib.add_upload(name, data, sleeve)
    except ValueError as e:
        raise HTTPException(400, str(e))


@app.post("/tryon")
async def tryon(
    request: Request,
    image: UploadFile = File(...),
    garment: str = Form(DEFAULT),
    fit: float = Form(1.0),
    length: float = Form(1.0),
    mirror: bool = Form(False),
    rotate: int = Form(0),
    mode: str = Form("overlay"),
):
    """One photo -> try-on JPEG. mode='hq' is reserved for the diffusion backend (see hq_tryon.py)."""
    guard(request, tryon_limit)
    if mode == "hq":
        raise HTTPException(501, "HQ mode not configured")
    sess = TryOnSession(static=True)
    try:
        data, info = await asyncio.to_thread(
            _run,
            sess,
            await image.read(settings.max_upload_bytes + 1),
            dict(
                garment=garment,
                fit=min(max(fit, 0.8), 1.3),
                length=min(max(length, 0.8), 1.3),
                mirror=mirror,
                rotate=rotate,
                quality=92,
            ),
        )
    except ValueError as e:
        raise HTTPException(400, str(e))
    finally:
        sess.close()
    return Response(
        data,
        media_type="image/jpeg",
        headers={
            "X-Pose-Found": str(info["found"]).lower(),
            "X-Latency-Ms": str(info["ms"]),
        },
    )


@app.websocket("/ws/tryon")
async def ws_tryon(ws: WebSocket):
    """Text frames = JSON settings, binary frames = JPEG. Each frame is answered by a JPEG; send the next frame after the reply.
    Pose status arrives as small JSON text messages: {"found":bool,"ms":float}."""
    global active
    if not _auth_ok(ws.headers.get("x-api-key") or ws.query_params.get("api_key")):
        await ws.close(code=4401)
        return
    if active >= settings.max_connections:
        await ws.close(code=1013)
        return
    await ws.accept()
    active += 1
    sess = TryOnSession()
    cfg = dict(
        garment=DEFAULT,
        fit=1.0,
        length=1.0,
        mirror=True,
        rotate=0,
        quality=70,
        fov_ratio=None,
    )
    try:
        while True:
            try:
                msg = await asyncio.wait_for(ws.receive(), settings.idle_timeout_s)
            except asyncio.TimeoutError:
                await ws.close(code=1001)
                break
            if msg["type"] == "websocket.disconnect":
                break
            if msg.get("text"):
                try:
                    new = json.loads(msg["text"])
                    for k in ("garment", "mirror", "rotate", "quality", "fov_ratio"):
                        if k in new:
                            cfg[k] = new[k]
                    for k in ("fit", "length"):
                        if k in new:
                            cfg[k] = min(max(float(new[k]), 0.8), 1.3)
                    cfg["quality"] = min(max(int(cfg["quality"]), 30), 95)
                except (ValueError, TypeError):
                    await ws.send_text(json.dumps({"error": "bad settings"}))
            elif msg.get("bytes"):
                try:
                    data, info = await asyncio.to_thread(_run, sess, msg["bytes"], cfg)
                    await ws.send_text(
                        json.dumps({"found": info["found"], "ms": info["ms"]})
                    )
                    await ws.send_bytes(data)
                except ValueError as e:
                    await ws.send_text(json.dumps({"error": str(e)}))
    except Exception:
        log.exception("stream crashed")
    finally:
        active -= 1
        sess.close()
