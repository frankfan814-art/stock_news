from datetime import datetime
from typing import List, Optional
from scraper.base_scraper import BaseScraper
from app.models import NewsItem
import httpx
import time


class ClsScraper(BaseScraper):
    """财联社爬虫 - 使用 API"""

    def get_source_name(self) -> str:
        return "财联社"

    def fetch_news(self, target_date: Optional[str] = None) -> List[NewsItem]:
        items = []
        try:
            # 使用财联社的刷新电讯列表 API
            current_time = int(time.time())
            url = "https://www.cls.cn/nodeapi/refreshTelegraphList"
            params = {
                "app": "CailianpressWeb",
                "lastTime": current_time,
                "os": "web",
                "sv": "8.4.6",
                "sign": ""
            }

            response = httpx.get(url, params=params, timeout=30)
            if response.status_code == 200:
                data = response.json()
                if "l" in data:
                    # data['l'] 是一个字典，key 是新闻 id
                    for item_id, item_data in data["l"].items():
                        try:
                            title = item_data.get("brief", item_data.get("title", ""))
                            content = item_data.get("content", title)

                            if not title:
                                continue

                            # 构造链接
                            link = f"https://www.cls.cn/telegraph/{item_id}"

                            # 解析时间
                            ctime = item_data.get("ctime", int(time.time()))
                            published_dt = datetime.fromtimestamp(ctime)

                            # 日期过滤
                            if target_date and not self._match_date(published_dt, target_date):
                                continue

                            items.append(NewsItem(
                                source=self.get_source_name(),
                                title=title.strip(),
                                summary=self._clean_summary(content),
                                url=link,
                                published_at=self._format_datetime(published_dt),
                                fetched_at=self._format_datetime(datetime.now())
                            ))

                        except Exception:
                            continue

        except Exception as e:
            # API 失败时尝试网页抓取
            items.extend(self._scrape_web(target_date))

        return items

    def _scrape_web(self, target_date: Optional[str] = None) -> List[NewsItem]:
        """网页解析备用方案 - 使用 Playwright"""
        items = []
        try:
            html = self._fetch_with_playwright("https://www.cls.cn/telegraph", wait_time=5000)
            if not html:
                return items

            from bs4 import BeautifulSoup
            soup = BeautifulSoup(html, 'lxml')

            # 查找电讯内容
            selectors = [
                'div[class*="telegraph"]',
                'div[class*="item"]',
                'article',
                'a[href*="/telegraph/"]'
            ]

            for selector in selectors:
                elements = soup.select(selector)
                if elements:
                    for elem in elements[:50]:
                        try:
                            title_elem = elem.select_one('a') or elem
                            title = title_elem.get_text(strip=True)

                            link = title_elem.get('href', '')
                            if link and not link.startswith('http'):
                                link = "https://www.cls.cn" + link

                            if not title or not link:
                                continue

                            published_dt = datetime.now()

                            if target_date and not self._match_date(published_dt, target_date):
                                continue

                            summary = title[:100] + "..." if len(title) > 100 else title

                            items.append(NewsItem(
                                source=self.get_source_name(),
                                title=title,
                                summary=summary,
                                url=link,
                                published_at=self._format_datetime(published_dt),
                                fetched_at=self._format_datetime(datetime.now())
                            ))

                        except Exception:
                            continue

                    if items:
                        break

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

    def _clean_summary(self, text: str) -> str:
        """清理摘要"""
        text = text.strip()
        if len(text) > 200:
            text = text[:200] + "..."
        return text
