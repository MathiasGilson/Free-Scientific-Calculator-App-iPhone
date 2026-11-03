"""Route Jev and its text helper through OpenRouter with one key, as RecordMeeting's suite does."""

import os
import random
import re
import time

from jev_ultrafast import model

TYPESAFE_URL = "https://api.typesafe.ai/v1/systemone"
SYSTEM_ONE_URL = "https://openrouter.ai/api/v1/systemone"
RETRIABLE = re.compile(r"connection failed|HTTP (429|5\d\d)|Model unavailable")


def api_key():
    key = os.environ.get("OPEN_ROUTER_API_KEY") or os.environ.get("OPENROUTER_API_KEY")
    if not key:
        raise SystemExit("Set OPEN_ROUTER_API_KEY.")
    return key


def configure():
    key = api_key()
    os.environ["TYPESAFE_API_KEY"] = key
    os.environ.setdefault("TYPESAFE_MODEL", "jev-latest")
    os.environ.setdefault("TEXT_MODEL_API_KEY", key)
    os.environ.setdefault("TEXT_MODEL_BASE_URL", "https://openrouter.ai/api/v1")
    os.environ.setdefault("TEXT_MODEL", "google/gemini-2.5-flash-lite")
    os.environ.setdefault("TEXT_MODEL_REASONING", "none")

    original = model.post_json

    def routed(url, key, body):
        # Nothing has executed when a model call fails, so retrying is safe.
        for attempt in range(6):
            try:
                return original(SYSTEM_ONE_URL if url == TYPESAFE_URL else url, key, body)
            except RuntimeError as exc:
                if not RETRIABLE.search(str(exc)) or attempt == 5:
                    raise
                time.sleep(min(2.0 * 2**attempt, 30) + random.uniform(0, 1))

    model.post_json = routed


def system_one(body):
    return model.post_json(SYSTEM_ONE_URL, api_key(), body)
