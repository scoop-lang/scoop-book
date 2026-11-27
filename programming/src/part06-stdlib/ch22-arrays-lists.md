# 第 22 章　数组与列表

前面的章节已经用过不少数组和列表：`[90, 75, 60]` 这样的字面量，`ArrayList` 的 `add`，`for` 循环遍历，`map`、`filter`、`fold`。本章把这些内容系统地整理一遍。

Scoop 的顺序容器分成两层：

- **核心库**提供三种具体的容器 `Array`、`MutableArray`、`ArrayList`，以及描述它们共同能力的接口 `List`、`MutableList`。它们默认可用，不需要 import。
- **标准库 `scoop.std`** 在 `scoop.collections` 包中提供 `listOf`、`isEmpty`、`contains`、`sorted`、`joinToString` 等工厂函数和扩展函数，使用时要 `import scoop.collections.*`。第 23 章会完整介绍它们。

本章介绍：

- 三种容器各自的特点和选择方法；
- 数组字面量的类型规则；
- 按长度创建数组；
- 遍历、下标与越界；
- `Array` 和 `MutableArray` 之间的转换，以及快照语义；
- `List`、`MutableList` 接口：只读不等于不可变。

## 22.1　三种容器

```scoop
{{#include ../../examples/ch22/containers.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/containers.expected}}
```

| 容器 | 长度 | 元素 | 相当于 Kotlin 的 |
| --- | --- | --- | --- |
| `Array<T>` | 固定 | 只读 | 没有直接对应；最接近 `List<T>` 的只读用法 |
| `MutableArray<T>` | 固定 | 可写 | `Array<T>`、`IntArray` |
| `ArrayList<T>` | 可变 | 可写，可增删 | `ArrayList<T>`、`MutableList<T>` |

三者有几个共同点：

- **都是引用类型。** 把一个数组赋给另一个变量，或者传给函数，两边指向同一个对象（第 6 章）。
- **大小和下标都是 `Long`。** `size` 的类型是 `Long`，下标要写 `primes[0L]`（第 3 章）。
- **都能用 `for` 遍历，都实现了 `List<T>` 接口**（22.6）。
- **值类型的元素不装箱，连续存放。** `Array<Int>` 中的每个元素就是一个 `Int`，不像 Kotlin 那样要区分 `Array<Int>` 和 `IntArray`。struct 元素也是这样（第 8 章的“深入一点”）。

`ArrayList` 的几个基本操作：`add(value)` 追加到末尾，`add(index, value)` 插入到指定位置，`removeAt(index)` 删除并返回指定位置的元素，`list[i] = v` 替换元素，`clear()` 清空。例子中 `add(0L, "Alan")` 把 `Alan` 插到最前面，`removeAt(1L)` 删掉的是原来排在第一位的 `Ada`。

怎样选择：

- 元素数量确定、创建后不再修改，用 `Array`。这是最常见的情况，也是数组字面量的默认类型。
- 数量确定、但要原地改写元素（计数器、缓冲区、网格），用 `MutableArray`。
- 数量会变化，用 `ArrayList`。

## 22.2　数组字面量

`[a, b, c]` 是数组字面量。它构造 `Array` 还是 `MutableArray`、元素是什么类型，由元素和**期望类型**共同决定：

```scoop
{{#include ../../examples/ch22/literals.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/literals.expected}}
```

规则如下：

- **没有期望类型时，构造 `Array`。** 要得到 `MutableArray`，给变量写上类型，或者把字面量传给类型是 `MutableArray` 的参数。期望类型是 `List<String>` 这样的接口时，也构造 `Array`。
- **空字面量 `[]` 必须有期望类型**，否则编译器无从知道元素类型。
- **值类型元素的类型必须完全相同。** `[1, "Ada", true]` 不能编译，Scoop 不会把它推断成 `Array<Any>`。整数字面量是个例外：`[1, 2L, 3]` 中的 `1` 和 `3` 会按 `2L` 统一成 `Long`，得到 `Array<Long>`。
- **引用类型元素取共同的父类型。** `Square` 和 `Rect` 都实现了 `Shape`，所以 `[Square(2.0), Rect(2.0, 1.5)]` 的类型是 `Array<Shape>`。
- **值类型元素不会自动装箱。** 把 struct `Dot` 放进 `Array<Shape>`，要显式写 `Dot(0, 0) as Shape`。这是为了保证数组元素的内存布局是确定的：`Array<Dot>` 中的元素连续存放，`Array<Shape>` 中存放的是引用，两者不能悄悄地互相替代。
- 字面量的最后一个元素后面**不能**有逗号。

