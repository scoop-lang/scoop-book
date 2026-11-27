# 第 23 章　`scoop.std` 集合

第 22 章介绍了核心库中的顺序容器。其余的集合，包括 Map、Set、双端队列、优先队列，以及 `map`、`filter`、`groupBy`、`sorted` 这些集合操作和惰性的 `Sequence`，都由标准库 `scoop.std` 提供。

它们的名字和用法大多沿用 Kotlin：`HashMap`、`LinkedHashMap`、`mapOf`、`groupBy`、`sortedWith`……但有几处 Scoop 自己的规则需要特别注意：

- 键值对写成 tuple `("a", 1)`，没有 `to`；
- 作为 key 的类型必须**显式**实现相应的接口，struct 不会自动满足；
- 遍历 Map 和 Set 时修改它们会抛出异常；
- 没有 `sum`、`sortedByDescending` 等一部分 Kotlin 函数。

本章介绍：

- 怎样在单文件程序和 Cone 中使用 `scoop.std`；
- Map 和 Set 的基本操作；
- 无序、插入顺序和排序顺序三类实现；
- 对 key 的要求，以及 `Comparator`；
- `ArrayDeque` 和 `PriorityQueue`；
- 急切的集合操作；
- 惰性的 `Sequence`；
- 遍历时修改集合的规则。

## 23.1　使用 `scoop.std`

标准库是一个普通的库 Cone，坐标是 `scoop:scoop.std:0.1.0`。它包含好几个包，本章用到的是前三个：

| 包 | 内容 |
| --- | --- |
| `scoop.collections` | 集合接口与实现、工厂函数、集合操作 |
| `scoop.comparisons` | `Comparator` 与比较器组合 |
| `scoop.sequences` | 惰性序列 `Sequence` |
| `scoop.text` | 文本操作、数值解析（第 4 章） |
| `scoop` | `Result` 与 `Option` 的扩展函数（第 12、20 章） |
| `scoop.bytes`、`scoop.io.encoding`、`scoop.random`、`scoop.uuid`、`scoop.time`、`scoop.datetime` | 字节、编码、随机数、时间等（第 24 章） |

注意依赖的**坐标**（`scoop.std`）和代码中 import 的**包名**（`scoop.collections` 等）是两回事：一个 Cone 可以提供多个包，包名也不必以 Cone 的名字开头。

**单文件程序**默认就依赖标准库，直接 import 需要的包即可，前面各章的例子都是这样。

**Cone** 要在 `Cone.toml` 中声明依赖：

```toml
{{#include ../../examples/ch23/wordfreq/Cone.toml}}
```

`[dependencies]` 中的 `"scoop:scoop.std" = "0.1.0"` 就是标准库的依赖声明。`Cone.toml` 的其他字段见第 28 章。这个 Cone 的源码是一个词频统计程序，工具链附带的 `scoop example collections/map` 是它的简化版本：

```scoop
{{#include ../../examples/ch23/wordfreq/src/main.scoop}}
```

```sh
$ scoop run wordfreq --release
```

输出：

```text
{{#include ../../examples/ch23/wordfreq/expected.txt}}
```

`counts[word] ?: 0` 读取当前的计数，没有时从 0 开始；后面各节会解释用到的每一个函数。

## 23.2　Map

```scoop
{{#include ../../examples/ch23/maps.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/maps.expected}}
```

Map 的基本操作和 Kotlin 一致，区别主要在于“没有这个 key”用 `Option` 表示：

- **读取**：`stock["apple"]` 的类型是 `Int?`，key 不存在时为 `None`，通常配合 `?:` 使用。`"pear" in stock` 判断 key 是否存在，等同于 `containsKey`。
- **写入**：`stock["apple"] = 8` 放入或替换。`put` 做同样的事，并返回原来的值，原来没有时返回 `None`。
- **删除**：`remove` 返回被删除的值，key 不存在时返回 `None`。
- **缺失时的处理**：`getOrDefault(key, 默认值)`、`getOrElse(key) { 默认值 }` 在 key 不存在时给出默认值；`getValue` 在 key 不存在时抛出 `NoSuchElementException`。

