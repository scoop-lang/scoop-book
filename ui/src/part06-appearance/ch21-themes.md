# 第 21 章　主题

前面所有的示例都在 `main` 中写过一行 `context(ThemeSource(...))`，控件的颜色、字号、圆角和阴影都来自这里的主题。第六部分讨论外观：本章讲整个应用的主题，下一章讲给某一块内容或某一个控件单独设置样式。读完本章，你会知道：

- 四套预设主题各自的取向，怎样选择；
- 主题由哪些数据组成，为什么改了主色按钮却没有变；
- 怎样在预设上修改，怎样从一个主题派生出另一个；
- 怎样在运行时切换主题，为什么切换不会丢失界面的状态；
- 怎样跟随系统的明暗和系统的强调色；
- 高对比度、减少透明度、文字缩放这些显示偏好怎样作用到主题上。

## 21.1　四套预设

主题预设放在四个独立的 Cone 中，按需依赖其中一个或几个：

| Cone | 工厂函数 | 取向 |
| --- | --- | --- |
| `scoop.ui.style.macos` | `macosTheme` | 紧凑的 macOS 风格，采用 macOS Sequoia 的 Aqua 和 Dark Aqua 外观 |
| `scoop.ui.style.material` | `materialTheme` | Material 3 风格：胶囊形按钮、圆形的状态层 |
| `scoop.ui.style.fluent` | `fluentTheme` | Fluent 2 风格 |
| `scoop.ui.style.shadcn` | `shadcnTheme` | shadcn/ui 风格：黑白为主、简洁的轮廓，本书大部分示例用的就是它 |

四个工厂函数的形状相同：

```scoop
macosTheme(mode = ThemeMode.Light, palette = None) { ... }
```

`mode` 是 `ThemeMode.Light` 或 `Dark`；`palette` 是可选的配色，`None` 时使用这套预设自己的配色（21.5 节用它接入系统颜色）；最后的配置块用来在预设上修改（21.3 节）。返回值是 `ShapeTheme`，它实现了公共的 `Theme` 接口，所以控件、样式和你自己的绘图代码都不关心它来自哪套预设。

在单文件程序中，依赖头里同时写 `scoop.ui.style`（`ThemeSource`、`ThemeMode` 等公共类型）和所选的预设：

```scoop
//! dep: scoop:scoop.ui.style:0.1.0
//! dep: scoop:scoop.ui.style.macos:0.1.0
```

选择哪一套主要看应用的定位：只在 macOS 上发布、希望和系统的原生应用放在一起不显突兀，用 macOS；跨平台、希望各平台外观一致，shadcn 或 Material 更合适；面向 Windows 用户，用 Fluent。21.4 节的示例可以在四者之间切换，比较它们的样子。

主题只决定 Scoop **自己绘制**的内容的外观，不修改系统设置，也不改变原生窗口的标题栏（第 1.3 节）。

## 21.2　主题由什么组成

主题是一份不可变的数据，大致分为两层：

- **`tokens`**：整个界面共用的基础数值。`palette` 是语义配色，比如 `background`（页面背景）、`primary`（主色）、`card`、`border`、`ring`（焦点环）等，大部分是一对 `ColorPair(background, foreground)`，表示一种底色和放在它上面的文字颜色；`typography` 是文字样式，有 `body`、`caption`、`action` 三种；还有 `spacing`、`corners`、`motion`（悬停、按下、选中的过渡动画）和 `effects`（`raised`、`floating` 两种阴影）。
- **部件**：`surfaces`（`plain`、`action`、`outlinedAction`、`elevated` 等表面，按钮、输入框、卡片都画在表面上）、`checkbox`、`radio`、`scrollbar`。每个部件有自己的尺寸、填充色、边框色、文字颜色、焦点环和阴影。

