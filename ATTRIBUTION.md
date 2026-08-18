# Pochodzenie i licencje materiałów

Kod gry: licencja MIT (patrz `LICENSE`).

## Silnik

- **Godot Engine 4.3+** — licencja MIT. https://godotengine.org

## Czcionki (`assets/fonts/`)

| Plik | Krój | Licencja |
|---|---|---|
| `EBGaramond-Regular/Medium/Bold.ttf` | EB Garamond | SIL Open Font License 1.1 |
| `EBGaramond12-Regular/Bold/Italic.ttf` | EB Garamond 12 | SIL Open Font License 1.1 |
| `GreatVibes-Regular.ttf` | Great Vibes | SIL Open Font License 1.1 |
| `Almendra-Regular.ttf` | Almendra | SIL Open Font License 1.1 |

Pełny tekst licencji: `assets/fonts/OFL.txt`. OFL pozwala na użycie komercyjne,
w tym w grze sprzedawanej odpłatnie.

## Grafiki interfejsu (`assets/ui/`)

Przygotowane z paczki **Kronikarz Asset Pack Extended**, dostarczonej przez
autora projektu. Skrypt `tools/build_ui.py` je przycina, skaluje i dorabia
wypełnienia pasków.

> **Do uzupełnienia przed publikacją.** Autor projektu musi potwierdzić, na
> jakiej licencji otrzymał tę paczkę i czy wolno jej używać komercyjnie.

## Dźwięki interfejsu (`assets/audio/`)

`click.wav`, `back.wav` — wygenerowane na potrzeby projektu, bez zewnętrznych
praw.

## Muzyka (`assets/music/`)

| Plik | Tytuł | Autor | Narzędzie |
|---|---|---|---|
| `the_hollow_crown_1.mp3` | The Hollow Crown 1 | Łukasz TM | AI Music Factory (aimusicfactory.ai) |
| `the_hollow_crown_2.mp3` | The Hollow Crown 2 | Łukasz TM | AI Music Factory (aimusicfactory.ai) |

Oba utwory stworzył autor projektu w serwisie AI Music Factory. Prawa do nich
przysługują autorowi projektu; nie są to materiały z biblioteki stockowej ani
cudze nagrania, więc nie ma tu obowiązku podawania trzeciej strony.

> **Jedna rzecz do potwierdzenia przed sprzedażą gry.** Serwisy generujące
> muzykę zwykle wiążą prawa do użycia komercyjnego z rodzajem wykupionego
> planu — na darmowym bywa ono wyłączone albo wymaga wzmianki o narzędziu.
> Sprawdź w swoim regulaminie i podsumowaniu konta, czy plan, na którym
> powstały te utwory, obejmuje użycie komercyjne. Jeśli tak, ten wpis jest
> kompletny. Jeśli regulamin wymaga podania narzędzia — wiersz „Narzędzie”
> powyżej to spełnia i wystarczy pokazać ten plik przy grze.

Gra działa bez tych plików: wystarczy opróżnić `assets/music/`, a odtwarzacz
po prostu zamilknie. Gracz może wtedy wrzucić własne utwory do katalogu
`muzyka` w danych gry.
