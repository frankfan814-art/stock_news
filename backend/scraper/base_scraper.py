from abc import ABC, abstractmethod
from typing import List, Optional
import httpx
import logging
from datetime import datetime
from app.models import NewsItem

logger = logging.getLogger(__name__)


class BaseScraper(ABC):
    """爬虫基类"""

    def __init__(self):
        self.client = httpx.Client(
            headers={
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
            },
            timeout=30.0,
            follow_redirects=True
        )
        self.max_retries = 3
        self._playwright_page = None

    @abstractmethod
    def get_source_name(self) -> str:
        """返回来源名称"""
        pass

    @abstractmethod
    def fetch_news(self, target_date: Optional[str] = None) -> List[NewsItem]:
        """抓取新闻"""
        pass

    def _fetch_with_retry(self, url: str) -> Optional[str]:
        """带重试的请求"""
        for attempt in range(self.max_retries):
            try:
                response = self.client.get(url)
                response.raise_for_status()
                return response.text
            except Exception as e:
                logger.warning(f"{self.get_source_name()} 请求失败 (尝试 {attempt + 1}/{self.max_retries}): {e}")
                if attempt == self.max_retries - 1:
                    return None
        return None

    def _fetch_with_playwright(self, url: str, wait_selector: Optional[str] = None, wait_time: int = 3000) -> Optional[str]:
        """使用 Playwright 获取 JavaScript 渲染的页面"""
        try:
            from playwright.sync_api import sync_playwright

            with sync_playwright() as p:
                browser = p.chromium.launch(headless=True)
                page = browser.new_page(
                    user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
                )
                page.goto(url, wait_until="domcontentloaded", timeout=30000)

                # 等待特定元素出现
                if wait_selector:
                    try:
                        page.wait_for_selector(wait_selector, timeout=10000)
                    except:
                        pass

                # 额外等待时间让 JavaScript 执行
                page.wait_for_timeout(wait_time)

                content = page.content()
                browser.close()
                return content
        except Exception as e:
            logger.error(f"{self.get_source_name()} Playwright 抓取失败: {e}")
            return None

    def _format_datetime(self, dt: datetime) -> str:
        """格式化日期时间为 ISO 8601 格式"""
        return dt.isoformat()

    def close(self):
        """关闭客户端"""
        self.client.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
