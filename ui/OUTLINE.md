# 《Scoop UI 编程指南》大纲

更新日期：2026-11-27。本文件是写作计划，不进入 mdbook 构建（不在 `src/` 下）。

**进度**：前言和第一至七部分（第 1～26 章）已完成，其余章节为空文件。

## 0. 定位与写作原则

**读者**：已掌握 Scoop 语言基础（类、lambda、接收者 lambda、委托属性、Context、Option）的程序员，想用 Scoop 写原生桌面应用。语言部分不在本书展开，前置读物为《Scoop 程序设计》（`../scoop-book`）或官网《语言基础》。

**与官网 UI 教程的关系**：官网 `guides/UI-*.md` 共 13 篇 24 章，是按任务组织的教程，也是本书的主要素材，其中约 45 个示例已经过验证。本书在此基础上做三件事：

1. **建立心智模型**：用单独的章节讲清组件、视图、State、Element 和"一帧"的管线，后面各章都在这张图上展开。
2. **补齐已实现但教程未覆盖的能力**：剪贴板与拖放、文本菜单与系统文本服务、软键盘、滚动物理、树的多列、系统偏好、Live 公告、系统通知、Dock／任务栏、2D 图形离屏绘制、`scoop bundle` 打包等。
3. **工程化闭环**：从单文件到 Cone、测试、无障碍、性能、打包分发，最后用综合项目串起全书。

**示例策略**：每章用独立、可单独运行的示例（优先复用官网已验证示例）。第十部分的综合项目沿用官网 Payments 应用，并扩展到表单、导入导出、测试和打包，把全书知识收拢起来。

**写作约定**（沿用官网指南约定）：

- 每章包含：要完成的任务 → 运行前提 → 完整示例 → 运行结果（截图）→ 规则讲解 → 常见错误 → 继续阅读。
- 单文件示例用 `//! dep:` 声明依赖，统一 `scoop run xxx.scoop --release`；Windows 写作 `sco`；快捷键统一称 Primary（macOS ⌘，其他平台 Ctrl）。
- "已支持"以当前工具链实现和验证为准；只写实际验证过的平台，未完成的能力明确标为计划。
- 新增内容以工具链 `<SYSROOT>/src/<cone>/README.md`、`examples/`、`scoop api show` 和 Scoop 仓库 `docs/specs/` 为依据，示例全部经实际编译运行。

**素材缩写**：

| 缩写 | 位置 |
| --- | --- |
| 官网 | `../scoop-lang.org/guides/UI-*.md` 与 `guides/examples/ui-*.scoop` |
| skill | `~/.scoop/toolchains/<ver>/tooling/scoop-programming/references/{libraries,design}.md` |
| README | `<SYSROOT>/src/<cone>/README.md`（scoop.ui、scoop.ui.component、scoop.window、scoop.desktop 等） |
| 工具链示例 | `<SYSROOT>/src/<cone>/examples/*`（如 shadcn Gallery、touch-input、glass、download、drop-target） |
| 仓库 | `../scoop/docs/`（specs、scoop-bundle、desktop-ui 等） |

标记 **【新增】** 的章节或小节没有现成教程，需要根据 README、规范和源码新写。

---

## 前言

- 本书讲什么、不讲什么；读者与前置知识
- Scoop UI 的设计取向：Skia 自绘 + 系统原生桌面能力
- 三条阅读路线：快速上手（第 1–3、5、8–9 章 → 综合项目）、应用开发者（第一至六、八部分）、控件作者（再加第七部分与第 31 章无障碍）
- 示例约定、平台与验证状态说明、如何获取示例源码

## 第一部分　起步

### 第 1 章　认识 Scoop UI 【已完成】
- 1.1 先看一眼：运行工具链附带的 Gallery
- 1.2 声明式 UI：与 React／Jetpack Compose／SwiftUI 的对照与区别
- 1.3 自己绘制，原生集成：Skia 自绘的结果；交给系统的部分；语义树
- 1.4 由哪些库组成：分层表；普通应用依赖哪些；框架与控件分离
- 1.5 平台与安装：三类平台与验证状态；Wayland／X11；安装 GUI 组件
- 1.6 怎样使用这本书

示例与截图：`src/images/ch01/gallery-data.png`

