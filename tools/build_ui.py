import os, numpy as np
from lib_wipe import load, save, wipe, restore_ink, clean_patches, wipe_label
SRC = "gui_zip/Kronikarz_GUI_Godot/assets/"
OUT = "ui_out"; os.makedirs(OUT, exist_ok=True)

menu = load(SRC+"backgrounds/menu_full.png")
game = load(SRC+"backgrounds/game_full.png")
grain = clean_patches(game, (120,120,1460,780), n=5, size=96, max_ink=0.009)

# ——————————————————————— PŁYTY TŁA ———————————————————————
m = menu.copy()
wipe(m, (893,148,494,548), grain, soft=30, seed=5)      # cała kolumna przycisków naraz
save(m, OUT+"/plate_menu.png")

g = game.copy()
for i, r in enumerate([
    (138,42,382,62), (1150,42,150,54), (1284,36,176,84), (1440,36,176,84),
    (152,110,896,592), (138,706,908,178), (1150,118,430,768),
]):
    wipe(g, r, grain, soft=11, seed=31+i)
for r in [(174,232,44,474), (960,232,44,474),
          (1146,112,40,42), (1550,112,36,42),
          (1146,852,40,40), (1552,852,34,38),
          (474,704,50,36), (718,704,50,36),
          (140,710,336,26), (764,710,282,26)]:
    restore_ink(g, game, r, soft=7)
save(g, OUT+"/plate_play.png")

# ——————————————————————— PRZYCISKI (9-patch) ———————————————————————
def plate(src, rect_text, pct=30, name=""):
    a = load(SRC+src)
    wipe_label(a, rect_text, soft=5, pct=pct)
    save(a, OUT+"/"+name)
    return a

plate("buttons/menu_new_story.png", (54,26,348,74), 34, "btn_wide_gold.png")
plate("buttons/menu_load.png",      (50,18,348,74), 30, "btn_wide.png")
plate("buttons/game_execute.png",   (24,14,146,48), 34, "btn_small_gold.png")
plate("buttons/game_menu.png",      (22,10,108,42), 30, "btn_small.png")
plate("buttons/game_choice_2.png",  (28,10,276,48), 30, "btn_choice.png")
plate("panels/game_command_input.png", (34,16,640,44), 34, "field.png")

# ——————————————————————— PASKI ———————————————————————
def bar_parts(src, fill_x, track_x, name_fill, name_track=None):
    a = load(SRC+src); h, w, _ = a.shape
    cap_l, cap_r = 10, 10
    fill = a.copy(); fill[:, cap_l:w-cap_r] = np.repeat(a[:, fill_x:fill_x+1], w-cap_l-cap_r, axis=1)
    save(fill, OUT+"/"+name_fill)
    if name_track:
        tr = a.copy(); tr[:, cap_l:w-cap_r] = np.repeat(a[:, track_x:track_x+1], w-cap_l-cap_r, axis=1)
        # lewy kapturek też musi być pusty
        tr[:, :cap_l] = np.repeat(a[:, track_x:track_x+1], cap_l, axis=1)
        save(tr, OUT+"/"+name_track)

bar_parts("bars/xp_bar.png", 120, 330, "bar_fill_gold.png", "bar_track.png")
bar_parts("bars/health_bar.png", 120, 330, "bar_fill_red.png")

# mana — przebarwiony pasek złoty na chłodny błękit
b = load(OUT+"/bar_fill_gold.png")
r, gg, bl = b[:,:,0], b[:,:,1], b[:,:,2]
lum = (r*0.35 + gg*0.45 + bl*0.20)
b[:,:,0] = lum*0.42; b[:,:,1] = lum*0.66; b[:,:,2] = np.clip(lum*1.05, 0, 255)
save(b, OUT+"/bar_fill_blue.png")

# ——————————————————————— DETALE ———————————————————————
import shutil
shutil.copy(SRC+"details/menu_footer_ornament.png", OUT+"/ornament.png")
shutil.copy(SRC+"details/menu_logo_area.png",       OUT+"/logo.png")
print("assety UI gotowe")
