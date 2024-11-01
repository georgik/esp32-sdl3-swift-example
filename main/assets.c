#include <stdlib.h>
#include <stdio.h>

const char* getBmpFilePath(void) {
    return "/assets/coin_gold.bmp";
}


const char* getDangerFilePath(void) {
    return "/assets/slime_normal.bmp";
}

const char* getFontFilePath(void) {
    return "/assets/FreeSans.ttf";
}

// Function to get a random float between min and max
float getRandomFloat(float min, float max) {
    float scale = rand() / (float) RAND_MAX;
    return min + scale * (max - min);
}

void logFloat( double value) {
    printf("> %f\n", value);
}

// Function to generate the score text
void getScoreText(int score, char* buffer, int bufferSize) {
    snprintf(buffer, bufferSize, "SCORE %d", score);
}