### 第 2 章　第一个窗口 【已完成】
- 2.1 最小的程序
- 2.2 逐行看一遍：依赖声明、组件、状态、render、runUiApplication 与主题来源
- 2.3 为什么按钮铺满了窗口：紧约束
- 2.4 用布局和多个控件改写：builder、State 字段、窗口底色、frame、文字居中
- 2.5 builder 块里的“外层接收者”（E0716／H0402，两种改法）
- 2.6 常见错误（含缺少主题来源时的 MissingContextException 实际输出）

示例：`examples/ch02/`（counter、counter_layout、outer_receiver_fail）

### 第 3 章　从单文件到 Cone 项目 【已完成】
- 3.1 什么时候该用 Cone
- 3.2 用 scoop new 创建项目
- 3.3 声明依赖：`[dependencies]`、`[test-dependencies]`、`[windows] subsystem`、Cone.lock
- 3.4 package 与源码文件：模型、视图、入口；间接读取也是依赖
- 3.5 测试模型
- 3.6 日常命令
- 3.7 去哪里查资料：scoop example、scoop api、离线文档、README 与 examples、Gallery 源码、编辑器

示例：`examples/ch03/counter-app/`

### 第 4 章　核心模型：组件、视图与一帧 【已完成】
- 4.1 四个角色：Component、View、State、Element
- 4.2 从一次点击到新画面：逻辑更新与呈现
- 4.3 动手观察：会打印每一步的演示程序与八个实验
- 4.4 规则一：读取即依赖（含主题读取交互偏好导致的启动二次 render）
- 4.5 规则二：写入先记账，回调结束后统一更新；render 中不能写
- 4.6 规则三：父组件 render，子组件跟着 render；InputComparison
- 4.7 规则四：身份由位置、key 和类型决定
- 4.8 规则五：三层工作量（UiInvalidation、requestFrame／requestLayout、布局失效传播、scene 每帧执行）
- 4.9 以真正呈现的画面为准（Accepted）
- 4.10 静止时什么都不做
- 4.11 一切发生在 UI 线程
- 4.12 全书的地图

示例：`examples/ch04/pipeline.scoop`

## 第二部分　布局与文字

### 第 5 章　布局容器 【已完成】
- 5.1 一张名片：row、column 与 stack（属性与默认值、stack 叠放、主题表面）
- 5.2 主轴上的分配：justify、basis、grow 与 shrink；基线对齐
- 5.3 书写方向：从右到左（direction、逻辑方向与不镜像的部分、logicalPadding）
- 5.4 frame：尺寸、内边距、对齐与外观（width 是上限、放宽约束、clipContent）
- 5.5 wrap 与 grid（单元格对齐与 Label 占满单元格的对照）
- 5.6 absolute 与 aspectRatio（无界父轴时的 IllegalArgumentException）
- 5.7 builder 块里的同名成员（E0501；作用范围是整个块；三种解决办法）
- 5.8 把 render 拆成函数

示例：`examples/ch05/`（card、flex、wrap_grid、absolute、builder_unit_fail）

### 第 6 章　约束模型 【已完成】
- 6.1 约束向下，尺寸向上（Constraints；紧约束、宽松约束、无界约束）
- 6.2 六条规则（含根 frame 的 width 不生效）
- 6.3 约束实验室：五组对照实验
- 6.4 回头看前面的谜题
- 6.5 排查布局问题

示例：`examples/ch06/constraints.scoop`

### 第 7 章　文字与排版 【已完成】
- 7.1 一页文字
- 7.2 label 与 SpanStyle
- 7.3 段落设置（对齐、maxLines 与省略号、行高与字距、字体族、多种文字混排）
- 7.4 StyledText：一段文字里的多种样式（不继承主题）
- 7.5 typography：排版角色、行内代码、列表与表格
- 7.6 键帽：kbd 与 kbdGroup
- 7.7 可选择的文本
- 7.8 字体：FontCollection、登记自有字体、includeBytes
- 7.9 从右到左的段落（句末标点的位置；写了 settings 就不再继承方向）

示例：`examples/ch07/`（text、paragraph、document、rtl）

## 第三部分　状态与数据流

