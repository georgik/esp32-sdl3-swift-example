
struct Pumpkin {
    var destRect: SDL_FRect     // Position and size
    var xSpeed: Float           // Speed in X direction
    var ySpeed: Float           // Speed in Y direction
    var isActive: Bool          // Whether the pumpkin is active (visible)
}

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

func pointInRect(x: Float, y: Float, rect: SDL_FRect) -> Bool {
    return x >= rect.x && x <= rect.x + rect.w && y >= rect.y && y <= rect.y + rect.h
}

func sdl_thread_entry_point(arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("SDL thread started.")
    let numberOfPumpkins = 25
    var pumpkins: [Pumpkin] = []

    // Screen boundaries
    let screenWidth = Float(BSP_LCD_H_RES)
    let screenHeight = Float(BSP_LCD_V_RES)

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

    // let bmpFilePath: StaticString = "assets/espressif.bmp"
    let dangerSurface = SDL_LoadBMP(getDangerFilePath())
    if (dangerSurface == nil) {
        print("Failed to load image")
    }

    let dangerTexture = SDL_CreateTextureFromSurface(renderer, dangerSurface);
    SDL_DestroySurface(dangerSurface);

    var destRect = SDL_FRect()

    // Assign values to the fields
    destRect.x = 10
    destRect.y = 10
    destRect.w = 32
    destRect.h = 32

    SDL_RenderTexture(renderer, imageTexture, nil, &destRect);
    SDL_RenderPresent(renderer)

    var xSpeed: Float = 2.0
    var ySpeed: Float = 2.0

    // Initialize pumpkins
    for _ in 0..<numberOfPumpkins {
        var destRect = SDL_FRect()
        destRect.w = 32.0
        destRect.h = 32.0
        destRect.x = Float.random(in: 0...(screenWidth - destRect.w))
        destRect.y = Float.random(in: 0...(screenHeight - destRect.h))

        let xSpeed = Float.random(in: -15.0...15.0)
        let ySpeed = Float.random(in: -15.0...15.0)

        let pumpkin = Pumpkin(destRect: destRect, xSpeed: xSpeed, ySpeed: ySpeed, isActive: true)
        pumpkins.append(pumpkin)
    }
    var score = 0
    var event = SDL_Event()
    var running = true

    while running {
        // Handle events
        while SDL_PollEvent(&event) {
            if event.type == SDL_EVENT_QUIT.rawValue {
                running = false
                break
            } else if event.type == SDL_EVENT_FINGER_UP.rawValue {
                // Get touch coordinates (normalized between 0 and 1)
                let touchX = event.tfinger.x * screenWidth
                let touchY = event.tfinger.y * screenHeight
                
                // Check if touch intersects any pumpkin
                for i in 0..<pumpkins.count {
                    if pumpkins[i].isActive && pointInRect(x: touchX, y: touchY, rect: pumpkins[i].destRect) {
                        // Pumpkin was tapped
                        pumpkins[i].isActive = false // Make it disappear
                        score += 1 // Increase score
                        
                        // Reposition the pumpkin
                        pumpkins[i].destRect.x = Float.random(in: 0...(screenWidth - pumpkins[i].destRect.w))
                        pumpkins[i].destRect.y = Float.random(in: 0...(screenHeight - pumpkins[i].destRect.h))
                        pumpkins[i].xSpeed = Float.random(in: -15.0...15.0)
                        pumpkins[i].ySpeed = Float.random(in: -15.0...15.0)
                        pumpkins[i].isActive = true // Reactivate
                        break // Assume only one pumpkin can be tapped at a time
                    }
                }
            }
        }

        // Update pumpkin positions and check for collisions
        for i in 0..<pumpkins.count {
            if pumpkins[i].isActive {
                pumpkins[i].destRect.x += pumpkins[i].xSpeed
                pumpkins[i].destRect.y += pumpkins[i].ySpeed

                // Check for collision with edges
                if pumpkins[i].destRect.x <= 0 || pumpkins[i].destRect.x + pumpkins[i].destRect.w >= screenWidth {
                    pumpkins[i].xSpeed = -pumpkins[i].xSpeed
                }
                if pumpkins[i].destRect.y <= 0 || pumpkins[i].destRect.y + pumpkins[i].destRect.h >= screenHeight {
                    pumpkins[i].ySpeed = -pumpkins[i].ySpeed
                }
            }
        }

        // Clear the renderer
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
        SDL_RenderClear(renderer)

        // Render active pumpkins
        for pumpkin in pumpkins {
            if pumpkin.isActive {
                var rect = pumpkin.destRect
                SDL_RenderTexture(renderer, imageTexture, nil, &rect)
            }
        }

        // Present the updated frame
        SDL_RenderPresent(renderer)

        // Delay to limit frame rate (~60 FPS)
        SDL_Delay(16)
    }
    return nil
}