另一个常用的函数是 `getOrPut`，它在 key 不存在时创建一个值放进去，然后返回这个值。按首字母给单词分组：

```scoop
{{#include ../../examples/ch23/get_or_put.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/get_or_put.expected}}
```

`getOrPut(首字母) { ArrayList<String>() }` 第一次遇到某个字母时创建一个空列表，之后返回同一个列表，`.add(word)` 直接往里面追加。

### 创建与遍历

```scoop
{{#include ../../examples/ch23/factories.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/factories.expected}}
```

**键值对写成 tuple**：`mapOf(("France", "Paris"), ...)`。Kotlin 的 `"France" to "Paris"` 在 Scoop 中不存在：

```scoop
{{#include ../../examples/ch23/to_fail.scoop}}
```

```text
{{#include ../../examples/ch23/to_fail.error}}
```

其他几点：

- **`mapOf` 创建只读的 Map，`mutableMapOf` 创建可修改的 Map**，两者都按放入的顺序遍历。`hashMapOf`、`linkedMapOf`、`sortedMapOf` 分别创建下一节介绍的三种具体实现。
- **遍历时每个条目是 `Map.Entry`**，它是一个有 `key` 和 `value` 两个字段的 struct，可以直接解构：`for ((country, city) in capitals)`。
- **`keys`、`values`、`entries` 是视图**，不是快照：`names` 是在加入 `bob` 之前取得的，但它能看到 `bob`。需要快照时调用 `toList()`。
- **tuple 的列表可以 `toMap()`**，同一个 key 出现多次时，最后一个值胜出。

## 23.3　Set

```scoop
{{#include ../../examples/ch23/sets.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/sets.expected}}
```

- `add` 返回 `Boolean`：真的加入了新元素时为 `true`，元素已经存在时为 `false`，并且不替换原来的元素。`remove` 同理。
- `in` 判断元素是否存在。
- `union`、`intersect`、`subtract` 是 `infix` 函数，分别求并集、交集和差集。结果保留左边集合的顺序，`union` 再把右边新出现的元素追加在后面。
- `toSet()` 去重，保留每个元素第一次出现的位置。
- `sortedSetOf` 创建排序的 Set，`firstOrNone`、`higher` 等查询在下一节介绍。

## 23.4　三种顺序

Map 和 Set 各有三种实现，区别在于**遍历顺序**和**判断“同一个 key”的方式**：

| 类别 | Map | Set | 遍历顺序 | 同一个 key 的判断 | 主要操作的开销 |
| --- | --- | --- | --- | --- | --- |
| 无序 | `HashMap` | `HashSet` | **不保证任何顺序** | `Equals` 和 `Hash` | 平均 O(1) |
| 插入顺序 | `LinkedHashMap` | `LinkedHashSet` | key 第一次放入的顺序 | `Equals` 和 `Hash` | 平均 O(1) |
| 排序 | `TreeMap` | `TreeSet` | 按比较器从小到大 | 比较结果为 0 | O(log n) |

```scoop
{{#include ../../examples/ch23/orders.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/orders.expected}}
```

**`HashMap` 不保证顺序。** 即使某次运行的输出看起来是有规律的，下次运行、换一个平台或者换一个版本都可能不同。所以本书中需要打印遍历结果的例子都用 `LinkedHashMap` 或 `TreeMap`。程序的输出依赖遍历顺序时，不要用 `HashMap`。

**`LinkedHashMap` 记住 key 第一次放入的顺序。** 更新已有 key 的值不改变它的位置，`banana` 仍然在最前面；删除后重新放入，就排到了最后，所以 `apple` 跑到了末尾。它没有 Kotlin 那种“按访问顺序”的模式，不能直接当作 LRU 缓存。`mapOf`、`mutableMapOf`、`setOf`、`toSet()` 等默认的工厂函数，以及后面的 `groupBy`、`distinct`，结果都是插入顺序的。