### 第 8 章　State 与依赖追踪 【已完成】
- 8.1 两种写法（字段与委托；state() 不能写在 render 中）
- 8.2 一个会说话的例子
- 8.3 依赖每次重新收集（条件分支中的读取）
- 8.4 可变对象：原地修改不会通知任何人
- 8.5 struct：天然适合做状态（副本更新）
- 8.6 每次赋值都会通知（相同的值也会）
- 8.7 连续写入与派生值
- 8.8 State 与线程

示例：`examples/ch08/dependencies.scoop`

### 第 9 章　组件之间传值：Props 与 Binding 【已完成】
- 9.1 构造参数与 Props
- 9.2 温度换算器
- 9.3 Binding：读写别人的值（派生 Binding）
- 9.4 两个陷阱：把 Props 复制进本地状态；长期保存的回调用了旧的输入
- 9.5 选择传递方式（构造参数、Props、Binding、Context；InputComparison）

示例：`examples/ch09/`（temperature、props_pitfalls）

### 第 10 章　业务 Store 与 Context 【已完成】
- 10.1 一个阅读清单
- 10.2 Store 是普通的类（精确更新：每本书的进度是单独的 State；数据放在哪里）
- 10.3 用 Context 注入 Store（绑定覆盖整个运行过程；闭包和 View 描述不捕获 Context）
- 10.4 可选的依赖与缺失的依赖（contextOrNone、MissingContextException）
- 10.5 组件持有的资源（scope.resource、scope.onDispose）

示例：`examples/ch10/reading_list.scoop`

### 第 11 章　组件身份与 key 【已完成】
- 11.1 匹配的规则
- 11.2 列表重排：本地状态跟谁走
- 11.3 条件分支：状态串到了另一个对象上
- 11.4 有意地丢弃状态
- 11.5 关于 key 的几条约束（duplicate sibling ViewKey）

示例：`examples/ch11/`（keys、branches）

## 第四部分　输入与交互

### 第 12 章　文本输入 【已完成】
- 12.1 一个文本输入的示例（姓名、手机号、密码、输入组、备注、验证码）
- 12.2 编辑模型由你持有：TextEditorState（读 text 即依赖；replaceAll、undo）
- 12.3 input 与 textarea（onSubmit；textarea 默认 Primary+Enter 提交；编辑器自己处理 ⌘V）
- 12.4 编辑策略：替换换行 → paste → transform → acceptsInsertedText（逐段检查改写后的新增文字，任一段失败丢弃整次编辑）→ maxLength（按字素截断）；单行时回调输出的换行同样转为空格
- 12.5 密码框：projection 与 protectedText 相互独立；TextCopyPolicy
- 12.6 输入组与验证码（InputOtpPattern）
- 12.7 输入用途与软键盘（macOS 未验证）
- 12.8 文本上下文菜单与系统文本服务（按文档介绍，后台右键未能打开菜单）

示例：`examples/ch12/`（text_inputs）

### 第 13 章　选择控件与表单 【已完成】
- 13.1 选择控件一览（值都通过 Binding 传入）
- 13.2 复选框（三态派生 Binding）、开关与切换按钮
- 13.3 单选组与滑块（Array<Double> 与 RangeSpec）
- 13.4 下拉框与组合框（Binding 类型决定单选／多选；ChoiceSource）
- 13.5 FieldTarget：标签与控件的关联（点击标签、读屏器名字）
- 13.6 field：标签、说明、错误与必填；fieldGroup／fieldSet
- 13.7 校验：业务决定错误，控件只负责呈现（资料表单）

示例：`examples/ch13/`（choices、profile）

### 第 14 章　焦点与键盘 【已完成】
- 14.1 一个键盘示例
- 14.2 默认的 Tab 顺序
- 14.3 FocusOptions：order、tabStop、handle
- 14.4 FocusHandle：在程序中移动焦点（isPending；不能在 render 中请求）
- 14.5 方向键导航（keyNavigation、roving）与焦点范围（focusScope）
- 14.6 快捷键（ShortcutScope、Primary、kbdGroup；UiHost.shortcutScope 见第 27 章）
- 14.7 焦点环什么时候显示（FocusVisibility.Automatic）

示例：`examples/ch14/`（keyboard；Tab、方向键与快捷键经用户允许在前台实测）

