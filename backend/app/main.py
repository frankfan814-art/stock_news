from fastapi import FastAPI, HTTPException, Query, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, timedelta
from typing import List, Optional
import logging
import asyncio
from concurrent.futures import ThreadPoolExecutor

from app.models import NewsItem, CrawlRequest, CrawlResponse, HealthResponse
from app.deduplicator import NewsDeduplicator
from scraper.manager import ScraperManager

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 创建 FastAPI 应用
app = FastAPI(title="财经新闻爬虫 API", version="1.0.0")

# 配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 全局去重器
deduplicator = NewsDeduplicator()
# 爬虫管理器
scraper_manager = ScraperManager()

# 存储当前新闻数据（内存）
current_news: List[NewsItem] = []
last_fetch_time: Optional[datetime] = None


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """健康检查"""
    return HealthResponse(status="ok", message="财经新闻爬虫服务运行中")


def _run_crawl(target_date, keywords):
    """在后台线程中运行爬虫任务（同步函数）"""
    logger.info(f"[后台线程] 开始抓取新闻 - 日期: {target_date or '今日'}, 关键词: {keywords}")

    # 清空去重缓存（每次抓取都获取最新数据）
    deduplicator.clear()

    # 抓取新闻（同步操作，在线程池中执行）
    all_items, failed_sources = scraper_manager.fetch_all(target_date)

    # 去重
    unique_items = deduplicator.deduplicate(all_items)

    # 关键词过滤
    if keywords:
        unique_items = deduplicator.filter_by_keywords(unique_items, keywords)

    # 按时间倒序排序
    unique_items.sort(key=lambda x: x.published_at, reverse=True)

    logger.info(f"[后台线程] 抓取完成 - 成功: {len(unique_items)} 条, 失败来源: {failed_sources}")

    return unique_items, failed_sources


@app.post("/crawl", response_model=CrawlResponse)
async def crawl_news(request: CrawlRequest = None):
    """
    触发新闻抓取
    - date: 目标日期 (YYYY-MM-DD)，可选，默认今日
    - keywords: 关键词列表，可选
    """
    global current_news, last_fetch_time

    try:
        target_date = request.date if request else None
        keywords = request.keywords if request else None

        logger.info(f"开始抓取新闻 - 日期: {target_date or '今日'}, 关键词: {keywords}")

        # 在线程池中执行爬虫任务，不阻塞事件循环
        loop = asyncio.get_event_loop()
        unique_items, failed_sources = await loop.run_in_executor(
            None,  # 使用默认的 ThreadPoolExecutor
            _run_crawl,
            target_date,
            keywords
        )

        # 更新全局数据
        current_news = unique_items
        last_fetch_time = datetime.now()

        return CrawlResponse(
            success=len(failed_sources) < len(scraper_manager.scrapers),
            count=len(unique_items),
            failed_sources=failed_sources,
            message=f"成功抓取 {len(unique_items)} 条新闻" + (f", {len(failed_sources)} 个来源失败" if failed_sources else "")
        )

    except Exception as e:
        logger.error(f"抓取失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


def _run_fetch_news(date, keyword_list):
    """在后台线程中运行新闻获取任务"""
    all_items, _ = scraper_manager.fetch_all(date)
    items = deduplicator.deduplicate(all_items)
    if keyword_list:
        items = deduplicator.filter_by_keywords(items, keyword_list)
    items.sort(key=lambda x: x.published_at, reverse=True)
    return items


@app.get("/news", response_model=List[NewsItem])
async def get_news(
    date: Optional[str] = Query(None, description="目标日期 (YYYY-MM-DD)"),
    keywords: Optional[str] = Query(None, description="关键词，用逗号分隔")
):
    """
    获取新闻列表
    - date: 目标日期，可选
    - keywords: 关键词（逗号分隔），可选
    """
    global current_news

    try:
        keyword_list = [k.strip() for k in keywords.split(",")] if keywords else None

        # 如果请求了特定日期或关键词，重新抓取（不阻塞）
        if date or keyword_list:
            loop = asyncio.get_event_loop()
            items = await loop.run_in_executor(
                None,
                _run_fetch_news,
                date,
                keyword_list
            )
            return items

        # 否则返回当前缓存的数据
        return current_news

    except Exception as e:
        logger.error(f"获取新闻失败: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/last-update")
async def get_last_update():
    """获取上次更新时间"""
    if last_fetch_time:
        return {"last_update": last_fetch_time.isoformat()}
    return {"last_update": None}


@app.on_event("shutdown")
async def shutdown_event():
    """关闭时清理资源"""
    scraper_manager.close_all()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
