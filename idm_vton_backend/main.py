import os
import shutil
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse

from fastapi import BackgroundTasks, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from gradio_client import Client, handle_file
from PIL import Image
from dotenv import load_dotenv

load_dotenv()

from chat_api import router as chat_router
from tryon_store import TryOnStoreError, get_tryon_store

# The Colab tunnel URL can change whenever the notebook is restarted.  Keep the
# current public URL as the default, while allowing deployment configuration to
# update it without changing this API or the frontend.
CATVTON_URL = (
    (os.getenv("CATVTON_URL") or "https://849e3e88c9974d2815.gradio.live/")
    .strip()
    .rstrip("/")
)

app = FastAPI(title="Virtual Try-On API", version="1.0")
cors_origins = [
    origin.strip()
    for origin in (os.getenv("CORS_ORIGINS") or "*").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials="*" not in cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(chat_router)

_client = None
_client_url = None
_job_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="tryon")


def get_catvton_url() -> str:
    """Read the current CatVTON URL from Supabase before each model call."""
    configured_url = CATVTON_URL
    try:
        database_url = get_tryon_store().get_setting("catvton_url")
        if database_url:
            configured_url = database_url
    except TryOnStoreError:
        # Keep the environment fallback usable until app_settings is migrated.
        pass

    parsed = urlparse(configured_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise TryOnStoreError("The catvton_url application setting is not a valid URL.")
    return configured_url.rstrip("/")


def get_client() -> Client:
    """Connect to the current CatVTON URL, refreshing when it changes."""
    global _client, _client_url
    current_url = get_catvton_url()
    if _client is None or _client_url != current_url:
        _client = Client(current_url)
        _client_url = current_url
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


def _retry_tryon(operation):
    attempts = max(1, min(int(os.getenv("TRYON_MAX_ATTEMPTS", "3")), 3))
    delay = max(float(os.getenv("TRYON_RETRY_DELAY_SECONDS", "1.5")), 0.1)
    errors = []
    for attempt in range(1, attempts + 1):
        try:
            return operation()
        except Exception as error:
            errors.append(str(error))
            if attempt < attempts:
                time.sleep(delay * attempt)
    raise HTTPException(
        status_code=502,
        detail=f"Try-on upstream failed after {attempts} attempts: {errors[-1]}",
    )


def _image_content_type(image: UploadFile) -> str:
    allowed = {"image/jpeg", "image/jpg", "image/png", "image/webp"}
    extension_types = {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }
    content_type = image.content_type or ""
    extension_type = extension_types.get(
        "." + (image.filename or "").rsplit(".", 1)[-1].lower()
    )
    if content_type not in allowed and extension_type is None:
        raise HTTPException(
            status_code=415,
            detail="Only JPG, JPEG, PNG, and WebP images are supported.",
        )
    return content_type if content_type in allowed else extension_type


def _tryon_category(category: str) -> str:
    value = category.strip().lower()
    aliases = {
        "upper": "upper",
        "hood": "upper",
        "hoodie": "upper",
        "jack": "upper",
        "jacket": "upper",
        "shirt": "upper",
        "lower": "lower",
        "pant": "lower",
        "pants": "lower",
        "trouser": "lower",
        "trousers": "lower",
        "overall": "overall",
        "dress": "overall",
        "jumpsuit": "overall",
    }
    if value not in aliases:
        raise HTTPException(
            status_code=422,
            detail="Try-on category must be upper, lower, or overall.",
        )
    return aliases[value]


def _run_background_tryon(job_id: str, user_id: str, person_photo_id: str, garment_id: str):
    store = get_tryon_store()
    try:
        store.update_job(job_id, {"status": "processing", "error": None})
        person_bytes = store.get_photo_content(user_id, person_photo_id)
        garment_bytes, _, category = store.get_garment_content(user_id, garment_id)
        result_bytes = _generate_tryon_bytes(
            person_bytes,
            garment_bytes,
            garment_description="a piece of clothing",
            cloth_type=_tryon_category(category),
            denoise_steps=30,
            seed=42,
        )
        saved = store.save_result(
            user_id=user_id,
            person_photo_id=person_photo_id,
            wardrobe_item_id=garment_id,
            content=result_bytes,
        )
        store.update_job(
            job_id,
            {"status": "completed", "result_id": saved["id"], "error": None},
        )
    except Exception as error:
        store.update_job(job_id, {"status": "failed", "error": str(error)})


def _generate_tryon_bytes(
    person_bytes: bytes,
    garment_bytes: bytes,
    *,
    garment_description: str,
    cloth_type: str,
    denoise_steps: int,
    seed: int,
) -> bytes:
    tmp = tempfile.mkdtemp()
    try:
        person_upload_path = os.path.join(tmp, "person-upload.jpg")
        garment_upload_path = os.path.join(tmp, "garment-upload.jpg")
        with open(person_upload_path, "wb") as file:
            file.write(person_bytes)
        with open(garment_upload_path, "wb") as file:
            file.write(garment_bytes)
        person_path = convert_to_png(person_upload_path, os.path.join(tmp, "person.png"), rgba=True)
        garment_path = convert_to_png(garment_upload_path, os.path.join(tmp, "garment.png"), rgba=False)
        mask_path = create_empty_mask(person_path, os.path.join(tmp, "mask.png"))
        result = _retry_tryon(
            lambda: get_client().predict(
                person_image={
                    "background": handle_file(person_path),
                    "layers": [handle_file(mask_path)],
                    "composite": None,
                },
                cloth_image=handle_file(garment_path),
                cloth_type=cloth_type,
                num_inference_steps=denoise_steps,
                guidance_scale=2.5,
                seed=seed,
                show_type="result only",
                api_name="/submit_function",
            )
        )
        output_path = result[0] if isinstance(result, (list, tuple)) else result
        with open(output_path, "rb") as file:
            return file.read()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


@app.post("/users/{user_id}/tryon-jobs", status_code=202)
def create_tryon_job(
    user_id: str,
    person_photo_id: str = Form(...),
    wardrobe_item_id: str = Form(...),
):
    try:
        store = get_tryon_store()
        job = store.create_job(user_id, person_photo_id, wardrobe_item_id)
        if job.get("status") == "queued":
            _job_executor.submit(
                _run_background_tryon,
                job["id"],
                user_id,
                person_photo_id,
                wardrobe_item_id,
            )
        return job
    except TryOnStoreError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.get("/users/{user_id}/tryon-jobs/{job_id}")
def get_tryon_job(user_id: str, job_id: str):
    try:
        job = get_tryon_store().get_job(user_id, job_id)
        if job.get("result_id"):
            job["result"] = next(
                (
                    item
                    for item in get_tryon_store().list_results(user_id)
                    if item["id"] == job["result_id"]
                ),
                None,
            )
        return job
    except TryOnStoreError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@app.get("/users/{user_id}/tryon-jobs")
def list_tryon_jobs(user_id: str):
    try:
        store = get_tryon_store()
        jobs = (
            store.supabase.table("tryon_jobs")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(100)
            .execute()
            .data
            or []
        )
        results = {item["id"]: item for item in store.list_results(user_id)}
        for job in jobs:
            if job.get("result_id") in results:
                job["result"] = results[job["result_id"]]
        return {
            "jobs": jobs,
        }
    except TryOnStoreError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.post("/users/{user_id}/photos", status_code=201)
def save_user_photo(
    user_id: str,
    image: UploadFile = File(...),
):
    content_type = _image_content_type(image)
    content = image.file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Images must be 10 MB or smaller.")
    try:
        return get_tryon_store().save_user_photo(
            user_id=user_id,
            filename=image.filename or "user-photo",
            content_type=content_type,
            content=content,
        )
    except TryOnStoreError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.get("/users/{user_id}/photos")
def list_user_photos(user_id: str):
    try:
        return {"photos": get_tryon_store().list_user_photos(user_id)}
    except TryOnStoreError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.get("/users/{user_id}/tryon-results")
def list_tryon_results(user_id: str):
    try:
        return {"results": get_tryon_store().list_results(user_id)}
    except TryOnStoreError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


@app.delete("/users/{user_id}/photos/{photo_id}", status_code=204)
def delete_user_photo(user_id: str, photo_id: str):
    try:
        get_tryon_store().delete_user_photo(user_id, photo_id)
    except TryOnStoreError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@app.get("/")
def health():
    return {"status": "ok", "upstream": get_catvton_url(), "model": "CatVTON"}


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
    cloth_type: str = Form("upper"),
    auto_mask: bool = Form(True, description="Auto-generate the clothing mask"),
    auto_crop: bool = Form(False, description="Auto-crop and resize the person image"),
    denoise_steps: int = Form(30, ge=20, le=40),
    seed: int = Form(42),
    user_id: str | None = Form(None),
    person_photo_id: str | None = Form(None),
    wardrobe_item_id: str | None = Form(None),
    force_refresh: bool = Form(False),
):
    identifiers = (user_id, person_photo_id, wardrobe_item_id)
    if any(value is not None for value in identifiers) and not all(
        value is not None for value in identifiers
    ):
        raise HTTPException(
            status_code=422,
            detail="user_id, person_photo_id, and wardrobe_item_id must be provided together.",
        )

    try:
        store = (
            get_tryon_store()
            if all(value is not None for value in identifiers)
            else None
        )
    except TryOnStoreError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    if store is not None:
        try:
            store.validate_tryon_inputs(user_id, person_photo_id, wardrobe_item_id)
            if not force_refresh:
                cached = store.get_cached_result(
                    user_id, person_photo_id, wardrobe_item_id
                )
                if cached is not None:
                    image_bytes, metadata = cached
                    return Response(
                        content=image_bytes,
                        media_type="image/png",
                        headers={
                            "X-TryOn-Result-Id": metadata["id"],
                            "X-TryOn-Cache": "HIT",
                        },
                    )
        except TryOnStoreError as error:
            raise HTTPException(status_code=404, detail=str(error)) from error

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
        result = _retry_tryon(
            lambda: get_client().predict(
                person_image={
                    "background": handle_file(person_path),
                    "layers": [handle_file(mask_path)],
                    "composite": None,
                },
                cloth_image=handle_file(garment_path),
                cloth_type=_tryon_category(cloth_type),
                num_inference_steps=denoise_steps,
                guidance_scale=2.5,
                seed=seed,
                show_type="result only",
                api_name="/submit_function",
            )
        )

        # CatVTON returns the generated image filepath.
        output_path = result[0] if isinstance(result, (list, tuple)) else result
        with open(output_path, "rb") as f:
            image_bytes = f.read()

        headers = {"X-TryOn-Cache": "MISS"}
        if store is not None:
            try:
                saved = _retry_tryon(
                    lambda: store.save_result(
                        user_id=user_id,
                        person_photo_id=person_photo_id,
                        wardrobe_item_id=wardrobe_item_id,
                        content=image_bytes,
                    )
                )
                headers["X-TryOn-Result-Id"] = saved["id"]
            except TryOnStoreError as error:
                raise HTTPException(
                    status_code=503, detail=f"Could not save try-on result: {error}"
                ) from error
        return Response(content=image_bytes, media_type="image/png", headers=headers)

    except HTTPException:
        raise
    except Exception as e:
        # Common causes: Colab runtime stopped, queue timeout, or a changed API.
        raise HTTPException(status_code=502, detail=f"Try-on failed: {e}")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