几个常见的错误：

```scoop
{{#include ../../examples/ch22/empty_fail.scoop}}
```

```text
{{#include ../../examples/ch22/empty_fail.error}}
```

```scoop
{{#include ../../examples/ch22/mixed_fail.scoop}}
```

```text
{{#include ../../examples/ch22/mixed_fail.error}}
```

```scoop
{{#include ../../examples/ch22/box_fail.scoop}}
```

```text
{{#include ../../examples/ch22/box_fail.error}}
```

需要“一行里放几种不同类型的值”时，应该用 tuple（第 9 章）或者 struct，而不是数组。

`Array` 的元素是只读的，下标赋值会被拒绝：

```scoop
{{#include ../../examples/ch22/array_set_fail.scoop}}
```

```text
{{#include ../../examples/ch22/array_set_fail.error}}
```

## 22.3　按长度创建

元素个数在运行时才知道时，用 `Array` 或 `MutableArray` 的构造器，传入长度和一个初始化函数：

```scoop
{{#include ../../examples/ch22/sized.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/sized.expected}}
```

- `Array<Long>(5L) { i -> i * i }` 对下标 `0L` 到 `4L` 依次调用 lambda 一次，用返回值作为元素。下标 `i` 的类型是 `Long`。
- 所有元素都必须有一个合法的值。Scoop 没有 Kotlin 的 `IntArray(4)` 那种“自动填零”的构造器，也没有 `arrayOfNulls`：需要全零就写 `{ 0 }`，需要“空位”就让元素类型是 `Option`，用 `{ None }` 填充。
- 长度为负数时抛出 `IllegalArgumentException`。

## 22.4　遍历与下标

```scoop
{{#include ../../examples/ch22/iterate.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/iterate.expected}}
```

- 只需要元素时，直接 `for (word in words)`。
- 需要下标时，用 `0L until words.size` 这个 `Long` 区间（第 5 章）。Kotlin 的 `indices` 和 `lastIndex` 在 Scoop 中不存在，最后一个下标写 `words.size - 1L`。
- `withIndex()` 同时给出下标和元素，配合解构写成 `for ((i, word) in ...)`。它来自 `scoop.collections`，所以文件开头要 import。
- 下标越界时抛出 `IndexOutOfBoundsException`。

## 22.5　转换与快照

`Array<T>` 和 `MutableArray<T>` 之间**没有**父子类型关系，`MutableArray<Int>` 不能当作 `Array<Int>` 使用，反过来也不行。两者之间要显式转换：

```scoop
{{#include ../../examples/ch22/conversion.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/conversion.expected}}
```

- `toMutableArray()`、`toArray()`，或者以另一种数组为参数的构造器 `MutableArray(frozen)`、`Array(editable)`，**每次都创建一个新的数组**，复制当时的全部元素。之后修改其中一个，另一个不受影响：`frozen` 是在 `editable[1L] = 200` 之前创建的，所以 `frozen[1L]` 还是 `2`。
- 复制是**浅的**：值类型元素复制值，引用类型元素复制引用。`builders` 和 `copy` 是两个数组，但它们的第一个元素是同一个 `StringBuilder`，这和第 8 章 struct 的浅复制是同一个道理。

`ArrayList` 也有 `toArray()` 和 `toMutableArray()`，同样返回独立的快照：

```scoop
{{#include ../../examples/ch22/snapshot.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/snapshot.expected}}
```

工具链附带的 `scoop example collections/list` 和这个例子相同。快照常用于把一个正在构建的列表“定型”：先用 `ArrayList` 收集数据，收集完成后 `toArray()`，把结果作为不再变化的 `Array` 交出去。

## 22.6　`List` 与 `MutableList`

核心库用两个接口描述顺序容器的能力：

- `List<T>`：有 `size`，能用下标读取，能遍历；
- `MutableList<T>`：在 `List<T>` 的基础上，能写入、追加、插入、删除和清空。

`Array` 和 `MutableArray` 实现了 `List`，`ArrayList` 实现了 `MutableList`。`MutableArray` 虽然可写，但长度固定，不能 `add` 和 `removeAt`，所以它**不是** `MutableList`。

函数参数写成 `List<T>`，就能同时接受三种容器：

```scoop
{{#include ../../examples/ch22/list_interface.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/list_interface.expected}}
```

**`List` 是只读的，但不是不可变的。** `List<Int>` 只说明“通过这个变量不能修改”，不说明“没有人能修改”。`view` 和 `growable` 指向同一个 `ArrayList`，通过 `growable` 追加的元素，`view` 也能看到。需要一份不会再变化的数据时，取快照：`toList()` 返回一个独立的只读列表，`toArray()` 返回一个独立的 `Array`。

