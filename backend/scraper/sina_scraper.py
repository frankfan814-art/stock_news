import httpx
from bs4 import BeautifulSoup
from datetime import datetime
from typing import List, Optional
from scraper.base_scraper import BaseScraper
from app.models import NewsItem


class SinaScraper(BaseScraper):
    """新浪财经爬虫 - 使用网页抓取"""

    def get_source_name(self) -> str:
        return "新浪财经"

    def fetch_news(self, target_date: Optional[str] = None) -> List[NewsItem]:
        items = []

        try:
            # 使用新浪财经滚动新闻页面
            url = "https://finance.sina.com.cn/roll/index.d.html"
            response = self.client.get(url, timeout=15)

            if response.status_code != 200:
                return items

            soup = BeautifulSoup(response.text, 'lxml')

            # 查找新闻列表
            news_list = soup.select('li a[href*="/s/"]') or soup.select('a[href*="/finance/"]')

            for link_elem in news_list[:50]:
                try:
                    title = link_elem.get_text(strip=True)
                    href = link_elem.get('href', '')

                    if not title or not href:
                        continue

                    # 补全URL
                    if href.startswith('/'):
                        href = 'https://finance.sina.com.cn' + href

                    published_dt = datetime.now()

                    if target_date and not self._match_date(published_dt, target_date):
                        continue

                    items.append(NewsItem(
                        source=self.get_source_name(),
                        title=title,
                        summary=title[:100] + "...",
                        url=href,
                        published_at=self._format_datetime(published_dt),
                        fetched_at=self._format_datetime(datetime.now())
                    ))

                except Exception:
                    continue

        except Exception:
            pass

        return items

    def _match_date(self, dt: datetime, target_date: str) -> bool:
        """检查日期是否匹配"""
        try:
            target = datetime.strptime(target_date, "%Y-%m-%d").date()
            return dt.date() == target
        except:
            return True
