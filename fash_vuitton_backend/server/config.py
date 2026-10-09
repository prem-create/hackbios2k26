import os
from dataclasses import dataclass, field

def _i(n, d): return int(os.getenv(n, d))
def _f(n, d): return float(os.getenv(n, d))

@dataclass(frozen=True)
class Settings:
    api_key: str = os.getenv("TRYON_API_KEY", "")            # empty = auth disabled (dev only)
    max_connections: int = _i("TRYON_MAX_CONNECTIONS", 4)     # concurrent live streams per worker
    max_frame_bytes: int = _i("TRYON_MAX_FRAME_BYTES", 2_000_000)
    max_upload_bytes: int = _i("TRYON_MAX_UPLOAD_BYTES", 8_000_000)
    frame_width: int = _i("TRYON_FRAME_WIDTH", 640)           # frames are downscaled to this
    focal_ratio: float = _f("TRYON_FOCAL_RATIO", 0.85)        # focal length / frame width (about 62 deg FOV)
    max_reproj_px: float = _f("TRYON_MAX_REPROJ_PX", 30)      # reject 3D fits worse than this
    model_complexity: int = _i("TRYON_MODEL_COMPLEXITY", 1)
    garment_dir: str = os.getenv("TRYON_GARMENT_DIR", "garments")
    idle_timeout_s: int = _i("TRYON_IDLE_TIMEOUT_S", 30)
    cors_origins: tuple = tuple(o for o in os.getenv("TRYON_CORS_ORIGINS", "").split(",") if o)

settings = Settings()
