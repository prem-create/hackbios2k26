import sys, pathlib, os, json
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "server"))
os.environ["TRYON_GARMENT_DIR"] = "/tmp/tg_api"; os.environ["TRYON_API_KEY"] = "secret"
import cv2, numpy as np, pytest
from fastapi.testclient import TestClient
import app as appmod
c = TestClient(appmod.app); H = {"x-api-key": "secret"}
JPG = cv2.imencode(".jpg", np.full((480, 640, 3), 90, np.uint8))[1].tobytes()

def test_health_and_auth():
    assert c.get("/health").json()["ok"]
    assert c.get("/garments").status_code == 401
    assert c.get("/garments", headers=H).status_code == 200

def test_tryon_no_person_returns_image():
    r = c.post("/tryon", headers=H, files={"image": ("a.jpg", JPG, "image/jpeg")})
    assert r.status_code == 200 and r.headers["x-pose-found"] == "false"

def test_tryon_bad_image():
    assert c.post("/tryon", headers=H, files={"image": ("a.jpg", b"nope", "image/jpeg")}).status_code == 400

def test_upload_validation_and_use():
    assert c.post("/garments", headers=H, files={"file": ("x.png", cv2.imencode(".png", np.zeros((50, 50, 3), np.uint8))[1].tobytes(), "image/png")}).status_code == 400
    rgba = np.zeros((200, 200, 4), np.uint8); rgba[20:180, 20:180] = (0, 200, 0, 255)
    r = c.post("/garments", headers=H, files={"file": ("x.png", cv2.imencode(".png", rgba)[1].tobytes(), "image/png")}, data={"name": "green"})
    assert r.status_code == 200
    with c.websocket_connect("/ws/tryon", headers=H) as ws:
        ws.send_text(json.dumps({"garment": "up:" + r.json()["id"], "mirror": False}))
        ws.send_bytes(JPG); st = json.loads(ws.receive_text()); assert st["found"] is False
        assert len(ws.receive_bytes()) > 1000

def test_ws_requires_key():
    with pytest.raises(Exception):
        with c.websocket_connect("/ws/tryon") as ws: ws.receive_text()

def test_metrics_and_ready():
    assert "tryon_frames_total" in c.get("/metrics").text
    assert c.get("/ready").json()["ready"]
