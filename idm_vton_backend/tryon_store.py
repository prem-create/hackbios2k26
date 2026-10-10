import os
from functools import lru_cache
from typing import Any
from uuid import UUID, uuid4

from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()


class TryOnStoreError(RuntimeError):
    pass


class TryOnStore:
    def __init__(self, supabase: Client, bucket: str):
        self.supabase = supabase
        self.bucket = supabase.storage.from_(bucket)

    def get_setting(self, key: str) -> str | None:
        try:
            response = (
                self.supabase.table("app_settings")
                .select("value")
                .eq("key", key)
                .limit(1)
                .execute()
            )
        except Exception as error:
            raise TryOnStoreError(f"Could not read application setting '{key}'") from error
        if not response.data:
            return None
        value = response.data[0].get("value")
        return value.strip() if isinstance(value, str) and value.strip() else None

    def save_user_photo(
        self,
        *,
        user_id: str,
        filename: str,
        content_type: str,
        content: bytes,
    ) -> dict[str, Any]:
        photo_id = str(uuid4())
        path = f"users/{user_id}/photos/{photo_id}-{os.path.basename(filename)}"
        try:
            self.bucket.upload(
                path,
                content,
                {"content-type": content_type, "upsert": "false"},
            )
            response = (
                self.supabase.table("user_photos")
                .insert(
                    {
                        "id": photo_id,
                        "user_id": user_id,
                        "image_path": path,
                        "original_filename": os.path.basename(filename),
                    }
                )
                .execute()
            )
            item = _one(response, "Could not save user photo")
            item["image_url"] = self._signed_url(path)
            return item
        except Exception:
            try:
                self.bucket.remove([path])
            except Exception:
                pass
            raise

    def list_user_photos(self, user_id: str) -> list[dict[str, Any]]:
        rows = (
            self.supabase.table("user_photos")
            .select("id, user_id, original_filename, image_path, created_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
            .data
            or []
        )
        for row in rows:
            row["image_url"] = self._signed_url(row.get("image_path"))
        return rows

    def delete_user_photo(self, user_id: str, photo_id: str) -> None:
        row = self._photo(user_id, photo_id)
        self.supabase.table("user_photos").delete().eq("id", photo_id).eq(
            "user_id", user_id
        ).execute()
        if row.get("image_path"):
            self.bucket.remove([row["image_path"]])

    def get_cached_result(
        self, user_id: str, person_photo_id: str, wardrobe_item_id: str
    ) -> tuple[bytes, dict[str, Any]] | None:
        row = (
            self.supabase.table("tryon_results")
            .select("*")
            .eq("user_id", user_id)
            .eq("person_photo_id", person_photo_id)
            .eq("wardrobe_item_id", wardrobe_item_id)
            .limit(1)
            .execute()
            .data
            or []
        )
        if not row:
            return None
        item = row[0]
        try:
            response = self.bucket.download(item["result_path"])
        except Exception as error:
            if "not_found" in str(error) or "Object not found" in str(error):
                return None
            raise
        return response, item

    def list_results(self, user_id: str) -> list[dict[str, Any]]:
        rows = (
            self.supabase.table("tryon_results")
            .select(
                "id, user_id, person_photo_id, wardrobe_item_id, result_path, created_at"
            )
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
            .data
            or []
        )
        for row in rows:
            row["image_url"] = self._signed_url(row.get("result_path"))
        return rows

    def create_job(
        self, user_id: str, person_photo_id: str, wardrobe_item_id: str
    ) -> dict[str, Any]:
        self.validate_tryon_inputs(user_id, person_photo_id, wardrobe_item_id)
        cached = (
            self.supabase.table("tryon_results")
            .select("id")
            .eq("user_id", user_id)
            .eq("person_photo_id", person_photo_id)
            .eq("wardrobe_item_id", wardrobe_item_id)
            .limit(1)
            .execute()
            .data
            or []
        )
        response = (
            self.supabase.table("tryon_jobs")
            .insert(
                {
                    "user_id": user_id,
                    "person_photo_id": person_photo_id,
                    "wardrobe_item_id": wardrobe_item_id,
                    "status": "completed" if cached else "queued",
                    "result_id": cached[0]["id"] if cached else None,
                }
            )
            .execute()
        )
        return _one(response, "Could not create try-on job")

    def get_job(self, user_id: str, job_id: str) -> dict[str, Any]:
        _parse_uuid(job_id, "job_id")
        response = (
            self.supabase.table("tryon_jobs")
            .select("*")
            .eq("id", job_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return _one(response, "Try-on job was not found")

    def update_job(self, job_id: str, values: dict[str, Any]) -> dict[str, Any]:
        response = (
            self.supabase.table("tryon_jobs").update(values).eq("id", job_id).execute()
        )
        return _one(response, "Could not update try-on job")

    def get_photo_content(self, user_id: str, photo_id: str) -> bytes:
        photo = self._photo(user_id, photo_id)
        return self.bucket.download(photo["image_path"])

    def get_garment_content(
        self, user_id: str, garment_id: str
    ) -> tuple[bytes, str, str]:
        _parse_uuid(garment_id, "wardrobe_item_id")
        response = (
            self.supabase.table("wardrobe_items")
            .select("image_path, category")
            .eq("id", garment_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        garment = _one(response, "Wardrobe item was not found")
        if not garment.get("image_path"):
            raise TryOnStoreError("The selected wardrobe item has no image.")
        return (
            self.bucket.download(garment["image_path"]),
            garment["image_path"],
            garment.get("category") or "upper",
        )

    def validate_tryon_inputs(
        self, user_id: str, person_photo_id: str, wardrobe_item_id: str
    ) -> None:
        self._photo(user_id, person_photo_id)
        _parse_uuid(wardrobe_item_id, "wardrobe_item_id")
        response = (
            self.supabase.table("wardrobe_items")
            .select("id")
            .eq("id", wardrobe_item_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        _one(response, "Wardrobe item was not found")

    def save_result(
        self,
        *,
        user_id: str,
        person_photo_id: str,
        wardrobe_item_id: str,
        content: bytes,
    ) -> dict[str, Any]:
        existing = (
            self.supabase.table("tryon_results")
            .select("*")
            .eq("user_id", user_id)
            .eq("person_photo_id", person_photo_id)
            .eq("wardrobe_item_id", wardrobe_item_id)
            .limit(1)
            .execute()
            .data
            or []
        )
        if existing:
            item = existing[0]
            try:
                self.bucket.download(item["result_path"])
                item["image_url"] = self._signed_url(item["result_path"])
                return item
            except Exception as error:
                if "not_found" not in str(error) and "Object not found" not in str(error):
                    raise

        result_id = str(uuid4())
        path = f"users/{user_id}/tryon-results/{result_id}.png"
        self.bucket.upload(
            path,
            content,
            {"content-type": "image/png", "upsert": "false"},
        )
        try:
            if existing:
                response = (
                    self.supabase.table("tryon_results")
                    .update({"result_path": path})
                    .eq("id", existing[0]["id"])
                    .execute()
                )
            else:
                response = (
                    self.supabase.table("tryon_results")
                    .insert(
                        {
                            "id": result_id,
                            "user_id": user_id,
                            "person_photo_id": person_photo_id,
                            "wardrobe_item_id": wardrobe_item_id,
                            "result_path": path,
                        }
                    )
                    .execute()
                )
            item = _one(response, "Could not save try-on result")
            item["image_url"] = self._signed_url(item.get("result_path"))
            return item
        except Exception:
            try:
                self.bucket.remove([path])
            except Exception:
                pass
            raise

    def _photo(self, user_id: str, photo_id: str) -> dict[str, Any]:
        _parse_uuid(photo_id, "person_photo_id")
        response = (
            self.supabase.table("user_photos")
            .select("*")
            .eq("id", photo_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return _one(response, "User photo was not found")

    def _signed_url(self, path: str | None) -> str | None:
        if not path:
            return None
        expires_in = int(os.getenv("WARDROBE_IMAGE_URL_TTL", "3600"))
        result = self.bucket.create_signed_url(path, expires_in)
        return result.get("signedURL") or result.get("signedUrl")


@lru_cache
def get_tryon_store() -> TryOnStore:
    url = (os.getenv("SUPABASE_URL") or "").strip()
    key = (os.getenv("SUPABASE_SECRET_KEY") or "").strip()
    if not url or not key:
        raise TryOnStoreError("SUPABASE_URL and SUPABASE_SECRET_KEY must be configured")
    bucket = (os.getenv("WARDROBE_BUCKET") or "wardrobe").strip()
    return TryOnStore(create_client(url, key), bucket)


def _one(response: Any, message: str) -> dict[str, Any]:
    if not response.data:
        raise TryOnStoreError(message)
    return response.data[0]


def _parse_uuid(value: str, field: str) -> str:
    try:
        return str(UUID(value))
    except ValueError as error:
        raise TryOnStoreError(f"{field} must be a UUID") from error
