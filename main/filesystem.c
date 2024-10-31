#include "filesystem.h"
#include <stdio.h>
#include "esp_vfs.h"
#include "esp_littlefs.h"

void SDL_InitFS(void) {
    printf("Initialising File System\n");

    esp_vfs_littlefs_conf_t conf = {
        .base_path = "/assets",
        .partition_label = "assets",
        .format_if_mount_failed = false,
        .dont_mount = false,
    };

    esp_err_t err = esp_vfs_littlefs_register(&conf);
    if (err != ESP_OK) {
        printf("Failed to mount or format filesystem\n");
    } else {
        printf("Filesystem mounted\n");
        listFiles("/assets");
    }
}

void listFiles(const char *dirname) {
    DIR *dir = opendir(dirname);
    if (!dir) {
        printf("Failed to open directory: %s\n", dirname);
        return;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        struct stat entry_stat;
        char path[1024];
        snprintf(path, sizeof(path), "%s/%s", dirname, entry->d_name);

        if (stat(path, &entry_stat) == -1) {
            printf("Failed to stat %s\n", path);
            continue;
        }

        if (S_ISDIR(entry_stat.st_mode)) {
            printf("[DIR]  %s\n", entry->d_name);
        } else if (S_ISREG(entry_stat.st_mode)) {
            printf("[FILE] %s (Size: %ld bytes)\n", entry->d_name, entry_stat.st_size);
        }
    }

    closedir(dir);
}

void TestFileOpen(const char *file) {
    SDL_IOStream *rw = SDL_IOFromFile(file, "rb");
    if (rw == NULL) {
        printf("Failed to open file: %s\n", SDL_GetError());
    } else {
        printf("File opened successfully.\n");
        SDL_CloseIO(rw);
    }
}
