#include "tally.h"

#include <math.h>
#include <stdlib.h>

struct Tally {
    TallySummary summary;
    double sum_of_squares;
};

Tally *tally_new(void) {
    return calloc(1, sizeof(Tally));
}

void tally_add(Tally *tally, double value) {
    TallySummary *s = &tally->summary;
    if (s->count == 0 || value < s->min) s->min = value;
    if (s->count == 0 || value > s->max) s->max = value;
    s->count += 1;
    s->sum += value;
    tally->sum_of_squares += value * value;
}

TallySummary tally_summary(const Tally *tally) {
    return tally->summary;
}

int32_t tally_stddev(const Tally *tally, double *out) {
    const TallySummary *s = &tally->summary;
    if (s->count == 0) return 0;
    double mean = s->sum / (double)s->count;
    *out = sqrt(tally->sum_of_squares / (double)s->count - mean * mean);
    return 1;
}

void tally_free(Tally *tally) {
    free(tally);
}
