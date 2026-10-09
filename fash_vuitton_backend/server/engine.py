"""Pose -> 3D fit -> 3D garment -> composite. One TryOnSession per camera stream."""
import time
import cv2, numpy as np, mediapipe as mp
from server.config import settings
from server.geometry import OneEuro, fit_rigid, body_frame, intrinsics, project
from server.mesh3d import torso_mesh, sleeve_mesh, render_layer

# Body parts redrawn over the garment when they are in front of the torso (sleeve end -> hand)
ARM_SEGS = {"tank": [(11, 13), (13, 15), (15, 19), (12, 14), (14, 16), (16, 20)],
            "tee": [(13, 15), (15, 19), (14, 16), (16, 20)],
            "long": [(15, 19), (16, 20)]}
ROT = {90: cv2.ROTATE_90_CLOCKWISE, 180: cv2.ROTATE_180, 270: cv2.ROTATE_90_COUNTERCLOCKWISE}


def compose3d(bgr, cam, vis, seg, g, K, fit=1.0, length=1.0):
    """Render the garment for camera-space joints `cam` (metres) and composite it over `bgr`."""
    h, w = bgr.shape[:2]
    fr = body_frame(cam)
    o, ex, ey, nf, Ws, L, Wh = fr
    parts = [torso_mesh(fr, g, ease=1.06 * fit, hem=1.12 * length)]
    for side in (0, 1):
        s = sleeve_mesh(fr, cam, side, g, ease=fit)
        if s: parts.append(s)
    rgb, alpha = render_layer(parts, K, (h, w))
    px = project(cam, K)
    sw = float(np.linalg.norm(px[11] - px[12]))
    if seg is not None:                      # stay on the person (dilated so loose fits still show)
        k = max(3, int(sw * 0.15)) | 1
        person = cv2.dilate((seg > 0.5).astype(np.uint8), np.ones((k, k), np.uint8))
        keep = cv2.GaussianBlur(person.astype(np.float32), (0, 0), 2)
        alpha, rgb = alpha * keep, rgb * keep[..., None]
    z_ref = (o[2] + (cam[23][2] + cam[24][2]) / 2) / 2 - 0.06        # about the front surface of the chest
    arms = np.zeros((h, w), np.uint8); thick = max(4, int(sw * 0.16))
    for a, b in ARM_SEGS[g.style]:
        if vis[a] > 0.3 and vis[b] > 0.3 and (cam[a][2] + cam[b][2]) / 2 < z_ref:
            cv2.line(arms, tuple(px[a].astype(int)), tuple(px[b].astype(int)), 255, thick, cv2.LINE_AA)
    free = 1 - cv2.GaussianBlur(arms.astype(np.float32) / 255, (0, 0), max(1, thick / 6))
    alpha, rgb = alpha * free, rgb * free[..., None]
    out = bgr.astype(np.float32) * (1 - alpha[..., None]) + rgb
    return np.clip(out, 0, 255).astype(np.uint8)


class TryOnSession:
    def __init__(self, complexity=None, static=False):
        self.pose = mp.solutions.pose.Pose(
            static_image_mode=static, model_complexity=settings.model_complexity if complexity is None else complexity,
            enable_segmentation=True, smooth_segmentation=not static,
            min_detection_confidence=0.5, min_tracking_confidence=0.5)
        self.filter, self.lost, self.t0 = OneEuro(), 99, time.monotonic()

    def close(self): self.pose.close()

    def process(self, bgr, garment, fit=1.0, length=1.0, mirror=False, rotate=0, focal_ratio=None):
        """Returns (output_bgr, info). info: found, reproj_px, ms."""
        t = time.perf_counter()
        if rotate in ROT: bgr = cv2.rotate(bgr, ROT[rotate])
        if mirror: bgr = cv2.flip(bgr, 1)
        h, w = bgr.shape[:2]
        res = self.pose.process(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
        info = {"found": False, "reproj_px": None}
        if res.pose_landmarks and res.pose_world_landmarks:
            lm, wl = res.pose_landmarks.landmark, res.pose_world_landmarks.landmark
            img = np.array([[p.x * w, p.y * h] for p in lm]); vis = np.array([p.visibility for p in lm])
            world = np.array([[p.x, p.y, p.z] for p in wl])
            K = intrinsics(w, h, focal_ratio or settings.focal_ratio)
            fit3 = fit_rigid(world, img, vis, K)
            if fit3 and fit3[1] <= settings.max_reproj_px:
                cam, err = fit3
                if self.lost > 8: self.filter.reset()
                cam = self.filter(cam, time.monotonic() - self.t0)
                bgr = compose3d(bgr, cam, vis, res.segmentation_mask, garment, K, float(fit), float(length))
                self.lost, info = 0, {"found": True, "reproj_px": round(err, 1)}
        if not info["found"]: self.lost += 1
        info["ms"] = round((time.perf_counter() - t) * 1000, 1)
        return bgr, info
