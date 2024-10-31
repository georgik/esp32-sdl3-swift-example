
// Define sprite types
enum SpriteType {
    case pumpkin
    case danger
}

// Generalized Sprite struct
struct Sprite {
    var destRect: SDL_FRect     // Position and size
    var xSpeed: Float           // Speed in X direction
    var ySpeed: Float           // Speed in Y direction
    var isActive: Bool          // Whether the sprite is active (visible)
    var type: SpriteType        // Type of the sprite (pumpkin or danger)
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

// Helper function to get random float (since Float.random(in:) may not be available)
func getRandomFloat_C(_ min: Float, _ max: Float) -> Float {
    return getRandomFloat(min, max)
}

// Random number generation helper (since Float.random(in:) may not be available)
func getRandomFloat(min: Float, max: Float) -> Float {
    return getRandomFloat_C(min, max)
}

func sdl_thread_entry_point(arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("SDL thread started.")

    // Initialize sprites
    let numberOfPumpkins = 25
    let numberOfDangers = 10
    var sprites: [Sprite] = []

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

    let pumpkinTexture = SDL_CreateTextureFromSurface(renderer, imageSurface);
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

    SDL_RenderTexture(renderer, pumpkinTexture, nil, &destRect);
    SDL_RenderPresent(renderer)

    var xSpeed: Float = 2.0
    var ySpeed: Float = 2.0

    // Initialize pumpkins
    for _ in 0..<numberOfPumpkins {
        var destRect = SDL_FRect()
        destRect.w = 32.0
        destRect.h = 32.0
        destRect.x = getRandomFloat(min: 0, max: screenWidth - destRect.w)
        destRect.y = getRandomFloat(min: 0, max: screenHeight - destRect.h)

        let xSpeed = getRandomFloat(min: -15.0, max: 15.0)
        let ySpeed = getRandomFloat(min: -15.0, max: 15.0)

        let sprite = Sprite(destRect: destRect, xSpeed: xSpeed, ySpeed: ySpeed, isActive: true, type: .pumpkin)
        sprites.append(sprite)
    }

    // Initialize dangers
    for _ in 0..<numberOfDangers {
        var destRect = SDL_FRect()
        destRect.w = 32.0
        destRect.h = 32.0
        destRect.x = getRandomFloat(min: 0, max: screenWidth - destRect.w)
        destRect.y = getRandomFloat(min: 0, max: screenHeight - destRect.h)

        let xSpeed = getRandomFloat(min: -15.0, max: 15.0)
        let ySpeed = getRandomFloat(min: -15.0, max: 15.0)

        let sprite = Sprite(destRect: destRect, xSpeed: xSpeed, ySpeed: ySpeed, isActive: true, type: .danger)
        sprites.append(sprite)
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

                // Check if touch intersects any sprite
                for i in 0..<sprites.count {
                    if sprites[i].isActive && pointInRect(x: touchX, y: touchY, rect: sprites[i].destRect) {
                        if sprites[i].type == .pumpkin {
                            // Pumpkin was tapped
                            sprites[i].isActive = false // Make it disappear
                            score += 1 // Increase score
                        } else if sprites[i].type == .danger {
                            // Danger was tapped
                            score = 0 // Reset score
                        }

                        // Reposition the sprite
                        sprites[i].destRect.x = getRandomFloat(min: 0, max: screenWidth - sprites[i].destRect.w)
                        sprites[i].destRect.y = getRandomFloat(min: 0, max: screenHeight - sprites[i].destRect.h)
                        sprites[i].xSpeed = getRandomFloat(min: -15.0, max: 15.0)
                        sprites[i].ySpeed = getRandomFloat(min: -15.0, max: 15.0)
                        sprites[i].isActive = true // Reactivate

                        break // Assume only one sprite can be tapped at a time
                    }
                }
            }
        }

        // Update sprite positions and check for collisions
        for i in 0..<sprites.count {
            if sprites[i].isActive {
                sprites[i].destRect.x += sprites[i].xSpeed
                sprites[i].destRect.y += sprites[i].ySpeed

                // Check for collision with edges
                if sprites[i].destRect.x <= 0 || sprites[i].destRect.x + sprites[i].destRect.w >= screenWidth {
                    sprites[i].xSpeed = -sprites[i].xSpeed
                }
                if sprites[i].destRect.y <= 0 || sprites[i].destRect.y + sprites[i].destRect.h >= screenHeight {
                    sprites[i].ySpeed = -sprites[i].ySpeed
                }
            }
        }

        // Clear the renderer
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
        SDL_RenderClear(renderer)

        // Render active sprites
        for sprite in sprites {
            if sprite.isActive {
                var rect = sprite.destRect
                if sprite.type == .pumpkin {
                    SDL_RenderTexture(renderer, pumpkinTexture, nil, &rect)
                } else if sprite.type == .danger {
                    SDL_RenderTexture(renderer, dangerTexture, nil, &rect)
                }
            }
        }
        // Present the updated frame
        SDL_RenderPresent(renderer)

        // Delay to limit frame rate (~60 FPS)
        SDL_Delay(16)
        // print("tick")
    }
    return nil
}
