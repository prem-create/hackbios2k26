# Virtual Try-On v2: 3D pose-driven garments (Python backend + Flutter client)

```
Flutter --JPEG frames over WSS--> FastAPI --> MediaPipe Pose (2D + metric 3D) + person mask
   ^                                   --> PnP fit: 3D body pose in camera space  --> One-Euro smoothing
   |                                   --> parametric 3D garment mesh (torso + sleeves along arm bones)
   +------------JPEG + status----------<-- z-sorted, lit, 2x supersampled render --> composite (mask + arm occlusion)
```

## What is new vs v1
- **Real 3D**: the shirt is a mesh in camera space. It turns with you (tested at 0/35/70 degrees), sleeves follow your actual arm bones, stripes and lighting wrap the surface.
- **Uploaded garments** are wrapped onto the 3D torso; the PNG's transparency cuts the silhouette (sleeves come from the 3D tubes, colored from the image).
- **Production wrapper**: API-key auth, rate limits, connection cap, size limits, idle timeout, `/health` `/ready` `/metrics`, Docker, 11 automated tests.

## Run
```bash
pip install -r requirements.txt
python run_local.py                                   # webcam demo
cp .env.example .env && docker compose up --build     # server (set TRYON_API_KEY!)
python -m pytest tests                                # tests
```
Put the server behind HTTPS/WSS (Caddy, nginx, or your cloud load balancer). Do not expose it without an API key.

## Accuracy: what is real and what is not (read this)
Verified by tests: PnP recovers body pose from synthetic landmarks (<3 cm, noisy 1.5 px input <6 cm), mesh turns correctly, API/auth/limits behave.
**NOT verified here**: behaviour on real people and real cameras (no webcam or device in my environment), Flutter app on a device, iOS conversion, frame rate on your hardware. Expect to tune `TRYON_FOCAL_RATIO` per device, and the garment proportions in `mesh3d.py`.

Known accuracy ceilings of this approach (single RGB camera + parametric garment):
1. Body depth/shape is *assumed* (elliptical torso), not measured. Loose or tight fit is approximate.
2. Your real top still shows where it is bigger than the virtual one. Fix needs human parsing (SCHP/Sapiens) + inpainting.
3. No cloth physics; the garment is rigid-ish and does not drape or wrinkle.
4. Occlusion by hands/arms is heuristic (depth comparison of joints), not per-pixel depth.
5. Only upper-body garments, one person, MediaPipe pose range (about 1-4 m).

## Path to photoreal / truly accurate (needs GPU + licences, not buildable in this environment)
1. **Body**: replace the elliptical torso with an SMPL-X mesh from HMR 2.0 / SMPLer-X (register for SMPL-X weights; check licences for commercial use).
2. **Garments**: author real garments (CLO3D/Marvelous Designer -> GLB), skin them to SMPL-X, add cloth simulation or learned drape; render with a real engine (pyrender/Open3D or on-device Filament/Unity).
3. **Clothing removal**: human parsing + diffusion inpainting of the original top.
4. **Photoreal stills**: implement `server/hq_tryon.py` with CatVTON / IDM-VTON and enable `mode=hq`.
5. **Scale**: GPU workers, Redis rate limits, per-user auth (JWT), CDN for garment assets, on-device overlay for lowest latency.

## API
`GET /health /ready /metrics` | `GET|POST /garments` | `POST /tryon` (photo) | `WS /ws/tryon` (live)
Header `x-api-key`. Garment spec: `proc:tee:c2432b` or `proc:long:1f4e79:stripes` or `up:<id>`.
WS: text = settings JSON (`garment, fit, length, mirror, rotate, quality, fov_ratio`), binary = JPEG; each frame gets a status JSON then a JPEG.
