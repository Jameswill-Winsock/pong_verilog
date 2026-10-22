// sim_main.cpp - Verilator + SDL3 front end for the Verilog pong.
//   W/S = left paddle, Up/Down = right paddle, R = reset, Esc = quit
//   --ai1 / --ai2 : let the computer drive that paddle
//   --headless N [out.ppm] : run N frames with no window (for testing)
#include <SDL3/SDL.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include "Vtop.h"
#include "verilated.h"

static const int W = 64, H = 64, SCALE = 10, CLOCKS_PER_FRAME = W * H;
static Vtop* top;
static uint8_t fb[H][W];

static void tick() {
    top->clk = 0; 
    top->eval();
    if (top->vid_we) fb[top->vid_y][top->vid_x] = top->vid_data;   // sample before the edge
    top->clk = 1; 
    top->eval();
}

static void run_frame() { 
    for (int i = 0; i < CLOCKS_PER_FRAME; i++) {
        tick(); 
    }
}

static void reset() {
    top->srst = 1; 
    for (int i = 0; i < 4; i++) {
        tick();
    }
    top->srst = 0; 
    tick();
}

// very simple computer player: follow the ball with a little delay and simulated sloppiness
static void ai(bool left, int& up, int& down) {
    int paddle_c = (left ? top->p1_y : top->p2_y) + 5;
    int ball_c   = top->ball_y + 1;
    int d        = ball_c - paddle_c;
    up = d < -2;
    down = d > 2;
}

static uint32_t shade(uint8_t v) { 
    uint32_t g = v * 17; 
    return 0xFF000000u | g << 16 | g << 8 | g; 
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vtop;
    bool ai1 = false, ai2 = false, headless = false;
    int  headless_frames = 0; 
    const char* out = nullptr;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--ai1")) {
            ai1 = true;
        }
        else if (!strcmp(argv[i], "--ai2")) {
            ai2 = true;
        }
        else if (!strcmp(argv[i], "--headless") && i + 1 < argc) {
            headless = true; 
            headless_frames = atoi(argv[++i]);
            if (i + 1 < argc && argv[i + 1][0] != '-') {}
            out = argv[++i];
        }
    }

    top->p1_up = top->p1_down = top->p2_up = top->p2_down = 0;
    reset();

    // not exactly needed.... just included for testing in case you need it
    if (headless) 
    {
        int last1 = 0, last2 = 0;
        for (int f = 0; f < headless_frames; f++) {
            int u, d;
            if (ai1) { 
                ai(true, u, d);  
                top->p1_up = u; 
                top->p1_down = d; 
            }
            if (ai2) { 
                ai(false, u, d); 
                top->p2_up = u; 
                top->p2_down = d; 
            }
            run_frame();
            int s1 = top->p1_score + (top->p1_ten ? 0 : 0), s2 = top->p2_score;
            if (s1 != last1 || s2 != last2) { 
                printf("frame %d: score %d - %d%s\n", f, s1, s2, top->game_over ? "  GAME OVER" : ""); 
                last1 = s1; 
                last2 = s2; 
            }
        }
        printf("final: %d - %d  game_over=%d ball=(%d,%d) p1_y=%d p2_y=%d\n", top->p1_score, top->p2_score, top->game_over, top->ball_x, top->ball_y, top->p1_y, top->p2_y);
        if (out) { 
            FILE* fp = fopen(out, "wb"); 
            fprintf(fp, "P5\n%d %d\n15\n", W, H); 
            fwrite(fb, 1, W * H, fp); 
            fclose(fp); 
        }
        delete top; 
        return 0;
    }

    if (!SDL_Init(SDL_INIT_VIDEO)) { 
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError()); 
        return 1; 
    }
    SDL_Window*   win = SDL_CreateWindow("pong", W * SCALE, H * SCALE, 0);
    SDL_Renderer* ren = win ? SDL_CreateRenderer(win, nullptr) : nullptr;
    if (!win || !ren) { 
        fprintf(stderr, "SDL window/renderer: %s\n", SDL_GetError()); 
        return 1; 
    }
    SDL_SetRenderVSync(ren, 1);
    SDL_SetRenderLogicalPresentation(ren, W, H, SDL_LOGICAL_PRESENTATION_LETTERBOX);
    SDL_Texture*  tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, W, H);
    SDL_SetTextureScaleMode(tex, SDL_SCALEMODE_NEAREST);

    bool running = true;
    while (running) {
        Uint64 t0 = SDL_GetTicks();
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_EVENT_QUIT) {
                running = false;
            }
            if (e.type == SDL_EVENT_KEY_DOWN && e.key.scancode == SDL_SCANCODE_ESCAPE) {
                running = false;
            }
            if (e.type == SDL_EVENT_KEY_DOWN && e.key.scancode == SDL_SCANCODE_R) {
                reset();
            }
        }
        const bool* k = SDL_GetKeyboardState(nullptr);
        int u, d;
        top->p1_up = k[SDL_SCANCODE_W];  
        top->p1_down = k[SDL_SCANCODE_S];
        top->p2_up = k[SDL_SCANCODE_UP]; 
        top->p2_down = k[SDL_SCANCODE_DOWN];
        if (ai1) { 
            ai(true, u, d);  
            top->p1_up = u; 
            top->p1_down = d; 
        }
        if (ai2) { 
            ai(false, u, d); 
            top->p2_up = u; 
            top->p2_down = d; 
        }

        run_frame();

        uint32_t px[W * H];
        for (int y = 0; y < H; y++) {
            for (int x = 0; x < W; x++) {
                px[y * W + x] = shade(fb[y][x]);
            }
        }
        SDL_UpdateTexture(tex, nullptr, px, W * 4);
        SDL_RenderClear(ren); 
        SDL_RenderTexture(ren, tex, nullptr, nullptr); 
        SDL_RenderPresent(ren);

        char title[96];
        snprintf(title, sizeof title, "pong  %d - %d%s", top->p1_score, top->p2_score, top->game_over ? "  GAME OVER (R to restart)" : "");
        SDL_SetWindowTitle(win, title);

        Uint64 dt = SDL_GetTicks() - t0;
        if (dt < 16) SDL_Delay((Uint32)(16 - dt));          // ~60 fps
    }
    SDL_DestroyTexture(tex); 
    SDL_DestroyRenderer(ren); 
    SDL_DestroyWindow(win); 
    SDL_Quit();
    delete top; 
    return 0;
}