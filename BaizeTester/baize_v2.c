#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

// v5: Communicate SOLELY via exit code.
// Each test result encoded as a bit in the exit code.
// This avoids relying on printf/stdout (proved unreachable in v4).

int main(int argc, char **argv) {
    int result = 0;
    
    // Test 1: fopen /tmp/baize_v2_test.txt
    {
        FILE *f = fopen("/tmp/baize_v2_test.txt", "w");
        if (f) {
            fprintf(f, "OK\n");
            fclose(f);
            result |= 1;  // bit 0 = /tmp/ writable
        }
    }
    
    // Test 2: fopen /var/mobile/Documents/baize_v2_test.txt
    {
        FILE *f = fopen("/var/mobile/Documents/baize_v2_test.txt", "w");
        if (f) {
            fprintf(f, "OK\n");
            fclose(f);
            result |= 2;  // bit 1 = /var/mobile/Documents/ writable
        }
    }
    
    // Test 3: fopen /private/tmp/baize_v2_test.txt
    {
        FILE *f = fopen("/private/tmp/baize_v2_test.txt", "w");
        if (f) {
            fprintf(f, "OK\n");
            fclose(f);
            result |= 4;  // bit 2 = /private/tmp/ writable
        }
    }
    
    // Test 4: access("/tmp/", W_OK)
    if (access("/tmp/", W_OK) == 0) {
        result |= 8;  // bit 3 = /tmp/ access says writable
    }
    
    // Test 5: mkdir
    if (mkdir("/tmp/baize_v2_mkdir_test", 0755) == 0) {
        rmdir("/tmp/baize_v2_mkdir_test");
        result |= 16;  // bit 4 = mkdir OK
    }
    
    // Test 6: getcwd
    char cwd[1024];
    if (getcwd(cwd, sizeof(cwd))) {
        result |= 32;  // bit 5 = getcwd OK
    }
    
    // Test 7: printf reachable? (bare minimum - if this doesn't add to exit code,
    //          it means printf itself crashes the process)
    // We can't report this via exit code without printf first.
    // Instead, we use a known-safe operation.
    result |= 64;  // bit 6 = reached this point (basic execution sanity)
    
    return result;
}
