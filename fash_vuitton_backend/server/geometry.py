"""3D body fitting: MediaPipe world landmarks + 2D landmarks -> camera-space joints via PnP."""
import math
import cv2, numpy as np

FIT_IDX = [0, 11, 12, 13, 14, 15, 16, 23, 24]


class OneEuro:
    """One-euro filter: removes jitter at rest, adds almost no lag when moving. Units: metres."""
    def __init__(self, min_cutoff=1.5, beta=8.0, d_cutoff=1.0):
        self.mc, self.beta, self.dc = min_cutoff, beta, d_cutoff
        self.reset()

    def reset(self): self.prev = self.dx = self.t = None

    @staticmethod
    def _alpha(cutoff, dt): return 1.0 / (1.0 + (1.0 / (2 * math.pi * cutoff)) / dt)

    def __call__(self, x, t):
        x = np.asarray(x, np.float64)
        if self.prev is None:
            self.prev, self.dx, self.t = x.copy(), np.zeros_like(x), t
            return x
        dt = max(t - self.t, 1e-3)
        dx = (x - self.prev) / dt
        ad = self._alpha(self.dc, dt)
        self.dx = ad * dx + (1 - ad) * self.dx
        a = self._alpha(self.mc + self.beta * np.abs(self.dx), dt)
        self.prev = a * x + (1 - a) * self.prev
        self.t = t
        return self.prev


def intrinsics(w, h, focal_ratio):
    f = focal_ratio * w
    return np.array([[f, 0, w / 2], [0, f, h / 2], [0, 0, 1]], np.float64)


def fit_rigid(world, img, vis, K):
    """Find the rigid transform that makes MediaPipe's metric 3D pose agree with its 2D landmarks.
    Returns (cam_joints (33,3) in metres, mean reprojection error in px) or None."""
    idx = [i for i in FIT_IDX if vis[i] > 0.5]
    if len(idx) < 6 or any(i not in idx for i in (11, 12, 23, 24)):
        return None
    obj, im = world[idx].astype(np.float64), img[idx].astype(np.float64)
    sw_px = np.linalg.norm(img[11] - img[12])
    sw_m = np.linalg.norm(world[11] - world[12])
    if sw_px < 8 or sw_m < 0.05:
        return None
    z0 = K[0, 0] * sw_m / sw_px
    hip = (img[23] + img[24]) / 2
    t0 = np.array([(hip[0] - K[0, 2]) * z0 / K[0, 0], (hip[1] - K[1, 2]) * z0 / K[1, 1], z0])
    ok, rvec, tvec = cv2.solvePnP(obj, im, K, None, np.zeros(3), t0.copy(), True, cv2.SOLVEPNP_ITERATIVE)
    if not ok or tvec[2] <= 0.2:
        return None
    R, _ = cv2.Rodrigues(rvec)
    cam = world @ R.T + tvec.reshape(1, 3)
    proj, _ = cv2.projectPoints(obj, rvec, tvec, K, None)
    err = float(np.linalg.norm(proj.reshape(-1, 2) - im, axis=1).mean())
    return cam, err


def project(P, K):
    z = np.maximum(P[:, 2], 1e-3)
    return np.stack([K[0, 0] * P[:, 0] / z + K[0, 2], K[1, 1] * P[:, 1] / z + K[1, 2]], 1)


def body_frame(cam):
    """Torso coordinate frame in camera space. ex: across shoulders, ey: down the spine,
    nf: forward (towards the camera for a person facing it). Returns o, ex, ey, nf, Ws, L, Wh."""
    ex = cam[11] - cam[12]; Ws = float(np.linalg.norm(ex)); ex = ex / max(Ws, 1e-6)
    o = (cam[11] + cam[12]) / 2
    spine = (cam[23] + cam[24]) / 2 - o
    ey = spine - ex * np.dot(spine, ex); L = float(np.linalg.norm(ey)); ey = ey / max(L, 1e-6)
    nf = -np.cross(ex, ey)
    if np.dot(cam[0] - o, nf) < 0:          # use the nose to decide which way is "forward"
        ex, nf = -ex, -nf
    Wh = float(np.linalg.norm(cam[23] - cam[24]))
    return o, ex, ey, nf, Ws, L, Wh
