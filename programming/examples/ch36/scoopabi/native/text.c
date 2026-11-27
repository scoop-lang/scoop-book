#include <scoop_rt.h>

#include <stdint.h>

/* 直接读取 Scoop 字符串的 UTF-8 字节，不复制。
 * 调用期间不进入任何可能触发 GC 的操作，所以可以直接使用传入的引用。 */
int64_t text_count_upper(const ScoopString *text) {
    int64_t count = 0;
    for (uint64_t i = 0; i < text->len; i++) {
        unsigned char c = (unsigned char)text->data[i];
        if (c >= 'A' && c <= 'Z') count++;
    }
    return count;
}

/* 演示 native root：在可能触发 GC 的操作前后保住两个引用。
 * 这里用 scoop_runtime_gc_collect() 代表“任何可能触发 GC 的运行时调用”。 */
int64_t text_total_length(ScoopString *a, ScoopString *b) {
    void **slots[2] = {(void **)&a, (void **)&b};
    ScoopNativeRootFrame frame;
    scoop_rt_push_native_roots(&frame, slots, 2);

    scoop_runtime_gc_collect();   /* 之后 a、b 可能已经指向新地址 */

    int64_t total = (int64_t)(a->len + b->len);   /* 从 slot 重新读取 */
    scoop_rt_pop_native_roots(&frame);
    return total;
}
