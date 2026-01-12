from typing import List, Optional, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed, TimeoutError as FutureTimeoutError
from scraper.base_scraper import BaseScraper
from scraper.cls_scraper import ClsScraper
from scraper.kr36_scraper import Kr36Scraper
from scraper.huxiu_scraper import HuxiuScraper
from app.models import NewsItem
import logging

logger = logging.getLogger(__name__)

# 单个爬虫超时时间（秒）
SCRAPER_TIMEOUT = 30
# 整体抓取超时时间（秒）
TOTAL_TIMEOUT = 60


class ScraperManager:
    """爬虫管理器 - 支持并发抓取和超时控制"""

    def __init__(self):
        self.scrapers: List[BaseScraper] = [
            ClsScraper(),         # 财联社（API）
            Kr36Scraper(),        # 36氪（科技资讯）
            HuxiuScraper(),       # 虎嗅（商业资讯）
        ]

    def _fetch_single(self, scraper: BaseScraper, target_date: Optional[str] = None) -> Tuple[List[NewsItem], Optional[str]]:
        """
        抓取单个来源
        返回: (新闻列表, 失败的来源名称，None表示成功)
        """
        try:
            with scraper:
                items = scraper.fetch_news(target_date)
                logger.info(f"{scraper.get_source_name()} 抓取到 {len(items)} 条新闻")
                return items, None
        except Exception as e:
            logger.error(f"{scraper.get_source_name()} 抓取失败: {e}")
            return [], scraper.get_source_name()

    def fetch_all(self, target_date: Optional[str] = None) -> tuple[List[NewsItem], List[str]]:
        """
        并发抓取所有来源新闻
        返回: (新闻列表, 失败的来源列表)
        """
        all_items = []
        failed_sources = []

        with ThreadPoolExecutor(max_workers=len(self.scrapers)) as executor:
            # 提交所有任务
            future_to_scraper = {
                executor.submit(self._fetch_single, scraper, target_date): scraper
                for scraper in self.scrapers
            }

            # 收集结果（带超时）
            for future in as_completed(future_to_scraper, timeout=TOTAL_TIMEOUT):
                scraper = future_to_scraper[future]
                try:
                    items, failed = future.result(timeout=SCRAPER_TIMEOUT)
                    all_items.extend(items)
                    if failed:
                        failed_sources.append(failed)
                except FutureTimeoutError:
                    logger.error(f"{scraper.get_source_name()} 抓取超时 (> {SCRAPER_TIMEOUT}秒)")
                    failed_sources.append(scraper.get_source_name())
                except Exception as e:
                    logger.error(f"{scraper.get_source_name()} 执行异常: {e}")
                    failed_sources.append(scraper.get_source_name())

        return all_items, failed_sources

    def close_all(self):
        """关闭所有爬虫"""
        for scraper in self.scrapers:
            try:
                scraper.close()
            except Exception:
                pass
