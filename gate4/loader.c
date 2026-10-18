#include <os/log.h>

__attribute__((constructor))
static void hytale_gl_loaded(void)
{
    os_log(OS_LOG_DEFAULT, "HytaleGL loaded into process");
}
