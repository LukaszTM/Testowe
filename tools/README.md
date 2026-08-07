# Skrypty do przygotowania grafik interfejsu

`assets/ui/*.png` nie są rysowane ręcznie — powstają automatycznie z dwóch
makiet koncepcyjnych (`menu_full.png`, `game_full.png`, 1672×941). Makiety mają
tekst wtopiony w piksele, więc do gry trzeba go najpierw usunąć.

- `lib_wipe.py` — usuwanie napisów. Tło pod wymazanym prostokątem jest
  odtwarzane przez dyfuzję koloru papieru z otoczenia, a ziarno i plamy
  pergaminu doklejane z zweryfikowanych, czystych wycinków tej samej karty
  (sklejanie z zakładką i losowym przesunięciem, żeby nie było widać
  powtórzeń). `restore_ink` przywraca sam rysunek ornamentu na nowym papierze.
  `cut_from_paper` wycina okucia przycisków z otaczającego pergaminu, licząc
  alfę z odległości od koloru papieru. `drop_center_ornament` usuwa ozdobę ze
  środka listwy, żeby ramkę dało się rozciągać jako 9-patch.
- `build_ui.py` — właściwy przepis: co i gdzie wymazać, co przywrócić,
  jak pociąć przyciski i paski.

## Uruchomienie

```
pip install Pillow numpy
# obok skryptu potrzebny katalog gui_zip/Kronikarz_GUI_Godot/assets z makietami
python3 build_ui.py          # wynik ląduje w ui_out/
```

Potem skopiuj `ui_out/*.png` do `assets/ui/`.

## Podmiana na własne grafiki

Jeśli zamówisz nowe ilustracje, nie musisz ruszać kodu — wystarczy podmienić
pliki w `assets/ui/` przy zachowaniu nazw i proporcji. Współrzędne obszarów,
w których gra rysuje żywe kontrolki, siedzą w `src/ui/Ui.gd` jako stałe `R_*`
(w przestrzeni 1672×941).