**`TreeMap` 按 key 从小到大遍历**，并且能按大小查找相邻的 key：

| 函数 | 结果 |
| --- | --- |
| `firstEntryOrNone()`、`lastEntryOrNone()` | 最小、最大的条目 |
| `floorEntry(k)`、`ceilingEntry(k)` | 不大于 `k` 的最大条目、不小于 `k` 的最小条目 |
| `lowerEntry(k)`、`higherEntry(k)` | 小于 `k` 的最大条目、大于 `k` 的最小条目 |
| `copyOfRange(from, to)` | 默认包含 `from`、不包含 `to` 的范围内的条目组成的新 Map |

找不到时都返回 `None`。`TreeSet` 有对应的 `firstOrNone`、`lastOrNone`、`floor`、`ceiling`、`lower`、`higher` 和 `copyOfRange`。

`TreeMap` 和 `TreeSet` 的构造器**必须**传入一个比较器（23.5）。按 key 的自然顺序排序时，用 `sortedMapOf()`、`sortedSetOf()` 创建，空的写成 `sortedMapOf<String, Int>()`。

## 23.5　对 key 的要求

### Hash 系列：`Equals` 和 `Hash`

`HashMap`、`HashSet` 及其 Linked 版本用 `equals` 判断两个 key 是否相同，用 `hash` 快速定位，所以 key 的类型必须实现 `Equals<K>` 和 `Hash` 两个接口。`String`、整数、`Char`、`Boolean` 都满足。struct 和 class 要**显式声明**实现这两个接口，第 8 章 8.7 节给出了完整的写法；只能用 `==` 比较是不够的：

```scoop
{{#include ../../examples/ch23/key_fail.scoop}}
```

```text
{{#include ../../examples/ch23/key_fail.error}}
```

`Float` 和 `Double` 没有实现 `Hash`（第 3 章），不能作为 Hash 系列的 key：

```scoop
{{#include ../../examples/ch23/double_key_fail.scoop}}
```

```text
{{#include ../../examples/ch23/double_key_fail.error}}
```

需要按浮点数查找时，可以用 `TreeMap`，它只需要比较，不需要哈希。

实现 `Equals` 和 `Hash` 时，有一条编译器无法检查的规则：**相等的两个 key 必须有相同的 hash，而且 key 放进容器之后，决定相等和 hash 的内容不能再改变。** 违反了它，容器就会“找不到”自己里面的元素：

```scoop
{{#include ../../examples/ch23/mutable_key.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/mutable_key.expected}}
```

`tag` 是以 `draft` 的 hash 放进去的。改名之后，用 `final` 查找，按新的 hash 找不到这个条目；用 `draft` 查找，hash 对得上，但 `equals` 比较的是已经变成 `final` 的名字，也不相等。条目还在（`size` 是 1），但再也取不出来了。所以 key 最好用 struct 这样的值类型，或者只用 `val` 字段计算 `equals` 和 `hash` 的 class。

### Tree 系列：`Compare` 或 `Comparator`

`TreeMap`、`TreeSet` 不需要 `Hash`，只需要比较。key 的类型实现了 `Compare<K>`（第 16 章）时，`sortedMapOf`、`sortedSetOf` 按它的自然顺序排序；没有实现时，这些工厂函数不能使用：

```scoop
{{#include ../../examples/ch23/tree_key_fail.scoop}}
```

```text
{{#include ../../examples/ch23/tree_key_fail.error}}
```

两条 `cause` 说明了 `sortedSetOf` 的两个重载为什么都不适用：一个要求第一个参数是比较器，另一个要求元素实现 `Compare`。这时可以给类型实现 `Compare`，也可以单独提供一个**比较器**。

### `Comparator`