`listOf(...)` 和 `toList()` 一样，创建一个独立的只读列表，它没有 `add` 方法：

```scoop
{{#include ../../examples/ch22/list_add_fail.scoop}}
```

```text
{{#include ../../examples/ch22/list_add_fail.error}}
```

要可以增删的列表，用 `ArrayList<String>()`，或者 `scoop.collections` 中的 `mutableListOf(...)`、`arrayListOf(...)`。

`MutableArray` 不是 `MutableList` 这一点，在排序时最容易碰到：标准库的原地排序 `sort()` 定义在 `MutableList` 上，不能用于 `MutableArray`：

```scoop
{{#include ../../examples/ch22/array_sort_fail.scoop}}
```

```text
{{#include ../../examples/ch22/array_sort_fail.error}}
```

可以用 `sorted()` 得到一个排好序的新列表，或者转成 `ArrayList` 再原地排序：

```scoop
{{#include ../../examples/ch22/sorting.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/sorting.expected}}
```

另外，泛型是不变的（第 17 章）：即使 `Square` 实现了 `Shape`，`List<Square>` 也不是 `List<Shape>`。

### 列表不能直接比较和打印

数组和列表都没有实现 `Equals` 和 `ToString`，所以不能用 `==` 比较内容，也不能直接 `println`：

```scoop
{{#include ../../examples/ch22/array_eq_fail.scoop}}
```

```text
{{#include ../../examples/ch22/array_eq_fail.error}}
```

原因是 `List<T>` 对 `T` 没有任何要求，而“比较两个列表”需要元素能比较，“打印列表”需要元素能打印。打印时用 `joinToString()` 把元素拼成字符串（前面的例子一直在这样做）；比较内容时，可以自己写一个要求 `T : Equals<T>` 的函数：

```scoop
{{#include ../../examples/ch22/same_elements.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/same_elements.expected}}
```

`zip` 把两个列表按位置配成 tuple 的列表，`all` 检查是否每一对都相等，lambda 的参数 `(x, y)` 是第 10 章的解构写法。

### 按值删除

`ArrayList` 只有按下标删除的 `removeAt`，没有 Kotlin 的 `remove(element)`：

```scoop
{{#include ../../examples/ch22/remove_fail.scoop}}
```

```text
{{#include ../../examples/ch22/remove_fail.error}}
```

按值删除要先找到下标，或者使用 `scoop.collections` 的 `removeAll`：

```scoop
{{#include ../../examples/ch22/remove_value.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/remove_value.expected}}
```

`indexOf` 找不到时返回 `-1L`。`indexOf`、`removeAll` 和 `in` 都要比较元素，所以要求元素类型实现 `Equals`。

### 遍历时修改

遍历 `Array`、`MutableArray` 和 `ArrayList` 时，迭代器每一步都按下标读取当时的内容，**不会**因为列表在遍历中被修改而抛出异常：

```scoop
{{#include ../../examples/ch22/modify_loop.scoop}}
```

输出：

```text
{{#include ../../examples/ch22/modify_loop.expected}}
```

遍历中追加的 `next` 也被遍历到了。追加是安全的，可以用来实现简单的工作队列；但在遍历中插入或删除元素，可能导致某些元素被跳过或者遍历两次，应该避免。第 23 章的 Map 和 Set 规则不同，它们在遍历中被修改时会抛出 `ConcurrentModificationException`。

> **深入一点：`ArrayList` 的容量**
>
> `ArrayList` 内部用一个比当前元素多一些的数组保存元素，多出来的部分叫**容量**。追加时如果容量还够，直接写入下一个位置；不够时分配一个更大的数组，把已有元素复制过去。因为每次扩容都会成倍增加容量，平均下来每次追加的开销是常数，称为“摊还 O(1)”。
>
> 下标读写是 O(1)；在中间插入或删除要移动后面的所有元素，是 O(n)；`clear` 也是 O(n)，因为要清掉已删除元素的引用，让 GC 能回收它们。如果事先知道大约要放多少元素，可以写 `ArrayList<String>(1000L)` 预留容量，避免多次扩容。预留的容量不是元素，`size` 仍然是 0。
>
> 和数组一样，`ArrayList<Point>` 中的 struct 元素直接存放在内部数组里，不会逐个装箱（第 37 章）。

## 从 Kotlin 过来：常见写法对照