两层之间有一条重要的规则：**预设在创建时用 `tokens` 算出各部件的颜色，之后单独修改 `tokens`，已经算好的部件不会跟着变。** 改了 `palette.primary`，主按钮仍然是原来的颜色，因为主按钮用的是 `surfaces.action` 中已经算好的填充色。需要同步改变时，要把相关的部件也显式配置上，下一节的示例就是这样做的。

文字也一样：`typography.body` 是正文，`typography.action` 是按钮之类控件上的文字。只改 `body`，标签变了，按钮上的字不变。

所有页面都应该从主题读取颜色，而不是写死。前面的示例都在 `render()` 中这样给页面铺底色：

```scoop
val background = this.theme.read(scope).tokens.palette.background.background
```

`currentThemeSource()` 在组件构造时取得当前的 `ThemeSource`，`read(scope)` 读取当前的主题（21.6 节会解释它为什么不直接读 `current`）。这样页面的背景和标准控件会一起响应主题的切换和显示偏好。

## 21.3　在预设上修改

很多时候你只想在某套预设上换个品牌色、把正文调大一点。保存为 `brand.scoop`：

```scoop
{{#include ../../examples/ch21/brand.scoop}}
```

```sh
scoop run brand.scoop --release
```

<img src="../images/ch21/brand.png" width="450" alt="品牌主题示例：灰色背景上是 Brand theme 标题，下面一行是紫色的 Clicked 0 times 按钮、紫色勾选的复选框和 Uses the brand color 文字，再下面是白色的 Larger text 按钮">

配置块会在**完整的预设数据**上执行一次：

- 嵌套的块（`tokens { palette { ... } }`）只修改你写到的字段，其余字段保持预设的值；
- 直接给某个字段赋一个完整的值，则整体替换它，比如 `shadows = []` 去掉了主按钮的投影。

`brandTheme` 做了三处修改：把主色和焦点环换成紫色，正文字号改为 15，去掉主按钮的投影。按照上一节的规则，它除了 `palette { primary = ... }`，还分别配置了 `surfaces { action { ... } }` 和 `checkbox { appearance { ... } }`，紫色才出现在按钮和复选框上。

`StateColors(normal, hovered, pressed, disabled)` 给出部件在四种交互状态下的颜色，`StateColors.solid(color)` 表示四种状态用同一种颜色；`mixThemeColor(from, to, progress)` 把两种颜色按比例混合，方便从一个基础色派生出悬停和按下时的颜色。

### 用 copy 派生新主题

主题是不可变的值。`theme.copy { ... }` 以已有主题为起点，接受同样的配置块，返回一个新主题，原来的主题不受影响。示例的 Larger text 按钮就用它派生了一个正文更大的版本：

```scoop
source.current.value = if (large.value)
    brand.copy { tokens { typography { body { fontSize = 19.0 } } } }
else
    brand
```

点 Larger text，标题和 “Uses the brand color” 变大了，两个按钮上的文字却没有变：它们用的是 `typography.action`，而不是 `body`。按钮上的计数也还在，这是 21.4 节要讲的。再点一次 Normal text，切回原来的 `brand`，它从来没有被修改过。

`copy` 适合在一套基础主题上派生几个变体，比如“紧凑模式”或“大字模式”。`palette`、`typography` 等分组本身也有各自的 `copy`。

## 21.4　运行时切换主题

应用持有一个稳定的 `ThemeSource`，用 `context(source) { ... }` 包住 `runUiApplication`。`ThemeSource.current` 是一个 `State<Theme>`，给它赋一个新值就切换了主题。保存为 `themes.scoop`：

```scoop
{{#include ../../examples/ch21/themes.scoop}}
```

```sh
scoop run themes.scoop --release
```

窗口最上面一排按钮选择预设，第二排选择浅色、深色或跟随系统，System colors 切换系统配色（21.5 节），下面是一个计数按钮、一个复选框和一个输入框。点一次 Count，取消勾选 Remember me，把输入框中的文字改为 `Atlas`，再点 Material，窗口是这样的：