### 第 15 章　指针、触摸与手势 【已完成】
- 15.1 同一个操作，多个入口
- 15.2 一个手势面板（自绘 Element 上的输入区域）
- 15.3 press 与 longPress（longPress 只识别手指和触控笔，鼠标用上下文菜单）
- 15.4 drag：四个阶段与接管
- 15.5 swipeGesture：轻扫（mouse 默认 false）；轻扫翻页与 routeChildren；style 块中 border 的陷阱
- 15.6 transformGesture：捏合与旋转（未验证）
- 15.7 连续点击：双击与三击
- 15.8 触摸滚动与输入的接管

示例：`examples/ch15/`（gesture_pads、swipe_pages）

### 第 16 章　剪贴板与拖放 【已完成】
- 16.1 一个示例
- 16.2 剪贴板：readText／writeText／writeTexts；多种表示；何时读取；PRIMARY
- 16.3 接收拖放：dropTarget、DropAreaHandlers、hover 反馈、沿父级交接
- 16.4 发起拖放：dragSource、DragSourceData、Move 由业务删除；本节未完成的验证
- 16.5 窗口层的原生拖放：registerDropTarget、beginDrag
- 16.6 文本控件中的拖放
- 16.7 官方的拖放示例（drop-target，复制出来即可构建）

示例：`examples/ch16/`（transfer；剪贴板已验证，真实拖动会话无法用合成事件启动，需手动验收）

## 第五部分　组织界面

### 第 17 章　滚动与长列表 【已完成】
- 17.1 一个滚动区域（scrollArea 常用配置；构建并保持全部内容）
- 17.2 ScrollState：读取（来自 Accepted，读取即依赖）与控制（scrollTo／scrollBy／animateTo／reveal；聚焦即滚动到控件；observeIntent）
- 17.3 滚动条与边界：scrollbarBehavior 的 FollowSystem／Static／Custom、Overlay／Gutter；ScrollPhysicsOptions 的 Platform／Hard／Elastic 与惯性；chain 与 touchScroll 【新增】
- 17.4 虚拟列表：ItemSource（稳定 key、indexOfKey 一致）；数据变化换新的数据源对象；ItemExtent.Fixed／Variable；overscan
- 17.5 按行定位与阅读位置：scrollToItem、reading、restore（书签）；anchor 的 KeepVisible／FollowEnd／None（三个实验）
- 17.6 保留行状态与绘制缓存：Dispose 与交互中的行、KeepAlive(n)、不能丢的数据放模型；PaintCachePolicy.Tiles
- 17.7 一亿行的列表（Fixed、overscan、ItemNavigation.Roving、focusItem；读屏器分页：超过 4096 行按页提供，Go to row，需 d31c5543 之后的工具链）
- 写作注意：后台窗口中滚动条不淡入淡出（allowed() 要求窗口聚焦且未遮挡），FollowSystem 的自动隐藏按源码描述；弹性回弹需要连续相位滚动，未核对；onMount 中 scrollToItem 返回 false

示例：`examples/ch17/`（scroll_area、chat_log、huge_list）

### 第 18 章　弹层 【已完成】
- 18.1 一个示例（popovers）
- 18.2 open 绑定是唯一的状态来源；触发器可选；onCloseRequest 与 OverlayCloseReason；直接写状态不经过拦截
- 18.3 提示、悬浮卡片与 Popover；三种 OverlayMode；builder 同名成员的陷阱
- 18.4 dialog、alertDialog、sheet、drawer；操作按钮不替你关闭；打开前准备草稿
- 18.5 菜单：menu 内容在 dropdownMenu／contextMenu／menubar 间复用；shortcut 只是标签；原生菜单见第 28 章
- 18.6 Toast：ToastState、toaster、ToastId 的 update／dismiss、暂停计时
- 18.7 焦点：OverlayFocusOptions；关闭后恢复到原焦点
- 写作注意：自动化工具的左键点击和按键不能送达后台窗口，点击外部与 Escape 未在窗口中核对

示例：`examples/ch18/`（popovers、dialogs、menus）

