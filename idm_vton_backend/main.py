import os
import shutil
import tempfile

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from gradio_client import Client, handle_file
from PIL import Image

# The Colab tunnel URL can change whenever the notebook is restarted.  Keep the
# current public URL as the default, while allowing deployment configuration to
# update it without changing this API or the frontend.
CATVTON_URL = (
    (os.getenv("CATVTON_URL") or "https://738f83cd4c124e0d50.gradio.live/")
    .strip()
    .rstrip("/")
)

app = FastAPI(title="Virtual Try-On API", version="1.0")

_client = None


def get_client() -> Client:
    """Connect to the Colab-hosted CatVTON Gradio app on first use."""
    global _client
    if _client is None:
        _client = Client(CATVTON_URL)
    return _client


def save_upload(upload: UploadFile, folder: str, name: str) -> str:
    ext = os.path.splitext(upload.filename or "")[1] or ".jpg"
    path = os.path.join(folder, name + ext)
    with open(path, "wb") as f:
        shutil.copyfileobj(upload.file, f)
    return path


def convert_to_png(source_path: str, destination_path: str, *, rgba: bool) -> str:
    """Convert an upload to PNG, using RGBA when it is an ImageEditor input."""
    with Image.open(source_path) as image:
        image.convert("RGBA" if rgba else "RGB").save(destination_path, format="PNG")
    return destination_path


def create_empty_mask(person_path: str, mask_path: str) -> str:
    """Create the blank ImageEditor layer CatVTON expects for auto-masking."""
    with Image.open(person_path) as person:
        Image.new("L", person.size, color=0).save(mask_path, format="PNG")
    return mask_path


@app.get("/")
def health():
    return {"status": "ok", "upstream": CATVTON_URL, "model": "CatVTON"}


@app.get("/api-info")
def api_info():
    """Print the Colab Gradio app's endpoints in the server console."""
    try:
        get_client().view_api()
    except Exception as e:
        raise HTTPException(
            status_code=502, detail=f"Could not connect to CatVTON: {e}"
        )
    return {"detail": "Check the server console for CatVTON API details."}


# A normal "def" (not "async def") makes FastAPI run this in a worker thread,
# so the slow Space call doesn't block other requests.
@app.post("/tryon", responses={200: {"content": {"image/png": {}}}})
def tryon(
    person_image: UploadFile = File(..., description="Photo of the person"),
    garment_image: UploadFile = File(..., description="Photo of the garment"),
    garment_description: str = Form("a piece of clothing"),
    auto_mask: bool = Form(True, description="Auto-generate the clothing mask"),
    auto_crop: bool = Form(False, description="Auto-crop and resize the person image"),
    denoise_steps: int = Form(30, ge=20, le=40),
    seed: int = Form(42),
):
    tmp = tempfile.mkdtemp()
    try:
        person_upload_path = save_upload(person_image, tmp, "person-upload")
        garment_upload_path = save_upload(garment_image, tmp, "garment-upload")

        # Gradio's ImageEditor converts the background to RGBA. Supplying a
        # JPEG makes it try to save RGBA pixels as JPEG, which fails upstream.
        person_path = convert_to_png(
            person_upload_path, os.path.join(tmp, "person.png"), rgba=True
        )
        garment_path = convert_to_png(
            garment_upload_path, os.path.join(tmp, "garment.png"), rgba=False
        )
        mask_path = create_empty_mask(person_path, os.path.join(tmp, "mask.png"))

        # CatVTON's public Gradio API accepts an ImageEditor value for the
        # person image and a separate garment image.  The local /tryon request
        # and its image response stay exactly the same for frontend callers.
        result = get_client().predict(
            person_image={
                "background": handle_file(person_path),
                # The Colab app accesses layers[0] even when automatic masking
                # is selected. A blank layer triggers its auto-mask fallback.
                "layers": [handle_file(mask_path)],
                "composite": None,
            },
            cloth_image=handle_file(garment_path),
            # The old endpoint had no clothing category.  "upper" is the
            # CatVTON default and preserves the old general clothing behavior.
            cloth_type="upper",
            num_inference_steps=denoise_steps,
            guidance_scale=2.5,
            seed=seed,
            show_type="result only",
            api_name="/submit_function",
        )

        # CatVTON returns the generated image filepath.
        output_path = result[0] if isinstance(result, (list, tuple)) else result
        with open(output_path, "rb") as f:
            image_bytes = f.read()

        return Response(content=image_bytes, media_type="image/png")

    except Exception as e:
        # Common causes: Colab runtime stopped, queue timeout, or a changed API.
        raise HTTPException(status_code=502, detail=f"Try-on failed: {e}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
