import feedparser
from datetime import datetime
from typing import List, Optional
from scraper.base_scraper import BaseScraper
from app.models import NewsItem
import httpx


class BrokerScraper(BaseScraper):
    """券商研报爬虫 - 聚合各大证券公司研究报告"""

    def get_source_name(self) -> str:
        return "券商研报"

    def fetch_news(self, target_date: Optional[str] = None) -> List[NewsItem]:
        items = []

        # 券商研报RSS源
        rss_sources = [
            # 头部券商研报
            ("中金公司", "https://research.cicc.com/rss/research.xml"),
            ("中信证券", "https://research.citics.com/rss/index.xml"),
            ("国泰君安", "https://research.gtja.com/rss/research.xml"),
            ("华泰证券", "https://research.htsc.com/rss/index.xml"),
            ("招商证券", "https://research.cmschina.com/rss/index.xml"),
            ("海通证券", "https://research.htsec.com/rss/index.xml"),
            ("广发证券", "https://research.gf.com.cn/rss/index.xml"),
            ("申万宏源", "https://research.swsresearch.com/rss/index.xml"),
            ("兴业证券", "https://research.xyzq.com.cn/rss/index.xml"),
            ("长江证券", "https://research.cjsc.com.cn/rss/index.xml"),
        ]

        for source_name, rss_url in rss_sources:
            try:
                # 使用 httpx 获取RSS内容，设置更长的超时时间
                response = self.client.get(rss_url, timeout=30)
                if response.status_code != 200:
                    continue

                feed = feedparser.parse(response.content)

                for entry in feed.get('entries', [])[:30]:
                    try:
                        title = entry.get('title', '')
                        link = entry.get('link', '')
                        summary = entry.get('description', entry.get('summary', ''))
                        published_str = entry.get('published', '')

                        if not title or not link:
                            continue

                        # 过滤掉非研报内容
                        if not any(keyword in title for keyword in ['研报', '报告', '深度', '分析', '投资', '策略']):
                            continue

                        published_dt = self._parse_date(published_str)

                        if target_date and not self._match_date(published_dt, target_date):
                            continue

                        items.append(NewsItem(
                            source=f"{source_name}研报",
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
