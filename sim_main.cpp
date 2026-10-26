// sim_main.cpp - Verilator + SDL3 front end for the Verilog pong.
//   W/S = left paddle, Up/Down = right paddle, R = reset, Esc = quit
//   --ai1 / --ai2 : let the Verilog ai_paddle drive that paddle
//   --level N (0 easy .. 3 insane), or --level1 N / --level2 N per side
//   --mute : no sound (M toggles it in the window)    --wav out.wav : with --headless, also dump the audio
//   --headless N [out.ppm] : run N frames with no window (for simulated monte carlo runs)
#include <SDL3/SDL.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>
#include <cstdint>
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

// ---- audio: the Verilog beeper is a 1-bit line clocked at 64*64*60 Hz. Box-filter it down to 48 kHz
// (exactly 800 samples per 4096-clock frame) and strip DC so on/off steps don't click.
static const int SAMPLE_RATE = 48000, SAMPLES_PER_FRAME = 800;
static int16_t audio_buf[SAMPLES_PER_FRAME];
static std::vector<int16_t> wav_samples;
static bool record_wav = false;

static void run_frame() { 
    static int sum = 0, cnt = 0;
    static float x1 = 0.f, y1 = 0.f;                 // DC blocker state
    int n = 0;
    for (int i = 0; i < CLOCKS_PER_FRAME; i++) {
        tick(); 
        sum += top->beep; 
        cnt++;
        if ((i + 1) * SAMPLES_PER_FRAME / CLOCKS_PER_FRAME > i * SAMPLES_PER_FRAME / CLOCKS_PER_FRAME) {
            float x = (float)sum / cnt;              // 0..1 average of the beep line
            float y = x - x1 + 0.995f * y1;
            x1 = x; 
            y1 = y;
            audio_buf[n++] = (int16_t)(y * 9000.f);
            sum = 0; 
            cnt = 0;
        }
    }
    if (record_wav) {
        wav_samples.insert(wav_samples.end(), audio_buf, audio_buf + n);
    }
}

static void write_wav(const char* path) {
    FILE* fp = fopen(path, "wb");
    if (!fp) return;
    uint32_t data_bytes = (uint32_t)(wav_samples.size() * 2), riff = 36 + data_bytes, fmt = 16, rate = SAMPLE_RATE, byte_rate = SAMPLE_RATE * 2;
    uint16_t pcm = 1, ch = 1, align = 2, bits = 16;
    fwrite("RIFF", 1, 4, fp); fwrite(&riff, 4, 1, fp); fwrite("WAVEfmt ", 1, 8, fp); fwrite(&fmt, 4, 1, fp);
    fwrite(&pcm, 2, 1, fp); fwrite(&ch, 2, 1, fp); fwrite(&rate, 4, 1, fp); fwrite(&byte_rate, 4, 1, fp);
    fwrite(&align, 2, 1, fp); fwrite(&bits, 2, 1, fp); fwrite("data", 1, 4, fp); fwrite(&data_bytes, 4, 1, fp);
    fwrite(wav_samples.data(), 2, wav_samples.size(), fp);
    fclose(fp);
}

static void reset() {
    top->srst = 1; 
    for (int i = 0; i < 4; i++) {
        tick();
    }
    top->srst = 0; 
    tick();
}

static uint32_t shade(uint8_t v) { 
    uint32_t g = v * 17; 
    return 0xFF000000u | g << 16 | g << 8 | g; 
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    top = new Vtop;
    bool ai1 = false, ai2 = false, headless = false;
    int level1 = 2, level2 = 2;
    bool mute = false;
    const char* wav_path = nullptr;
    int headless_frames = 0; 
    const char* out = nullptr;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--ai1")) {
            ai1 = true;
        }
        else if (!strcmp(argv[i], "--level") && i + 1 < argc) {
            level1 = level2 = atoi(argv[++i]) & 3;
        }
        else if (!strcmp(argv[i], "--level1") && i + 1 < argc) {
            level1 = atoi(argv[++i]) & 3;
        }
        else if (!strcmp(argv[i], "--level2") && i + 1 < argc) {
            level2 = atoi(argv[++i]) & 3;
        }
        else if (!strcmp(argv[i], "--mute")) {
            mute = true;
        }
        else if (!strcmp(argv[i], "--wav") && i + 1 < argc) {
            wav_path = argv[++i];
            record_wav = true;
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
    // opponents live in ai_paddle.v
    top->ai1_en = ai1; 
    top->ai2_en = ai2;
    top->ai1_diff = level1; 
    top->ai2_diff = level2;
    reset();

    // not exactly needed.... just included for testing in case you want to do monte carlo runs on the ai, might have to cook up something to get stats running monte carlo runs to get probabilities n shit
    // only if like you want the nerdy stats n shit ill do it later if i got time
    if (headless) 
    {
        int last1 = 0, last2 = 0;
        for (int f = 0; f < headless_frames; f++) {
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
        if (wav_path) {
            write_wav(wav_path);
        }
        delete top; 
        return 0;
    }

    // sdl plumbing bs
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO)) { 
        fprintf(stderr, "SDL_Init: %s\n", SDL_GetError()); 
        return 1; 
    }
    SDL_Window*   win = SDL_CreateWindow("pong", W * SCALE, H * SCALE, 0);
    SDL_Renderer* ren = win ? SDL_CreateRenderer(win, nullptr) : nullptr;
    if (!win || !ren) { 
        fprintf(stderr, "SDL window/renderer: %s\n", SDL_GetError()); 
        return 1; 
    }
    // audio is optional: if the device won't open the game just runs silent
    bool muted = false;
    SDL_AudioStream* astream = nullptr;
    if (!mute) {
        SDL_AudioSpec spec;
        SDL_zero(spec);
        spec.format = SDL_AUDIO_S16;
        spec.channels = 1;
        spec.freq = SAMPLE_RATE;
        astream = SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec, nullptr, nullptr);
        if (astream) {
            SDL_ResumeAudioStreamDevice(astream);
        } else {
            fprintf(stderr, "audio disabled: %s\n", SDL_GetError());
        }
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
            if (e.type == SDL_EVENT_KEY_DOWN && e.key.scancode == SDL_SCANCODE_M) {
                muted = !muted;
            }
            if (e.type == SDL_EVENT_KEY_DOWN && e.key.scancode == SDL_SCANCODE_R) {
                reset();
            }
        }
        const bool* k = SDL_GetKeyboardState(nullptr);
        top->p1_up = k[SDL_SCANCODE_W];
        top->p1_down = k[SDL_SCANCODE_S];
        top->p2_up = k[SDL_SCANCODE_UP]; 
        top->p2_down = k[SDL_SCANCODE_DOWN];

        run_frame();
        // keep latency bounded: if more than ~3 frames are already queued, drop this frame's audio
        if (astream && !muted && SDL_GetAudioStreamQueued(astream) < 3 * SAMPLES_PER_FRAME * 2) {
            SDL_PutAudioStreamData(astream, audio_buf, SAMPLES_PER_FRAME * (int)sizeof(int16_t));
        }

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
    if (astream) {
        SDL_DestroyAudioStream(astream);
    }
    SDL_DestroyTexture(tex); 
    SDL_DestroyRenderer(ren); 
    SDL_DestroyWindow(win); 
    SDL_Quit();
    delete top; 
    return 0;
}