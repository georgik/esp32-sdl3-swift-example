
// Define sprite types
enum SpriteType {
    case coin
    case danger
}

// Generalized Sprite struct
struct Sprite {
    var destRect: SDL_FRect     // Position and size
    var xSpeed: Float           // Speed in X direction
    var ySpeed: Float           // Speed in Y direction
    var isActive: Bool          // Whether the sprite is active (visible)
    var type: SpriteType        // Type of the sprite (coin or danger)
}


@_cdecl("app_main")
func app_main() {
    print("Initializing SDL3 from Swift.")

    // Initialize pthread attributes
    var sdl_pthread = pthread_t(bitPattern: 0)
    var attr = pthread_attr_t()

    pthread_attr_init(&attr)
    pthread_attr_setstacksize(&attr, 65536) // Set the stack size for the thread

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
    let margin: Float = 30.0
    return x >= rect.x - margin && x <= rect.x + rect.w + margin &&
           y >= rect.y - margin && y <= rect.y + rect.h + margin
}

// Function to generate a random Float between min and max
func getRandomFloat(min: Float, max: Float) -> Float {
    let scale = Float.random(in: 0...1)
    return min + scale * (max - min)
}

var scoreDestRect = SDL_FRect(x: 10.0, y: 10.0, w: 120.0, h: 50.0)
var score = 0


func sdl_thread_entry_point(arg: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("SDL thread started.")

    // Initialize sprites
    let numberOfCoins = 25
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

    TTF_Init()
    let font = TTF_OpenFont("/assets/FreeSans.ttf", 42);
    if (font == nil) {
        print("Font load failed")
    }

    let imageSurface = SDL_LoadBMP("/assets/coin_gold.bmp")
    if (imageSurface == nil) {
        print("Failed to load image")
    }

    let coinTexture = SDL_CreateTextureFromSurface(renderer, imageSurface);
    SDL_DestroySurface(imageSurface);

    let dangerSurface = SDL_LoadBMP("/assets/slime_normal.bmp")
    if (dangerSurface == nil) {
        print("Failed to load image")
    }

    let dangerTexture = SDL_CreateTextureFromSurface(renderer, dangerSurface);
    SDL_DestroySurface(dangerSurface);

    var scoreRect = SDL_FRect()

    // Assign values to the fields
    scoreRect.x = 10
    scoreRect.y = 10
    scoreRect.w = 32
    scoreRect.h = 32

    SDL_RenderTexture(renderer, coinTexture, nil, &scoreRect);
    SDL_RenderPresent(renderer)

    var xSpeed: Float = 2.0
    var ySpeed: Float = 2.0

    // Initialize coins
    for _ in 0..<numberOfCoins {
        var destRect = SDL_FRect()
        destRect.w = 32.0
        destRect.h = 32.0
        destRect.x = getRandomFloat(min: 0, max: screenWidth - destRect.w)
        destRect.y = getRandomFloat(min: 0, max: screenHeight - destRect.h)

        let xSpeed = getRandomFloat(min: -15.0, max: 15.0)
        let ySpeed = getRandomFloat(min: -15.0, max: 15.0)

        let sprite = Sprite(destRect: destRect, xSpeed: xSpeed, ySpeed: ySpeed, isActive: true, type: .coin)
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

    print("Entering main loop...")

    while running {
        // Handle events
        while SDL_PollEvent(&event) {
            if event.type == SDL_EVENT_QUIT.rawValue {
                running = false
                break
            } else if event.type == SDL_EVENT_FINGER_UP.rawValue {
                // Get touch coordinates (normalized between 0 and 1)
                let touchX = event.tfinger.x
                let touchY = event.tfinger.y

                // Check if touch intersects any sprite
                for i in 0..<sprites.count {
                    if sprites[i].isActive && pointInRect(x: touchX, y: touchY, rect: sprites[i].destRect) {
                        if sprites[i].type == .coin {
                            // Coin was tapped
                            sprites[i].isActive = false // Make it disappear
                            score += 1 // Increase score
                        } else if sprites[i].type == .danger {
                            // Danger was tapped
                            score = 0 // Reset score
                            SDL_SetRenderDrawColor(renderer, 200, 200, 0, 255)
                            SDL_RenderClear(renderer)
                            SDL_RenderPresent(renderer)
                            SDL_Delay(500)
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
                if sprite.type == .coin {
                    SDL_RenderTexture(renderer, coinTexture, nil, &rect)
                } else if sprite.type == .danger {
                    SDL_RenderTexture(renderer, dangerTexture, nil, &rect)
                }
            }
        }

        let scoreText = "SCORE \(score)"

        // Convert the string to a C-compatible null-terminated character buffer (CChar array)
        var scoreTextBuffer = Array(scoreText.utf8CString)

        // Render text to surface
        let fontSurface = TTF_RenderText_Blended(font, &scoreTextBuffer, 0, SDL_Color(r: 40, g: 255, b: 40, a: 255))

        // Create texture from surface
        var scoreTexture = SDL_CreateTextureFromSurface(renderer, fontSurface)
        SDL_RenderTexture(renderer, scoreTexture, nil, &scoreDestRect)
        SDL_DestroySurface(fontSurface)

        // Present the updated frame
        SDL_RenderPresent(renderer)

        // Delay to limit frame rate (~60 FPS)
        SDL_Delay(16)
        // print("tick")
    }
    return nil
}
