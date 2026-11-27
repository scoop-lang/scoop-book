#ifndef EVENTS_H
#define EVENTS_H

#include <stdint.h>

/* 回调的第一个参数是调用方传入的 context，C 库只负责原样传回 */
typedef void (*events_value_fn)(void *context, int32_t value);

/* 同步：在返回之前，对 [1, limit] 中的每个质数调用一次 fn */
void events_each_prime(int32_t limit, events_value_fn fn, void *context);

/* 异步：启动一个后台线程，依次以 1..count 调用 fn */
typedef struct EventsTicker EventsTicker;
EventsTicker *events_ticker_start(int32_t count, events_value_fn fn, void *context);
/* 等待后台线程结束并释放 ticker */
void events_ticker_join(EventsTicker *ticker);

#endif