`scoop.comparisons` 包中的 `Comparator<T>` 是一个接口，只有一个方法 `compare(left, right): Long`：负数表示 `left` 在前，正数表示 `right` 在前，0 表示两者相等。通常不需要自己实现它，而是用下面的函数组合出来：

```scoop
{{#include ../../examples/ch23/comparators.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/comparators.expected}}
```

| 函数 | 作用 |
| --- | --- |
| `compareBy { v -> 字段 }` | 按选出的字段比较，字段要实现 `Compare` |
| `c.thenBy { v -> 字段 }` | `c` 认为相等时，再按另一个字段比较 |
| `c.reversed()` | 反过来比较 |
| `naturalOrder<T>()`、`reverseOrder<T>()` | 按 `T` 的 `Compare` 正序、逆序 |
| `comparatorOf<T> { a, b -> ... }` | 用一个返回 `Long` 的函数作为比较器 |

比较器可以传给 `TreeMap`、`TreeSet`、`PriorityQueue` 的构造器，也可以传给 `sortedWith`、`minWithOrNone` 等集合操作。

注意例子中的 `byMajor`：**`TreeSet` 把比较结果为 0 的两个元素当作同一个元素**。`1.5` 和 `1.12` 的 `major` 相同，后加入的 `1.12` 被认为已经存在，没有加进去。用比较器建立 Tree 系列容器时，要确保它区分了所有你认为不同的元素。

`compareBy` 有两个类型参数，元素类型和字段类型。有期望类型时可以省略它们，比如 `val byMajor: Comparator<Version> = compareBy { ... }`，或者直接作为 `TreeSet<Version>(...)` 的参数；后面紧接着调用 `.thenBy`、`.reversed()` 时，编译器无法从后面推断，就要写成 `compareBy<Version, Int> { ... }`。

## 23.6　`ArrayDeque` 与 `PriorityQueue`

`ArrayDeque` 是双端队列，两端的插入和删除都是摊还 O(1)。Scoop 没有单独的 `Stack` 和 `Queue` 类，栈和队列都用它：

```scoop
{{#include ../../examples/ch23/deque.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/deque.expected}}
```

- `addFirst`、`addLast` 在两端加入；`removeFirst`、`removeLast` 在两端取出，队列为空时抛出 `NoSuchElementException`。
- 带 `OrNone` 的版本在队列为空时返回 `None`，配合 `?: break` 写循环很方便。
- `firstOrNone`、`lastOrNone` 只查看、不取出。

`PriorityQueue` 每次取出的都是**最小**的元素：

```scoop
{{#include ../../examples/ch23/priority.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/priority.expected}}
```

- `priorityQueueOf(...)` 按元素的自然顺序，要求元素实现 `Compare`。其他情况用 `PriorityQueue<T>(比较器)` 构造。想让“最大的先出来”，把比较器 `reversed()`。
- `peek` 查看、`removeFirst` 取出最小的元素，`add` 加入。加入和取出是 O(log n)。
- 优先级相同的元素，取出的先后顺序不保证与加入的顺序相同。
- 直接遍历 `PriorityQueue` 得到的顺序**不是**排好序的。要按顺序处理，就像例子这样逐个 `removeFirst`。

## 23.7　集合操作

第 7 章介绍过 `map`、`filter`、`fold`、`any`、`all`。`scoop.collections` 中还有一大批类似的函数，用法和 Kotlin 基本相同：

```scoop
{{#include ../../examples/ch23/operations.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/operations.expected}}
```

