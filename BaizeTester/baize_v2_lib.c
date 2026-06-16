#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <sys/stat.h>

// v6: Compiled as .dylib, run via dlopen+dlsym in App process.
// Same tests as v5 but as an exported C function.

__attribute__((visibility("default")))
int baize_v2_test(void) {
    int result = 0;
    
    // Test 1: fopen /tmp/baize_v2_test.txt
    {
        FILE *f = fopen("/tmp/baize_v2_test.txt", "w");
        if (f) {
            fprintf(f, "OK\n");
            fclose(f);
            result |= 1;
        }
    }
    
    // Test 2: fopen /var/mobile/Documents/baize_v2_test.txt
    {
        FILE *f = fopen("/var/mobile/Documents/baize_v2_test.txt", "w");
        if (f) {
            fprintf(f, "OK\n");
            fclose(f);
            result |= 2;
        }
    }
    
    // Test 3: fopen /private/tmp/baize_v2_test.txt
    {
        FILE *f = fopen("/private/tmp/baize_v2_test.txt", "w");
        if (f) {
            fprintf(f, "OK\n");
            fclose(f);
            result |= 4;
        }
    }
    
    // Test 4: access("/tmp/", W_OK)
    if (access("/tmp/", W_OK) == 0) {
        result |= 8;
    }
    
    // Test 5: mkdir
    if (mkdir("/tmp/baize_v2_mkdir_test", 0755) == 0) {
        rmdir("/tmp/baize_v2_mkdir_test");
        result |= 16;
    }
    
    // Test 6: getcwd
    char cwd[1024];
    if (getcwd(cwd, sizeof(cwd))) {
        result |= 32;
    }
    
    // Test 7: printf reachable (since we're in-process now!)
    printf("BAIZE_V2_DYLIB_OK pid=%d\n", getpid());
    fflush(stdout);
    result |= 64;
    
    return result;
}
