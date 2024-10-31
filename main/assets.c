#include <stdlib.h>
#include <stdio.h>

const char* getBmpFilePath(void) {
    return "/assets/espressif.bmp";
}


const char* getDangerFilePath(void) {
    return "/assets/danger.bmp";
}

// Function to get a random float between min and max
float getRandomFloat(float min, float max) {
    float scale = rand() / (float) RAND_MAX;
    return min + scale * (max - min);
}