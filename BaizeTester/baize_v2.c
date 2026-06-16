#include <stdio.h>
#include <unistd.h>

int main(void) {
    // Test 1: write a file to /tmp/
    FILE *f = fopen("/tmp/baize_v2_test.txt", "w");
    if (!f) return 1;
    fprintf(f, "BAIZE_V2_OK %d\n", getpid());
    fclose(f);
    
    // Test 2: write to /var/mobile/Documents/
    FILE *f2 = fopen("/var/mobile/Documents/baize_v2_test.txt", "w");
    if (!f2) return 2;
    fprintf(f2, "BAIZE_V2_DOCUMENTS_OK %d\n", getpid());
    fclose(f2);
    
    // Test 3: list a directory to stdout
    FILE *ls = popen("ls /var/mobile/ 2>&1", "r");
    if (ls) {
        char buf[4096];
        while (fgets(buf, sizeof(buf), ls)) {
            fputs(buf, stdout);
        }
        pclose(ls);
    }
    
    return 0;
}
