
@_cdecl("app_main")
func app_main() {
    print("Initializing SDL3 from Swift.")

    // Initialize pthread attributes
    var sdl_pthread = pthread_t(bitPattern: 0)
    var attr = pthread_attr_t()

    pthread_attr_init(&attr)
    pthread_attr_setstacksize(&attr, 32768) // Set the stack size for the thread

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

    // Initialize SDL
    if SDL_Init(UInt32(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) == false {
        print("Unable to initialize SDL")
        return nil
    }
    print("SDL initialized successfully")

    guard let window = SDL_CreateWindow(nil, Int32(BSP_LCD_H_RES), Int32(BSP_LCD_V_RES), 0) else {
        return nil
    }

    // Create SDL renderer
    guard let renderer = SDL_CreateRenderer(window, nil) else {
        print("Failed to create renderer")
        return nil
    }

    SDL_SetRenderDrawColor(renderer, 22, 10, 33, 255)
    SDL_RenderClear(renderer)
    SDL_RenderPresent(renderer)

    SDL_InitFS();

    // let bmpFilePath: StaticString = "assets/espressif.bmp"
    let imageSurface = SDL_LoadBMP(getBmpFilePath())
    if (imageSurface == nil) {
        print("Failed to load image")
    }

    let imageTexture = SDL_CreateTextureFromSurface(renderer, imageSurface);
    SDL_DestroySurface(imageSurface);

    var destRect = SDL_FRect()

    // Assign values to the fields
    destRect.x = 10
    destRect.y = 10
    destRect.w = 32
    destRect.h = 32

    SDL_RenderTexture(renderer, imageTexture, nil, &destRect);
    SDL_RenderPresent(renderer)

    var event = SDL_Event()
    var running = true
    var xSpeed: Float = 2.0
    var ySpeed: Float = 2.0

    while running {
        // Handle events (e.g., window close)
        while SDL_PollEvent(&event) {
            if event.type == SDL_EVENT_QUIT.rawValue {
                running = false
                break
            }
            // Handle other events if needed
        }

        // Update the position of the image
        destRect.x += xSpeed
        destRect.y += ySpeed

        // Check for collision with the left and right edges
        if destRect.x <= 0 {
            destRect.x = 0
            xSpeed = -xSpeed // Reverse X direction
        } else if destRect.x + destRect.w >= Float(BSP_LCD_H_RES) {
            destRect.x = Float(BSP_LCD_H_RES) - destRect.w
            xSpeed = -xSpeed // Reverse X direction
        }

        // Check for collision with the top and bottom edges
        if destRect.y <= 0 {
            destRect.y = 0
            ySpeed = -ySpeed // Reverse Y direction
        } else if destRect.y + destRect.h >= Float(BSP_LCD_V_RES) {
            destRect.y = Float(BSP_LCD_V_RES) - destRect.h
            ySpeed = -ySpeed // Reverse Y direction
        }

        // Clear the renderer with a black color
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
        SDL_RenderClear(renderer)

        // Render the image at the new position
        SDL_RenderTexture(renderer, imageTexture, nil, &destRect)

        // Present the updated frame
        SDL_RenderPresent(renderer)

        // Delay to limit the frame rate (~60 FPS)
        SDL_Delay(16)
    }

    return nil
}
