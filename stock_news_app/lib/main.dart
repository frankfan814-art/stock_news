import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'models/news_item.dart';
import 'services/api_service.dart';

void main() {
  runApp(const StockNewsApp());
}

class StockNewsApp extends StatelessWidget {
  const StockNewsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '财经新闻',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
        // 使用系统字体，避免加载 Google Fonts
        fontFamily: 'System',
      ),
      home: const NewsListPage(),
    );
  }
}

class NewsListPage extends StatefulWidget {
  const NewsListPage({super.key});

  @override
  State<NewsListPage> createState() => _NewsListPageState();
}

class _NewsListPageState extends State<NewsListPage> {
  final List<NewsItem> _newsItems = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastUpdateTime;
  String _selectedDate = '';
  bool _isServerOnline = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _checkServerHealth();
  }

  Future<void> _checkServerHealth() async {
    final isOnline = await ApiService.checkHealth();
    setState(() {
      _isServerOnline = isOnline;
    });
    if (!isOnline) {
      setState(() {
        _errorMessage = '后端服务未启动，请先启动 Python 服务';
      });
    }
  }

  Future<void> _fetchNews({bool showLoading = true}) async {
    if (!_isServerOnline) {
      await _checkServerHealth();
      if (!_isServerOnline) {
        setState(() {
          _errorMessage = '后端服务未启动，请先启动 Python 服务';
        });
        return;
      }
    }

    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final keywords = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();

      final crawlResult = await ApiService.crawlNews(
        date: null,  // 不过滤日期，获取所有新闻
        keywords: keywords != null ? [keywords] : null,
      );

      final news = await ApiService.getNews(
        date: null,  // 不过滤日期，获取所有新闻
        keywords: keywords,
      );

      final lastUpdate = await ApiService.getLastUpdate();

      setState(() {
        _newsItems.clear();
        _newsItems.addAll(news);
        // 按发布时间倒序排列（最新的在最上面）
        _newsItems.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        _lastUpdateTime = lastUpdate;
        _isLoading = false;
        _errorMessage = news.isEmpty ? '暂无数据，请刷新' : null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(crawlResult['message'] ?? '抓取完成'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      await _fetchNews();
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('财经新闻'),
        backgroundColor: theme.colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: '选择日期',
            onPressed: _pickDate,
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _isLoading ? null : () => _fetchNews(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索关键词...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _fetchNews();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    onSubmitted: (_) => _fetchNews(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : () => _fetchNews(),
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),

          if (!_isServerOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.errorContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '后端服务未连接，请先启动 Python 后端服务',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: _checkServerHealth,
                    child: Text(
                      '重试',
                      style: TextStyle(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _buildNewsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList() {
    if (_isLoading && _newsItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在抓取新闻...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _newsItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isServerOnline ? Icons.info_outline : Icons.error_outline,
              size: 64,
              color: _isServerOnline ? Colors.grey : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_isServerOnline)
              FilledButton.icon(
                onPressed: () => _fetchNews(),
                icon: const Icon(Icons.refresh),
                label: const Text('重新抓取'),
              ),
          ],
        ),
      );
    }

    if (_newsItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '暂无数据，请刷新',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchNews(showLoading: false),
      child: ListView.builder(
        itemCount: _newsItems.length + 1,
        itemBuilder: (context, index) {
          if (index == _newsItems.length) {
            return _lastUpdateTime != null
                ? Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: Text(
                      '上次更新: ${DateFormat('HH:mm:ss').format(_lastUpdateTime!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final item = _newsItems[index];
          return _NewsCard(
            item: item,
            onTap: () => _openUrl(item.url),
          );
        },
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onTap;

  const _NewsCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.source,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeFormat.format(item.publishedAt),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                item.summary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.open_in_new,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '查看原文',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
