from typing import List, Optional
from scraper.base_scraper import BaseScraper
from scraper.sina_scraper import SinaScraper
from scraper.eastmoney_scraper import EastmoneyScraper
from scraper.wallstreetcn_scraper import WallstreetcnScraper
from scraper.cls_scraper import ClsScraper
from scraper.kr36_scraper import Kr36Scraper
from scraper.huxiu_scraper import HuxiuScraper
from app.models import NewsItem
import logging

logger = logging.getLogger(__name__)


class ScraperManager:
    """爬虫管理器"""

    def __init__(self):
        self.scrapers: List[BaseScraper] = [
            SinaScraper(),        # 新浪财经
            EastmoneyScraper(),   # 东方财富
            WallstreetcnScraper(),# 财经聚合（网易、搜狐、和讯）
            ClsScraper(),         # 财联社
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

        return all_items, failed_sources

    def close_all(self):
        """关闭所有爬虫"""
        for scraper in self.scrapers:
            try:
                scraper.close()
            except Exception:
                pass
