// sim_main.cpp - Verilator + SDL3 front end for the verilog pong.
//   title screen -> pick 1 player / 2 players / cpu vs cpu -> (difficulty) -> 3-2-1 -> game (see ui.h)
//   in game: W/S = left paddle, D or Space = left smash, Up/Down = right paddle, Left = right smash
//            (in 1 player mode the arrows work for you too), P = pause, R = restart, M = mute, Esc = pause/back
//   --ai1 / --ai2 : let the verilog ai_paddle drive that paddle
//   --level N (0 easy .. 3 insane), or --level1 N / --level2 N per side
//   --nomusic : no soundtrack (sound effects only)
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
#include "ui.h"

double sc_time_stamp() { return 0.0; }

static const int W = 128, H = 64, SCALE = 8, CLOCKS_PER_FRAME = W * H;
static Vtop* top;
static uint8_t fb[H][W];

static void tick() {
    top->clk = 0; 
    top->eval(); 
    if (top->vid_we) fb[top->vid_y][top->vid_x] = top->vid_data;   // sample before the edge
    top->clk = 1; 
    top->eval();
}

// audio
// the verilog beeper is a 1-bit line clocked at 128*64*60 Hz
// so we box-filter it down to 48 kHz
// (exactly 800 samples per 4096-clock frame) and strip DC so on/off steps don't click
static const int SAMPLE_RATE = 48000, SAMPLES_PER_FRAME = 800;
static int16_t audio_buf[SAMPLES_PER_FRAME];
static std::vector<int16_t> wav_samples;
static bool record_wav = false;
static bool use_music = true;

