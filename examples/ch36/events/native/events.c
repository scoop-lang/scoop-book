#include "events.h"

#include <pthread.h>
#include <stdlib.h>

void events_each_prime(int32_t limit, events_value_fn fn, void *context) {
    for (int32_t n = 2; n <= limit; n++) {
        int prime = 1;
        for (int32_t d = 2; d * d <= n; d++) {
            if (n % d == 0) { prime = 0; break; }
        }
        if (prime) fn(context, n);
    }
}

struct EventsTicker {
    pthread_t thread;
    int32_t count;
    events_value_fn fn;
    void *context;
};

static void *ticker_main(void *arg) {
    EventsTicker *ticker = arg;
    for (int32_t i = 1; i <= ticker->count; i++) ticker->fn(ticker->context, i);
    return NULL;
}

EventsTicker *events_ticker_start(int32_t count, events_value_fn fn, void *context) {
    EventsTicker *ticker = malloc(sizeof(EventsTicker));
    if (ticker == NULL) return NULL;
    ticker->count = count;
    ticker->fn = fn;
    ticker->context = context;
    if (pthread_create(&ticker->thread, NULL, ticker_main, ticker) != 0) {
        free(ticker);
        return NULL;
    }
    return ticker;
}

void events_ticker_join(EventsTicker *ticker) {
    pthread_join(ticker->thread, NULL);
    free(ticker);
}