### 第 19 章　导航与工作区 【已完成】
- 19.1 一个导航的示例（没有路由器，页面就是 State）
- 19.2 导航菜单（link／item，open 绑定）与面包屑
- 19.3 页签（Choice、variant、activation、retention：KeepMounted 保留的是组件自己的状态）与分页
- 19.4 一个精简的工作区（workspace）
- 19.5 侧栏（collapsible、variant、rail、Auto 布局与 breakpoint、⌘B；sidebarMenu）
- 19.6 可调面板（ResizableSize 放在自己的状态中；minimum／collapsible；键盘调整）
- 19.7 命令面板（commandItems、keywords、CommandFilter；放进 dialog）
- 19.8 一份状态，多个入口

示例：`examples/ch19/`（navigation、workspace）

### 第 20 章　数据展示 【已完成】
- 20.1 内容块：卡片、提示、空状态、条目、头像、标签、骨架、进度、Spinner
- 20.2 表格：table 与 dataTable（DataTableState、TableRecord 的 key、列定义与列宽、TableData.Provided；tableColumnResize）
- 20.3 树：TreeNode／TreeData／TreeColumns、选择与级联勾选、TreeHandle 定位、sticky、筛选与高亮
- 20.4 日历与日期选择器（calendar／calendarMultiple／calendarRange、today、rules、datePicker 与 draft）
- 20.5 图表（ChartModel、ChartKind、图例隐藏系列）与会话组件（bubble、message、marker、trace；messageScroller 简介）
- 20.6 图片与图标：imageView 的四种 ContentFit（需要确定的区域，aspectRatio）、Lucide 图标与只有图标的按钮、SvgDocument 与 svgView 【新增】

示例：`examples/ch20/`（content、tables、files、dates、report、media）

## 第六部分　外观

### 第 21 章　主题 【已完成】
- 21.1 四套预设：Cone、工厂函数 `xxxTheme(mode, palette) { }`、取向与选择
- 21.2 主题由什么组成：tokens 与部件两层；改 tokens 不重算部件；按钮文字用 typography.action；read(scope) 取页面颜色
- 21.3 在预设上修改（brand）；copy 派生（Larger text：body 变大、按钮文字不变）
- 21.4 运行时切换主题（themes）：不重建界面，状态全部保留；选择与最终主题分开保存
- 21.5 跟随系统明暗（observedTheme、ThemeChanged）与系统配色 `macosSystemPalette(mode)`（快照、主线程、仅 macOS）【新增】
- 21.6 显示偏好：read(scope) 与 current 的区别；theme.preferences；`runUiApplication(preferences = uiPreferences { })` 覆盖；运行中改用 UiWindow.preferences；contrastThemeColors 【新增】
- 写作注意：切换系统外观未实际操作；按钮直接放在 column 中会占满宽度（居中的标签按可用宽度排版），示例把按钮放进 row

示例：`examples/ch21/`（brand、themes、preferences）

### 第 22 章　局部样式与效果 【已完成】
- 22.1 一个示例（styles）
- 22.2 styled：Style 的字段；对布局透明、不加内边距、增减效果不重建内容
- 22.3 绘制顺序与内容效果（BoxShadow 与 DropShadow 的区别、Glow、Blur 不是毛玻璃；StylePainter 与滤镜）
- 22.4 控件的样式：ButtonStyle、CheckboxStyle、TextFieldStyle、states；局部样式要克制
- 22.5 StyleOverride：Inherit 与 Set、resolve、then、copy（overrides 控制台程序）
- 22.6 样式块中的陷阱：`frame { style { border = Some(...) } }` 选中顶层 `style {}` 被丢弃（style_trap 截图对照）

示例：`examples/ch22/`（styles、overrides、style_trap）

## 第七部分　自定义控件

### 第 23 章　自绘 Element 【已完成】
- 23.1 Component 与 Element
- 23.2 一个完整的自绘控件：级别条
- 23.3 生命周期：onMount、update、onUnmount
- 23.4 measure：约束、尺寸与子项（含 skipChild）
- 23.5 scene：输入区域、子项与绘制顺序；SceneContext 变换与 Canvas 变换（Peek 示例，读屏器位置随变换移动）
- 23.6 draw：PaintContext 与 Canvas
- 23.7 输入与动画（弹簧）；自绘控件对读屏器不可见
- 23.8 停帧；createDeadline（code-editor 光标闪烁）；外部事件驱动的帧（scoop-video）
- 23.9 onFrameComplete（solar-system 命中与模拟时间、grid 只在 Accepted 后提交）
- 23.10 真实项目中的自绘控件：六个 scoop-lang 开源项目总览

