# 服务器访问地址

## 服务器信息

- **服务器 IP**: `124.222.203.221`
- **操作系统**: OpenCloudOS 9.4
- **部署时间**: 2026-01-12

## API 访问地址

### Web 浏览器访问

| 端点 | 地址 | 说明 |
|------|------|------|
| API 文档 | http://124.222.203.221/docs | Swagger UI 交互式文档 |
| 健康检查 | http://124.222.203.221/health | 服务健康状态 |
| 新闻列表 | http://124.222.203.221/news | 获取新闻数据 |
| 更新时间 | http://124.222.203.221/last-update | 最后抓取时间 |

### API 端点

| 方法 | 端点 | 说明 |
|------|------|------|
| GET | /health | 健康检查 |
| GET | /news | 获取新闻列表 |
| POST | /crawl | 触发新闻爬取 |
| GET | /last-update | 获取最后更新时间 |
| GET | /docs | API 文档 |
| GET | /openapi.json | OpenAPI 规范 |

## 命令行测试示例

```bash
# 健康检查
curl http://124.222.203.221/health

# 获取新闻列表
curl http://124.222.203.221/news

# 触发新闻爬取（需要 2-3 分钟）
curl -X POST http://124.222.203.221/crawl

# 获取最后更新时间
curl http://124.222.203.221/last-update
```

## 前端配置

### Flutter 应用配置

修改 `stock_news_app/lib/api_service.dart`:

```dart
class ApiService {
  // 开发环境使用本地地址
  // static const String baseURL = 'http://localhost:8000';

  // 生产环境使用服务器地址
  static const String baseURL = 'http://124.222.203.221';
}
```

## 服务管理

### 登录服务器

```bash
ssh root@124.222.203.221
```

### 常用运维命令

```bash
# 查看后端服务状态
systemctl status stock-news-api

# 重启后端服务
systemctl restart stock-news-api

# 查看实时日志
journalctl -u stock-news-api -f

# 查看 Nginx 状态
/usr/local/openresty/nginx/sbin/nginx -t
/usr/local/openresty/nginx/sbin/nginx -s reload

# 查看防火墙规则
firewall-cmd --list-ports
```

## 网络配置

### 防火墙端口

服务器防火墙已开放以下端口：
- TCP 22 - SSH
- TCP 80 - HTTP
- TCP 443 - HTTPS

### 腾讯云安全组

**重要**: 确保在腾讯云控制台配置安全组规则：

1. 登录 https://console.cloud.tencent.com/cvm
2. 找到对应服务器 → 点击「安全组」
3. 添加入站规则：
   - 端口：22，协议：TCP，来源：0.0.0.0/0
   - 端口：80，协议：TCP，来源：0.0.0.0/0

## 故障排查

### 无法访问服务

1. **检查服务状态**
   ```bash
   systemctl status stock-news-api
   ```

2. **检查端口监听**
   ```bash
   netstat -tlnp | grep -E '80|8000'
   ```

3. **检查防火墙**
   ```bash
   firewall-cmd --list-all
   ```

4. **检查安全组**
   - 确认腾讯云控制台安全组已开放端口 80

### 服务响应慢

新闻爬取操作需要 2-3 分钟，这是正常现象。如需调整超时时间，修改 Nginx 配置：

```bash
# 编辑配置
vi /usr/local/openresty/nginx/conf/conf.d/stock-news-api.conf

# 调整超时参数
proxy_read_timeout 300s;

# 重载配置
/usr/local/openresty/nginx/sbin/nginx -s reload
```

## 更新日志

| 日期 | 说明 |
|------|------|
| 2026-01-12 | 初始部署完成，服务正常运行 |