<img src="../images/ch21/themes-material.png" width="500" alt="主题切换示例的 Material 浅色外观：淡紫色背景上是 Theme gallery 标题，macOS、Material、Fluent、shadcn 四个胶囊形按钮中 Material 被选中填充为紫色，Light、Dark、Follow system、System colors 四个按钮中 Follow system 被选中，下面是紫色的 Count: 1 按钮、未勾选的方形复选框和 Remember me 文字">

按钮变成了 Material 的胶囊形，背景变为淡紫色，计数仍然是 1，复选框仍然没有勾选，输入框中仍然是 `Atlas`。

**换主题不会重建界面。** 挂载树、组件实例和它们的 State 都保留，只是读到了新主题的组件重新 `render()` 或重新绘制。按钮的计数、复选框的勾选、输入框中的文字和光标、当前的焦点都不受影响。这也是主题要通过 `ThemeSource` 这个 State 来提供，而不是作为参数一层层传下去的原因：读取即依赖（第 8 章），只有真正读了主题的地方才会更新。

示例的结构值得看一下：`ThemeModel` 保存用户的三个选择（预设、明暗、是否使用系统配色），`apply()` 把它们组合成一个主题写入 `source.current`。用户的选择和最终的主题分开保存，这样任何一个选择变化时，都从头组合一次，不会出现“换了预设，明暗却被重置”这样的问题。

每套预设都是独立的 Cone，只依赖应用真正提供的风格即可。示例为了演示依赖了四个。

## 21.5　跟随系统明暗与系统配色

### 系统明暗

“跟随系统”需要两件事：启动时读取系统当前的外观，之后在系统外观变化时得到通知。示例在 `onMount` 中这样做：

```scoop
public override fun onMount() {
    val model = this.model
    val window = scope.nativeWindow
    model.systemChanged(window.observedTheme)
    scope.observeWindow(window) { event ->
        when (event) {
            case ThemeChanged(val value) -> model.systemChanged(value)
            else -> {}
        }
    }
}
```

- `scope.nativeWindow` 是组件所在的原生窗口；
- `observedTheme` 是窗口当前观察到的系统外观，类型是 `scoop.window.Theme?`。它和 UI 的 `Theme` 同名，示例用 `import scoop.window.Theme as WindowTheme` 换了一个名字；
- `observeWindow` 登记窗口事件的回调，组件卸载时自动注销。

收到 `WindowEvent.ThemeChanged` 后，模型只更新记录下来的系统外观；只有当前的选择是 Follow system 时，`apply()` 才会因此换主题。用户手动选了 Light 或 Dark，系统变化不会覆盖用户的选择。

在 macOS 的“系统设置 → 外观”中切换浅色和深色，选择了 Follow system 的窗口会随之变化。本书写作时示例以 Follow system 启动，按系统当前的浅色外观显示；为了不改动作者电脑的系统设置，切换系统外观的过程没有实际操作。

### 系统配色

macOS 上，`scoop.ui.style.macos` 还提供 `macosSystemPalette(mode)`：它读取系统在指定明暗外观下的语义颜色，**包括用户在系统设置中选的强调色**，返回一个普通的 `ThemePalette`。把它交给任意一套预设的 `palette` 参数：

```scoop
// The system palette is a snapshot: read it again every time the theme is rebuilt.
val palette = if (systemColors.value) Some(macosSystemPalette(resolved)) else None
```

预设拿到一份配色后，会用它生成文字和各部件的状态颜色，同时保留自己的几何形状和动效。所以系统配色和风格是两个独立的选择：Material 的胶囊按钮可以配上 macOS 的系统蓝。在示例中打开 System colors，选 Dark 和 Material：

<img src="../images/ch21/themes-system.png" width="500" alt="Material 深色外观配上系统配色：黑色背景上是 Theme gallery 标题，胶囊形按钮中被选中的 Material、Dark、System colors 和 Count: 1 都填充为系统的蓝色，未选中的按钮是深色描边、蓝色文字，下面是 Atlas 输入框">

