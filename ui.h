// ui.h 
// software-rendered game ui for sim_main.cpp (menus, hud, pause, game over).
// no sdl and no verilator in here, so it can be built and previewed on its own (see tools/ui_preview.cpp).
// the verilog still draws the field (paddles, ball, net, score digits) on its 128x64 grid 
// this just scales that up, dims it under menus, and draws everything else at window resolution
#pragma once
#include <cstdint>
#include <cstring>

namespace ui {

static const int FW = 128, FH = 64, SCALE = 8;
static const int HUD_H = 56;
static const int WIN_W = FW * SCALE, WIN_H = FH * SCALE + HUD_H;

enum Screen { S_TITLE, S_DIFF, S_COUNT, S_PLAY, S_PAUSE, S_OVER };

struct View {
    Screen screen = S_TITLE;
    int sel = 0;                 // highlighted menu row
    int count = 3;               // countdown digit
    int s1 = 0, s2 = 0;          // scores
    int m1 = 0, m2 = 0;          // smash meters 0..3
    bool armed1 = false, armed2 = false;
    bool ai1 = false, ai2 = true;
    int lvl1 = 1, lvl2 = 1;      // 0 easy .. 3 insane
    bool muted = false;
    int frame = 0;               // for blinking
    int winner = 0;              // 1 or 2 on game over
    bool diff_for_two_cpu = false;
};

static const uint32_t COL_BG = 0xFF000000, COL_HUD = 0xFF0E1620, COL_LINE = 0xFF263445;
static const uint32_t COL_WHITE = 0xFFF2F2F2, COL_DIM = 0xFF7A8794, COL_AMBER = 0xFFFFB000;
static const uint32_t COL_P1 = 0xFF40C8FF, COL_P2 = 0xFFFF6090;

// 5x7 font, one byte per row, bit 4 = leftmost pixel
struct Glyph { char c; uint8_t r[7]; };
static const Glyph FONT[] = {
    {'A',{0x0E,0x11,0x11,0x1F,0x11,0x11,0x11}}, {'B',{0x1E,0x11,0x11,0x1E,0x11,0x11,0x1E}},
    {'C',{0x0E,0x11,0x10,0x10,0x10,0x11,0x0E}}, {'D',{0x1E,0x11,0x11,0x11,0x11,0x11,0x1E}},
    {'E',{0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F}}, {'F',{0x1F,0x10,0x10,0x1E,0x10,0x10,0x10}},
    {'G',{0x0E,0x11,0x10,0x17,0x11,0x11,0x0F}}, {'H',{0x11,0x11,0x11,0x1F,0x11,0x11,0x11}},
    {'I',{0x0E,0x04,0x04,0x04,0x04,0x04,0x0E}}, {'J',{0x07,0x02,0x02,0x02,0x02,0x12,0x0C}},
    {'K',{0x11,0x12,0x14,0x18,0x14,0x12,0x11}}, {'L',{0x10,0x10,0x10,0x10,0x10,0x10,0x1F}},
    {'M',{0x11,0x1B,0x15,0x15,0x11,0x11,0x11}}, {'N',{0x11,0x11,0x19,0x15,0x13,0x11,0x11}},
    {'O',{0x0E,0x11,0x11,0x11,0x11,0x11,0x0E}}, {'P',{0x1E,0x11,0x11,0x1E,0x10,0x10,0x10}},
    {'Q',{0x0E,0x11,0x11,0x11,0x15,0x12,0x0D}}, {'R',{0x1E,0x11,0x11,0x1E,0x14,0x12,0x11}},
    {'S',{0x0F,0x10,0x10,0x0E,0x01,0x01,0x1E}}, {'T',{0x1F,0x04,0x04,0x04,0x04,0x04,0x04}},
    {'U',{0x11,0x11,0x11,0x11,0x11,0x11,0x0E}}, {'V',{0x11,0x11,0x11,0x11,0x11,0x0A,0x04}},
    {'W',{0x11,0x11,0x11,0x15,0x15,0x15,0x0A}}, {'X',{0x11,0x11,0x0A,0x04,0x0A,0x11,0x11}},
    {'Y',{0x11,0x11,0x0A,0x04,0x04,0x04,0x04}}, {'Z',{0x1F,0x01,0x02,0x04,0x08,0x10,0x1F}},
    {'0',{0x0E,0x11,0x13,0x15,0x19,0x11,0x0E}}, {'1',{0x04,0x0C,0x04,0x04,0x04,0x04,0x0E}},
    {'2',{0x0E,0x11,0x01,0x02,0x04,0x08,0x1F}}, {'3',{0x1F,0x02,0x04,0x02,0x01,0x11,0x0E}},
    {'4',{0x02,0x06,0x0A,0x12,0x1F,0x02,0x02}}, {'5',{0x1F,0x10,0x1E,0x01,0x01,0x11,0x0E}},
    {'6',{0x06,0x08,0x10,0x1E,0x11,0x11,0x0E}}, {'7',{0x1F,0x01,0x02,0x04,0x08,0x08,0x08}},
    {'8',{0x0E,0x11,0x11,0x0E,0x11,0x11,0x0E}}, {'9',{0x0E,0x11,0x11,0x0F,0x01,0x02,0x0C}},
    {'-',{0x00,0x00,0x00,0x1F,0x00,0x00,0x00}}, {':',{0x00,0x04,0x00,0x00,0x00,0x04,0x00}},
    {'.',{0x00,0x00,0x00,0x00,0x00,0x0C,0x0C}}, {'!',{0x04,0x04,0x04,0x04,0x04,0x00,0x04}},
    {'<',{0x02,0x04,0x08,0x10,0x08,0x04,0x02}}, {'>',{0x08,0x04,0x02,0x01,0x02,0x04,0x08}},
    {'/',{0x01,0x01,0x02,0x04,0x08,0x10,0x10}}, {'?',{0x0E,0x11,0x01,0x02,0x04,0x00,0x04}},
};

static inline const Glyph* find_glyph(char c) {
    if (c >= 'a' && c <= 'z') c = (char)(c - 32);
    for (const Glyph& g : FONT) if (g.c == c) return &g;
    return nullptr;
}

struct Canvas {
    uint32_t* px;
    void rect(int x, int y, int w, int h, uint32_t c) const {
        for (int j = y < 0 ? 0 : y; j < y + h && j < WIN_H; j++)
            for (int i = x < 0 ? 0 : x; i < x + w && i < WIN_W; i++) px[j * WIN_W + i] = c;
    }
    static int text_w(const char* s, int sc) { return (int)strlen(s) * 6 * sc - sc; }
    void text(int x, int y, int sc, const char* s, uint32_t c) const {
        for (; *s; s++, x += 6 * sc) {
            const Glyph* g = find_glyph(*s);
            if (!g) continue;
            for (int r = 0; r < 7; r++)
                for (int b = 0; b < 5; b++)
                    if (g->r[r] & (0x10 >> b)) rect(x + b * sc, y + r * sc, sc, sc, c);
        }
    }
    void text_c(int cx, int y, int sc, const char* s, uint32_t c) const { text(cx - text_w(s, sc) / 2, y, sc, s, c); }
    void text_r(int rx, int y, int sc, const char* s, uint32_t c) const { text(rx - text_w(s, sc), y, sc, s, c); }
    void dim_field() const {                        // 25% brightness under menus
        for (int j = 0; j < FH * SCALE; j++)
            for (int i = 0; i < WIN_W; i++) {
                uint32_t p = px[j * WIN_W + i];
                px[j * WIN_W + i] = 0xFF000000u | (((p >> 18) & 0x3F) << 16) | (((p >> 10) & 0x3F) << 8) | ((p >> 2) & 0x3F);
            }
    }
};

static const char* const LEVEL_NAME[4] = {"EASY", "MEDIUM", "HARD", "INSANE"};
static const char* const TITLE_ITEMS[4] = {"1 PLAYER", "2 PLAYERS", "CPU VS CPU", "QUIT"};

static inline int menu_count(Screen s) { return s == S_TITLE ? 4 : s == S_DIFF ? 4 : s == S_PAUSE ? 3 : s == S_OVER ? 2 : 0; }

static inline void menu(const Canvas& cv, const char* const* items, int n, int sel, int y0, int sc, int frame) {
    for (int i = 0; i < n; i++) {
        int y = y0 + i * (sc * 7 + 22);
        if (i == sel) {
            bool on = (frame / 20) % 2 == 0;
            cv.text_c(WIN_W / 2, y, sc, items[i], COL_AMBER);
            int w = Canvas::text_w(items[i], sc) / 2 + 28;
            if (on) { cv.text_c(WIN_W / 2 - w, y, sc, ">", COL_AMBER); cv.text_c(WIN_W / 2 + w, y, sc, "<", COL_AMBER); }
        } else cv.text_c(WIN_W / 2, y, sc, items[i], COL_DIM);
    }
}

static inline void side_hud(const Canvas& cv, bool left, int meter, bool armed, bool ai, int lvl, uint32_t col, int frame, bool two_ai) {
    const int y = FH * SCALE;
    char label[32];
    if (ai) snprintf(label, sizeof label, "CPU %s", LEVEL_NAME[lvl & 3]);
    else snprintf(label, sizeof label, left ? "P1" : "P2");
    int x0 = left ? 20 : WIN_W - 20;
    if (left) cv.text(x0, y + 8, 3, label, col); else cv.text_r(x0, y + 8, 3, label, col);
    // three pips for the smash meter; flash the whole row when armed
    bool flash = armed && (frame / 4) % 2 == 0;
    for (int i = 0; i < 3; i++) {
        int w = 34, h = 14, gap = 8;
        int px_ = left ? x0 + i * (w + gap) : x0 - w - i * (w + gap);
        uint32_t c = flash ? COL_WHITE : (i < meter ? col : COL_LINE);
        cv.rect(px_, y + 34, w, h, c);
    }
    if (armed) {
        int tx = left ? x0 + 3 * 42 + 6 : x0 - 3 * 42 - 6;
        if (left) cv.text(tx, y + 33, 2, "SMASH!", COL_AMBER); else cv.text_r(tx, y + 33, 2, "SMASH!", COL_AMBER);
    } else if (meter == 3) {
        int tx = left ? x0 + 3 * 42 + 6 : x0 - 3 * 42 - 6;
        if (left) cv.text(tx, y + 33, 2, "READY", COL_DIM); else cv.text_r(tx, y + 33, 2, "READY", COL_DIM);
    }
    (void)two_ai;
}

// field: 128x64 4-bit framebuffer from the verilog; out: WIN_W*WIN_H argb pixels
static inline void render(uint32_t* out, const uint8_t field[FH][FW], const View& v) {
    Canvas cv{out};
    for (int y = 0; y < FH; y++)
        for (int x = 0; x < FW; x++) {
            uint32_t g = field[y][x] * 17u;
            cv.rect(x * SCALE, y * SCALE, SCALE, SCALE, 0xFF000000u | g << 16 | g << 8 | g);
        }
    cv.rect(0, FH * SCALE, WIN_W, HUD_H, COL_HUD);
    cv.rect(0, FH * SCALE, WIN_W, 2, COL_LINE);

    bool in_game = v.screen == S_COUNT || v.screen == S_PLAY || v.screen == S_PAUSE || v.screen == S_OVER;
    if (in_game) {
        side_hud(cv, true, v.m1, v.armed1, v.ai1, v.lvl1, COL_P1, v.frame, false);
        side_hud(cv, false, v.m2, v.armed2, v.ai2, v.lvl2, COL_P2, v.frame, false);
        cv.text_c(WIN_W / 2, FH * SCALE + 8, 3, "FIRST TO 10", COL_DIM);
        cv.text_c(WIN_W / 2, FH * SCALE + 34, 2, v.muted ? "M: UNMUTE   P: PAUSE" : "M: MUTE   P: PAUSE", COL_DIM);
    } else {
        cv.text_c(WIN_W / 2, FH * SCALE + 12, 2, "UP/DOWN: MOVE   ENTER: SELECT   ESC: BACK", COL_DIM);
        cv.text_c(WIN_W / 2, FH * SCALE + 34, 2, v.muted ? "M: UNMUTE" : "M: MUTE", COL_DIM);
    }

    switch (v.screen) {
    case S_TITLE: {
        cv.dim_field();
        cv.text_c(WIN_W / 2, 40, 18, "PONG", COL_WHITE);
        cv.text_c(WIN_W / 2, 190, 4, "VERILOG EDITION", COL_AMBER);
        menu(cv, TITLE_ITEMS, 4, v.sel, 262, 4, v.frame);
        break; }
    case S_DIFF: {
        cv.dim_field();
        cv.text_c(WIN_W / 2, 60, 8, "DIFFICULTY", COL_WHITE);
        menu(cv, LEVEL_NAME, 4, v.sel, 170, 5, v.frame);
        cv.text_c(WIN_W / 2, 430, 3, "W/S OR D: PLAYER 1     SPACE OR LEFT: SMASH", COL_DIM);
        break; }
    case S_COUNT: {
        cv.dim_field();
        char d[2] = {(char)('0' + v.count), 0};
        cv.text_c(WIN_W / 2, 150, 24, d, COL_AMBER);
        cv.text_c(WIN_W / 2, 380, 4, "GET READY", COL_DIM);
        break; }
    case S_PAUSE: {
        cv.dim_field();
        cv.text_c(WIN_W / 2, 70, 12, "PAUSED", COL_WHITE);
        static const char* const items[3] = {"RESUME", "RESTART", "MAIN MENU"};
        menu(cv, items, 3, v.sel, 220, 4, v.frame);
        break; }
    case S_OVER: {
        cv.dim_field();
        char msg[24];
        if (v.ai1 && v.ai2) snprintf(msg, sizeof msg, "CPU %d WINS", v.winner);
        else if (v.ai2 && !v.ai1) snprintf(msg, sizeof msg, v.winner == 1 ? "YOU WIN!" : "CPU WINS");
        else snprintf(msg, sizeof msg, "PLAYER %d WINS", v.winner);
        cv.text_c(WIN_W / 2, 60, 9, msg, v.winner == 1 ? COL_P1 : COL_P2);
        char sc[16]; snprintf(sc, sizeof sc, "%d - %d", v.s1, v.s2);
        cv.text_c(WIN_W / 2, 170, 7, sc, COL_WHITE);
        static const char* const items[2] = {"REMATCH", "MAIN MENU"};
        menu(cv, items, 2, v.sel, 290, 4, v.frame);
        break; }
    case S_PLAY: break;
    }
}

} // namespace ui