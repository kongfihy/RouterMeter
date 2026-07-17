<p align="center">
  <strong>中文</strong> · <a href="README_EN.md">English</a>
</p>

# RouterMeter for macOS

**把 OpenRouter 的余额、今日花费和每次调用，放进 Mac 菜单栏。**

RouterMeter 是一款原生 macOS 菜单栏工具。它适合希望随时确认 OpenRouter 花费、余额和模型调用情况，又不想频繁打开网页控制台的人。

<p align="center">
  <img src="screenshots/overview.png" width="620" alt="RouterMeter Overview" />
</p>

<p align="center">
  <img src="screenshots/logs.png" width="620" alt="RouterMeter Request Logs" />
</p>

## 为什么做 RouterMeter

RouterMeter 基于开源项目 [OpenRouter Monitor](https://github.com/godsall-dev/openrouter-usage-menu-macos) 改造。原项目已经具备余额、预算、模型统计和趋势图等基础能力，但在日常使用中仍有几个不方便的地方：

- “今日花费”主要来自当前 API Key，无法完整反映 Management Key 所看到的账户级支出。
- 只能看到按模型汇总后的统计，无法查看最近一次调用具体用了什么模型、花了多少钱。
- 菜单栏一次只能显示余额、百分比或今日费用，无法同时看到今日费用和剩余余额。
- 金额固定保留两位小数，MiMo 等低成本调用容易显示成 `$0.00`。
- 没有当天调用时，“Today”可能继续显示最近一次活跃日的数据。
- “最近 7 天请求数”按最后 7 个活跃日期计算；“This Month”在部分情况下实际是最近 30 天。
- 原应用的名称、Bundle ID、Keychain 和本地缓存与改造版本共用，不适合长期独立使用。

RouterMeter 保留了原项目的监控能力，并把重点放在更直接的费用查看和调用记录上。

## 主要改动

### 今日费用与余额

- 按 Mac 本地自然日计算账户级今日费用。
- 菜单栏可以同时显示“今日花费 · 剩余余额”。
- 保留余额、剩余百分比和单独今日费用模式。

### Request Logs

- 增加独立的 Logs 页面，默认展示最近 100 条调用。
- 支持按最近时间、费用和 Token 数排序。
- 支持搜索模型、服务商、状态和 Generation ID。
- 展示模型、服务商、Prompt / Completion / Reasoning Token、费用、延迟、完成状态、流式请求和 BYOK 信息。
- 只补充新增日志的详情，本地缓存已读取的数据，减少重复请求。
- 不下载 Prompt 和模型回复正文。

### 更适合小额调用的费用显示

金额会根据大小自动增加小数位，例如：

```text
$12.50
$0.0125
$0.001943
```

低成本模型不再因为四舍五入显示成零。

### 更自然的 macOS 交互

- 菜单栏窗口内容使用轻量淡入和短距离位移，不接管系统窗口动画。
- Overview、Models、Activity 和 Logs 页面切换保留方向感，但避免网页式大幅滑动。
- 余额、费用和请求数刷新时使用 SwiftUI 原生数字过渡。
- 自动跟随 macOS“减少动态效果”辅助功能设置。

### 独立的 macOS 应用身份

- 应用名称：`RouterMeter`
- Bundle ID：`local.routermeter.mac`
- Keychain Service：`local.routermeter.openrouter`
- 本地缓存：`~/Library/Application Support/RouterMeter/state.json`

它可以作为独立应用安装，不会覆盖原版 OpenRouter Monitor 的设置和缓存。

## 功能概览

- 菜单栏实时显示费用或余额
- OpenRouter 账户余额和已用额度
- 今日、近 7 天、近 30 天和本月费用
- 按模型统计请求数、费用和 Token
- Generation 级调用日志和请求详情
- 30 天费用趋势和 BYOK 对比
- 月末费用预测和预算提醒
- API Key 健康状态与到期提醒
- 模型价格、上下文长度和可用性跟踪
- 自动刷新和登录时启动
- USD / GBP 显示
- 本地 JSON 数据导出

## 安装与 Gatekeeper

1. 在 [Releases](https://github.com/kongfihy/RouterMeter/releases) 下载最新的 `RouterMeter.dmg`。
2. 打开 DMG，把 `RouterMeter.app` 拖入“应用程序”。
3. 启动 RouterMeter，在 Settings 中保存 OpenRouter API Key。

当前公开测试版使用 Ad-hoc 本地签名，尚未经过 Apple Developer ID 签名和 Notarization。开启 Gatekeeper 的 Mac 可能会在首次启动时阻止应用。

> [!IMPORTANT]
> RouterMeter 不需要关闭 SIP。优先使用“仍要打开”或仅移除 RouterMeter 的隔离标记。只有完全理解安全影响时，才考虑全局关闭 Gatekeeper。

### 方案一：只允许 RouterMeter（推荐）

1. 先正常打开一次 `RouterMeter.app`。
2. 打开 **系统设置 → 隐私与安全性**。
3. 在安全性区域找到 RouterMeter 被阻止的提示。
4. 点击 **仍要打开 / Open Anyway**。
5. 使用 Touch ID 或管理员密码确认。

这是影响范围最小的方式，不会降低其他下载软件的安全检查。

### 方案二：在终端中只移除 RouterMeter 的隔离标记

确认应用来自本仓库的正式 Release 后，执行：

```bash
sudo xattr -dr com.apple.quarantine /Applications/RouterMeter.app
open /Applications/RouterMeter.app
```

这只处理 RouterMeter，不会关闭整个系统的 Gatekeeper。不要对来源不明的应用执行这条命令。

### 方案三：全局关闭 Gatekeeper（不推荐）

先检查状态：

```bash
spctl --status
```

在较新的 macOS 上：

```bash
sudo spctl --global-disable
```

该命令会在 **系统设置 → 隐私与安全性** 中显示“允许从任何来源下载的应用”选项。进入设置并手动选择 **任何来源 / Anywhere**。

在 macOS 14 上，如果 `--global-disable` 不可用，可以使用：

```bash
sudo spctl --master-disable
```

安装并成功启动 RouterMeter 后，建议立即重新开启 Gatekeeper：

```bash
sudo spctl --global-enable
```

macOS 14 可以使用：

```bash
sudo spctl --master-enable
```

然后在 **系统设置 → 隐私与安全性** 中恢复为 **App Store 与被认可的开发者**。

### SIP 开启时

使用下面的命令检查 SIP：

```bash
csrutil status
```

如果显示：

```text
System Integrity Protection status: enabled.
```

这是推荐状态。SIP 开启时仍然可以使用：

- “隐私与安全性 → 仍要打开”；
- `xattr` 只移除 RouterMeter 的隔离标记；
- Gatekeeper 的系统设置。

**不需要为了运行 RouterMeter 关闭 SIP。**

### SIP 已关闭时

如果显示：

```text
System Integrity Protection status: disabled.
```

操作方式与 SIP 开启时相同。SIP 和 Gatekeeper 是两套不同的安全机制，关闭 SIP 不会自动关闭 Gatekeeper。

如果 RouterMeter 仍被阻止，请依次使用：

1. “隐私与安全性 → 仍要打开”；
2. 移除 RouterMeter 的隔离标记；
3. 最后才考虑全局关闭 Gatekeeper。

### 如何开启或关闭 SIP

> [!WARNING]
> 关闭 SIP 会降低整个系统的保护能力。RouterMeter 本身不需要这项操作，下面的步骤只用于高级系统维护或恢复已经被关闭的 SIP。

Apple Silicon Mac：

1. 关机。
2. 按住电源键，直到出现“正在载入启动选项”。
3. 选择 **选项 → 继续**。
4. 在恢复模式菜单中打开 **实用工具 → 终端**。

Intel Mac：

1. 重新启动 Mac。
2. 启动时按住 `Command-R` 进入恢复模式。
3. 打开 **实用工具 → 终端**。

关闭 SIP：

```bash
csrutil disable
reboot
```

重新开启 SIP（推荐）：

```bash
csrutil enable
reboot
```

## API Key 权限

普通 OpenRouter API Key 可以读取当前 Key 的基础使用数据。

以下功能需要 **OpenRouter Management API Key**：

- 账户总余额
- 按本地自然日统计的账户级今日费用
- API Key 列表和账户级分析
- Generation 级 Request Logs

RouterMeter 只调用 OpenRouter 的只读统计接口，不会使用你的 Key 发起模型推理。

## 隐私

- API Key 只保存在 Apple Keychain。
- 本地状态文件不包含 API Key。
- 日志浏览器只读取 Generation 元数据，不读取 Prompt 和回复正文。
- RouterMeter 没有自己的服务器，也不上传统计数据。

## 系统要求

- macOS 14 或更高版本
- Xcode Command Line Tools / Swift 6.1（仅源码构建需要）
- OpenRouter API Key
- Management API Key（账户余额和 Logs 需要）

## 从源码构建

```bash
git clone https://github.com/kongfihy/RouterMeter.git
cd RouterMeter
swift run OpenRouterMonitor
```

运行检查：

```bash
swift run OpenRouterMonitorCoreChecks
```

生成应用：

```bash
./scripts/package_app.sh
```

生成 DMG：

```bash
./scripts/package_dmg.sh
```

生成结果默认位于 `dist/`，该目录不会提交到 Git。

## 当前限制

- Logs 依赖 OpenRouter Analytics 和 Generation 接口的可用性。
- 为避免 Analytics 查询超时，应用先读取最多 500 条候选记录，再按 Generation 时间戳选出最近日志。
- 首次加载 Logs 时需要补充 Generation 详情，之后会利用本地缓存减少请求。
- 当前 DMG 尚未使用 Developer ID 签名和 Apple Notarization。
- 暂不支持自动更新。

## 上游项目、Logs 实现与许可证

RouterMeter 基于 [godsall-dev/openrouter-usage-menu-macos](https://github.com/godsall-dev/openrouter-usage-menu-macos) 开发，并保留了原项目的 Git 历史。

主要新增内容包括账户级本地日费用、组合菜单栏显示、Generation 日志浏览、请求详情、增量日志缓存、小额费用精度、日期统计修正、原生交互动效和独立应用身份。

### Logs 接口实现来源

Logs 功能没有引入或复制其他开源项目的日志浏览器，也没有使用第三方 Swift Package。它是在 RouterMeter 现有 `OpenRouterClient` 网络层上直接实现的，使用 OpenRouter 提供的接口：

- Analytics Metadata：读取当前账户可用的指标与维度；
- Analytics Query：查询 `generation_id`、费用和请求数；
- Generation：按 Generation ID 补充模型、服务商、Token、延迟和状态详情。

界面、缓存、排序、增量详情请求和日期解析均在 RouterMeter 仓库中实现。早期调研过其他费用监控工具的产品形态，但当前代码库中没有包含它们的源码、组件或资源，因此不需要增加额外的第三方开源许可证声明。

RouterMeter 与上游项目均使用 **GNU General Public License v3.0**。详见 [LICENSE](LICENSE)。

RouterMeter 是社区项目，与 OpenRouter 官方没有隶属关系。
