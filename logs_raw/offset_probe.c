#include <linux/module.h>
#include <linux/sched.h>
#include <linux/cred.h>
#include <linux/fs.h>
#include <linux/nsproxy.h>
#include <linux/sched/signal.h>
const unsigned long probe_offsets[] = {
	offsetof(struct task_struct, cred),
	offsetof(struct task_struct, real_cred),
	offsetof(struct task_struct, rcu_read_lock_nesting),
	offsetof(struct task_struct, thread_pid),
	offsetof(struct task_struct, pid),
	offsetof(struct task_struct, tgid),
	offsetof(struct task_struct, comm),
	offsetof(struct task_struct, mm),
	offsetof(struct task_struct, nsproxy),
	offsetof(struct task_struct, fs),
	offsetof(struct task_struct, files),
	offsetof(struct task_struct, signal),
	offsetof(struct task_struct, security),
	offsetof(struct task_struct, thread),
	offsetof(struct task_struct, stack),
	offsetof(struct task_struct, tasks),
	offsetof(struct cred, uid),
	offsetof(struct cred, gid),
	offsetof(struct cred, euid),
	offsetof(struct cred, egid),
	offsetof(struct cred, fsuid),
	offsetof(struct cred, fsgid),
	offsetof(struct cred, cap_permitted),
	offsetof(struct cred, cap_effective),
	offsetof(struct cred, user),
	offsetof(struct cred, user_ns),
	offsetof(struct cred, security),
	offsetof(struct cred, group_info),
	offsetof(struct cred, usage),
	offsetof(struct file, f_cred),
	offsetof(struct file, f_path),
	offsetof(struct file, f_inode),
};
static int __init probe_init(void) { return -1; }
module_init(probe_init);
MODULE_LICENSE("GPL");
