#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

// All output via stdout (printf) so parent can capture via pipe
#define SAY(fmt, ...) printf(fmt "\n", ##__VA_ARGS__); fflush(stdout)

int main(int argc, char **argv) {
    SAY(">>> baize_v2 started pid=%d", getpid());
    
    // Test 1: write to /tmp/
    {
        const char *path = "/tmp/baize_v2_test.txt";
        FILE *f = fopen(path, "w");
        if (!f) {
            SAY("T1_FAIL: fopen(%s) errno=%d (%s)", path, errno, strerror(errno));
        } else {
            fprintf(f, "BAIZE_V2_OK pid=%d\n", getpid());
            fclose(f);
            SAY("T1_OK: wrote %s", path);
        }
    }
    
    // Test 2: write to /var/mobile/Documents/
    {
        const char *path = "/var/mobile/Documents/baize_v2_test.txt";
        FILE *f = fopen(path, "w");
        if (!f) {
            SAY("T2_FAIL: fopen(%s) errno=%d (%s)", path, errno, strerror(errno));
        } else {
            fprintf(f, "BAIZE_V2_DOCUMENTS_OK pid=%d\n", getpid());
            fclose(f);
            SAY("T2_OK: wrote %s", path);
        }
    }
    
    // Test 3: try /private/tmp/
    {
        const char *path = "/private/tmp/baize_v2_test.txt";
        FILE *f = fopen(path, "w");
        if (!f) {
            SAY("T3_FAIL: fopen(%s) errno=%d (%s)", path, errno, strerror(errno));
        } else {
            fprintf(f, "BAIZE_V2_PRIVATE_TMP_OK pid=%d\n", getpid());
            fclose(f);
            SAY("T3_OK: wrote %s", path);
        }
    }
    
    // Test 4: what does getcwd() say?
    {
        char cwd[1024];
        if (getcwd(cwd, sizeof(cwd))) {
            SAY("T4_CWD: %s", cwd);
        } else {
            SAY("T4_CWD: getcwd failed errno=%d", errno);
        }
    }
    
    // Test 5: can we access() /tmp/ ?
    {
        if (access("/tmp/", W_OK) == 0) {
            SAY("T5_ACCESS: /tmp/ is writable");
        } else {
            SAY("T5_ACCESS: /tmp/ NOT writable errno=%d (%s)", errno, strerror(errno));
        }
    }
    
    // Test 6: can we mkdir?
    {
        int r = mkdir("/tmp/baize_v2_dir_test", 0755);
        if (r == 0) {
            SAY("T6_MKDIR: created /tmp/baize_v2_dir_test OK");
            rmdir("/tmp/baize_v2_dir_test");
        } else {
            SAY("T6_MKDIR: mkdir failed errno=%d (%s)", errno, strerror(errno));
        }
    }
    
    SAY(">>> baize_v2 exiting");
    return 0;
}
