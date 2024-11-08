let TAG = "WeatherApp"

// Wi-Fi credentials and OpenWeatherMap API details
var wifi_ssid = [CChar](repeating: 0, count: 32)
var wifi_password = [CChar](repeating: 0, count: 64)
var openweather_api_key = [CChar](repeating: 0, count: 42)
var openweather_city_name = [CChar](repeating: 0, count: 32)
var openweather_code = [CChar](repeating: 0, count: 6)

let MAXIMUM_RETRY = 5

var s_wifi_event_group: EventGroupHandle_t?

let SSID_LEN = 32
let PASS_LEN = 64


var s_retry_num = 0

var response_buffer: UnsafeMutablePointer<CChar>?
var response_len = 0

var window: OpaquePointer?
var renderer: OpaquePointer?
var font: OpaquePointer?

let portTICK_PERIOD_MS: UInt32 = 1 // Assuming configTICK_RATE_HZ is 1000


struct WeatherData {
    var description = [CChar](repeating: 0, count: 64)
    var icon = [CChar](repeating: 0, count: 16)
    var temperature: Double = 0.0
    var pressure: Int32 = 0
    var humidity: Int32 = 0
    var sunrise_hour: Int32 = 0
    var sunrise_minute: Int32 = 0
    var sunset_hour: Int32 = 0
    var sunset_minute: Int32 = 0
}

var current_weather = WeatherData()

func ESP_LOGE(_ tag: String, _ message: String) {
    // tag.withCString { tagPtr in
    //     message.withCString { msgPtr in
    //         // esp_log_write(ESP_LOG_ERROR, tagPtr, "%s", msgPtr)
    //     }
    // }
}

func ESP_LOGI(_ tag: String, _ message: String) {
    print(message)
    // tag.withCString { tagPtr in
    //     message.withCString { msgPtr in
    //         // esp_log_write(ESP_LOG_INFO, tagPtr, "%s", msgPtr)
    //     }
    // }
}

func ESP_LOGD(_ tag: String, _ message: String) {
    // tag.withCString { tagPtr in
    //     message.withCString { msgPtr in
    //         // esp_log_write(ESP_LOG_DEBUG, tagPtr, "%s", msgPtr)
    //     }
    // }
}


// Define ESP_ERROR_CHECK in Swift
func ESP_ERROR_CHECK(_ expression: esp_err_t, file: StaticString = #file, line: UInt = #line) {
    if expression != ESP_OK {
        // Log the error with file and line information
        ESP_LOGE(TAG, "ESP_ERROR_CHECK failed: esp_err_t \(expression) at \(file):\(line)")
        // Handle the error, possibly by aborting the program
        abort()
    }
}


@_cdecl("app_main")
func app_main() {
    print("Initializing Swift Weather Application.")

    // Initialize pthread attributes
    var sdl_pthread = pthread_t(bitPattern: 0)
    var attr = pthread_attr_t()

    pthread_attr_init(&attr)
    pthread_attr_setstacksize(&attr, 32000) // Set the stack size for the thread

    // Create the SDL thread
    let ret = pthread_create(&sdl_pthread, &attr, sdl_thread_entry_point, nil)
    if ret != 0 {
        print("Failed to create SDL thread")
        return
    }

    // Optionally detach the thread if you don't need to join it later
    pthread_detach(sdl_pthread)
}

func sdl_thread_entry_point(arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("SDL thread started.")

    // Initialize NVS (Non-Volatile Storage)
    var ret = nvs_flash_init()
    if ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND {
        // NVS partition was truncated and needs to be erased
        ESP_ERROR_CHECK(nvs_flash_erase())
        ret = nvs_flash_init()
    }
    ESP_ERROR_CHECK(ret)

    // Initialize Wi-Fi
    ESP_LOGI(TAG, "ESP_WIFI_MODE_STA")
    wifi_init_sta()

    // Synchronize time using SNTP
    time_sync()

    // Fetch weather data
    fetch_weather_data()

    // Shutdown WiFi
    ESP_LOGI(TAG, "Shutdown WiFi")
    esp_wifi_stop()
    esp_wifi_deinit()

    SDL_InitFS()
    initialize_sdl()

    // Render weather data
    render_weather_data()

    // Optionally, enter deep sleep or restart
    while true {
        vTaskDelay(10000 / portTICK_PERIOD_MS)
    }

    return nil
}

typealias BaseType_t = Int32

let pdFALSE: BaseType_t = 0
let pdTRUE: BaseType_t = 1
let portMAX_DELAY: TickType_t = TickType_t.max
// Type Definitions
typealias EventBits_t = UInt32

