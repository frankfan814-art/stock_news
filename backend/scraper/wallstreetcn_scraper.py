import feedparser
from datetime import datetime
from typing import List, Optional
from scraper.base_scraper import BaseScraper
from app.models import NewsItem


class WallstreetcnScraper(BaseScraper):
    """华尔街见闻爬虫 - 使用 Reddit Stocks/Economy RSS 作为替代源"""

    def get_source_name(self) -> str:
        return "Reddit 股市"

    def fetch_news(self, target_date: Optional[str] = None) -> List[NewsItem]:
        items = []
        try:
            # 使用 Reddit Stocks RSS
            feed = feedparser.parse("https://www.reddit.com/r/stocks/.rss")

            for entry in feed.get('entries', [])[:50]:
                try:
                    title = entry.get('title', '')
                    link = entry.get('link', '')
                    summary = entry.get('description', entry.get('summary', ''))
                    published_str = entry.get('published', '')

                    if not title or not link:
                        continue

                    published_dt = self._parse_date(published_str)

                    if target_date and not self._match_date(published_dt, target_date):
                        continue

                    items.append(NewsItem(
                        source=self.get_source_name(),
                        title=title.strip(),
                        summary=self._clean_summary(summary),
                        url=link,
                        published_at=self._format_datetime(published_dt),
                        fetched_at=self._format_datetime(datetime.now())
                    ))

                except Exception:
                    continue

        except Exception:
            pass

        return items

    def _parse_date(self, date_str: str) -> datetime:
        """解析日期字符串"""
        try:
            from dateutil import parser
            return parser.parse(date_str)
        except:
            return datetime.now()

    def _match_date(self, dt: datetime, target_date: str) -> bool:
        """检查日期是否匹配"""
        try:
            target = datetime.strptime(target_date, "%Y-%m-%d").date()
            return dt.date() == target
        except:
            return True

    def _clean_summary(self, html: str) -> str:
        """清理 HTML 标签"""
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(html, 'lxml')
        text = soup.get_text(strip=True)
        return text[:200] + "..." if len(text) > 200 else text
