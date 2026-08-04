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
- **Karta bohatera** — zdrowie, mana (w światach z nadnaturalnością), punkty
  doświadczenia i poziomy; przy awansie rozdajesz punkty atrybutów (Siła,
  Zręczność, Intelekt, Charyzma), które wzmacniają rzuty kością.
- **Postacie** — wybór płci, archetypy w formach męskich i żeńskich (plus
  własny), avatar z dysku, a także **magazyn postaci**: bohaterowie zapisują
  się między opowieściami razem z poziomem i atrybutami.
- **Biblioteka postaci niezależnych** — w trybie Mistrza Gry AI spotkane
  postacie (z imionami nadawanymi przez MG) trafiają do Kroniki wraz z krótkim
  opisem relacji i uczuć wobec bohatera; każda dostaje proceduralny
  medalion-portret.
- **Zapisy** — dowolna liczba kronik zapisywanych lokalnie, do wczytania w każdej chwili.
- **Trzy tryby prowadzenia opowieści:**
  - *Offline (darmowy)* — prosta narracja proceduralna, bez internetu i kluczy.
  - *Claude API (zalecany)* — pełny **Mistrz Gry w chmurze**: reaguje na to,
    co piszesz, tworzy postacie niezależne z imionami i charakterami oraz
    prowadzi z Tobą ich dialogi. To hostowana usługa Anthropic
    (api.anthropic.com) — **nie stawiasz żadnego serwera** i działa
    niezależnie od Twojego komputera; potrzebny jest tylko klucz API
    z [platform.claude.com](https://platform.claude.com) (usługa płatna za
    zużycie, klucz zapisuje się wyłącznie lokalnie).
  - *Ollama* — model językowy uruchomiony lokalnie na Twoim komputerze.

  Gdy wybrany tryb online zawiedzie (brak sieci, zły klucz), gra po cichu
  dokańcza turę w trybie offline.

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
  Audio.gd             dźwięki przycisków
src/ui/                interfejs
  Ui.gd                paleta, czcionki, motyw i fabryki kontrolek
  Router.gd            przełączanie ekranów
  MainMenu / WorldCreation / CharacterCreation / PlayScreen / LoadScreen / SettingsScreen
assets/fonts/          Great Vibes (tytuł), Almendra (menu), EB Garamond (narracja) — licencja OFL
assets/audio/          dźwięki przycisków
icon.svg               ikona aplikacji
```

## Ustawienia

W menu **Ustawienia** można zmienić m.in.:

- **rozdzielczość** — lista jest budowana automatycznie na podstawie ekranu (z oznaczoną rozdzielczością natywną),
- **tryb okna** — w oknie / bez ramki / pełny ekran,
- **dźwięki przycisków**,
- **Mistrz Gry** — offline / Claude API (chmura) / Ollama (lokalnie),
- **rzuty kością** — tylko przy starciach i ryzyku (domyślnie), zawsze albo nigdy,
- **wielkość tekstu**.

## Licencja

Kod gry objęty jest licencją MIT (patrz [`LICENSE`](LICENSE)) — można go
swobodnie wykorzystywać, także komercyjnie. Silnik Godot rozprowadzany jest na
licencji MIT i nie nakłada opłat licencyjnych ani tantiem od sprzedaży gry.

Dołączone zasoby również nadają się do użytku komercyjnego:

- **Czcionki Great Vibes, Almendra i EB Garamond** — licencja SIL Open Font
  License 1.1 (patrz [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt)).
- **Dźwięki** (`assets/audio/`) — wygenerowane na potrzeby projektu,
  możesz ich używać i podmieniać bez ograniczeń.
