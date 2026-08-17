# Przygotowanie grafik interfejsu

`assets/ui/*.png` powstają z paczki **Kronikarz Asset Pack Extended**
(`backgrounds/`, `buttons/`, `frames/`, `bars/`, `controls/`, `ornaments/`).
Grafiki z paczki są czyste — nie mają wtopionego tekstu — więc skrypt tylko je
przycina, skaluje i dokłada to, czego w paczce nie ma.

`build_ui.py` robi trzy rzeczy:

1. **Przycina przezroczyste marginesy.** Okucia i ramy przychodzą w kadrach
   2172×724 z szerokim pustym obramowaniem. Bez przycięcia marginesy 9-patcha
   wypadłyby w pustce i przycisk rozjechałby się przy rozciąganiu.
2. **Skaluje do rozmiarów użytkowych** (przestrzeń rysowania gry to 1672×941).
   Pełne kadry ważą po 2 MB; w grze wystarczy 300–760 px szerokości.
3. **Dorabia wypełnienia pasków.** Paczka daje samą ramę paska
   (`bars/progress_bar_frame.png`). Skrypt znajduje w niej szczelinę — najdłuższy
   ciągły ciemny odcinek w kolumnie przez środek — i generuje trzy wypełnienia
   (zdrowie, mana, PD) dokładnie w jej obrysie, z zaokrąglonymi końcami.
   Rama jest budowana w wysokości, w jakiej gra ją rysuje (46 px), więc
   rozciąga się tylko w poziomie i ozdobne końcówki zostają nietknięte.

## Uruchomienie

```
pip install Pillow numpy
# obok skryptu katalog incoming/ z rozpakowaną paczką
python3 build_ui.py       # wynik w ui_out3/
```

Potem skopiuj `ui_out3/*.png` do `assets/ui/`.

## Podmiana na własne grafiki

Nie trzeba ruszać kodu — wystarczy podmienić pliki w `assets/ui/` przy
zachowaniu nazw i proporcji. Dwie rzeczy trzeba wtedy sprawdzić w `src/ui/Ui.gd`:

- marginesy 9-patcha przy wywołaniach `_sbt(nazwa, mx, my, cx, cy)` —
  `mx`/`my` to nierozciągane narożniki grafiki, `cx`/`cy` to miejsce na napis;
- stałe `M_*` i `P_*` — obszary, w których gra rysuje kontrolki na tle
  (współrzędne w przestrzeni 1672×941).
