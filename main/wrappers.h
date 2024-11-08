#ifndef ESP_IDF_SWIFT_WRAPPERS
#define ESP_IDF_SWIFT_WRAPPERS
// BridgingHeader.h

#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "esp_wifi.h"

// Add the wrapper function prototype
EventBits_t xEventGroupSetBitsWrapper(EventGroupHandle_t xEventGroup, const EventBits_t uxBitsToSet);


void sntp_set_sync_mode_wrapper(sntp_sync_mode_t sync_mode);
void sntp_setservername_wrapper(uint8_t idx, const char* server);
void sntp_init_wrapper(void);

wifi_init_config_t get_wifi_init_config_default(void);
#endif