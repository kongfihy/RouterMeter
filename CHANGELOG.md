# Changelog

## 0.2.4 Beta

RouterMeter 的首个公开测试版本。

### 新增

- 账户级今日费用，按 Mac 本地自然日计算
- 菜单栏“今日花费 · 剩余余额”组合显示
- Generation 级 Request Logs 页面
- 日志搜索，以及最近时间、费用、Token 排序
- 模型、服务商、Token、费用、延迟、状态、流式和 BYOK 详情
- 最近 100 条日志与增量详情缓存
- 小额费用自适应精度，避免低成本调用显示为零
- 独立应用名称、Bundle ID、Keychain Service 和缓存目录
- 启动时自动刷新

### 修复

- 修复 Analytics 按费用截取少量记录时遗漏低成本模型的问题
- 修复 `gen-stt-*` Generation ID 的时间戳解析
- 修复 Logs 排序控件在窄窗口中换行的问题
