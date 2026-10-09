"""Supabase persistence and Gemini orchestration for wardrobe chat."""

import json
import os
from functools import lru_cache
from typing import Any

from dotenv import load_dotenv
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
from supabase import Client, create_client

load_dotenv()

RECENT_MESSAGE_COUNT = 12
SYSTEM_INSTRUCTION = """You are a helpful wardrobe stylist. Converse naturally to learn the
occasion and preferences. Use only supplied wardrobe item IDs; never invent items. Set
is_ready_for_suggestion true only if you have enough information and can recommend at
least one supplied item. Otherwise ask one useful follow-up question. Return JSON only."""


class ChatServiceError(RuntimeError):
    pass


class ChatNotFoundError(ChatServiceError):
    pass


class OutfitSuggestion(BaseModel):
    name: str = Field(min_length=1, max_length=160)
    wardrobe_item_ids: list[str] = Field(default_factory=list)
    reason: str = Field(min_length=1, max_length=1000)


class GeminiChatResponse(BaseModel):
    assistant_message: str = Field(min_length=1, max_length=4000)
    is_ready_for_suggestion: bool
    missing_information: list[str] = Field(default_factory=list)
    session_summary: str = Field(max_length=4000)
    suggestions: list[OutfitSuggestion] = Field(default_factory=list, max_length=3)


class ChatService:
    def __init__(self, supabase: Client, gemini_client: genai.Client, model: str):
        self.supabase = supabase
        self.gemini_client = gemini_client
        self.model = model

    def create_session(self, user_id: str) -> dict[str, Any]:
        return self._one(
            self.supabase.table("chat_sessions").insert({"user_id": user_id}).execute(),
            "Could not create chat session",
        )

    def get_session(self, session_id: str, user_id: str) -> dict[str, Any]:
        response = (
            self.supabase.table("chat_sessions")
            .select("*")
            .eq("id", session_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        return self._one(response, "Chat session was not found", not_found=True)

    def get_messages(
        self, session_id: str, user_id: str, limit: int
    ) -> list[dict[str, Any]]:
        self.get_session(session_id, user_id)
        return (
            self.supabase.table("chat_messages")
            .select("id, role, content, metadata, created_at")
            .eq("session_id", session_id)
            .order("created_at")
            .limit(limit)
            .execute()
            .data
            or []
        )

    def get_wardrobe_items(self, user_id: str) -> list[dict[str, Any]]:
        return (
            self.supabase.table("wardrobe_items")
            .select("id, name, category, description, image_path, created_at")
            .eq("user_id", user_id)
            .order("created_at")
            .execute()
            .data
            or []
        )

    def create_wardrobe_item(self, item: dict[str, Any]) -> dict[str, Any]:
        return self._one(
            self.supabase.table("wardrobe_items").insert(item).execute(),
            "Could not create wardrobe item",
        )

    def get_suggestions(self, session_id: str, user_id: str) -> list[dict[str, Any]]:
        self.get_session(session_id, user_id)
        return (
            self.supabase.table("outfit_suggestions")
            .select("id, name, wardrobe_item_ids, reason, created_at")
            .eq("session_id", session_id)
            .order("created_at")
            .execute()
            .data
            or []
        )

    def send_message(
        self, session_id: str, user_id: str, content: str
    ) -> dict[str, Any]:
        session = self.get_session(session_id, user_id)
        self._one(
            self.supabase.table("chat_messages")
            .insert({"session_id": session_id, "role": "user", "content": content})
            .execute(),
            "Could not save user message",
        )
        response = self._ask_gemini(
            session, self._recent_messages(session_id), self.get_wardrobe_items(user_id)
        )
        wardrobe_ids = {item["id"] for item in self.get_wardrobe_items(user_id)}
        suggestions = [
            item
            for item in response.suggestions
            if set(item.wardrobe_item_ids).issubset(wardrobe_ids)
        ]
        is_ready = response.is_ready_for_suggestion and bool(suggestions)
        assistant_message = self._one(
            self.supabase.table("chat_messages")
            .insert(
                {
                    "session_id": session_id,
                    "role": "assistant",
                    "content": response.assistant_message,
                    "metadata": {
                        "missing_information": response.missing_information,
                        "is_ready_for_suggestion": is_ready,
                    },
                }
            )
            .execute(),
            "Could not save assistant message",
        )
        self.supabase.table("chat_sessions").update(
            {
                "context_summary": response.session_summary,
                "is_ready_for_suggestion": is_ready,
            }
        ).eq("id", session_id).execute()
        saved = []
        for suggestion in suggestions:
            saved.append(
                self._one(
                    self.supabase.table("outfit_suggestions")
                    .insert(
                        {
                            "session_id": session_id,
                            "message_id": assistant_message["id"],
                            "name": suggestion.name,
                            "wardrobe_item_ids": suggestion.wardrobe_item_ids,
                            "reason": suggestion.reason,
                        }
                    )
                    .execute(),
                    "Could not save outfit suggestion",
                )
            )
        return {
            "session_id": session_id,
            "message": assistant_message,
            "is_ready_for_suggestion": is_ready,
            "missing_information": response.missing_information,
            "suggestions": saved,
        }

    def _recent_messages(self, session_id: str) -> list[dict[str, Any]]:
        response = (
            self.supabase.table("chat_messages")
            .select("role, content")
            .eq("session_id", session_id)
            .order("created_at", desc=True)
            .limit(RECENT_MESSAGE_COUNT)
            .execute()
        )
        return list(reversed(response.data or []))

    def _ask_gemini(
        self,
        session: dict[str, Any],
        history: list[dict[str, Any]],
        wardrobe: list[dict[str, Any]],
    ) -> GeminiChatResponse:
        prompt = "\n\n".join(
            (
                SYSTEM_INSTRUCTION,
                f"Saved summary: {session.get('context_summary') or '(none)'}",
                f"History: {json.dumps(history, ensure_ascii=False)}",
                f"Wardrobe: {json.dumps(wardrobe, ensure_ascii=False)}",
            )
        )
        try:
            result = self.gemini_client.models.generate_content(
                model=self.model,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=GeminiChatResponse,
                ),
            )
            return GeminiChatResponse.model_validate_json(result.text)
        except Exception as error:
            raise ChatServiceError(f"Gemini request failed: {error}") from error

    @staticmethod
    def _one(response: Any, message: str, *, not_found: bool = False) -> dict[str, Any]:
        if not response.data:
            if not_found:
                raise ChatNotFoundError(message)
            raise ChatServiceError(message)
        return response.data[0]


@lru_cache
def get_chat_service() -> ChatService:
    supabase_url = (os.getenv("SUPABASE_URL") or "").strip()
    supabase_key = (os.getenv("SUPABASE_SECRET_KEY") or "").strip()
    gemini_key = (os.getenv("GEMINI_API_KEY") or "").strip()
    model = (os.getenv("GEMINI_MODEL") or "gemini-2.5-flash").strip()
    if not supabase_url or not supabase_key:
        raise ChatServiceError(
            "SUPABASE_URL and SUPABASE_SECRET_KEY must be configured"
        )
    if not gemini_key:
        raise ChatServiceError("GEMINI_API_KEY must be configured")
    return ChatService(
        create_client(supabase_url, supabase_key),
        genai.Client(api_key=gemini_key),
        model,
    )