| 用途 | 函数 |
| --- | --- |
| 变换 | `map`、`mapIndexed`、`mapNotNone`、`flatMap`、`flatten` |
| 过滤 | `filter`、`filterNot`、`filterNotNone`、`partition` |
| 归约 | `fold`、`reduce`、`reduceOrNone`、`count` |
| 判断 | `any`、`all`、`none`、`in`（即 `contains`） |
| 查找 | `find`、`first`/`firstOrNone`、`last`/`lastOrNone`、`single`/`singleOrNone`、`indexOf` |
| 极值 | `minOrNone`、`maxOrNone`、`minWithOrNone`、`maxWithOrNone` |
| 截取 | `take`、`drop`、`takeWhile`、`dropWhile`、`reversed` |
| 组合 | `zip`、`withIndex`、`chunked`、`windowed` |
| 分组与去重 | `groupBy`、`associate`、`associateBy`、`associateWith`、`distinct`、`distinctBy` |
| 排序 | `sorted`、`sortedDescending`、`sortedBy`、`sortedWith`，原地的 `sort`、`sortWith`（第 22 章），`binarySearch` |
| 输出 | `joinToString`、`toList`、`toSet`、`toMap`、`mapTo`、`filterTo` |

使用时要注意的几点：

- **它们都是急切的，返回新的集合。** `map`、`filter` 等立即遍历全部元素，返回一个新的只读 `List`，原来的集合不变。下标、计数类的参数和结果都是 `Long`，比如 `take(2L)`、`chunked(2L)`，`count` 返回 `Long`。
- **对元素有要求的函数会写在约束里。** `in`、`indexOf`、`distinct` 要求元素实现 `Equals`（`distinct`、`groupBy` 的 key 还要实现 `Hash`）；`sorted`、`maxOrNone` 要求实现 `Compare`；不带 `transform` 参数的 `joinToString` 要求元素实现 `ToString`。元素不满足时，用 `sortedWith(比较器)`、`maxWithOrNone(比较器)`、`joinToString { e -> ... }` 这些带函数参数的版本。
- **可能为空的查找有 `OrNone` 版本。** `first`、`single`、`reduce` 在没有结果时抛出 `NoSuchElementException`；`firstOrNone`、`singleOrNone`、`reduceOrNone` 返回 `None`。`minOrNone`、`maxOrNone` 只有 `OrNone` 版本。
- **排序是稳定的**：比较结果相等的元素保持原来的先后顺序。23.1 的词频统计就利用了这一点。
- **结果的顺序**：`groupBy` 按 key 第一次出现的顺序排列各组，组内保持原来的顺序；`associateBy` 遇到重复的 key 时，后面的覆盖前面的，所以 `book` 对应的是 `cy` 的订单。

Kotlin 中有几个常用的函数在 Scoop 中不存在：

- `sum()`、`sumOf { }`、`average()`：用 `fold`，比如 `list.fold(0) { sum, o -> sum + o.amount }`；
- `sortedByDescending { }`：用 `sortedWith(compareBy { ... }.reversed())`；
- `maxBy { }`、`minBy { }`：用 `maxWithOrNone(compareBy { ... })`；
- `"a" to 1`：用 tuple `("a", 1)`。

## 23.8　`Sequence`：惰性求值

集合操作是急切的：每一步都完整地遍历输入，生成一个新列表，再交给下一步。`Sequence` 是惰性的：中间步骤只记录“要做什么”，等到最后需要结果时，才让元素**一个一个**地流过整条处理链。

```scoop
{{#include ../../examples/ch23/sequences.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/sequences.expected}}
```

对比两段输出：

- **急切的版本**先对 5 个单词全部计算长度，生成一个列表；再过滤；最后取第一个。
- **惰性的版本**在 `toList()` 之前什么都没有计算。开始取结果时，`apple` 计算出长度 5，通过了过滤，`take(1L)` 已经满足，后面的单词就不再处理了。

`Sequence` 在 `scoop.sequences` 包中，取得方式有：

- `iterable.asSequence()`：把已有的集合变成序列；
- `sequenceOf(a, b, c)`、`emptySequence()`；
- `generateSequence(初值) { 上一个 -> 下一个 }`：返回 `None` 时序列结束，一直返回 `Some` 就是一个无限序列；
- `iterator.asSequence()`：把一个迭代器包装成序列。

