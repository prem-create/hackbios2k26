"""HTTP routes for chat sessions and wardrobe descriptions."""

from uuid import UUID

from fastapi import APIRouter, File, Form, HTTPException, Query, UploadFile, status
from postgrest.exceptions import APIError
from pydantic import BaseModel, Field
from storage3.exceptions import StorageApiError

from chat_service import ChatNotFoundError, ChatServiceError, get_chat_service

router = APIRouter(prefix="/chat", tags=["chat"])


class CreateSessionRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=128)


class SendMessageRequest(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class WardrobeItemRequest(BaseModel):
    user_id: str = Field(min_length=1, max_length=128)
    name: str = Field(min_length=1, max_length=160)
    category: str = Field(min_length=1, max_length=80)
    description: str = Field(min_length=1, max_length=2000)
    image_path: str | None = Field(default=None, max_length=1000)


class WardrobeItemUpdateRequest(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=160)
    category: str | None = Field(default=None, min_length=1, max_length=80)
    description: str | None = Field(default=None, min_length=1, max_length=2000)
    image_path: str | None = Field(default=None, max_length=1000)


def service():
    try:
        return get_chat_service()
    except ChatServiceError as error:
        raise HTTPException(status_code=503, detail=str(error)) from error


def call_service(operation):
    try:
        return operation()
    except ChatNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except ChatServiceError as error:
        raise HTTPException(status_code=502, detail=str(error)) from error
    except APIError as error:
        if getattr(error, "code", None) == "42501":
            raise HTTPException(
                status_code=503,
                detail=(
                    "Supabase denied the request with row-level security. "
                    "Set SUPABASE_SECRET_KEY to the backend secret/service-role key "
                    "(sb_secret_...), not the publishable key."
                ),
            ) from error
        raise HTTPException(
            status_code=502,
            detail="Supabase request failed. Run supabase_schema.sql and verify the server key.",
        ) from error
    except StorageApiError as error:
        detail = str(error)
        if "Bucket not found" in detail:
            raise HTTPException(
                status_code=503,
                detail="Supabase Storage bucket 'wardrobe' does not exist. Create it as a private bucket in Dashboard > Storage.",
            ) from error
        raise HTTPException(
            status_code=502, detail="Supabase Storage request failed."
        ) from error


@router.post(
    "/sessions",
    status_code=status.HTTP_201_CREATED,
    summary="Create a chat session",
    description="Create this first. The response contains the UUID required by the other session endpoints.",
)
def create_session(payload: CreateSessionRequest):
    return call_service(lambda: service().create_session(payload.user_id))


@router.get(
    "/sessions/{session_id}",
    summary="Get a chat session",
    description="session_id must be the UUID returned by POST /chat/sessions, not an arbitrary number.",
)
def get_session(session_id: UUID, user_id: str = Query(min_length=1, max_length=128)):
    return call_service(lambda: service().get_session(str(session_id), user_id))


@router.get("/sessions/{session_id}/messages")
def get_messages(
    session_id: UUID,
    user_id: str = Query(min_length=1, max_length=128),
    limit: int = Query(50, ge=1, le=100),
):
    return call_service(
        lambda: {"messages": service().get_messages(str(session_id), user_id, limit)}
    )


@router.post("/sessions/{session_id}/messages")
def send_message(
    session_id: UUID,
    payload: SendMessageRequest,
    user_id: str = Query(min_length=1, max_length=128),
):
    result = call_service(
        lambda: service().send_message(str(session_id), user_id, payload.content)
    )
    assistant_message = result.pop("message")
    result["message_id"] = assistant_message["id"]
    result["role"] = assistant_message["role"]
    result["message"] = assistant_message["content"]
    return result


@router.get("/sessions/{session_id}/suggestions")
def get_suggestions(
    session_id: UUID, user_id: str = Query(min_length=1, max_length=128)
):
    return call_service(
        lambda: {"suggestions": service().get_suggestions(str(session_id), user_id)}
    )


@router.post("/wardrobe/items", status_code=status.HTTP_201_CREATED)
def create_wardrobe_item(payload: WardrobeItemRequest):
    return call_service(lambda: service().create_wardrobe_item(payload.model_dump()))


@router.post("/wardrobe/items/upload", status_code=status.HTTP_201_CREATED)
def upload_wardrobe_item(
    user_id: str = Form(..., min_length=1, max_length=128),
    name: str = Form(..., min_length=1, max_length=160),
    category: str = Form(..., min_length=1, max_length=80),
    description: str = Form(..., min_length=1, max_length=2000),
    image: UploadFile = File(...),
):
    allowed_content_types = {
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp",
    }
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
    if content_type not in allowed_content_types and extension_type is None:
        raise HTTPException(
            status_code=415,
            detail="Only JPG, JPEG, PNG, and WebP wardrobe images are supported.",
        )
    content = image.file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413, detail="Wardrobe images must be 10 MB or smaller."
        )
    return call_service(
        lambda: service().create_wardrobe_item_with_image(
            user_id=user_id,
            name=name,
            category=category,
            description=description,
            filename=image.filename or "wardrobe-image",
            content_type=(
                content_type
                if content_type in allowed_content_types
                else extension_type
            ),
            content=content,
        )
    )


@router.patch("/wardrobe/items/{item_id}")
def update_wardrobe_item(
    item_id: UUID,
    payload: WardrobeItemUpdateRequest,
    user_id: str = Query(min_length=1, max_length=128),
):
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        raise HTTPException(status_code=422, detail="At least one field is required.")
    return call_service(
        lambda: service().update_wardrobe_item(str(item_id), user_id, updates)
    )


@router.delete("/wardrobe/items/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_wardrobe_item(
    item_id: UUID, user_id: str = Query(min_length=1, max_length=128)
):
    call_service(lambda: service().delete_wardrobe_item(str(item_id), user_id))
    return None


@router.get("/wardrobe/items")
def list_wardrobe_items(user_id: str = Query(min_length=1, max_length=128)):
    return call_service(lambda: {"items": service().get_wardrobe_items(user_id)})
