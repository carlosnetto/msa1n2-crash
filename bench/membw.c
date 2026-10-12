// Single-thread memcpy bandwidth, best of 5, 1 GiB buffers.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
int main(){size_t s=1UL<<30;char*a=malloc(s),*b=malloc(s);memset(a,1,s);memset(b,2,s);double best=0;
  for(int i=0;i<5;i++){struct timespec x,y;clock_gettime(CLOCK_MONOTONIC,&x);memcpy(b,a,s);clock_gettime(CLOCK_MONOTONIC,&y);
    double t=(y.tv_sec-x.tv_sec)+(y.tv_nsec-x.tv_nsec)/1e9,g=2.0*s/t/1e9;if(g>best)best=g;}
  printf("memcpy 1GiB single-thread: %.1f GB/s\n",best);}