`Sequence` 支持 23.7 中的大部分操作。`map`、`filter`、`take` 这类中间操作返回新的 `Sequence`，不做任何计算；`toList`、`joinToString`、`count`、`first` 这类终结操作才真正遍历。

什么时候用 `Sequence`：

- 处理链很长、数据量大，而且后面有 `take`、`first`、`any` 这样能提前结束的操作；
- 数据是无限的，或者是逐个生成的；
- 不想为中间结果分配一个个新列表。

数据量不大、每一步都要处理全部元素时，直接用集合操作更简单，也不一定更慢。注意并不是所有序列操作都只占用很少的内存：`sorted` 要先收集全部元素才能排序，`groupBy`、`toList` 要读完全部元素才能返回，它们都不能用于无限序列；`distinct` 可以用于无限序列，但要记住所有见过的元素。

还要注意序列能不能**重复遍历**：

```scoop
{{#include ../../examples/ch23/once.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/once.expected}}
```

从集合得到的序列每次遍历都重新读取集合，可以重复使用；从迭代器得到的序列只能遍历一次，第二次遍历会抛出 `IllegalStateException`，因为迭代器已经走到了头。不带初值的 `generateSequence { ... }` 也只能遍历一次。需要多次使用一个只能遍历一次的序列时，先 `toList()` 保存下来。

> **从 Kotlin 过来**
>
> Kotlin 的 `sequence { yield(...) }` 生成器在 Scoop 中没有对应物，异步的 `Flow` 也不在标准库中。需要按需生成元素时，用 `generateSequence`，或者自己实现 `Sequence` 接口和 `Iterator` 接口：后者只有一个 `next(): T?` 方法，返回 `None` 表示结束，比 Kotlin 的 `hasNext` 加 `next` 简单。

## 23.9　遍历时修改

第 22 章讲过，遍历 `ArrayList` 时修改它不会报错。Map、Set、`ArrayDeque` 和 `PriorityQueue` 的规则不同：迭代器创建之后，容器发生了**结构修改**（增加或删除元素），这个迭代器的下一次 `next` 就会抛出 `ConcurrentModificationException`。

```scoop
{{#include ../../examples/ch23/modification.scoop}}
```

输出：

```text
{{#include ../../examples/ch23/modification.expected}}
```

- **替换已有 key 的值不算结构修改**，遍历中可以做，第一个循环把所有计数加了 1。
- **增加或删除 key 是结构修改**。第二个循环删除 `apple` 之后，下一次取元素时抛出了异常。注意异常之前的那次删除已经生效了，集合不会回滚。
- 常用的写法是**先收集、再修改**：先用 `filter`、`map` 得到要删除的 key 的列表（这是一个独立的快照），再遍历这个列表逐个删除。

这个检查只是为了在单线程中尽早发现错误，**不是**线程安全的保证。多个线程同时访问同一个集合，仍然需要自己同步（第 27 章）。

## 从 Kotlin 过来：常见写法对照

| Kotlin | Scoop |
| --- | --- |
| `mapOf("a" to 1, "b" to 2)` | `mapOf(("a", 1), ("b", 2))` |
| `map["a"]`（类型 `Int?`） | 相同，类型是 `Int?`，即 `Option<Int>` |
| `for ((k, v) in map)` | 相同 |
| `map.getOrPut(k) { ... }` | 相同 |
| `HashMap` 的遍历顺序 | 同样不保证；需要顺序时用 `LinkedHashMap` 或 `TreeMap` |
| `TreeMap<String, Int>()` | `sortedMapOf<String, Int>()`，或 `TreeMap<String, Int>(naturalOrder())` |
| `data class` 直接作为 key | struct 要显式实现 `Equals<T>` 和 `Hash`（第 8 章） |
| `Comparable<T>`、`Comparator<T>` | `Compare<T>`、`scoop.comparisons.Comparator<T>`，比较结果是 `Long` |
| `compareBy<V> { it.major }` | `compareBy<Version, Int> { v -> v.major }`，或在有期望类型时省略类型参数 |
| `list.sum()`、`sumOf { }` | `fold(0) { acc, v -> acc + v }` |
| `sortedByDescending { }` | `sortedWith(compareBy { ... }.reversed())` |
| `maxBy { }`、`maxByOrNull { }` | `maxWithOrNone(compareBy { ... })` |
| `firstOrNull`、`singleOrNull` | `firstOrNone`、`singleOrNone` |
| `Stack`、`LinkedList` 当队列用 | `ArrayDeque` |
| `PriorityQueue` | 相同；自然顺序用 `priorityQueueOf(...)` |
| `LinkedHashMap(16, 0.75f, true)`（LRU） | 没有访问顺序模式 |
| `sequence { yield(x) }` | 不存在；用 `generateSequence` 或自己实现 `Sequence` |

