# Kronikarz

Tekstowa gra fabularna, w której **to gracz tworzy świat**. Wybierasz gatunek,
epokę i realia, budujesz postać i prowadzisz opowieść scena po scenie —
a wszystko, co odkryjesz po drodze, trafia do Twojej Kroniki.

W odróżnieniu od wcześniejszego prototypu Kronikarz jest teraz **samodzielną
aplikacją desktopową** (Windows / Linux / macOS). Nie uruchamia się w oknie
przeglądarki, nie stawia lokalnego serwera i nie wymaga połączenia z siecią,
by grać.

## Co oferuje

- **Kreator świata** — dziesięć konwencji (fantasy, historyczny, współczesny,
  noir, horror, science fiction, cyberpunk, postapokalipsa, western, steampunk),
  z szablonami, które podpowiadają realia, a które w całości można nadpisać.
- **Świadoma narracja** — wybrany gatunek i epoka realnie kształtują opisy,
  sugerowane działania oraz miejsca dopisywane do Kroniki. W cyberpunku pojawi
  się „bar z neonami”, a nie karczma.
- **System scen z rzutem kością** — każde działanie rozstrzyga rzut, który
  nadaje decyzjom stawkę: od krytycznej porażki po krytyczny sukces.
- **Kronika** — na bieżąco spisuje odwiedzone miejsca, odkrycia i wątki.
- **Zapisy** — dowolna liczba kronik zapisywanych lokalnie, do wczytania w każdej chwili.
- **Dwa tryby narracji:**
  - *Offline (darmowy)* — pełna rozgrywka bez internetu i bez kluczy API.
  - *Online (AI)* — swobodna rozmowa z Mistrzem Gry prowadzona przez lokalny
    model językowy uruchomiony w [Ollamie](https://ollama.com) (np. Bielik).
    Gdy model jest niedostępny, gra po cichu wraca do trybu offline.

## Uruchomienie z gotowej wersji

Pobierz wydanie dla swojego systemu i uruchom plik wykonywalny:

- **Windows:** `Kronikarz.exe`
- **Linux:** `./Kronikarz.x86_64`

Zapisane kroniki i ustawienia trzymane są w katalogu danych użytkownika systemu
operacyjnego (np. `%APPDATA%\Godot\app_userdata\Kronikarz` na Windows).

## Budowanie ze źródeł

Projekt korzysta z silnika [Godot 4.3+](https://godotengine.org) (licencja MIT).
Pełne instrukcje: [`BUILD.md`](BUILD.md). W skrócie:

```bash
# 1. Otwórz projekt w edytorze Godot i pozwól mu zaimportować zasoby,
#    albo z linii poleceń:
godot --headless --import

# 2. Uruchom:
godot

# 3. Wyeksportuj gotową aplikację (po zainstalowaniu szablonów eksportu):
godot --headless --export-release "Windows Desktop" dist/Kronikarz.exe
godot --headless --export-release "Linux" dist/Kronikarz.x86_64
```

## Struktura projektu

```
project.godot          konfiguracja i lista autoloadów
scenes/Main.tscn       scena główna (router ekranów)
src/core/              logika gry (autoloady)
  Genres.gd            profile gatunkowe: słownictwo, archetypy, szablony
  Narrator.gd          silnik narracji + rzuty kością + tryb AI (Ollama)
  GameState.gd         stan sesji, Kronika, przebieg akcji
  SaveManager.gd       zapis i odczyt kronik
src/ui/                interfejs
  Ui.gd                paleta, motyw i fabryki kontrolek
  Router.gd            przełączanie ekranów
  MainMenu / WorldCreation / CharacterCreation / PlayScreen / LoadScreen / SettingsScreen
icon.svg               ikona aplikacji
```

## Licencja

Kod gry objęty jest licencją MIT (patrz [`LICENSE`](LICENSE)) — można go
swobodnie wykorzystywać, także komercyjnie. Silnik Godot rozprowadzany jest na
licencji MIT i nie nakłada opłat licencyjnych ani tantiem od sprzedaży gry.
