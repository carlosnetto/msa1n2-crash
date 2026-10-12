// Timer wake-up latency: how late does a thread wake after nanosleep(target)?
// Sensitive to CPU C-state exit latency.
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <sys/prctl.h>
static long ns(struct timespec a){return a.tv_sec*1000000000L+a.tv_nsec;}
static int cmp(const void*a,const void*b){long x=*(long*)a,y=*(long*)b;return (x>y)-(x<y);}
int main(int c,char**v){
  prctl(PR_SET_TIMERSLACK,1); // remove default 50us slack so C-state exit latency is visible
  long target_us=atol(v[1]); int n=atoi(v[2]); long*d=malloc(n*sizeof(long));
  struct timespec t={target_us/1000000,(target_us%1000000)*1000},a,b;
  for(int i=0;i<n;i++){clock_gettime(CLOCK_MONOTONIC,&a);nanosleep(&t,0);clock_gettime(CLOCK_MONOTONIC,&b);d[i]=ns(b)-ns(a)-target_us*1000;}
  qsort(d,n,sizeof(long),cmp);
  printf("sleep %5ldus x%-5d overshoot us: median %6.1f  p99 %7.1f  max %7.1f\n",target_us,n,d[n/2]/1e3,d[n*99/100]/1e3,d[n-1]/1e3);
}