## 常见误用

- **用 `to` 构造键值对**：写成 tuple `("a", 1)`。
- **依赖 `HashMap`、`HashSet` 的遍历顺序**：它们不保证顺序。
- **用没有实现 `Equals` 和 `Hash` 的 struct 作为 key**：显式实现这两个接口。
- **用 `Double` 作为 Hash 系列的 key**：它没有 `Hash`；考虑 `TreeMap`，或者换成整数（比如以“分”为单位保存金额）。
- **修改已经放进容器的 key**：容器会找不到它。
- **用比较器建立 `TreeSet` 时没有区分所有不同的元素**：比较结果为 0 的元素会被当作同一个。
- **`TreeMap<K, V>()` 不传比较器**：构造器必须传；按自然顺序用 `sortedMapOf()`。
- **找 `sum`、`sortedByDescending`**：用 `fold`、`sortedWith(...reversed())`。
- **遍历 Map 或 Set 时增删元素**：先收集要修改的 key，再修改。
- **对无限序列使用 `sorted`、`toList`**：它们要读完全部元素，程序不会结束。
- **重复遍历从迭代器得到的序列**：第二次会抛出异常，先 `toList()`。

## 小结

- `scoop.std` 提供 Map、Set、Deque、优先队列、集合操作和 `Sequence`。单文件程序默认可用，Cone 要在 `Cone.toml` 中声明 `"scoop:scoop.std" = "0.1.0"`，代码中 import `scoop.collections`、`scoop.comparisons`、`scoop.sequences` 等包。
- Map 的读取返回 `Option`；`put`、`remove` 返回原来的值；键值对写成 tuple。`keys`、`values`、`entries` 是视图。
- Hash 系列不保证顺序，Linked 系列保持插入顺序，Tree 系列按比较器排序并支持相邻查找。默认工厂函数的结果都是插入顺序。
- Hash 系列的 key 要实现 `Equals` 和 `Hash`，Tree 系列的 key 要实现 `Compare` 或提供 `Comparator`；key 放进容器后不能再改变。
- `ArrayDeque` 用作栈和队列，`PriorityQueue` 每次取出最小的元素。
- 集合操作是急切的，返回新集合；`Sequence` 是惰性的，适合长处理链、提前结束和无限数据。
- 遍历 Map、Set 时增删元素会抛出 `ConcurrentModificationException`。

## 练习

1. 改进 23.1 的词频统计：忽略大小写（提示：第 4 章的 `lowercaseAscii()`），并只输出出现次数最多的前 5 个单词。
2. 有一组 `(学生, 课程, 分数)` 的 tuple，用 `groupBy` 计算每门课的平均分（用 `fold` 求和），按平均分从高到低输出。
3. 用 `TreeMap<Int, String>` 实现一个成绩等级表：90 分以上为 A，80 分以上为 B，以此类推。给定一个分数，用 `floorEntry` 查出它的等级。
4. 用 `ArrayDeque` 实现二叉树的层序遍历（用 class 表示树节点）。
5. 用 `generateSequence` 生成斐波那契数列，求第一个超过 1000 的数。提示：序列的元素可以是 tuple `(Long, Long)`。
