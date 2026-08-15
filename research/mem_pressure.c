#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
/* 内存压力工具: 分配并触碰内存 → 触发内核 shrinker + compaction (免 root 清 slab) */
int main(void) {
    size_t total = 0, chunk = 256UL*1024*1024;
    char *ptrs[16]; int n = 0;
    while (total < 2000UL*1024*1024 && n < 16) {
        char *p = malloc(chunk);
        if (!p) break;
        memset(p, 0x41, chunk); /* 触碰所有页 */
        ptrs[n++] = p; total += chunk;
        fprintf(stderr, "alloc %zu MB\n", total/1024/1024);
    }
    fprintf(stderr, "holding %zu MB, sleeping 15s...\n", total/1024/1024);
    sleep(15);
    for (int i = 0; i < n; i++) free(ptrs[i]);
    fprintf(stderr, "freed, done\n");
    return 0;
}
