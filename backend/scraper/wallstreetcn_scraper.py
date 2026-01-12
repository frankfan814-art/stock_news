import feedparser
from datetime import datetime
from typing import List, Optional
from scraper.base_scraper import BaseScraper
from app.models import NewsItem


class WallstreetcnScraper(BaseScraper):
    """多源财经新闻爬虫 - 聚合国内各大财经媒体RSS"""

    def get_source_name(self) -> str:
        return "财经聚合"

    def fetch_news(self, target_date: Optional[str] = None) -> List[NewsItem]:
        items = []

        # 国内可用的RSS源
        rss_sources = [
            # 网易财经RSS（可用）
            ("网易财经", "http://money.163.com/special/002557S8/money_rss.xml"),

            # 搜狐财经RSS（可用）
            ("搜狐财经", "http://business.sohu.com/rss/business.xml"),

            # 和讯网RSS（可用）
            ("和讯网", "http://rss.hexun.com/rss/News.xml"),
        ]

        for source_name, rss_url in rss_sources:
            try:
                feed = feedparser.parse(rss_url)

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
                            source=source_name,
                            title=title.strip(),
                            summary=self._clean_summary(summary),
                            url=link,
                            published_at=self._format_datetime(published_dt),
                            fetched_at=self._format_datetime(datetime.now())
                        ))

                    except Exception:
                        continue

                # 如果成功获取到数据，继续尝试其他源（聚合多个来源）
                # 不 break，尝试获取所有可用源

            except Exception:
                continue

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

    def _clean_summary(self, text: str) -> str:
        """清理 HTML 标签"""
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(text, 'lxml')
        text = soup.get_text(strip=True)
        return text[:200] + "..." if len(text) > 200 else text