Material 原本的紫色换成了系统的蓝色（作者的电脑使用默认的蓝色强调色），按钮的形状仍然是 Material 的。

几点说明：

- **它是一份快照。** `macosSystemPalette` 不注册任何监听，用户在系统设置中换了强调色，要由应用重新读取并发布新的主题。示例在每次 `apply()` 时都重新读取，系统明暗变化时也会走到这里。
- **只能在主线程调用**，在 UI 的回调和生命周期函数中调用即可。
- **只有 macOS 提供。** 这个函数只在 macOS 上编译，示例因此只能在 macOS 上构建。跨平台的应用需要把这部分代码放进只在 macOS 上编译的源码目录（Cone.toml 中带平台条件的 `[[sources]]`，见《Scoop 程序设计》第 28 章），在其他平台上使用预设配色。

## 21.6　显示偏好

系统的辅助功能设置中有几项会影响外观：增强对比度、减少透明度、减少动态效果，以及更大的文字。Scoop 把它们统称为显示偏好。

### 偏好怎样作用到主题上

`ThemeSource` 中保存的 `current` 是应用选择的**基础主题**；`read(scope)` 返回的是基础主题**加上这个窗口当前的偏好**之后的结果。内置的预设会这样处理偏好：

- **高对比度**：边框、次要文字等颜色变深，提高和背景的对比；
- **减少透明度**：半透明的颜色和阴影换成不透明的；
- **文字缩放**：按比例放大文字样式；
- **减少动画**：控件跳过过渡动画，直接呈现目标状态；第 17 章的滚动回弹也会关闭。

所以组件中应当总是用 `source.read(scope)` 读取主题，而不是直接读 `source.current.value`：后者是没有应用偏好的基础主题，自绘的背景会和标准控件对不上。`read(scope)` 在 `render()` 中调用时，会同时订阅主题和偏好的变化。

`theme.preferences` 是已经应用到这份主题上的偏好，类型是 `ThemePreferences`，有 `highContrast`、`reduceTransparency`、`reduceMotion` 和 `textScaleFactor` 四个字段。自己绘制的控件可以读取它，比如在 `reduceMotion` 为 true 时不播放动画。

### 覆盖系统的偏好

默认情况下，偏好跟随系统。`runUiApplication` 的 `preferences` 参数可以为这个窗口覆盖其中的一部分。保存为 `preferences.scoop`：

```scoop
{{#include ../../examples/ch21/preferences.scoop}}
```

```sh
scoop run preferences.scoop --release
```

`uiPreferences { ... }` 的每个字段默认是 `None`，表示跟随系统；赋一个 `Some(...)` 就覆盖它。示例打开了高对比度，并把文字放大到 1.25 倍。下面左边是去掉这两项覆盖之后的样子，右边是示例的样子：

<img src="../images/ch21/preferences-default.png" width="400" alt="没有覆盖偏好时的窗口：Display preferences 标题，灰色的 high contrast off · reduce transparency off · reduce motion off · text scale 1.0，下面是 Save、Cancel 按钮、勾选的 Remember me 复选框和一个输入框"> <img src="../images/ch21/preferences-override.png" width="400" alt="覆盖偏好之后的窗口：文字明显变大，状态行显示 high contrast on · text scale 1.25，Cancel 按钮、复选框和输入框的边框颜色更深，状态行的灰色文字也更深">

右边的文字更大，Cancel 按钮、复选框和输入框的边框更深，灰色的状态行文字也更深。状态行读的就是 `theme.preferences`。

`uiPreferences` 中还有几项和主题无关的字段：`autoHideScrollbars`（第 17.3 节）、`caretBlinkInterval`（光标闪烁的间隔，`Duration.ZERO` 表示常亮）、`caretWidthPixels` 等。