示例：`examples/ch23/`（meter、peek）

### 第 24 章　让自绘控件接入框架 【已完成】
- 24.1 给级别条补上键盘和读屏器：focusTarget、焦点通知、按键、语义节点（Slider、range、increment/decrement/setNumber），AX 实测
- 24.2 交互助手：scope.press 与 interaction；mergeLabels 与 routeSemanticsChildren；控件作者用的其他助手
- 24.3 ThemePainterCache 与主题几何
- 24.4 StylePainter
- 24.5 ParagraphHost 与行内子项；文字要自己发布语义（官网示例缺失，书中补上）；drawTextLayout；TextEditHost
- 24.6 drawLayer（故意写错版本号的对照）；cachedScene
- 24.7 真实项目：markdown MdSourceAction、terminal 屏幕缓存、markdown MdCodeField、code-editor 原始文本输入

示例：`examples/ch24/`（meter、tasks、note、badges）

### 第 25 章　2D 图形与着色器 【已完成】
- 25.1 路径、渐变、裁剪与变换；资源归属（仪表盘）
- 25.2 图像与图层：采样方式、整体透明度、图层滤镜
- 25.3 SkSL 着色器：程序结构、编译与绑定
- 25.4 背景效果：毛玻璃、drawBackdrop、saveBackdropLayer、runtimeShader 折射（glass 示例）
- 25.5 CPU 离屏绘制：RasterSurface、readPixels（有 .expected）、OffscreenSurface、recordDrawing
- 25.6 真实项目：video 的 NV12 着色器、solar-system 原生 GPU 渲染、terminal 两遍绘制与硬裁剪

示例：`examples/ch25/`（gauge、layers、shader、raster）

### 第 26 章　自定义弹层、容器与按需列表 【已完成】
- 26.1 portal 与锚点：AnchorBox、PanelArea、定位与关闭（官网示例改用 read(scope)）
- 26.2 模态弹层：自己画遮罩（frame 只会收缩），AX 中背景被移走
- 26.3 自定义滚动容器：ScrollViewport 四件事、ViewportScrollbars、ScrollAdjustment
- 26.4 LazyElement：ItemSource、pinnedItems、retention、lazyFocus、item(key) 与 withScrollReveal（未写示例）
- 26.5 LayoutInput：共用标签列宽的表单，试测与正式测量
- 26.6 真实项目：grid 两个方向的虚拟化与“测到稳定”、markdown 不挂载子项的按需布局、code-editor

示例：`examples/ch26/`（popover、confirm、rows、fields）

## 第八部分　桌面应用

### 第 27 章　应用、窗口与应用根
- 27.1 runUiApplication 做了什么
- 27.2 Application、ActiveApplication 与 UiHost
- 27.3 多窗口：共享状态与各自的状态
- 27.4 应用根：ApplicationComponent
- 27.5 错误隔离：onRootError 与 onApplicationError

素材：官网 UI-DESKTOP §19；示例 ui-desktop-windows

### 第 28 章　原生桌面能力
- 28.1 先查询能力
- 28.2 原生菜单
- 28.3 自绘窗框与全屏
- 28.4 工具窗口、模态窗口与文件对话框
- 28.5 托盘图标
- 28.6 Dock 与任务栏：角标、进度、Jump List 【新增】
- 28.7 系统通知 【新增】

素材：官网 UI-DESKTOP §20；示例 ui-desktop-native、ui-desktop-tray；工具链示例 native-desktop；README scoop.desktop "系统通知"、scoop.window "多窗口、模态与窗框"

### 第 29 章　异步与后台任务
- 29.1 UI 线程模型：等待用协程，计算用线程
- 29.2 后台线程：ApplicationProxy 投递、协作式取消、新任务替换旧任务、进度节流、退出时回收
- 29.3 协程：`runWithAsyncio`、应用作用域与取消
- 29.4 网络请求与下载进度（download 示例）

