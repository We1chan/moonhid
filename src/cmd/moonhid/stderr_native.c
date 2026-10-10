#include <stdio.h>

void moonhid_stderr_byte(int byte) {
  fputc(byte, stderr);
}
