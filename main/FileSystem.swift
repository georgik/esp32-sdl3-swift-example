

func SDL_InitFS() {
    print("Initializing File System")

    var config = esp_vfs_littlefs_conf_t(
        base_path: strdup("/assets"),
        partition_label: strdup("assets"),
        partition: nil,                 // Optional partition pointer; use nil if not needed
        format_if_mount_failed: 0,       // Convert false to UInt8 (0)
        read_only: 0,                    // Use 0 (false) since it's not read-only
        dont_mount: 0,                   // Convert false to UInt8 (0)
        grow_on_mount: 0                 // Convert false to UInt8 (0) if not needed
    )

    let result = esp_vfs_littlefs_register(&config)
    if result != ESP_OK {
        print("Failed to mount or format filesystem")
    } else {
        print("Filesystem mounted")
    }
}
