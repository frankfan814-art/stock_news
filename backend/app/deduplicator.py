from typing import List, Dict
from app.models import NewsItem


class NewsDeduplicator:
    """基于来源+标题+发布时间的去重器（内存存储）"""

    def __init__(self):
        self._seen: Dict[str, NewsItem] = {}

    def _make_key(self, item: NewsItem) -> str:
        """生成唯一键：来源 + 标题 + 发布时间"""
        return f"{item.source}|{item.title}|{item.published_at}"

    def deduplicate(self, items: List[NewsItem]) -> List[NewsItem]:
        """去重并返回唯一条目"""
        unique_items = []
        for item in items:
            key = self._make_key(item)
            if key not in self._seen:
                self._seen[key] = item
                unique_items.append(item)
        return unique_items

    def filter_by_keywords(self, items: List[NewsItem], keywords: List[str]) -> List[NewsItem]:
        """根据关键词过滤新闻"""
        if not keywords:
            return items

        filtered = []
        for item in items:
            combined_text = f"{item.title} {item.summary} {item.source}".lower()
            if any(kw.lower() in combined_text for kw in keywords):
                filtered.append(item)
        return filtered

    def clear(self):
        """清空缓存"""
        self._seen.clear()
