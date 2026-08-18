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

Oba utwory stworzył autor projektu w serwisie AI Music Factory. Nie są to
materiały z biblioteki stockowej ani cudze nagrania, więc nie ma obowiązku
podawania trzeciej strony.

**Użycie komercyjne: dozwolone.** Utwory powstały na aktywnym planie rocznym,
do którego serwis przypisuje prawa komercyjne do całej wygenerowanej muzyki.
Według panelu konta prawa te są bezterminowe i zostają przy autorze także
wtedy, gdy subskrypcja nie zostanie odnowiona — obejmują utwory stworzone
w okresie jej trwania. Gra może więc być sprzedawana z tą ścieżką dźwiękową.

> Warto zachować dowód: zrzut ekranu z panelu subskrypcji (sekcja „Prawa
> komercyjne”) oraz datę wygenerowania obu utworów. Prawa wynikają z konta
> i okresu subskrypcji, a nie z samych plików — po latach łatwiej pokazać
> potwierdzenie niż odtwarzać historię konta.

Gra działa bez tych plików: wystarczy opróżnić `assets/music/`, a odtwarzacz
po prostu zamilknie. Gracz może wtedy wrzucić własne utwory do katalogu
`muzyka` w danych gry.
