// ko_load.c - resolve .ko SHN_UNDEF via kallsyms -> SHN_ABS, then init_module(flags=0)
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <elf.h>
#ifndef SYS_init_module
#define SYS_init_module 105
#endif
#ifndef SHN_ABS
#define SHN_ABS 0xfff1
#endif
#define LOG(...) do { printf(__VA_ARGS__); fflush(stdout); } while (0)
#define HSIZE 16384
static long htab[HSIZE]; static char *hname[HSIZE]; static uint64_t haddr[HSIZE];
static unsigned hhash(const char *s){ unsigned long h=5381; int c; while((c=*s++)) h=h*33+(unsigned)c; return (unsigned)(h & (HSIZE-1)); }

int main(int argc, char **argv){
  const char *path=NULL, *kspath="/proc/kallsyms", *outpath=NULL; int dry=0;
  for (int i=1;i<argc;i++){
    if (!strcmp(argv[i],"--kallsyms") && i+1<argc) kspath=argv[++i];
    else if (!strcmp(argv[i],"--out") && i+1<argc) outpath=argv[++i];
    else if (!strcmp(argv[i],"--dry-run")) dry=1;
    else path=argv[i];
  }
  if (!path){ LOG("usage: %s [--kallsyms F] [--dry-run] [--out F] module.ko\n", argv[0]); return 2; }
  int fd=open(path,O_RDONLY); if(fd<0){ LOG("open %s: %s\n", path, strerror(errno)); return 2; }
  struct stat st; if(fstat(fd,&st)){ LOG("fstat: %s\n", strerror(errno)); return 2; }
  size_t len=(size_t)st.st_size; uint8_t *buf=malloc(len);
  if(!buf){ LOG("malloc failed\n"); return 2; }
  ssize_t off=0; while(off<(ssize_t)len){ ssize_t r=read(fd,buf+off,len-(size_t)off); if(r<=0){LOG("read: %s\n",strerror(errno));return 2;} off+=r; }
  close(fd);
  LOG("[*] read %s %zu bytes\n", path, len);
  Elf64_Ehdr *eh=(Elf64_Ehdr*)buf;
  if (memcmp(eh->e_ident, ELFMAG, SELFMAG) || eh->e_machine!=EM_AARCH64){ LOG("not aarch64 ELF\n"); return 2; }
  Elf64_Shdr *sh=(Elf64_Shdr*)(buf+eh->e_shoff);
  Elf64_Shdr *symtab=NULL; char *strtab=NULL;
  const char *shstr=(const char*)(buf+sh[eh->e_shstrndx].sh_offset);
  for (int i=0;i<eh->e_shnum;i++){
    if (sh[i].sh_type==SHT_SYMTAB && !symtab){ symtab=&sh[i]; strtab=(char*)(buf+sh[sh[i].sh_link].sh_offset); }
  }
  if(!symtab){ LOG("no symtab\n"); return 2; }
  (void)shstr;
  size_t nsyms=symtab->sh_size/sizeof(Elf64_Sym); Elf64_Sym *syms=(Elf64_Sym*)(buf+symtab->sh_offset);
  for(int i=0;i<HSIZE;i++){ htab[i]=-1; haddr[i]=0; }
  int nundef=0;
  for(size_t i=0;i<nsyms;i++){
    if(syms[i].st_shndx!=SHN_UNDEF || !syms[i].st_name) continue;
    const char *nm=strtab+syms[i].st_name; if(!*nm) continue;
    const char *rn=nm;
    if(!strcmp(nm,"kasan_flag_enabled")) rn="empty_zero_page";
    unsigned h=hhash(rn); int dup=0;
    while(htab[h]!=-1){ if(!strcmp(hname[h],rn)){dup=1;break;} h=(h+1)&(HSIZE-1); }
    if(dup) continue;
    htab[h]=(long)i; hname[h]=(char*)rn; nundef++;
  }
  LOG("[*] undefined symbols: %d\n", nundef);
  FILE *kf=fopen(kspath,"r"); if(!kf){ LOG("open %s: %s\n", kspath, strerror(errno)); return 2; }
  char line[1024]; long nres=0;
  while(fgets(line,sizeof line,kf)){
    char *p=line; uint64_t addr=strtoull(p,&p,16);
    while(*p==' '||*p=='\t')p++;
    if(!*p) continue;
    while(*p && *p!=' ' && *p!='\t') p++;   /* type token: letter OR ascii-code number */
    while(*p==' '||*p=='\t')p++;
    char *name=p, *end=name;
    while(*end && *end!='\n' && *end!='\t' && *end!=' ') end++;
    int is_module=(*end=='\t'); *end=0;
    if(!*name) continue;
    if(is_module) break;
    if(!addr) continue;
    unsigned h=hhash(name);
    while(htab[h]!=-1){ if(!strcmp(hname[h],name)){ if(!haddr[h]){ haddr[h]=addr; nres++; } break; } h=(h+1)&(HSIZE-1); }
  }
  fclose(kf);
  LOG("[*] resolved %ld of %d from %s\n", nres, nundef, kspath);
  int miss=0;
  for(int h=0;h<HSIZE;h++){
    if(htab[h]==-1) continue;
    long si=htab[h];
    if(!haddr[h]){ LOG("[!] UNRESOLVED: %s\n", hname[h]); miss++; continue; }
    syms[si].st_shndx=SHN_ABS; syms[si].st_value=haddr[h]; syms[si].st_size=0;
  }
  LOG("[*] patched %d symbols, unresolved %d\n", nundef-miss, miss);
  if(dry){
    if(!outpath){ LOG("dry-run needs --out\n"); return 2; }
    int w=open(outpath,O_WRONLY|O_CREAT|O_TRUNC,0600);
    if(w<0){ LOG("open out: %s\n", strerror(errno)); return 2; }
    size_t wo=0; while(wo<len){ ssize_t k=write(w,buf+wo,len-wo); if(k<=0){LOG("write: %s\n",strerror(errno));return 2;} wo+=(size_t)k; }
    close(w); LOG("[+] wrote %s dry-run\n", outpath); return miss?3:0;
  }
  if(miss){ LOG("[-] %d unresolved, aborting load\n", miss); return 3; }
  errno=0;
  long rc=syscall(SYS_init_module, buf, len, "");
  if(rc==0){ LOG("[+] module loaded\n"); return 0; }
  int e=errno;
  LOG("[-] init_module failed errno=%d %s\n", e, strerror(e));
  return 4;
}
