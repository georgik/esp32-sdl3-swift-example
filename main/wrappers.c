#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "esp_sntp.h"
#include "esp_wifi.h"

EventBits_t xEventGroupSetBitsWrapper(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToSet) {
    return xEventGroupSetBits(xEventGroup, uxBitsToSet);
}

void sntp_set_sync_mode_wrapper(sntp_sync_mode_t sync_mode) {
    sntp_set_sync_mode(sync_mode);
}

void sntp_setservername_wrapper(uint8_t idx, const char* server) {
    sntp_setservername(idx, server);
}

void sntp_init_wrapper(void) {
    sntp_init();
}

wifi_init_config_t get_wifi_init_config_default() {
    wifi_init_config_t config = WIFI_INIT_CONFIG_DEFAULT();
    return config;
}
