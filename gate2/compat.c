#include <stdarg.h>

/* macOS-only libSystem symbol that iOS does not export.
   The game only uses it for logging, so a no-op is safe. */
void hytale_syslog_ext(void) __asm("_syslog$DARWIN_EXTSN");
void hytale_syslog_ext(void) { }
