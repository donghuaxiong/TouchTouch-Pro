# 了解项目

> **Workspace:** /Users/donghua_xiong/study/TouchTouch

---

## User

了解一下项目

## Assistant

先快速查看项目目录和核心配置文件，确认技术栈、模块划分和启动方式，再给你一个简洁的项目概览。

目录看起来是一个 Swift 原生 macOS 项目，我继续读 `README`、`Package.swift` 和几个核心服务文件，确认它具体做什么以及主要能力。

已经确认它是 SwiftPM 管理的 macOS 菜单栏工具。接着我看手势监听、亮度/音量控制和权限相关实现，判断这个项目的核心链路。

核心链路已经比较清楚了：全局滚动监听 + 修饰键判断 + 触控边缘识别 + 系统亮度/音量写入。再补一眼构建脚本和辅助模块，就能把开发和发布流程一起说明清楚。

我再用一次测试命令确认仓库当前是可构建状态，这样给你的概览会包含“现在能不能直接跑起来”的结论。

测试没能验证到代码本身，当前环境里 `swift test` 在解析 `Package.swift` 时就被系统沙箱拦住了；我会把这点作为环境结论一起写清楚。

**项目定位**

- 这是一个原生 `macOS` 菜单栏工具，用触控板滚动手势快速调节屏幕亮度和系统音量，产品说明见 [README.md](file:///Users/donghua_xiong/study/TouchTouch/README.md)。
- 应用不占用 Dock，入口是 `SwiftUI` 的 `MenuBarExtra`，启动后会隐藏为辅助型应用，见 [TouchTouchApp.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/App/TouchTouchApp.swift#L4-L20)。
- 包管理使用 `SwiftPM`，最低系统版本是 `macOS 13`，可执行目标名为 `TouchTouch`，见 [Package.swift](file:///Users/donghua_xiong/study/TouchTouch/Package.swift#L1-L23)。

**核心能力**

- 默认模式下，按住 `Option` 后在触控板左边缘滑动调亮度、右边缘滑动调音量；关闭增强边缘识别后退化为 `Option=亮度`、`Command=音量`，说明见 [README.md](file:///Users/donghua_xiong/study/TouchTouch/README.md#L42-L67)。
- 支持可视化 HUD、触觉反馈、边缘宽度、滚动阈值、步长、方向反转等设置，UI 面板集中在 [SettingsView.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Views/SettingsView.swift)。
- 权限上依赖“辅助功能”和“输入监控”，请求逻辑在 [PermissionManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/PermissionManager.swift#L4-L19)。

**实现结构**

- 状态中心是 [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift#L4-L168)，负责：
  - 持久化用户设置到 `UserDefaults`
  - 启停监听器
  - 分发亮度/音量调整动作
  - 控制 HUD 和触觉反馈
- 手势监听核心是 [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift#L24-L374)，它同时使用：
  - `NSEvent` 的全局/本地 `scrollWheel` 监听
  - `CGEventTap` 做更底层的滚轮事件捕获和必要时的事件吞掉
  - 累积滚动增量 + 阈值 + 防抖，避免过于敏感
- 左右边缘识别依赖私有框架 `MultiTouchSupport`，通过读取触点平均 `x` 坐标判断是在左边还是右边，见 [MultiTouchSupportManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/MultiTouchSupportManager.swift#L32-L162)。
- 亮度控制在 [BrightnessManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/BrightnessManager.swift#L5-L140)：
  - 优先调用私有框架 `DisplayServices`
  - 失败后回退到外部 `brightness` CLI
- 音量控制在 [VolumeManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/VolumeManager.swift#L5-L226)：
  - 优先用 `AppleScript` 读写系统音量
  - 失败后回退到 `CoreAudio`
  - 写入做了短延迟合并，减少高频触发抖动
- HUD 和触觉反馈分别在 [HUDManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/HUDManager.swift#L4-L319) 和 [HapticManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/HapticManager.swift#L3-L16)。

**开发与打包**

- 日常开发推荐脚本 [build_and_run.sh](file:///Users/donghua_xiong/study/TouchTouch/script/build_and_run.sh#L1-L79)，它会编译、组装 `.app`、写 `Info.plist`、做 ad-hoc 签名并启动应用。
- 发布打包脚本是 [package_dmg.sh](file:///Users/donghua_xiong/study/TouchTouch/script/package_dmg.sh#L1-L123)，支持生成通用架构 `release` 包和 `DMG`。
- 进程调用统一封装在 [ProcessRunner.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Support/ProcessRunner.swift#L1-L29)。

**当前判断**

- 这是一个功能比较完整、结构清晰的小型 macOS 工具项目，重点不在复杂业务，而在系统事件监听、私有框架调用、权限处理和打包分发。
- 代码组织是“入口 + 状态中心 + 系统服务 + 设置 UI”的典型桌面工具结构，读起来比较顺。
- 测试目前很少，仓库里只有一个很基础的方向反转测试，见 [AdjustmentDirectionTests.swift](file:///Users/donghua_xiong/study/TouchTouch/Tests/TouchTouchTests/AdjustmentDirectionTests.swift#L1-L8)。

**需要注意**

- 项目依赖 `DisplayServices` 和 `MultiTouchSupport` 这类私有框架，适合本地工具或个人使用，正式分发会有签名、公证、兼容性和审核风险，README 里也明确提到了这一点，见 [README.md](file:///Users/donghua_xiong/study/TouchTouch/README.md#L172-L176)。
- 我尝试执行 `swift test`，但当前 IDE 运行环境在解析 `Package.swift` 时被系统沙箱阻止，报的是环境级 `sandbox_apply: Operation not permitted`，所以这次没法据此判断代码是否可在你本机正常构建。

**建议阅读顺序**

- 先看 [README.md](file:///Users/donghua_xiong/study/TouchTouch/README.md)
- 再看 [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift)
- 接着看 [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift)
- 最后看 [BrightnessManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/BrightnessManager.swift) 和 [VolumeManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/VolumeManager.swift)

- 如果你愿意，我下一步可以继续帮你做两种深入分析之一：`1.` 按代码执行链路详细讲一遍，`2.` 从“有哪些潜在风险/可优化点”角度做一次 review。

## User

他现在是一个单一的小工具 只用来进行音量和亮度的调节 你帮我分析 一下 还能作为其他什么作用 丰富一下功能 重点围绕触控板来解决问题 以达到能向用户收费使用的目的

## Assistant

我先从“哪些高频痛点最值得付费”这个角度拆解，把它从单点调节工具升级成一个围绕触控板的效率产品。**核心判断**

- 现在的 `TouchTouch` 本质上是一个“单点系统控制工具”，价值明确，但场景偏窄，用户对“只调音量和亮度”单独付费的意愿通常不高。
- 想做成可收费产品，不能只是再加几个小开关，而是要把它升级成“触控板驱动的上下文控制中心”。
- 最有机会收费的方向，不是做更多手势，而是让用户在“不离开键盘和触控板”的情况下，完成一批高频、连续、可节省时间的动作。

**产品定位**

- 推荐把产品定位从“亮度/音量调节器”升级为“Trackpad Power Controls”。
- 核心卖点可以是：用触控板边缘、角落、压力节奏、修饰键组合，在不同 App 中直接控制最常用的参数和操作。
- 付费理由应围绕这三点建立：
  - 高频使用
  - 明显省时
  - 有专业用户场景

**最值得做的方向**

- 第一方向：`系统级连续控制`
- 第二方向：`App 场景化控制`
- 第三方向：`自动化与专业工作流`

**方向一：系统级连续控制**

- 这是你现在最接近的方向，也是最容易落地和延展的。
- 目标是把“亮度/音量”扩成“所有适合连续滑动调节的系统参数”。

- 可以新增的连续控制项：
  - 键盘背光亮度
  - 麦克风输入音量
  - 屏幕缩放或显示预设切换
  - 鼠标/触控板滚动速度
  - 系统输出设备切换
  - 降噪/专注模式开关
  - 夜览与色温强度
  - 外接显示器亮度与音量

- 价值分析：
  - 这些都符合“滑动即调节”的交互模型
  - 用户能立刻理解，不需要教育成本
  - 适合做成 `基础版免费 + Pro 解锁更多控制项`

**方向二：App 场景化控制**

- 真正能收费的关键，在这里。
- 逻辑不是“手势控制系统”，而是“同样的触控板动作，在不同 App 里自动变成最合适的控制”。

- 典型场景：
  - 在 `Spotify`、`Music`、`网易云` 中：调音量、切歌、快进快退
  - 在 `YouTube`、`Bilibili`、`VLC`、`IINA` 中：调播放速度、时间轴快进、字幕偏移、音量、亮度
  - 在 `Zoom`、`Meet`、`Teams` 中：麦克风静音、摄像头开关、扬声器音量、共享控制
  - 在 `浏览器` 中：标签切换、页面缩放、前进后退、阅读模式
  - 在 `Figma`、`Sketch`、`Photoshop` 中：缩放画布、调整笔刷大小、图层切换
  - 在 `Final Cut Pro`、`Premiere`、`DaVinci Resolve` 中：时间轴缩放、帧级拖动、音轨音量、预览快进
  - 在 `Xcode`、`VS Code`、`iTerm` 中：标签切换、分屏调整、终端字体缩放、面板开关

- 这类功能为什么更值钱：
  - 用户会感受到“这个工具懂我现在在干什么”
  - 一套手势在不同 App 中自动映射，更像平台能力，不是小插件
  - 专业用户一旦形成习惯，迁移成本高，续费意愿更强

**方向三：自动化与专业工作流**

- 这是从“工具”变“平台”的关键一步。
- 给高级用户一个配置能力，让他们把触控板变成自己的控制台。

- 推荐能力：
  - 自定义手势绑定快捷键
  - 绑定 AppleScript、Shell、Shortcuts
  - 按 App 配置不同手势集
  - 按区域配置动作：左边缘、右边缘、上边缘、下边缘、四角
  - 按修饰键分层：`Option`、`Command`、`Control`、双击、长按
  - 连续滑动控制数值，轻触执行动作
  - 手势链：先触左角再滑动，触发高级操作
  - 工作模式切换：办公模式、创作模式、会议模式、编程模式

- 这个方向的收费潜力最高，因为：
  - 它满足重度用户的个性化需求
  - 配置本身会沉淀价值
  - 容易形成“离不开”的黏性

**围绕触控板最适合做的功能包**

- 我更建议你按“问题包”而不是“零碎功能”来设计。

**1. 会议控制包**

- 解决远程会议中的频繁中断操作。
- 功能建议：
  - 双指边缘滑动调会议音量
  - 三指点按麦克风静音
  - 四角触发摄像头开关
  - 长按边缘进入“发言模式”
  - 自动识别 `Zoom` / `Meet` / `Teams`
- 付费价值很强，因为这是明确办公痛点。

**2. 媒体控制包**

- 面向视频、音乐、播客、剪辑用户。
- 功能建议：
  - 边缘滑动调播放进度
  - 上下滑动调播放速度
  - 左右区域切换字幕和音轨
  - 长按触发 A-B 循环
  - 滚动强度映射为快进速度
- 这类用户愿意为顺手体验付费。

**3. 窗口与工作区包**

- 面向多任务办公用户。
- 功能建议：
  - 左边缘滑动切换 Space
  - 右边缘滑动切换窗口
  - 角落手势贴靠窗口
  - 三指边缘拖动窗口到另一块屏幕
  - 快速呼出常用 App 面板
- 这类功能和 `BetterTouchTool` 有重叠，但如果你做得更轻、更专注，也有空间。

**4. 创作者控制包**

- 面向设计师、剪辑师、摄影后期。
- 功能建议：
  - 画笔大小连续调节
  - 时间轴缩放
  - 图层切换
  - 不透明度/曝光/音轨音量调节
  - 自定义旋钮式触控板区域
- 这是最容易卖高价 Pro 的人群。

**最有机会收费的主线**

- 如果只能选一个主线，我建议：
- `从系统调节工具 -> 触控板场景化控制平台`
- 最佳切入顺序：
  - 先做系统级连续控制，扩大基础价值
  - 再做会议/媒体两个场景包，形成明确付费点
  - 最后做每 App 配置和自动化，形成 Pro 护城河

**可以做成付费点的功能**

- 免费版建议保留：
  - 亮度和音量
  - 基础边缘识别
  - 基础 HUD
  - 1 到 2 个手势
- Pro 版建议收费：
  - 每 App 独立配置
  - 媒体控制包
  - 会议控制包
  - 窗口管理包
  - 创作者控制包
  - 自定义手势和脚本
  - 多套配置方案
  - 高级 HUD
  - 外设联动
  - 数据统计与习惯推荐

**推荐定价**

- 一次性买断：
  - `68-128 元` 比较适合国内个人工具市场
- 订阅制：
  - 不建议一开始就纯订阅，除非你后面要做云同步、手势市场、模板共享
- 更好的方案：
  - `免费版 + Pro 买断`
  - `基础 Pro 98 元`
  - `创作者/高级自动化包` 另加价或更高档位

**和竞品竞争时的差异化**

- 市面上类似工具很多，但多数过于复杂。
- 你的差异化应该是：
  - 专注触控板，不做全输入设备大杂烩
  - 强调连续控制，不只是离散手势触发
  - 强调上下文识别，不同 App 自动切换行为
  - UI 简洁，开箱即用
  - 给出预设模板，而不是让用户从零配置

**建议优先级**

- 第一优先级：`更多连续控制项`
- 第二优先级：`按 App 自动切换功能`
- 第三优先级：`会议控制包`
- 第四优先级：`媒体控制包`
- 第五优先级：`自定义手势与自动化`

**为什么这条路更容易收费**

- 用户不会为“又一个音量亮度工具”长期买单。
- 用户会为“我开会、看片、剪视频、做设计时，触控板真的更高效了”买单。
- 付费本质不是买功能数量，而是买更少的打断、更顺的工作流、更少的鼠标键盘切换。

**一句话产品方向**

- 把它做成一个“基于触控板的上下文控制层”，而不是“多加几个开关的小工具”。

**下一步建议**

- 如果你愿意，我可以继续帮你输出一版更落地的方案：
  - `版本路线图`：V1、V2、V3 做什么
  - `收费方案`：免费版和 Pro 怎么切
  - `功能清单`：哪些最容易基于你现有代码实现
  - `竞品分析`：对比 BetterTouchTool、Mac Gesture、Swish 这类产品该怎么避开正面竞争

## User

继续输出方案

## Assistant

**路线图**

- `V1.5` 先把现有能力做成“可卖的基础版”：在 [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift) 之上扩展更多连续控制项，不改产品定位，只增强实用性。
- `V2.0` 引入“按 App 自动切换行为”：同一套边缘滑动，在不同应用里映射成不同控制，开始形成差异化。
- `V2.5` 推出两个高价值场景包：`会议控制` 和 `媒体控制`，这是最直接的付费理由。
- `V3.0` 做成“触控板自动化平台”：用户自定义手势、动作链、脚本、模板同步，进入 Pro 产品形态。

**V1.5 功能包**

- `系统控制扩展`：在现有亮度、音量外，增加键盘背光、麦克风输入音量、输出设备切换、勿扰模式、夜览开关。
- `触发区扩展`：从左/右边缘扩展到上边缘、下边缘、四角、双边缘长按。
- `反馈升级`：在 [HUDManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/HUDManager.swift) 上增加更细的状态提示，比如当前控制对象、百分比、设备名、App 名。
- `误触优化`：在 [MultiTouchSupportManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/MultiTouchSupportManager.swift) 和 [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift) 上增加边缘驻留时间、滑动角度限制、触发冷却、速度曲线。

**V2.0 功能包**

- `按 App 配置`：检测前台应用，根据 Bundle ID 切换映射规则。
- `动作模型`：把当前 [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift) 的“亮度/音量”升级成通用 `Action` 层，例如 `adjustBrightness`、`adjustVolume`、`sendShortcut`、`runAppleScript`、`openURL`。
- `配置中心`：在 [SettingsView.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Views/SettingsView.swift) 中增加“全局规则 / App 规则 / 手势规则”三层配置。
- `预设模板`：内置 `浏览器`、`会议`、`视频播放器`、`设计工具`、`开发工具` 五套模板，降低学习成本。

**V2.5 场景包**

- `会议控制包`
- 在 `Zoom` / `Meet` / `Teams` 中，边缘滑动调会议音量，角落点击做静音和摄像头切换，长按进入专注发言模式。
- 可扩展为快捷动作：切换耳机/扬声器、打开降噪、打开字幕、结束共享。
- 这是最容易对办公用户收费的模块。

- `媒体控制包`
- 在 `Music` / `Spotify` / `IINA` / 浏览器视频中，左边缘调进度，右边缘调音量，上边缘调播放速度，下边缘调字幕偏移。
- 增加“轻扫切歌”“停留预览”“双速临时加速”等高频动作。
- 这是第二个最强付费点，尤其适合重度影音用户。

**V3.0 平台化**

- `自定义动作`：快捷键、AppleScript、Shell、Shortcuts、URL Scheme。
- `动作链`：一个触发动作依次执行多个步骤，比如“静音麦克风 + 打开勿扰 + 降低系统音量”。
- `模式切换`：办公模式、剪辑模式、写代码模式、演示模式。
- `模板共享`：导入导出配置，后续甚至可以做社区模板库。
- `数据统计`：告诉用户哪些手势最常用、节省了多少操作、推荐哪些动作可自动化。

**最适合你现在代码的演进方式**

- `第一步` 抽象控制目标：把 [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift) 里的 `ControlTarget` 从 `brightness` / `volume` 扩成通用目标枚举，或改成动作 ID。
- `第二步` 抽象执行器：把 [BrightnessManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/BrightnessManager.swift) 和 [VolumeManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/VolumeManager.swift) 变成一类 `ActionExecutor`，未来统一挂接系统动作和脚本动作。
- `第三步` 抽象配置模型：把 [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift) 从“单组全局配置”升级为“全局配置 + 按 App 配置 + 手势配置”。
- `第四步` 抽象 UI：把 [SettingsView.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Views/SettingsView.swift) 拆成基础设置、规则编辑、模板管理三块，否则后面会很难维护。

**建议的数据模型**

- `GestureTrigger`：描述触发方式，如左边缘、右边缘、上边缘、角落、修饰键、滑动方向、速度阈值。
- `ActionDefinition`：描述动作，如调节亮度、发送快捷键、运行脚本、切换设备。
- `Rule`：前台 App + 手势触发 + 动作定义。
- `Profile`：办公、会议、影音、创作等配置集合。
- `FeedbackStyle`：HUD 样式、触觉强度、提示文字策略。

**免费版与收费版**

- `免费版`
- 保留亮度、音量、基础 HUD、基础边缘识别、1 套默认规则。
- 给用户一个明确价值，但故意不开放“真正形成工作流”的能力。

- `Pro 版`
- 按 App 独立配置
- 会议控制包
- 媒体控制包
- 更多触发区域
- 自定义快捷键 / 脚本 / Shortcuts
- 多套模式切换
- 模板导入导出
- 高级 HUD 与统计

**推荐定价**

- `买断制优先`：`68-98 元` 适合作为第一阶段 Pro 定价。
- `高阶 Pro`：如果后面做了模板库、云同步、社区配置，可以加 `128-168 元` 高阶档。
- `不建议一开始做订阅`：这个产品的第一阶段更像效率工具，买断更容易成交。

**用户画像**

- `办公用户`：会议频繁，愿意为静音、设备切换、发言模式买单。
- `影音用户`：天天看视频、听音乐，希望比系统手势更强。
- `创作者`：剪辑、设计、修图，愿意为连续参数控制买更高价格。
- `程序员`：愿意尝试自动化，但需要模板而不是纯 DIY。

**竞品避让**

- `BetterTouchTool` 很强，但太重、太全、学习成本高。
- 你的差异化不是“比它功能更多”，而是“专注触控板连续控制，开箱即用”。
- `Swish` 偏窗口管理，你不要从窗口手势切入做主打，否则会撞在强势赛道上。
- 更好的策略是占住“触控板参数控制 + App 场景控制”这个更窄但更清晰的位置。

**最值得优先做的 6 个功能**

- `1` 麦克风输入音量控制
- `2` 输出设备快速切换
- `3` 按 App 自动切换规则
- `4` 会议静音 / 摄像头开关
- `5` 媒体播放进度 / 播放速度控制
- `6` 自定义快捷键动作

**为什么这 6 个最重要**

- 都和“触控板连续操作”天然匹配。
- 都是高频、可感知、省步骤的行为。
- 都比“再多一个系统小开关”更像可以收费的产品能力。

**商业化包装**

- 产品名可以从“TouchTouch 调节工具”升级成“TouchTouch: Trackpad Control Center”。
- 官网文案不要写“支持多少种手势”，要写“会议时更少打断、看片时更顺手、创作时更像一块控制台”。
- 演示视频要围绕场景：开会、看片、剪辑、写代码，而不是设置面板。

**落地建议**

- 第一个可收费版本，建议只瞄准一个主线：`会议 + 媒体`。
- 原因是这两个场景都容易演示、容易理解、容易形成付费冲动。
- 不建议第一版就做成全能平台，否则产品会迅速复杂化，落入“大而杂但没人愿意配”的陷阱。

**我建议的实际开发顺序**

- 第 1 周：抽象 `Action` 和规则模型，改造 [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift)
- 第 2 周：支持前台 App 识别和按 App 映射
- 第 3 周：做会议控制包 MVP
- 第 4 周：做媒体控制包 MVP
- 第 5 周：补模板、引导和高级 HUD
- 第 6 周：做内测版和定价页

**一句话产品方案**

- 把它从“触控板调音量亮度的小工具”，升级成“用触控板直接操控当前场景的高频参数和动作的效率产品”。

**下一步我可以继续补两种内容**

- 我可以直接给你一版 `PRD 文档框架`，适合你写进 `Touch-演化方向.md`
- 我也可以继续给你一版 `技术架构改造方案`，明确现有代码怎么拆、怎么抽象、怎么一步步落地到可收费版本

## User

好 要一份 PRD框架 也补一个技术架构改造方案 也要收费页文案 + 用户分层 + 首版卖点

## Assistant

**PRD 框架**

**1. 产品名称**

- 中文名：`TouchTouch`
- 英文副标题：`Trackpad Control Center for Mac`
- 产品定位：`基于触控板的上下文控制层`

**2. 产品背景**

- 当前产品仅解决“亮度 / 音量调节”这一单点需求，虽然体验顺手，但单点价值不足以支撑稳定付费。
- 用户真正愿意付费的，不是更多孤立的小功能，而是在会议、媒体、创作、办公中减少打断、提升连续操作效率。
- 因此需要把产品从“触控板调节工具”升级为“触控板驱动的场景化控制平台”。

**3. 目标用户**

- 频繁开会的办公用户
- 高频观看视频和听音乐的媒体用户
- 设计、剪辑、修图等创作者
- 喜欢快捷操作和自动化的开发者与效率用户

**4. 核心问题**

- 键盘和鼠标之间切换频繁，打断当前任务流
- 会议中的静音、切设备、调音量操作不够顺手
- 视频和音乐控制依赖多个快捷键，学习成本高
- 专业软件中的连续参数调节不够自然
- 市面上现有工具往往功能太杂、配置太重

**5. 产品目标**

- 让用户在不离开触控板的情况下完成高频控制动作
- 让一套简单手势在不同 App 中自动映射到最合适的行为
- 提供足够强的预设模板，让非高级用户也能开箱即用
- 用会议和媒体场景做出首个可付费版本

**6. 非目标**

- 不做全输入设备自动化平台
- 不以复杂宏编排为第一阶段主卖点
- 不在第一版主打窗口管理，避免直接陷入强竞品赛道

**7. 首版产品定义**

- 首版定位：`会议 + 媒体场景的触控板控制工具`
- 免费版保留：亮度、音量、基础边缘识别、基础 HUD
- Pro 版主打：按 App 规则、会议控制包、媒体控制包、更多触发区、自定义快捷键动作

**8. 核心能力模块**

- `系统连续控制`
- 亮度、音量、麦克风输入音量、输出设备切换、夜览、勿扰

- `场景化规则引擎`
- 根据前台 App 自动切换控制行为

- `触发识别层`
- 左右边缘、上下边缘、四角、修饰键组合、停留、长按

- `动作执行层`
- 系统控制、快捷键、AppleScript、Shell、Shortcuts、URL Scheme

- `反馈层`
- HUD、触觉反馈、状态提示、执行成功 / 失败提示

**9. MVP 功能范围**

- 在 `Zoom` / `Meet` / `Teams` 中：
- 右边缘滑动调会议音量
- 左下角静音 / 取消静音
- 右下角开关摄像头
- 长按边缘进入会议专注模式

- 在 `Music` / `Spotify` / `IINA` / 浏览器视频中：
- 左边缘滑动调进度
- 右边缘滑动调音量
- 上边缘调播放速度
- 下边缘调字幕偏移或切换

- 全局保留：
- 亮度 / 音量调节
- HUD 和触觉反馈
- 基础规则模板

**10. 用户使用流程**

- 第一次启动
- 授权输入监控和辅助功能
- 选择默认模式：办公 / 会议 / 媒体
- 开启推荐模板
- 用引导浮层试用 2 到 3 个核心手势

- 日常使用
- 打开某个 App
- TouchTouch 自动切换到对应规则
- 用户在触控板边缘滑动或点按
- 系统执行动作并给出 HUD / 触觉反馈

**11. 成功指标**

- 安装后完成权限授予率
- 3 日内至少触发一次会议或媒体模板的用户占比
- 日均触发次数
- 免费转 Pro 转化率
- Pro 用户 7 日 / 30 日留存
- 模板启用率和自定义规则创建率

**12. 版本计划**

- `V1.5`
- 扩展系统连续控制项，打磨误触和反馈

- `V2.0`
- 支持按 App 自动切换规则

- `V2.5`
- 上线会议控制包、媒体控制包，推出 Pro 版

- `V3.0`
- 上线自定义动作、脚本、模式切换、模板共享

**13. 风险与约束**

- 依赖 `DisplayServices`、`MultiTouchSupport` 等私有框架，存在兼容性和分发风险
- 输入监控权限的获取和解释成本较高
- 不同 App 的控制方式差异大，适配成本会持续存在
- 若配置体验不够轻，容易掉入“功能很强但没人配”的陷阱

**技术架构改造方案**

**一、改造目标**

- 从“单一工具逻辑”升级成“规则驱动架构”
- 从“亮度 / 音量硬编码”升级成“触发器 + 规则 + 动作执行器”
- 从“单组全局配置”升级成“全局配置 + App 配置 + 模板配置”
- 为收费能力预留模块化边界

**二、现状问题**

- [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift) 目前既负责配置状态，也负责动作分发，后续功能一多会迅速膨胀。
- [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift) 当前把“识别目标”和“执行目标”耦合在一起，扩展到更多动作时可维护性会下降。
- `ControlTarget` 只有 `brightness` / `volume` 两种目标，不足以支持后续的场景化动作。
- [SettingsView.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Views/SettingsView.swift) 是单面板结构，未来增加 App 规则和模板后会很难维护。

**三、建议的目标架构**

- `Input Layer`
- 负责采集触控板输入与修饰键信息
- 包含 `TrackpadEventMonitor`、`MultiTouchSupportManager`

- `Gesture Interpretation Layer`
- 负责把原始输入解释为统一事件
- 例如：左边缘上滑、右下角点击、上边缘长按

- `Rule Engine`
- 根据前台 App、当前 Profile、手势事件查找匹配规则
- 输出一个或多个动作定义

- `Action Execution Layer`
- 执行动作定义
- 包括系统控制、快捷键、脚本、外部 App 控制

- `Feedback Layer`
- 控制 HUD、触觉、提示音、错误反馈

- `Configuration Layer`
- 负责全局配置、模板配置、App 规则配置的存储和读取

**四、建议的核心模型**

- `GestureEvent`
- 字段建议：`zone`、`direction`、`modifierFlags`、`touchCount`、`velocity`、`holdDuration`

- `AppContext`
- 字段建议：`bundleIdentifier`、`appName`、`category`

- `ActionDefinition`
- 字段建议：`id`、`type`、`payload`、`feedbackPolicy`

- `RuleDefinition`
- 字段建议：`id`、`scope`、`appMatcher`、`gestureMatcher`、`actions`

- `ProfileDefinition`
- 字段建议：`id`、`name`、`enabledRules`、`priority`

- `TemplateDefinition`
- 字段建议：`id`、`name`、`appTargets`、`presetRules`

**五、建议的代码拆分**

- 新增 `Domain`
- 放枚举、实体、规则模型、协议定义

- 新增 `Engines`
- 放 `GestureInterpreter`、`RuleEngine`、`ProfileResolver`

- 新增 `Executors`
- 放 `BrightnessExecutor`、`VolumeExecutor`、`ShortcutExecutor`、`AppleScriptExecutor`、`ShellExecutor`

- 新增 `Contexts`
- 放 `ForegroundAppMonitor`

- 新增 `Templates`
- 放会议、媒体、浏览器等默认模板

- 新增 `Persistence`
- 放本地配置持久化逻辑

**六、现有文件的改造建议**

- [TrackpadEventMonitor.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/TrackpadEventMonitor.swift)
- 当前职责：监听 + 目标判断 + 执行回调
- 改造方向：只输出 `GestureEvent`

- [AppState.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Stores/AppState.swift)
- 当前职责：设置存储 + 监听启停 + 动作执行
- 改造方向：成为 `AppCoordinator` 或 `RuntimeStore`，只负责运行时协调

- [BrightnessManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/BrightnessManager.swift)
- 改造方向：实现 `ActionExecutor` 协议，成为 `BrightnessExecutor`

- [VolumeManager.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Services/VolumeManager.swift)
- 改造方向：实现 `ActionExecutor` 协议，成为 `VolumeExecutor`

- [SettingsView.swift](file:///Users/donghua_xiong/study/TouchTouch/Sources/TouchTouch/Views/SettingsView.swift)
- 改造方向：拆成 `GeneralSettingsView`、`RulesView`、`TemplatesView`、`PricingView`

**七、首阶段接口抽象建议**

- `protocol GestureSource`
- 输出统一的 `GestureEvent`

- `protocol ActionExecutor`
- 定义 `canExecute(_:)` 和 `execute(_:)`

- `protocol RuleRepository`
- 负责读写规则和模板

- `protocol AppContextProvider`
- 负责提供当前前台 App 上下文

- `protocol FeedbackProviding`
- 负责 HUD、触觉和错误提示

**八、规则匹配优先级**

- 优先级建议：
- `临时模式规则`
- `当前 App 专属规则`
- `当前 App 分类规则`
- `全局默认规则`

- 这样可以保证：
- 用户在 `Zoom` 中优先触发会议规则
- 没有专属规则时回退到通用媒体或全局规则

**九、配置存储建议**

- 第一阶段继续用 `UserDefaults` 存简单配置
- 规则、模板和 Profile 建议尽早切到 `JSON file + Codable`
- 原因：
- 更适合导入导出
- 更适合做模板市场
- 更适合版本迁移

**十、分阶段落地计划**

- `阶段 1`
- 抽象 `GestureEvent`、`ActionDefinition`、`ActionExecutor`
- 把亮度和音量改造为第一批执行器

- `阶段 2`
- 增加前台 App 识别和规则引擎
- 接入会议、媒体模板

- `阶段 3`
- 增加快捷键、AppleScript、Shell 等动作执行器
- 支持更丰富的收费能力

- `阶段 4`
- 增加模板导入导出、Profile 切换、付费控制逻辑

**用户分层**

- `L1 轻度用户`
- 需求：只想更快调亮度、音量，最好不用配置
- 对应产品：免费版
- 核心策略：给开箱即用体验，培养习惯

- `L2 办公效率用户`
- 需求：会议静音、切设备、会议音量控制
- 对应产品：会议控制包
- 核心策略：突出少打断、少切窗口

- `L3 媒体重度用户`
- 需求：播放进度、速度、字幕、切歌
- 对应产品：媒体控制包
- 核心策略：突出连续控制和沉浸体验

- `L4 创作者`
- 需求：连续参数控制、时间轴缩放、画笔大小
- 对应产品：高级 Pro / 创作者包
- 核心策略：突出“触控板像控制台”

- `L5 高级自动化用户`
- 需求：自定义动作、脚本、模式切换
- 对应产品：高级 Pro
- 核心策略：突出自由度和可定制性

**收费策略建议**

- `免费版`
- 保留全局亮度 / 音量控制
- 保留基础 HUD、基础触觉反馈
- 提供 1 套系统默认模板

- `Pro 基础版`
- 定价建议：`68-98 元`
- 解锁按 App 配置
- 解锁会议控制包
- 解锁媒体控制包
- 解锁更多触发区

- `Pro 高阶版`
- 定价建议：`128-168 元`
- 解锁自定义快捷键 / AppleScript / Shell / Shortcuts
- 解锁多 Profile
- 解锁模板导入导出
- 解锁高级 HUD 和统计

**收费页文案**

**Hero 标题候选**

- `让 Mac 触控板真正变成你的控制台`
- `开会、看片、创作时，不再为调参数打断节奏`
- `TouchTouch，让触控板不止能滚动`

**Hero 副标题候选**

- `用触控板边缘和角落，直接控制亮度、音量、会议状态、媒体进度和更多高频动作。`
- `根据当前 App 自动切换控制逻辑，让同一套手势在不同场景里做最顺手的事。`

**核心卖点文案**

- `会议更安静`
- 一滑调会议音量，一点静音麦克风，一触切换摄像头，不再手忙脚乱找按钮。

- `媒体更顺手`
- 用触控板直接拖进度、调速度、切字幕，少记快捷键，少打断观看节奏。

- `创作更连贯`
- 把连续调节交给触控板，把注意力留给画面、时间轴和内容本身。

- `开箱就能用`
- 内置会议、媒体、浏览器等模板，不用从零配置一堆规则。

- `需要时也足够专业`
- 支持按 App 配置、自定义动作和脚本，让高级用户也能做出自己的工作流。

**收费对比文案**

- `免费版适合体验`
- 调亮度、调音量、体验基础边缘手势

- `Pro 版适合每天都在用的人`
- 会议控制、媒体控制、按 App 规则、自定义动作，把触控板真正变成效率工具

**按钮文案候选**

- `免费开始使用`
- `升级到 Pro`
- `解锁会议与媒体控制`
- `把触控板变成控制中心`

**FAQ 文案方向**

- `为什么 TouchTouch 值得付费？`
- 因为它不是单纯多几个手势，而是让你在高频场景里少切换、少打断、更连贯。

- `适合哪些人？`
- 经常开会、经常看视频听音乐、做设计剪辑、喜欢高效率操作的 Mac 用户。

- `需要复杂配置吗？`
- 不需要。默认模板可以直接上手，高级用户再按需自定义。

**首版卖点总结**

- `卖点 1：会议场景直击刚需`
- 静音、摄像头、会议音量都是刚需，且非常适合触控板快速控制。

- `卖点 2：媒体场景最容易感知价值`
- 进度、速度、字幕这些动作一旦顺手，用户会立刻感觉到差异。

- `卖点 3：上下文自动切换很有产品感`
- 同样的手势在不同 App 自动换行为，会让产品从“小工具”升级成“系统层能力”。

- `卖点 4：比大而全竞品更轻`
- 不需要用户先研究半天配置，先给价值，再给高级能力。

- `卖点 5：有升级路径`
- 从免费版到 Pro 基础版，再到高级 Pro，产品结构和收入结构都比较清晰。

**首版官网结构建议**

- 第一屏：一句话价值主张 + 演示视频 + 下载按钮
- 第二屏：三大场景，会议 / 媒体 / 创作
- 第三屏：实际手势示例和 HUD 效果
- 第四屏：免费版和 Pro 对比表
- 第五屏：FAQ 和兼容性说明

**最后建议**

- 第一版不要追求“功能很多”，而要追求“用户一试就觉得顺手”
- 第一版最应该证明的是：`会议 + 媒体` 这两个场景足够强，足够值得付费
- 真正的产品壁垒，不是更多开关，而是场景理解、默认模板和连续控制体验