`runUiApplication` 只在启动时接收这些覆盖。需要在运行中修改，比如在应用的设置页面中提供“高对比度”开关，要用第 27 章的 `UiHost` 自己创建窗口，它返回的 `UiWindow` 有一个可以随时赋值的 `preferences` 属性；把某一项改回 `None`，就重新跟随系统。

覆盖偏好主要用于两种场合：应用自己提供辅助功能设置；在开发时预览大字号和高对比度下的界面，而不必修改系统设置。本书写作时，用后者核对了示例的效果。

### 自绘内容的对比度

在自己选的颜色上画文字时，`contrastThemeColors(pair, canvas, minimum = 7.0)` 按实际的底色调整一对颜色，使文字和背景的对比度至少达到 `minimum`；边框之类的图形可以用 3.0。第 31 章讨论无障碍时还会用到它。

## 常见误用

- **改了 `palette.primary`，以为按钮会跟着变。** 部件的颜色在预设创建时已经算好，同时配置用到它的部件，或者通过 `palette` 参数交给工厂函数，让预设重新生成。
- **只改 `typography.body`，以为按钮上的字也会变。** 按钮用的是 `action`。
- **直接读 `source.current.value` 来取页面颜色。** 那是没有应用显示偏好的基础主题，用 `source.read(scope)`。
- **在 `render()` 中调用 `currentThemeSource()`。** 它要在组件构造时（字段初始化中）调用，并且 `runUiApplication` 要位于 `context(source) { ... }` 之内，否则报缺少上下文。
- **同时导入 `scoop.window.*` 和 `scoop.ui.style.*`。** 两边都有 `Theme`，用 `import scoop.window.Theme as WindowTheme` 单独导入窗口的那个。
- **根 `frame` 没有铺底色。** 窗口的内容区会是黑色。用主题的 `palette.background` 铺上。
- **以为 `macosSystemPalette` 会自动更新。** 它是快照，系统颜色变化后要重新读取并发布主题。

## 小结

- 四套预设分别在四个 Cone 中，工厂函数都是 `xxxTheme(mode, palette) { ... }`，返回实现了 `Theme` 的 `ShapeTheme`。
- 主题分为 `tokens` 和部件两层；部件的颜色在创建时由 `tokens` 算出，之后单独改 `tokens` 不会影响部件；按钮的文字用 `typography.action`。
- 配置块在完整的预设上修改，嵌套块只改写到的字段；`copy { ... }` 从已有主题派生新主题，原主题不变。
- 给 `ThemeSource.current` 赋值即可切换主题，界面不重建，所有状态都保留；用户的选择和最终的主题分开保存。
- `observedTheme` 和 `ThemeChanged` 用于跟随系统明暗；macOS 上 `macosSystemPalette(mode)` 读取包括强调色在内的系统配色，可以配合任意一套预设。
- `read(scope)` 返回应用了显示偏好的主题；`runUiApplication` 的 `preferences` 参数覆盖系统的偏好，运行中修改要用 `UiWindow.preferences`。

## 练习

1. 在 `brand.scoop` 中把品牌色换成绿色，并让 `palette.primary` 和 `surfaces.action` 用同一个变量，确认两处一起变化。
2. 给 `brandTheme` 再加一个配置，把 `typography.action` 的字号也改为 15，比较按钮上的文字。
3. 在 `themes.scoop` 中加一个 Reduce motion 按钮，用 `copy { tokens { motion { preference = MotionPreference.Reduced } } }` 派生主题。打开后切换复选框，过渡动画还在吗？
4. 让 `themes.scoop` 记住用户的选择：退出时把预设和明暗写入一个文件，下次启动时读回来。哪些状态应该保存，哪些不需要？
5. 把 `preferences.scoop` 的 `textScaleFactor` 改为 `Some(1.5)`，再去掉 `highContrast`，看看哪些文字变大了，哪些没有。