// Constants
let WIFI_CONNECTED_BIT: EventBits_t = 1 << 0
let WIFI_FAIL_BIT: EventBits_t = 1 << 1

let BIT0: UInt32 = 1 << 0
let BIT1: UInt32 = 1 << 1


func wifi_init_sta() {
    s_wifi_event_group = xEventGroupCreate()

    // Initialize the underlying TCP/IP stack
    ESP_ERROR_CHECK(esp_netif_init())

    // Create the default event loop
    ESP_ERROR_CHECK(esp_event_loop_create_default())

    // Create the default Wi-Fi station
    esp_netif_create_default_wifi_sta()

    // Initialize Wi-Fi with default configuration
    var cfg = get_wifi_init_config_default()
    ESP_ERROR_CHECK(esp_wifi_init(&cfg))

    // Registering Event Handlers
    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT,
                                            ESP_EVENT_ANY_ID,
                                            wifi_event_handler,
                                            nil))

    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT,
                                            Int32(IP_EVENT_STA_GOT_IP.rawValue),
                                            wifi_event_handler,
                                            nil))

    // Get Wi-Fi credentials
    ESP_ERROR_CHECK(get_wifi_credentials())

    // Configure the Wi-Fi connection
    var wifi_config = wifi_config_t()
    memset(&wifi_config, 0, MemoryLayout<wifi_config_t>.size)
    withUnsafeMutablePointer(to: &wifi_config.sta.ssid) { ssidPtr in
        wifi_ssid.withUnsafeBytes { ssidBytes in
            strncpy(ssidPtr, ssidBytes.baseAddress?.assumingMemoryBound(to: Int8.self), Int(SSID_LEN))
        }
    }
    withUnsafeMutablePointer(to: &wifi_config.sta.password) { passPtr in
        wifi_password.withUnsafeBytes { passBytes in
            strncpy(passPtr, passBytes.baseAddress?.assumingMemoryBound(to: Int8.self), Int(PASS_LEN))
        }
    }

    // Set the Wi-Fi mode to station
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA))

    // Set the Wi-Fi configuration
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config))

    // Start Wi-Fi
    ESP_ERROR_CHECK(esp_wifi_start())

    // Disable Wi-Fi power saving mode
    ESP_ERROR_CHECK(esp_wifi_set_ps(wifi_ps_type_t(WIFI_PS_NONE.rawValue)))

    // Wait for connection
    let bits = xEventGroupWaitBits(s_wifi_event_group,
                                WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
                                pdFALSE,
                                pdFALSE,
                                portMAX_DELAY)

    // Check the event bits to determine the connection status
    if (bits & WIFI_CONNECTED_BIT) != 0 {
        ESP_LOGI(TAG, "Connected to AP SSID:\(String(cString: wifi_ssid)) password:***")
    } else if (bits & WIFI_FAIL_BIT) != 0 {
        ESP_LOGI(TAG, "Failed to connect to SSID:\(String(cString: wifi_ssid)), password:***")
    } else {
        ESP_LOGE(TAG, "UNEXPECTED EVENT")
    }
}


// Type Definitions
typealias esp_event_handler_t = @convention(c) (
    UnsafeMutableRawPointer?,
    UnsafePointer<CChar>?,
    Int32,
    UnsafeMutableRawPointer?
) -> Void

func wifi_event_handler(event_handler_arg: UnsafeMutableRawPointer?,
                        event_base: UnsafePointer<CChar>?,
                        event_id: Int32,
                        event_data: UnsafeMutableRawPointer?) -> Void {
    // Ensure WIFI_EVENT and IP_EVENT are accessible
    if event_base == WIFI_EVENT && event_id == Int32(WIFI_EVENT_STA_START.rawValue) {
        esp_wifi_connect()
        ESP_LOGI(TAG, "Connecting to Wi-Fi...")
    } else if event_base == WIFI_EVENT && event_id == Int32(WIFI_EVENT_STA_DISCONNECTED.rawValue) {
        if s_retry_num < MAXIMUM_RETRY {
            esp_wifi_connect()
            s_retry_num += 1
            ESP_LOGI(TAG, "Retrying to connect to the Wi-Fi network...")
        } else {
            xEventGroupSetBitsWrapper(s_wifi_event_group, WIFI_FAIL_BIT)
            ESP_LOGE(TAG, "Failed to connect to Wi-Fi.")
        }
        ESP_LOGI(TAG, "Connect to the AP failed")
    } else if event_base == IP_EVENT && event_id == Int32(IP_EVENT_STA_GOT_IP.rawValue) {
        s_retry_num = 0
        let event = event_data!.assumingMemoryBound(to: ip_event_got_ip_t.self)
        var ipString = [CChar](repeating: 0, count: 16)
        inet_ntop(AF_INET, &event.pointee.ip_info.ip, &ipString, socklen_t(ipString.count))
        ESP_LOGI(TAG, "Got IP Address: \(String(cString: ipString))")
        xEventGroupSetBitsWrapper(s_wifi_event_group, WIFI_CONNECTED_BIT)
    }
}

