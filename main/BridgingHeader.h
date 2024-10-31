
#include <stdio.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "SDL3/SDL.h"
#include "pthread.h"
#include "bsp/esp-bsp.h"
#include "filesystem.h"

const char* getBmpFilePath(void);
const char* getDangerFilePath(void);
float getRandomFloat(float min, float max);
