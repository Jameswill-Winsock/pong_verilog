# make       -> build ./pong   (needs verilator, g++, make, SDL3 dev files)
# make run   -> build and play
SRC = top.v netdraw.v paddle_logic.v paddle_draw.v ball_logic.v score_display.v score_counter.v

SDL_CFLAGS := $(shell pkg-config --cflags sdl3)
SDL_LIBS   := $(shell pkg-config --libs sdl3)

# Two steps (generate C++, then compile/link) so SDL flags never go through
# Verilator's own option parser, which differs between versions.
pong: $(SRC) sim_main.cpp
	verilator -Wno-fatal --cc --exe --top-module top -Mdir obj_dir $(SRC) sim_main.cpp -o pong
	$(MAKE) -C obj_dir -f Vtop.mk VM_USER_CFLAGS="$(SDL_CFLAGS)" VM_USER_LDLIBS="$(SDL_LIBS)"
	cp obj_dir/pong ./pong

run: pong
	./pong

clean:
	rm -rf obj_dir pong

.PHONY: run clean