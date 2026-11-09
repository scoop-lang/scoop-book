#ifndef TALLY_H
#define TALLY_H

#include <stdint.h>

typedef struct Tally Tally;

typedef struct {
    int64_t count;
    double min;
    double max;
    double sum;
} TallySummary;

Tally *tally_new(void);
void tally_add(Tally *tally, double value);
TallySummary tally_summary(const Tally *tally);
/* 没有数据时返回 0；否则把标准差写入 *out 并返回 1 */
int32_t tally_stddev(const Tally *tally, double *out);
void tally_free(Tally *tally);

#endif
