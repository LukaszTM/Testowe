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

Paczka **Kronikarz Asset Pack Extended** — tła księgi, okucia przycisków, ramy,
paski i ornamenty. Wykonał ją autor projektu w ChatGPT (OpenAI, plan Pro).
Skrypt `tools/build_ui.py` przycina je, skaluje i dorabia wypełnienia pasków.

**Użycie komercyjne: dozwolone.** Regulamin OpenAI przenosi na użytkownika
prawa do wygenerowanych materiałów i nie zabrania używania ich zarobkowo ani
nie wymaga podawania narzędzia. Gra może być sprzedawana z tą oprawą graficzną.

> **Czym to się różni od muzyki.** Prawo autorskie w Polsce i UE chroni utwory
> o twórczym, ludzkim charakterze. Materiał wygenerowany przez model może więc
> nie być chroniony prawem autorskim w ogóle. Nie przeszkadza to sprzedawać
> gry — wolno używać takiej grafiki bez ograniczeń. Oznacza natomiast, że
> prawdopodobnie nie da się zakazać komuś użycia identycznej lub bardzo
> podobnej grafiki. Przy oprawie UI ryzyko jest niewielkie; gdyby te grafiki
> miały kiedyś stanowić znak rozpoznawczy marki (logo, okładka sklepowa),
> warto je domalować ręcznie albo zlecić grafikowi.
>
> To informacja praktyczna, nie porada prawna. Przed komercyjną premierą
> najlepiej potwierdzić stan rzeczy u prawnika.

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
