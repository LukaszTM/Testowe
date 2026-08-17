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

| Plik | Tytuł | Autor | Licencja |
|---|---|---|---|
| `the_hollow_crown_1.mp3` | The Hollow Crown 1 | — | **do ustalenia** |
| `the_hollow_crown_2.mp3` | The Hollow Crown 2 | — | **do ustalenia** |

> **Do uzupełnienia przed publikacją.** Utwory dostarczył autor projektu i nie
> dołączono do nich informacji licencyjnej. Przed jakąkolwiek publikacją —
> także darmową — trzeba wpisać tu autora i licencję (albo potwierdzić własne
> prawa autorskie). Jeżeli utwory pochodzą z generatora muzyki, obowiązują
> warunki jego regulaminu; jeżeli z biblioteki stockowej — warunki tej
> biblioteki, zwykle łącznie z obowiązkiem podania autora.
>
> Gra działa bez tych plików: wystarczy usunąć zawartość `assets/music/`,
> a odtwarzacz po prostu zamilknie. Gracz może wtedy wrzucić własne utwory do
> katalogu `muzyka` w danych gry.
