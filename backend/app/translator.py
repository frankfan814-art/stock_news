import httpx
import logging
from typing import Optional
import re

logger = logging.getLogger(__name__)


class Translator:
    """翻译器 - 快速关键词替换"""

    def __init__(self):
        self.client = httpx.Client(timeout=5.0)
        self.ollama_url = "http://localhost:11434/api/generate"

    def is_chinese(self, text: str) -> bool:
        """检测文本是否包含中文"""
        return bool(re.search(r'[\u4e00-\u9fff]', text))

    def translate_to_chinese(self, text: str) -> str:
        """
        将文本翻译成中文
        如果已经是中文则直接返回
        """
        if not text or not text.strip():
            return text

        # 如果包含中文，直接返回
        if self.is_chinese(text):
            return text

        # 使用快速关键词替换
        return self._simple_translate(text)

    def _simple_translate(self, text: str) -> str:
        """快速翻译 - 使用关键词替换"""
        terms = {
            # 股票市场
            "Stock": "股票", "stocks": "股票", "stock": "股票",
            "market": "市场", "Market": "市场",
            "shares": "股份", "share": "股份",
            "portfolio": "投资组合",
            "dividend": "股息", "dividends": "股息",
            "yield": "收益率",

            # 利率/央行
            "Fed": "美联储", "Federal Reserve": "美联储",
            "Rate": "利率", "rate": "利率", "rates": "利率",
            "interest rates": "利率",
            "inflation": "通胀", "Inflation": "通胀",
            "recession": "衰退",

            # 公司/企业
            "CEO": "CEO", "Chief Executive": "首席执行官",
            "CFO": "CFO",
            "earnings": "财报", "Earnings": "财报",
            "revenue": "营收", "Revenue": "营收",
            "profit": "利润", "Profit": "利润",
            "IPO": "IPO",

            # 指数
            "index": "指数", "indexes": "指数",
            "Dow": "道指", "Dow Jones": "道琼斯指数",
            "S&P": "标普", "S&P 500": "标普500",
            "Nasdaq": "纳斯达克",

            # 科技/AI
            "AI": "AI", "Artificial Intelligence": "人工智能",
            "Tech": "科技", "technology": "科技",
            "tech sector": "科技板块",

            # 银行金融
            "Bank": "银行", "bank": "银行", "banks": "银行",
            "Treasury": "财政部", "treasury": "国债",
            "bond": "债券", "bonds": "债券",

            # 加密货币
            "Bitcoin": "比特币", "crypto": "加密货币",
            "cryptocurrency": "加密货币",

            # 商品
            "oil": "石油", "Oil": "石油",
            "gold": "黄金", "Gold": "黄金",

            # 经济
            "economy": "经济", "Economy": "经济",
            "economic": "经济", "growth": "增长",
            "GDP": "GDP",

            # 地区
            "US": "美国", "U.S.": "美国", "USA": "美国",
            "China": "中国", "Chinese": "中国",
            "Trump": "特朗普",
            "tariff": "关税", "tariffs": "关税",

            # 其他
            "Volatility": "波动性", "volatility": "波动性",
            "ETF": "ETF", "ETFs": "ETF",
            "option": "期权", "options": "期权",
            "fund": "基金", "funds": "基金",
        }

        result = text
        for en, zh in terms.items():
            pattern = r'\b' + re.escape(en) + r'\b'
            result = re.sub(pattern, zh, result)

        return result

    def translate_news_item(self, title: str, summary: str) -> tuple[str, str]:
        """
        翻译新闻标题和摘要
        返回: (翻译后的标题, 翻译后的摘要)
        """
        translated_title = self.translate_to_chinese(title)
        translated_summary = self.translate_to_chinese(summary)
        return translated_title, translated_summary

    def close(self):
        """关闭客户端"""
        self.client.close()


# 全局翻译器实例
translator = Translator()
