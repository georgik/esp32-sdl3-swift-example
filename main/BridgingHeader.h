
#include <stdio.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "sdkconfig.h"
#include "SDL3/SDL.h"
#include "SDL3_ttf/SDL_ttf.h"
#include "pthread.h"
#include "bsp/esp-bsp.h"
#include "filesystem.h"

const char* getBmpFilePath(void);
const char* getDangerFilePath(void);
float getRandomFloat(float min, float max);
void logFloat(double value);
const char* getFontFilePath(void);
void getScoreText(int score, char* buffer, int bufferSize);
