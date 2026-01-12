# 财经新闻采集与展示

一个基于 Flutter 前端 + Python 爬虫的财经新闻聚合应用。

## 项目结构

```
stock_news/
├── backend/                    # Python 后端
│   ├── app/
│   │   ├── main.py            # FastAPI 主程序
│   │   ├── models.py          # 数据模型
│   │   └── deduplicator.py    # 去重模块
│   ├── scraper/
│   │   ├── base_scraper.py    # 爬虫基类
│   │   ├── sina_scraper.py    # 新浪财经
│   │   ├── eastmoney_scraper.py  # 东方财富
│   │   ├── wallstreetcn_scraper.py  # 华尔街见闻
│   │   ├── cls_scraper.py     # 财联社
│   │   └── manager.py         # 爬虫管理器
│   ├── logs/                  # 日志目录
│   └── requirements.txt       # Python 依赖
├── stock_news_app/            # Flutter 前端
│   ├── lib/
│   │   ├── main.dart          # 主程序
│   │   ├── models/            # 数据模型
│   │   └── services/          # API 服务
│   └── pubspec.yaml           # Flutter 依赖
└── requirements.md            # 需求文档
```

## 功能特性

- 手动触发新闻抓取
- 按日期筛选新闻
- 关键词搜索过滤
- 多来源聚合（新浪财经、东方财富、华尔街见闻、财联社）
- 简洁的 Material Design 3 界面
- 点击标题跳转原文

## 环境要求

### 后端
- Python 3.10+

### 前端
- Flutter 3.9+
- Dart 3.9+

## 快速开始

### 1. 启动后端服务

```bash
cd backend

# 安装依赖
pip install -r requirements.txt

# 启动服务
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

后端服务将在 `http://localhost:8000` 启动。

API 端点：
- `GET /health` - 健康检查
- `POST /crawl` - 触发新闻抓取
- `GET /news` - 获取新闻列表
- `GET /last-update` - 获取上次更新时间

### 2. 启动 Flutter 应用

```bash
cd stock_news_app

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

## 使用说明

1. 确保后端服务已启动
2. 启动 Flutter 应用
3. 点击刷新按钮抓取最新新闻
4. 使用搜索框过滤关键词
5. 使用日历图标选择特定日期
6. 点击新闻卡片跳转原文

## 数据格式

每条新闻包含以下字段：

```json
{
  "source": "华尔街见闻",
  "title": "美联储政策前瞻",
  "summary": "市场关注即将公布的通胀数据…",
  "url": "https://example.com/news/123",
  "published_at": "2026-01-11T07:55:00+08:00",
  "fetched_at": "2026-01-11T08:00:05+08:00"
}
```

## 注意事项

- 应用仅抓取公开新闻信息
- 数据存储在内存中，不落地存储
- 请遵守各站点的 robots.txt 和使用条款
- 控制抓取频率，避免对目标网站造成压力