| Kotlin | Scoop |
| --- | --- |
| `arrayOf(1, 2, 3)`、`listOf(1, 2, 3)` | `[1, 2, 3]`；也可以 `listOf(1, 2, 3)`（`import scoop.collections.*`） |
| `IntArray(4)` | `MutableArray<Int>(4L) { 0 }` |
| `arrayOfNulls<String>(3)` | `MutableArray<String?>(3L) { None }` |
| `Array(5) { it * it }` | `Array<Long>(5L) { i -> i * i }`，下标是 `Long` |
| `list.size`（`Int`）、`list[0]` | `list.size`（`Long`）、`list[0L]` |
| `list.indices`、`list.lastIndex` | `0L until list.size`、`list.size - 1L` |
| `mutableListOf<String>()` | `ArrayList<String>()`，或 `mutableListOf<String>()`（需要 import） |
| `list.isEmpty()`、`x in list` | 相同，需要 `import scoop.collections.*`；`in` 还要求元素实现 `Equals` |
| `list.remove(x)` | `indexOf` 加 `removeAt`，或 `removeAll(listOf(x))` |
| `list.sum()`、`list.sumOf { }` | 不存在；用 `fold(0) { acc, v -> acc + v }` |
| `array.sort()` | `MutableArray` 不能原地排序；用 `sorted()`，或者换成 `ArrayList` 再 `sort()` |
| `list.toTypedArray()` | `list.toArray()` |
| `a == b`、`a.contentEquals(b)` | 不能直接比较；自己写比较函数（22.6） |
| `println(list)`、`a.contentToString()` | `println(list.joinToString())` |
| `ConcurrentModificationException`（`ArrayList`） | `ArrayList` 不检查；Map 和 Set 会检查（第 23 章） |
| `IntArray` 与 `Array<Int>` 的区别 | 不存在；`Array<Int>` 的元素就不装箱 |

## 常见误用

- **下标写成 `Int`**：`list[0]` 要写成 `list[0L]`，`for (i in 0 until list.size)` 要写成 `0L until list.size`。
- **以为 `MutableArray` 能增删元素**：它的长度是固定的，需要增删就用 `ArrayList`。
- **对 `MutableArray` 调用 `sort()`**：它不是 `MutableList`。
- **以为 `List` 是不可变的**：它只是只读视图，原来的 `ArrayList` 被修改后，视图也会变。需要固定的内容时取快照。
- **以为 `toArray()`、`toMutableArray()` 会深度复制**：只复制一层，引用类型的元素仍是同一个对象。
- **空字面量 `[]` 没有期望类型**：给变量写上类型。
- **把不同类型的值放进同一个数组**：值类型不会合并成 `Any`，用 tuple 或 struct。
- **把 struct 直接放进接口类型的数组**：要显式写 `as 接口`。
- **找不到 `isEmpty`、`contains`、`joinToString`**：它们在 `scoop.collections` 中，需要 import。
- **用 `==` 比较或直接打印数组**：用 `joinToString()` 打印，自己写函数比较内容。

## 小结

- `Array` 长度固定、元素只读；`MutableArray` 长度固定、元素可写；`ArrayList` 可以增删。它们都在核心库中，都是引用类型，`size` 和下标都是 `Long`，值类型元素不装箱。
- 数组字面量默认构造 `Array`，有期望类型时可以构造 `MutableArray`；值类型元素类型必须相同，不会自动装箱；空字面量需要期望类型。
- `Array<T>(size) { i -> ... }` 按长度创建数组，每个元素都必须有值。
- `Array` 和 `MutableArray` 之间没有子类型关系，转换总是创建新数组；`toArray()`、`toList()` 等快照都是浅复制。
- `List` 是只读接口，`MutableList` 能增删；`MutableArray` 只实现 `List`。只读不等于不可变。
- 列表不能直接比较、打印；按值删除、`isEmpty`、`contains`、排序等操作来自 `scoop.collections`，第 23 章会继续介绍。

## 练习

1. 写一个函数 `histogram(scores: List<Int>): MutableArray<Int>`，统计 0～100 分的成绩分别落在 0～9、10～19……90～100 这 10 个区间的人数。
2. 写一个函数 `transpose(grid: Array<Array<Int>>): Array<Array<Int>>`，把一个矩形的二维数组转置。用 22.3 的按长度构造来创建结果。
3. 用 `ArrayList` 实现一个简单的“撤销栈”：`push` 把一个字符串压入，`pop` 弹出最后压入的字符串，栈为空时返回 `None`。
4. 下面的代码想把所有负数从列表中删掉，它的结果对吗？为什么？改正它。

```scoop
{{#include ../../examples/ch22/exercise_remove.scoop:remove}}
```