func get_wifi_credentials() -> esp_err_t {
    var err: esp_err_t

    var nvs_mem_handle: nvs_handle_t = 0

    ESP_LOGI(TAG, "Opening Non-Volatile Storage (NVS) handle")
    err = nvs_open_from_partition("nvs", "storage", NVS_READWRITE, &nvs_mem_handle)
    if err != ESP_OK {
        ESP_LOGE(TAG, "Error (\(esp_err_to_name(err))) opening NVS handle!\n")
        return err
    }

    ESP_LOGI(TAG, "The NVS handle successfully opened")

    var ssid_len = size_t(wifi_ssid.count)
    var pass_len = size_t(wifi_password.count)
    var openweather_api_key_len = size_t(openweather_api_key.count)
    var openweather_city_name_len = size_t(openweather_city_name.count)
    var openweather_code_len = size_t(openweather_code.count)

    err = nvs_get_str(nvs_mem_handle, "ssid", &wifi_ssid, &ssid_len)
    ESP_ERROR_CHECK(err)

    err = nvs_get_str(nvs_mem_handle, "password", &wifi_password, &pass_len)
    ESP_ERROR_CHECK(err)

    err = nvs_get_str(nvs_mem_handle, "ow_api_key", &openweather_api_key, &openweather_api_key_len)
    ESP_ERROR_CHECK(err)

    err = nvs_get_str(nvs_mem_handle, "ow_city", &openweather_city_name, &openweather_city_name_len)
    ESP_ERROR_CHECK(err)

    err = nvs_get_str(nvs_mem_handle, "ow_country", &openweather_code, &openweather_code_len)
    ESP_ERROR_CHECK(err)

    nvs_close(nvs_mem_handle)
    return ESP_OK
}

func time_sync() {
    ESP_LOGI(TAG, "Time sync.")

    // Set the SNTP sync mode
    sntp_set_sync_mode_wrapper(SNTP_SYNC_MODE_IMMED)

    // Set the SNTP server name
    sntp_setservername_wrapper(0, "pool.ntp.org")

    // Initialize SNTP
    sntp_init_wrapper()

    // Wait for time to be synchronized
    var timeinfo = tm()
    var now = time_t(0)
    var retry = 0
    let retry_count = 10
    while timeinfo.tm_year < (2016 - 1900) && retry < retry_count {
        ESP_LOGI(TAG, "Waiting for system time to be set... (\(retry)/\(retry_count))")
        vTaskDelay(2000 / portTICK_PERIOD_MS)
        time(&now)
        localtime_r(&now, &timeinfo)
        retry += 1
    }
    if retry == retry_count {
        ESP_LOGE(TAG, "Failed to synchronize time.")
    } else {
        let timeStr = asctime(&timeinfo)
        ESP_LOGI(TAG, "Time synchronized: \(String(cString: timeStr!))")
    }
}


func fetch_weather_data() {
    // Convert CChar arrays to Strings
    let cityName = String(cString: openweather_city_name)
    let countryCode = String(cString: openweather_code)
    let apiKey = String(cString: openweather_api_key)

    // Build the URL string using string interpolation
    let urlString = "http://api.openweathermap.org/data/2.5/weather?q=\(cityName),\(countryCode)&appid=\(apiKey)&units=metric"

    // Convert the URL string to CChar array
    var url = [CChar](urlString.utf8CString) // utf8CString includes null terminator

    // Initialize response buffer
    response_buffer = nil
    response_len = 0

    var config = esp_http_client_config_t()
    config.url = open_weather_url
    config.method = HTTP_METHOD_GET
    config.timeout_ms = 5000
    config.event_handler = http_event_handler
    config.user_data = nil

    let client = esp_http_client_init(&config)

    let err = esp_http_client_perform(client)

    if err == ESP_OK {
        let status_code = esp_http_client_get_status_code(client)
        ESP_LOGI(TAG, "HTTP GET Status = \(status_code)")

        if status_code == 200 {
            if response_buffer != nil {
                ESP_LOGI(TAG, "Received weather data: \(String(cString: response_buffer!))")
                parse_weather_data(response_buffer!)
                free(response_buffer)
                response_buffer = nil
                response_len = 0
            } else {
                ESP_LOGE(TAG, "Response buffer is NULL")
            }
        } else {
            ESP_LOGE(TAG, "HTTP GET request failed with status code: \(status_code)")
        }
    } else {
        ESP_LOGE(TAG, "HTTP GET request failed: \(String(cString: esp_err_to_name(err)))")
    }

    esp_http_client_cleanup(client)
}

