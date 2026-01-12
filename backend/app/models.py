from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class NewsItem(BaseModel):
    source: str
    title: str
    summary: str
    url: str
    published_at: str
    fetched_at: str


class CrawlRequest(BaseModel):
    date: Optional[str] = None  # YYYY-MM-DD
    keywords: Optional[list[str]] = None


class HealthResponse(BaseModel):
    status: str
    message: str


class CrawlResponse(BaseModel):
    success: bool
    count: int
    failed_sources: list[str]
    message: str