素材：官网 UI-DESKTOP §21、UI-STATE §5.6；示例 ui-desktop-worker；工具链示例 download

## 第九部分　质量与交付

### 第 30 章　测试 UI
- 30.1 先把逻辑放进业务类
- 30.2 一个可测试的 Cone
- 30.3 纯状态测试
- 30.4 在隐藏窗口中测试组件
- 30.5 等待真实的帧
- 30.6 在 Linux 和 Windows 上运行窗口测试
- 30.7 截图验证外观，操作后的状态验证交互

素材：官网 UI-TESTING；示例 ui-testing-cone；skill design.md UI 验证段

### 第 31 章　无障碍
- 31.1 标准控件的默认语义与 ComponentSemantics
- 31.2 表单语义：FieldTarget 关联标签、说明与错误
- 31.3 模态范围与焦点
- 31.4 自绘控件：SemanticsHandle 的角色、名称、状态与动作
- 31.5 状态与公告：SemanticLive 与 announce 【部分新增】
- 31.6 集合、表格与虚拟列表的语义（ItemSemantics）【新增】
- 31.7 三个平台：AX／VoiceOver、UIA／讲述人、AT-SPI／Orca，以及验证方法

素材：官网 UI-INTERACTION、UI-CUSTOM §17；工具链示例 accessibility；README scoop.ui "语义资源与原生 accessibility"、scoop.window "无障碍内容投影"；skill libraries.md（无障碍各条）

### 第 32 章　性能 【新增，综述章】
- 32.1 先测量：release 构建、`SCOOP_SURFACE_FPS` 帧率报告
- 32.2 减少重新 render：依赖粒度、写入合并、拆分组件
- 32.3 避免重新挂载：稳定 key
- 32.4 大量数据：虚拟列表与按需子项
- 32.5 绘制：drawLayer 缓存与停帧
- 32.6 后台任务：投递节流、只保留最新进度

素材：散见官网各篇；skill libraries.md "macOS GUI 实际帧率"

### 第 33 章　打包与分发 【新增】
- 33.1 产物与运行依赖：可执行文件、GUI 运行库、资源
- 33.2 `scoop bundle` 概览：.app、deb、rpm、AppImage、NSIS、MSI
- 33.3 应用元数据、图标与附加资源
- 33.4 签名（macOS codesign、Windows 可选签名）
- 33.5 各平台验证清单

素材：仓库 docs/scoop-bundle/DESIGN.md、PROGRESS.md；以工具链实际 `scoop bundle --help` 为准

## 第十部分　综合项目

### 第 34 章　付款管理应用
- 34.1 先决定数据放在哪里
- 34.2 第一步：数据模型与表格
- 34.3 第二步：筛选、分页和选择
- 34.4 第三步：行菜单与删除确认
- 34.5 第四步：撤销与汇总联动
- 34.6 第五步：新建与编辑付款（表单与校验）【新增】
- 34.7 第六步：导入导出（文件对话框、后台解析、拖入文件）【新增】
- 34.8 第七步：主题切换、原生菜单与快捷键 【新增】
- 34.9 第八步：测试与打包 【新增】
- 34.10 回顾：每一步用到了哪些章节

素材：官网 UI-PROJECT；示例 ui-project-step1～4

## 附录

- 附录 A　控件速查：`scoop.ui.component` 按类别列出控件、主要参数和所在章节
- 附录 B　常见错误与诊断：汇总各章"常见错误"表（E0716、MissingContextException、State 写入阶段错误、builder 返回 Unit 等）
- 附录 C　四套主题对照与 tokens 速查
- 附录 D　平台差异与验证状态：输入、无障碍、桌面能力、窗口测试在三个平台上的实际支持与验证情况
- 附录 E　概念对照：React／Jetpack Compose／SwiftUI → Scoop UI
- 附录 F　术语表（中英对照：紧约束、owner 线程、Accepted 帧……）
- 附录 G　生态与延伸阅读：scoop.ui.markdown、shadcn Gallery、UI 规范与各库 README

---

## 附：建议的 SUMMARY.md 与文件布局

沿用《Scoop 程序设计》的 `partNN-xxx/chNN-xxx.md` 命名，确认大纲后再写入 `src/SUMMARY.md`：