func http_event_handler(evt: UnsafeMutablePointer<esp_http_client_event_t>?) -> esp_err_t {
    guard let evt = evt else { return ESP_FAIL }

    switch evt.pointee.event_id {
    case HTTP_EVENT_ON_DATA:
        ESP_LOGD(TAG, "HTTP_EVENT_ON_DATA, len=\(evt.pointee.data_len)")
        if !esp_http_client_is_chunked_response(evt.pointee.client) {
            let dataLen = Int(evt.pointee.data_len)

            // Reallocate response_buffer to fit new data
            let totalSize = response_len + dataLen + 1
            let ptr = realloc(response_buffer, totalSize)
            if ptr == nil {
                ESP_LOGE(TAG, "Failed to allocate memory for response buffer")
                return ESP_FAIL
            }
            response_buffer = ptr?.assumingMemoryBound(to: CChar.self)
            memcpy(response_buffer! + response_len, evt.pointee.data, dataLen)
            response_len += dataLen
            response_buffer![response_len] = 0 // Null-terminate
        }
    default:
        break
    }
    return ESP_OK
}


func parse_weather_data(_ json: UnsafePointer<CChar>) {
    guard let root = cJSON_Parse(json) else {
        ESP_LOGE(TAG, "Failed to parse JSON")
        return
    }

    defer {
        cJSON_Delete(root)
    }

    guard let weather_array = cJSON_GetObjectItem(root, "weather"), cJSON_IsArray(weather_array) != 0 else {
        return
    }

    if let weather = cJSON_GetArrayItem(weather_array, 0) {
        if let description = cJSON_GetObjectItem(weather, "description"), let description_str = description.pointee.valuestring {
            strncpy(&current_weather.description, description_str, current_weather.description.count)
        }
        if let icon = cJSON_GetObjectItem(weather, "icon"), let icon_str = icon.pointee.valuestring {
            strncpy(&current_weather.icon, icon_str, current_weather.icon.count)
        }
    }

    if let main = cJSON_GetObjectItem(root, "main") {
        if let temp = cJSON_GetObjectItem(main, "temp"), cJSON_IsNumber(temp) != 0 {
            current_weather.temperature = temp.pointee.valuedouble
        }
        if let pressure = cJSON_GetObjectItem(main, "pressure"), cJSON_IsNumber(pressure) != 0 {
            current_weather.pressure = pressure.pointee.valueint
        }
        if let humidity = cJSON_GetObjectItem(main, "humidity"), cJSON_IsNumber(humidity) != 0 {
            current_weather.humidity = humidity.pointee.valueint
        }
    }

    // Parse sunrise and sunset
    if let sys = cJSON_GetObjectItem(root, "sys") {
        if let sunrise = cJSON_GetObjectItem(sys, "sunrise"), cJSON_IsNumber(sunrise) != 0 {
            var sunrise_time = time_t(sunrise.pointee.valueint)
            var sunrise_tm = tm()
            localtime_r(&sunrise_time, &sunrise_tm)
            current_weather.sunrise_hour = sunrise_tm.tm_hour
            current_weather.sunrise_minute = sunrise_tm.tm_min
        }
        if let sunset = cJSON_GetObjectItem(sys, "sunset"), cJSON_IsNumber(sunset) != 0 {
            var sunset_time = time_t(sunset.pointee.valueint)
            var sunset_tm = tm()
            localtime_r(&sunset_time, &sunset_tm)
            current_weather.sunset_hour = sunset_tm.tm_hour
            current_weather.sunset_minute = sunset_tm.tm_min
        }
    }

    // ESP_LOGI(TAG, "Parsed weather data:")
    // ESP_LOGI(TAG, "Description: \(String(cString: current_weather.description))")
    // ESP_LOGI(TAG, "Icon: \(String(cString: current_weather.icon))")
    // ESP_LOGI(TAG, "Temperature: \(current_weather.temperature)")
    // ESP_LOGI(TAG, "Pressure: \(current_weather.pressure)")
    // ESP_LOGI(TAG, "Humidity: \(current_weather.humidity)")
    // ESP_LOGI(TAG, "Sunrise: \(current_weather.sunrise_hour):\(current_weather.sunrise_minute)")
    // ESP_LOGI(TAG, "Sunset: \(current_weather.sunset_hour):\(current_weather.sunset_minute)")
}


