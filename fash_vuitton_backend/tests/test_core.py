import sys, pathlib, os
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "server"))
import cv2, numpy as np
from geometry import fit_rigid, intrinsics, project, body_frame, OneEuro
from garments import GarmentLibrary
from engine import compose3d

SKEL = np.zeros((33, 3))      # metres, hips at origin, x right / y down / z away from camera
SKEL[0] = (0, -0.62, -0.08); SKEL[11] = (0.19, -0.50, 0); SKEL[12] = (-0.19, -0.50, 0)
SKEL[13] = (0.26, -0.22, 0); SKEL[14] = (-0.26, -0.22, 0); SKEL[15] = (0.28, 0.02, -0.05); SKEL[16] = (-0.28, 0.02, -0.05)
SKEL[19] = (0.29, 0.10, -0.06); SKEL[20] = (-0.29, 0.10, -0.06); SKEL[23] = (0.09, 0, 0); SKEL[24] = (-0.09, 0, 0)
K = intrinsics(640, 480, 0.85)

def rot_y(deg):
    a = np.radians(deg); c, s = np.cos(a), np.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])

def scene(yaw, t=(0.1, 0.35, 2.4)):
    cam = SKEL @ rot_y(yaw).T + np.array(t)
    return cam, project(cam, K)

def test_pnp_recovers_pose_when_world_is_unrotated():
    for yaw in (0, 25, 40):
        cam_true, img = scene(yaw)
        vis = np.ones(33)
        cam, err = fit_rigid(SKEL, img, vis, K)         # MediaPipe-style input: unrotated metric pose
        assert err < 0.5
        assert np.abs(cam[[11, 12, 23, 24]] - cam_true[[11, 12, 23, 24]]).max() < 0.03

def test_pnp_with_pixel_noise():
    rng = np.random.default_rng(0); cam_true, img = scene(30)
    cam, err = fit_rigid(SKEL, img + rng.normal(0, 1.5, img.shape), np.ones(33), K)
    assert np.abs(cam[[11, 12]] - cam_true[[11, 12]]).max() < 0.06

def test_body_frame_forward_points_to_camera():
    cam, _ = scene(0); o, ex, ey, nf, Ws, L, Wh = body_frame(cam)
    assert nf[2] < -0.95 and abs(Ws - 0.38) < 1e-6 and abs(ey[1] - 1) < 1e-6

def test_one_euro_reduces_jitter():
    rng = np.random.default_rng(1); f = OneEuro(); raw = rng.normal(0, 0.01, 200)
    out = np.array([f(np.array([x]), i / 30)[0] for i, x in enumerate(raw)])
    assert out.std() < raw.std() * 0.6

def _sheet(g, name):
    lib = GarmentLibrary("/tmp/tg"); g = lib.resolve(g); tiles = []
    for yaw in (0, 35, 70):
        cam, img = scene(yaw)
        bg = np.full((480, 640, 3), 70, np.uint8)
        out = compose3d(bg, cam, np.ones(33), None, g, K)
        assert (out != bg).any(); tiles.append(out)
    cv2.imwrite(f"/tmp/{name}.png", np.hstack(tiles)); return tiles

def test_garment_turns_with_body():
    tiles = _sheet("proc:tee:c2432b", "sheet_tee")
    widths = []
    for t in tiles:
        m = (np.abs(t.astype(int) - 70).sum(2) > 30)[200:330]      # torso band
        widths.append(np.ptp(np.where(m.any(0))[0][np.r_[0:0]] if False else np.where(m.any(0))[0]))
    assert widths[0] > widths[2]                                    # narrower when turned 70 degrees
    _sheet("proc:long:1f4e79:stripes", "sheet_long"); _sheet("proc:tank:2f6b4f", "sheet_tank")
