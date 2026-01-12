from typing import List, Optional
from scraper.base_scraper import BaseScraper
from scraper.sina_scraper import SinaScraper
from scraper.eastmoney_scraper import EastmoneyScraper
from scraper.wallstreetcn_scraper import WallstreetcnScraper
from scraper.cls_scraper import ClsScraper
from scraper.broker_scraper import BrokerScraper
from scraper.kr36_scraper import Kr36Scraper
from scraper.huxiu_scraper import HuxiuScraper
from app.models import NewsItem
from app.translator import translator
import logging
import asyncio

logger = logging.getLogger(__name__)


class ScraperManager:
    """爬虫管理器"""

    def __init__(self):
        self.scrapers: List[BaseScraper] = [
            SinaScraper(),        # 新浪财经
            EastmoneyScraper(),   # 东方财富
            WallstreetcnScraper(),# 多源财经聚合（第一财经、财新、雪球等）
            ClsScraper(),         # 财联社
            BrokerScraper(),      # 券商研报（中金、中信、国泰君安等）
            Kr36Scraper(),        # 36氪（科技资讯）
            HuxiuScraper(),       # 虎嗅（商业资讯）
        ]

    def fetch_all(self, target_date: Optional[str] = None) -> tuple[List[NewsItem], List[str]]:
        """
        从所有来源抓取新闻
        返回: (新闻列表, 失败的来源列表)
        """
        all_items = []
        failed_sources = []

        for scraper in self.scrapers:
            try:
                with scraper:
                    items = scraper.fetch_news(target_date)
                    all_items.extend(items)
                    logger.info(f"{scraper.get_source_name()} 抓取到 {len(items)} 条新闻")
            except Exception as e:
                logger.error(f"{scraper.get_source_name()} 抓取失败: {e}")
                failed_sources.append(scraper.get_source_name())

        # 翻译非中文内容
        all_items = self._translate_items(all_items)

        return all_items, failed_sources

    def _translate_items(self, items: List[NewsItem]) -> List[NewsItem]:
        """翻译非中文的新闻标题和摘要"""
        translated_items = []
        for item in items:
            try:
                translated_title, translated_summary = translator.translate_news_item(
                    item.title, item.summary
                )
                # 创建翻译后的新闻项
                translated_items.append(NewsItem(
                    source=item.source,
                    title=translated_title,
                    summary=translated_summary,
                    url=item.url,
                    published_at=item.published_at,
                    fetched_at=item.fetched_at
                ))
            except Exception as e:
                logger.warning(f"翻译失败: {e}")
                translated_items.append(item)
        return translated_items

    def close_all(self):
        """关闭所有爬虫"""
        for scraper in self.scrapers:
            try:
                scraper.close()
            except Exception:
                pass