func initialize_sdl() {
    if !SDL_Init(UInt32(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
        // ESP_LOGE(TAG, "Unable to initialize SDL: \(String(cString: SDL_GetError()))")
        return
    }

    window = SDL_CreateWindow("SDL on ESP32", Int32(BSP_LCD_H_RES), Int32(BSP_LCD_V_RES), 0)
    if window == nil {
        // print("Failed to create window: \(String(cString: SDL_GetError()))")
        return
    }

    renderer = SDL_CreateRenderer(window, nil)
    if renderer == nil {
        // print("Failed to create renderer: \(String(cString: SDL_GetError()))")
        SDL_DestroyWindow(window)
        return
    }

    if !TTF_Init() {
        // ESP_LOGE(TAG, "Failed to initialize TTF: \(String(cString: SDL_GetError()))")
        return
    }

    font = TTF_OpenFont("/assets/FreeSans.ttf", 24)
    if font == nil {
        // ESP_LOGE(TAG, "Failed to open font: \(String(cString: SDL_GetError()))")
        return
    }
}

// Helper function to format Double values with specified decimal places
func formatDouble(_ value: Double, decimalPlaces: Int) -> String {
    // Handle rounding by adjusting the value
    let adjustment = value >= 0.0 ? 0.5 : -0.5

    // Calculate multiplier as 10^decimalPlaces without using pow
    var multiplier = 1.0
    for _ in 0..<decimalPlaces {
        multiplier *= 10.0
    }

    // Scale and round the value
    let scaledValue = value * multiplier + adjustment
    let intValue = Int(scaledValue)

    // Extract integer and fractional parts
    let integerPart = intValue / Int(multiplier)
    var fractionalPart = intValue % Int(multiplier)
    if fractionalPart < 0 { fractionalPart = -fractionalPart } // Handle negative fractions

    // Build fractional part string with leading zeros if necessary
    var fractionalString = String(fractionalPart)
    while fractionalString.count < decimalPlaces {
        fractionalString = "0" + fractionalString
    }

    return "\(integerPart).\(fractionalString)"
}

// Helper function to pad Int32 values with leading zeros if necessary
func padZero(_ value: Int32) -> String {
    return value < 10 ? "0\(value)" : "\(value)"
}

func render_weather_data() {
    // Clear the renderer
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
    SDL_RenderClear(renderer)

    var texts: [[CChar]] = []

    // Description
    texts.append(current_weather.description)

    // Temperature
    var temperature = [CChar](repeating: 0, count: 32)
    // sprintf(&temperature, "Temperature: %.1f°C", current_weather.temperature)
    texts.append(temperature)

    // Humidity
    var humidity = [CChar](repeating: 0, count: 32)
    // sprintf(&humidity, "Humidity: %d%%", current_weather.humidity)
    texts.append(humidity)

    // Pressure
    var pressure = [CChar](repeating: 0, count: 32)
    // sprintf(&pressure, "Pressure: %d hPa", current_weather.pressure)
    texts.append(pressure)

    // Sunrise
    var sunrise = [CChar](repeating: 0, count: 32)
    // sprintf(&sunrise, "Sunrise: %02d:%02d", current_weather.sunrise_hour, current_weather.sunrise_minute)
    texts.append(sunrise)

    // Sunset
    var sunset = [CChar](repeating: 0, count: 32)
    // sprintf(&sunset, "Sunset: %02d:%02d", current_weather.sunset_hour, current_weather.sunset_minute)
    texts.append(sunset)

    var yPosition: Float = 10.0

    for text in texts {
        let color = SDL_Color(r: 255, g: 255, b: 255, a: 255)
        let surface = TTF_RenderText_Blended(font, text, 0, color)
        let texture = SDL_CreateTextureFromSurface(renderer, surface)

        // var destRect = SDL_FRect(x: 10.0, y: yPosition, w: Float(surface!.pointee.w), h: Float(surface!.pointee.h))
        var destRect = SDL_FRect(x: 10.0, y: yPosition, w: 100.0, h: 100.0)

        SDL_RenderTexture(renderer, texture, nil, &destRect)
        SDL_DestroyTexture(texture)
        SDL_DestroySurface(surface)

        yPosition += destRect.h + 5.0
    }

    // Present the updated frame
    SDL_RenderPresent(renderer)
}