static void run_frame() { 
    static int sum = 0, cnt = 0;
    static float x1 = 0.f, y1 = 0.f;                 // DC blocker state
    int n = 0;
    for (int i = 0; i < CLOCKS_PER_FRAME; i++) {
        tick(); 
        sum += top->beep * 3 + top->music * 1 * (use_music ? 1 : 0);   // effects at 3 units, each music voice at 1
        cnt++;
        if ((i + 1) * SAMPLES_PER_FRAME / CLOCKS_PER_FRAME > i * SAMPLES_PER_FRAME / CLOCKS_PER_FRAME) {
            float x = (float)sum / (cnt * 6.f);      // 0..1: effects (3) + three music voices (3)
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
        else if (!strcmp(argv[i], "--nomusic")) {
            use_music = false;
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
    top->p1_smash = top->p2_smash = 0;
    top->music_en = 1;
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
    SDL_Window*   win = SDL_CreateWindow("pong", ui::WIN_W, ui::WIN_H, 0);
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
    SDL_SetRenderLogicalPresentation(ren, ui::WIN_W, ui::WIN_H, SDL_LOGICAL_PRESENTATION_LETTERBOX);
    SDL_Texture*  tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, ui::WIN_W, ui::WIN_H);
    SDL_SetTextureScaleMode(tex, SDL_SCALEMODE_NEAREST);

    // game flow: title (cpu vs cpu attract demo behind it) -> menus -> countdown -> play <-> pause -> game over
    // the verilog only gets clocked while the game is live, so pausing freezes the soundtrack in place too
    ui::View v;
    static uint32_t px[ui::WIN_W * ui::WIN_H];
    int mode = 0, level = 1;                       // mode 0 = 1 player, 1 = 2 players, 2 = cpu vs cpu
    int count_frames = 0;

    auto set_players = [&](bool a1, bool a2, int l1, int l2) {
        top->ai1_en = a1; top->ai2_en = a2; top->ai1_diff = l1; top->ai2_diff = l2;
        v.ai1 = a1; v.ai2 = a2; v.lvl1 = l1; v.lvl2 = l2;
    };
    auto go_title = [&]() {
        set_players(true, true, 1, 1);
        reset();
        v.screen = ui::S_TITLE; v.sel = 0;
    };
    auto start_game = [&]() {
        if (mode == 0) set_players(false, true, 0, level);
        else if (mode == 1) set_players(false, false, 0, 0);
        else set_players(true, true, level, level);
        reset();
        run_frame();                               // draw one frame so the countdown has a field behind it
        v.screen = ui::S_COUNT; v.count = 3; count_frames = 180;
    };
    auto pick = [&]() {                            // enter / space on a menu row
        switch (v.screen) {
        case ui::S_TITLE:
            if (v.sel == 3) return false;
            mode = v.sel;
            if (mode == 1) start_game(); else { v.screen = ui::S_DIFF; v.sel = level; }
            break;
        case ui::S_DIFF: level = v.sel; start_game(); break;
        case ui::S_PAUSE:
            if (v.sel == 0) v.screen = ui::S_PLAY;
            else if (v.sel == 1) start_game();
            else go_title();
            break;
        case ui::S_OVER:
            if (v.sel == 0) start_game(); else go_title();
            break;
        default: break;
        }
        return true;
    };
    go_title();

    bool running = true;
    while (running) {
        Uint64 t0 = SDL_GetTicks();
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_EVENT_QUIT) {
                running = false;
            }
            if (e.type != SDL_EVENT_KEY_DOWN) continue;
            SDL_Scancode sc = e.key.scancode;
            int rows = ui::menu_count(v.screen);
            bool in_game = v.screen == ui::S_PLAY || v.screen == ui::S_COUNT;
            if (sc == SDL_SCANCODE_M) {
                muted = !muted;
                v.muted = muted;
            }
            if (rows > 0) {
                if (sc == SDL_SCANCODE_UP || (sc == SDL_SCANCODE_W)) v.sel = (v.sel + rows - 1) % rows;
                if (sc == SDL_SCANCODE_DOWN || (sc == SDL_SCANCODE_S)) v.sel = (v.sel + 1) % rows;
                if (sc == SDL_SCANCODE_RETURN || sc == SDL_SCANCODE_KP_ENTER || sc == SDL_SCANCODE_SPACE) {
                    if (!pick()) running = false;
                }
            }
            if (sc == SDL_SCANCODE_ESCAPE) {
                switch (v.screen) {
                case ui::S_TITLE: running = false; break;
                case ui::S_DIFF: case ui::S_COUNT: case ui::S_OVER: go_title(); break;
                case ui::S_PLAY: v.screen = ui::S_PAUSE; v.sel = 0; break;
                case ui::S_PAUSE: v.screen = ui::S_PLAY; break;
                }
            }
            if (sc == SDL_SCANCODE_P) {
                if (v.screen == ui::S_PLAY) { v.screen = ui::S_PAUSE; v.sel = 0; }
                else if (v.screen == ui::S_PAUSE) v.screen = ui::S_PLAY;
            }
            if (sc == SDL_SCANCODE_R && (in_game || v.screen == ui::S_PAUSE)) start_game();
        }

        // inputs only matter while a game is live; in menus the cpu-vs-cpu attract demo runs on its own
        const bool* k = SDL_GetKeyboardState(nullptr);
        bool live = v.screen == ui::S_PLAY;
        bool one_p = (mode == 0);
        top->p1_up = live && (k[SDL_SCANCODE_W] || (one_p && k[SDL_SCANCODE_UP]));
        top->p1_down = live && (k[SDL_SCANCODE_S] || (one_p && k[SDL_SCANCODE_DOWN]));
        top->p1_smash = live && (k[SDL_SCANCODE_D] || k[SDL_SCANCODE_SPACE] || (one_p && k[SDL_SCANCODE_LEFT]));
        top->p2_up = live && k[SDL_SCANCODE_UP];
        top->p2_down = live && k[SDL_SCANCODE_DOWN];
        top->p2_smash = live && k[SDL_SCANCODE_LEFT];

        bool step = v.screen == ui::S_PLAY || v.screen == ui::S_TITLE || v.screen == ui::S_DIFF || v.screen == ui::S_OVER;
        top->music_en = v.screen != ui::S_OVER;
        if (step) {
            run_frame();
            // keep latency bounded: if more than ~3 frames are already queued, drop this frame's audio
            if (astream && !muted && SDL_GetAudioStreamQueued(astream) < 3 * SAMPLES_PER_FRAME * 2) {
                SDL_PutAudioStreamData(astream, audio_buf, SAMPLES_PER_FRAME * (int)sizeof(int16_t));
            }
        }
        if (v.screen == ui::S_COUNT && --count_frames <= 0) v.screen = ui::S_PLAY;
        if (v.screen == ui::S_COUNT) v.count = (count_frames + 59) / 60;
        if (top->game_over) {
            if (v.screen == ui::S_PLAY) { v.screen = ui::S_OVER; v.sel = 0; v.winner = top->p1_score > top->p2_score ? 1 : 2; }
            else if (v.screen == ui::S_TITLE || v.screen == ui::S_DIFF) reset();      // attract demo finished, start another
        }

        v.s1 = top->p1_score; v.s2 = top->p2_score;
        v.m1 = top->p1_meter; v.m2 = top->p2_meter;
        v.armed1 = top->p1_armed; v.armed2 = top->p2_armed;
        v.frame++;
        ui::render(px, fb, v);
        SDL_UpdateTexture(tex, nullptr, px, ui::WIN_W * 4);
        SDL_RenderClear(ren); 
        SDL_RenderTexture(ren, tex, nullptr, nullptr); 
        SDL_RenderPresent(ren);

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