#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/stat.h>

// Debug log file (write to a path we hope works)
void log_debug(const char *msg) {
    FILE *lf = fopen("/tmp/baize_v2_debug.txt", "a");
    if (lf) {
        fprintf(lf, "[%d] %s\n", getpid(), msg);
        fclose(lf);
    }
}

int main(int argc, char **argv) {
    log_debug("baize_v2 started");
    
    // Test 1: write to /tmp/baize_v2_test.txt
    {
        const char *path = "/tmp/baize_v2_test.txt";
        FILE *f = fopen(path, "w");
        if (!f) {
            char errmsg[256];
            snprintf(errmsg, sizeof(errmsg), "Test1 fopen FAIL: %s (errno=%d)", path, errno);
            log_debug(errmsg);
        } else {
            fprintf(f, "BAIZE_V2_OK pid=%d\n", getpid());
            fflush(f);
            fsync(fileno(f));
            fclose(f);
            char okmsg[256];
            snprintf(okmsg, sizeof(okmsg), "Test1 write OK: %s", path);
            log_debug(okmsg);
        }
    }
    
    // Test 2: write to /var/mobile/Documents/baize_v2_test.txt
    {
        const char *path = "/var/mobile/Documents/baize_v2_test.txt";
        FILE *f = fopen(path, "w");
        if (!f) {
            char errmsg[256];
            snprintf(errmsg, sizeof(errmsg), "Test2 fopen FAIL: %s (errno=%d)", path, errno);
            log_debug(errmsg);
        } else {
            fprintf(f, "BAIZE_V2_DOCUMENTS_OK pid=%d\n", getpid());
            fflush(f);
            fsync(fileno(f));
            fclose(f);
            char okmsg[256];
            snprintf(okmsg, sizeof(okmsg), "Test2 write OK: %s", path);
            log_debug(okmsg);
        }
    }
    
    // Test 3: try /private/tmp/
    {
        const char *path = "/private/tmp/baize_v2_test.txt";
        FILE *f = fopen(path, "w");
        if (!f) {
            char errmsg[256];
            snprintf(errmsg, sizeof(errmsg), "Test3 fopen FAIL: %s (errno=%d)", path, errno);
            log_debug(errmsg);
        } else {
            fprintf(f, "BAIZE_V2_PRIVATE_TMP_OK pid=%d\n", getpid());
            fflush(f);
            fsync(fileno(f));
            fclose(f);
            char okmsg[256];
            snprintf(okmsg, sizeof(okmsg), "Test3 write OK: %s", path);
            log_debug(okmsg);
        }
    }
    
    // Test 4: list /var/mobile/ (use execv of /bin/ls style - skip popen, no shell)
    log_debug("Test4: skipping popen (no /bin/sh on iOS)");
    
    log_debug("baize_v2 exiting");
    return 0;
}