```markdown
# 目录

[前言](preface.md)

# 第一部分　起步
- [第 1 章　认识 Scoop UI](part01-start/ch01-overview.md)
- [第 2 章　第一个窗口](part01-start/ch02-first-window.md)
- [第 3 章　从单文件到 Cone 项目](part01-start/ch03-cone-project.md)
- [第 4 章　核心模型：组件、视图与一帧](part01-start/ch04-mental-model.md)

# 第二部分　布局与文字
- [第 5 章　布局容器](part02-layout/ch05-containers.md)
- [第 6 章　约束模型](part02-layout/ch06-constraints.md)
- [第 7 章　文字与排版](part02-layout/ch07-text.md)

# 第三部分　状态与数据流
- [第 8 章　State 与依赖追踪](part03-state/ch08-state.md)
- [第 9 章　组件之间传值：Props 与 Binding](part03-state/ch09-props-binding.md)
- [第 10 章　业务 Store 与 Context](part03-state/ch10-store-context.md)
- [第 11 章　组件身份与 key](part03-state/ch11-keys.md)

# 第四部分　输入与交互
- [第 12 章　文本输入](part04-input/ch12-text-input.md)
- [第 13 章　选择控件与表单](part04-input/ch13-forms.md)
- [第 14 章　焦点与键盘](part04-input/ch14-focus-keyboard.md)
- [第 15 章　指针、触摸与手势](part04-input/ch15-pointer-gestures.md)
- [第 16 章　剪贴板与拖放](part04-input/ch16-clipboard-dnd.md)

# 第五部分　组织界面
- [第 17 章　滚动与长列表](part05-structure/ch17-scrolling.md)
- [第 18 章　弹层](part05-structure/ch18-overlays.md)
- [第 19 章　导航与工作区](part05-structure/ch19-navigation.md)
- [第 20 章　数据展示](part05-structure/ch20-data-display.md)

# 第六部分　外观
- [第 21 章　主题](part06-appearance/ch21-themes.md)
- [第 22 章　局部样式与效果](part06-appearance/ch22-styles.md)

# 第七部分　自定义控件
- [第 23 章　自绘 Element](part07-custom/ch23-element.md)
- [第 24 章　让自绘控件接入框架](part07-custom/ch24-integration.md)
- [第 25 章　2D 图形与着色器](part07-custom/ch25-graphics.md)
- [第 26 章　自定义弹层、容器与按需列表](part07-custom/ch26-custom-containers.md)

# 第八部分　桌面应用
- [第 27 章　应用、窗口与应用根](part08-desktop/ch27-application.md)
- [第 28 章　原生桌面能力](part08-desktop/ch28-native.md)
- [第 29 章　异步与后台任务](part08-desktop/ch29-async.md)

# 第九部分　质量与交付
- [第 30 章　测试 UI](part09-quality/ch30-testing.md)
- [第 31 章　无障碍](part09-quality/ch31-accessibility.md)
- [第 32 章　性能](part09-quality/ch32-performance.md)
- [第 33 章　打包与分发](part09-quality/ch33-bundle.md)

# 第十部分　综合项目
- [第 34 章　付款管理应用](part10-project/ch34-payments.md)

# 附录
- [附录 A　控件速查](appendix/a-components.md)
- [附录 B　常见错误与诊断](appendix/b-errors.md)
- [附录 C　主题对照与 tokens](appendix/c-themes.md)
- [附录 D　平台差异与验证状态](appendix/d-platforms.md)
- [附录 E　概念对照](appendix/e-concepts.md)
- [附录 F　术语表](appendix/f-glossary.md)
- [附录 G　生态与延伸阅读](appendix/g-ecosystem.md)
```

## 附：建议写作顺序

1. **骨架先行**：第 1～4 章（第 4 章是全书的地图，先写可以统一术语）。【已完成】
2. **主干迁移**：第 5–15、17–24、27、29、30、34.1–34.5 章，以官网教程为底稿重写，复用已验证示例。
3. **补齐新增**：第 3、16、25、26、28、31–33 章，以及各章标记【新增】的小节。先用工具链示例和 `scoop api show` 核实 API，再写示例。
4. **收尾**：综合项目扩展步骤（34.6–34.9）、附录、前言。
