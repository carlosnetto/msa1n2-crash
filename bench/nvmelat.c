// QD1 4K random O_DIRECT read latency, optionally with idle gaps between reads
// (gaps let the NVMe drive / PCIe link drop into power-save states).
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
static long ns(struct timespec a){return a.tv_sec*1000000000L+a.tv_nsec;}
static int cmp(const void*a,const void*b){long x=*(long*)a,y=*(long*)b;return (x>y)-(x<y);}
int main(int c,char**v){
  int fd=open(v[1],O_RDONLY|O_DIRECT); if(fd<0){perror("open");return 1;}
  long blocks=lseek(fd,0,SEEK_END)/4096; int n=atoi(v[2]); long gap_ms=atol(v[3]);
  void*buf; if(posix_memalign(&buf,4096,4096)) return 1; long*d=malloc(n*sizeof(long)); srand(42);
  struct timespec a,b,g={gap_ms/1000,(gap_ms%1000)*1000000};
  for(int i=0;i<n;i++){ if(gap_ms) nanosleep(&g,0);
    off_t off=((long)rand()*rand()%blocks)*4096;
    clock_gettime(CLOCK_MONOTONIC,&a); if(pread(fd,buf,4096,off)!=4096){perror("pread");return 1;}
    clock_gettime(CLOCK_MONOTONIC,&b); d[i]=ns(b)-ns(a);}
  qsort(d,n,sizeof(long),cmp);
  printf("4K read gap %4ldms x%-5d latency us: median %6.1f  p99 %7.1f  max %7.1f\n",gap_ms,n,d[n/2]/1e3,d[n*99/100]/1e3,d[n-1]/1e3);
}
