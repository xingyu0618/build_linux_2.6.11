#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
//#include <asm/termbits.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <string.h>
#include <stdarg.h>
#include <stdlib.h>

int do_syscall(int rc, char*msg, char*file, int line){
  if( rc<0 && rc==-1 ){
    printf("SyscallError at %s:%d\n"
           "  (%d)[%s]\n"
           "  `%s\n", 
      file, line, errno, strerror(errno), msg
    );
    exit(1);
  }else if( rc<0 && rc!=-1 ){
    printf("SyscallError at %s:%d\n"
           "  rc=%d, isn't -1\n", file, line, rc);
    exit(1);
  }
  return rc;
}

/* todo: check gcc macros */
#define Syscall(expr) \
do_syscall(expr, #expr, __FILE__, __LINE__)

void pexit(char*fmt, ...){
  va_list ap;
  va_start(ap, fmt);
  vfprintf(stdout, fmt, ap);
  exit(1);
}

void new_ctrlterm(){
  int fdin, fdout, fderr;
  char *ttynamex;
  pid_t pgid;

  printf("\n* new_ctrlterm\n");
  /* close old terminal */
  close(0);
  close(1);
  close(2);

  fdin=open("/dev/ttyS0", O_RDONLY);
  fdout=open("/dev/ttyS0", O_WRONLY);
  fderr=open("/dev/ttyS0", O_WRONLY);
  if( fdin!=0 && fdout!=1 && fderr!=2 ){
    pexit("fdin=%d, fdout=%d, fderr=%d\n", fdin, fdout, fderr);
  }

  Syscall( ioctl(0, TIOCSCTTY) );
  
  //ttynamex=ttyname(0);
  //pgid=Syscall( tcgetpgrp(0) );
  //printf("- tty=%s, pgid=%d\n", ttynamex, pgid);
}

void print_stats(){
  pid_t pid, pgid, sid, ppid, ttypgid;
  uid_t uid, euid;
  char *ttynamex;

  uid=getuid();
  euid=getuid();
  pid=getpid();
  sid=getsid(0);
  pgid=getpgid(0);
  ppid=getppid();
  
  if( sid>0 ){
    ttynamex=ttyname(0);
    ttypgid=Syscall( tcgetpgrp(0) );
  }


  printf("=== stats ===\n");
  printf("- pid=%d, ppid=%d, pgid=%d, sid=%d\n", pid, ppid, pgid, sid);
  printf("- uid=%d, euid=%d\n", uid, euid);
  if( sid>0 ) 
    printf("- tty=%s, pgid=%d\n", ttynamex, ttypgid);
  printf("==============\n");
}

int main(int ac, char**av){
  char *mode;
  pid_t sid;
  char*envp[]={"ENV=initrc", NULL};

  printf("\n"); print_stats();

  Syscall( setsid() );
  new_ctrlterm();
  
  printf("\n"); print_stats();
  
  printf("* run busybox shell\n");

  execle("/bin/sh", "sh", NULL, envp);

  return 0;
}
