"""Parametric 3D garment meshes driven by the fitted skeleton + a z-buffered software renderer."""
import numpy as np, cv2
from server.garments import X0, X1, Y0, Y1
from server.geometry import project

T_KEYS = np.array([-0.09, -0.05, 0.0, 0.12, 0.45, 0.80, 1.12])     # rings along spine (fraction of torso length)
A_KEYS = np.array([0.15, 0.30, 0.47, 0.44, 0.38, 0.39, 0.0])        # half-width / shoulder width
D_KEYS = np.array([1.0, 0.90, 0.75, 0.72, 0.72, 0.72, 0.72])        # depth / width ratio
LIGHT = np.array([-0.35, -0.5, -0.8]); LIGHT /= np.linalg.norm(LIGHT)


def _grid(n_rings, n_seg, wrap=True):
    i, j = np.meshgrid(np.arange(n_rings - 1), np.arange(n_seg), indexing="ij")
    j2 = (j + 1) % n_seg if wrap else j + 1
    a, b, c, d = i * n_seg + j, i * n_seg + j2, (i + 1) * n_seg + j, (i + 1) * n_seg + j2
    return np.concatenate([np.stack([a, c, d], -1).reshape(-1, 3), np.stack([a, d, b], -1).reshape(-1, 3)])


def _finish(verts, tris, ref, base, keep=None):
    """Orient triangles outward, apply lighting, drop cut-out triangles."""
    v = verts[tris]
    n = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
    flip = (n * ref[tris].mean(1)).sum(1) < 0
    tris = tris.copy(); tris[flip] = tris[flip][:, [0, 2, 1]]
    v = verts[tris]
    n = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0]); n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
    cen = v.mean(1); toward = -cen / (np.linalg.norm(cen, axis=1, keepdims=True) + 1e-12)
    facing = (n * toward).sum(1) > 0
    nn = np.where(facing[:, None], n, -n)
    shade = 0.48 + 0.52 * np.clip(nn @ LIGHT, 0, 1)
    shade *= 0.80 + 0.20 * np.abs((nn * toward).sum(1))
    shade = np.where(facing, shade, shade * 0.6)
    cols = np.clip(base * shade[:, None], 0, 255)
    if keep is not None:
        tris, cols = tris[keep], cols[keep]
    return {"verts": verts, "tris": tris, "colors": cols}


def _stripes(t, base):
    s = (np.floor((t + 0.1) * 16).astype(int) % 2)[:, None]
    return base * (1 - 0.16 * s)


def torso_mesh(frame, g, ease=1.06, hem=1.12, nr=34, ns=44):
    o, ex, ey, nf, Ws, L, Wh = frame
    tk = T_KEYS.copy(); tk[-1] = hem
    ak = A_KEYS.copy(); ak[-1] = max(0.40, 0.5 * Wh * 1.7 / Ws)
    ts = np.linspace(tk[0], tk[-1], nr)
    a = np.interp(ts, tk, ak) * Ws * ease
    b = a * np.interp(ts, tk, D_KEYS)
    phi = np.linspace(0, 2 * np.pi, ns, endpoint=False)
    c, s = np.cos(phi), np.sin(phi)
    sx, sz = np.sign(c) * np.abs(c) ** (2 / 2.6), np.sign(s) * np.abs(s) ** (2 / 2.6)   # superellipse section
    X, Z = a[:, None] * sx[None], b[:, None] * sz[None]
    Y = np.repeat((ts * L)[:, None], ns, 1)
    w = np.clip(-ts / 0.09, 0, 1)[:, None]                                                 # neckline scoop
    Y = Y + L * w * (0.13 * np.clip(sz, 0, None)[None] + 0.02 * np.clip(-sz, 0, None)[None])
    P = o + X[..., None] * ex + Y[..., None] * ey + Z[..., None] * nf
    ref = X[..., None] * ex + Z[..., None] * nf
    verts, ref = P.reshape(-1, 3), ref.reshape(-1, 3)
    tris = _grid(nr, ns)
    xt = (X / Ws).reshape(-1)[tris].mean(1); tt = np.repeat(ts[:, None], ns, 1).reshape(-1)[tris].mean(1)
    base = np.tile(np.array(g.color, np.float64), (len(tris), 1)); keep = None
    if g.texture is not None:                              # front image wrapped on the 3D torso, alpha cuts the silhouette
        u = np.clip(((xt - X0) / (X1 - X0)) * g.texture.shape[1], 0, g.texture.shape[1] - 1).astype(int)
        v = np.clip(((tt - Y0) / (Y1 - Y0)) * g.texture.shape[0], 0, g.texture.shape[0] - 1).astype(int)
        tex = g.texture[v, u]; front = np.repeat(sz[None], nr, 0).reshape(-1)[tris].mean(1) > 0
        base = np.where(front[:, None], tex[:, :3].astype(np.float64), base)
        keep = tex[:, 3] > 127
    elif g.pattern == "stripes":
        base = _stripes(tt, base)
    return _finish(verts, tris, ref, base, keep)


def sleeve_mesh(frame, cam, side, g, ease=1.0, per=8, ns=20):
    o, ex, ey, nf, Ws, L, Wh = frame
    sh, el, wr = (11, 13, 15) if side == 0 else (12, 14, 16)
    S = cam[sh] + (o - cam[sh]) * 0.10
    if g.style == "tee":
        pts, rad = [S, S + (cam[el] - S) * 0.55], [0.165, 0.14]
    elif g.style == "long":
        pts, rad = [S, cam[el], cam[wr]], [0.165, 0.135, 0.10]
    else:
        return None
    cs, rs = [], []
    for k in range(len(pts) - 1):
        for q in range(per + (1 if k == len(pts) - 2 else 0)):
            f = q / per; cs.append(pts[k] * (1 - f) + pts[k + 1] * f); rs.append(rad[k] * (1 - f) + rad[k + 1] * f)
    cs, rs = np.array(cs), np.array(rs) * Ws * ease
    d = np.gradient(cs, axis=0); d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
    e1 = nf[None] - d * (d @ nf)[:, None]
    bad = np.linalg.norm(e1, axis=1) < 1e-3; e1[bad] = ex
    e1 /= np.linalg.norm(e1, axis=1, keepdims=True); e2 = np.cross(d, e1)
    th = np.linspace(0, 2 * np.pi, ns, endpoint=False)
    off = rs[:, None, None] * (np.cos(th)[None, :, None] * e1[:, None] + np.sin(th)[None, :, None] * e2[:, None])
    verts, ref = (cs[:, None] + off).reshape(-1, 3), off.reshape(-1, 3)
    tris = _grid(len(cs), ns)
    base = np.tile(np.array(g.color, np.float64), (len(tris), 1))
    if g.pattern == "stripes" and g.texture is None:
        vv = np.repeat(np.linspace(0, 1, len(cs))[:, None], ns, 1).reshape(-1)[tris].mean(1)
        base = _stripes(vv * 1.2 - 0.1, base)
    return _finish(verts, tris, ref, base)


def render_layer(parts, K, shape, ss=2):
    """Painter's-algorithm rasteriser at ss x resolution. Returns premultiplied BGR (float32) and alpha."""
    h, w = shape
    V, T, C, off = [], [], [], 0
    for p in parts:
        V.append(p["verts"]); T.append(p["tris"] + off); C.append(p["colors"]); off += len(p["verts"])
    verts, tris, cols = np.concatenate(V), np.concatenate(T), np.concatenate(C)
    px = np.rint(project(verts, K) * ss).astype(np.int32)
    z = verts[:, 2]
    ok = (z[tris] > 0.1).all(1)
    tris, cols = tris[ok], cols[ok]
    order = np.argsort(-z[tris].mean(1))
    polys, cl = px[tris][order], np.concatenate([cols, np.full((len(cols), 1), 255.0)], 1)[order].astype(int).tolist()
    layer = np.zeros((h * ss, w * ss, 4), np.uint8)
    for poly, col in zip(polys, cl):
        cv2.fillConvexPoly(layer, poly, col)
    small = cv2.resize(layer, (w, h), interpolation=cv2.INTER_AREA).astype(np.float32)
    return small[..., :3], small[..., 3] / 255.0
