# KRONIKARZ 2.0

Tekstowa gra fabularna (RPG) instalowana na komputerze, w której **to gracz tworzy świat**:
wybiera gatunek, epokę, lata i okoliczności rozgrywki, buduje własną postać (z awatarem)
i prowadzi opowieść w rozmowie z Mistrzem Gry. Inspiracja klimatem gier typu *kf2.pl*,
ale z pełną swobodą kreacji świata.

Aplikacja to pojedynczy plik wykonywalny napisany w **Go**, który uruchamia lokalny serwer
i otwiera nowoczesne GUI (HTML/CSS/JS) osadzone w pliku wykonywalnym. Nic nie jest wysyłane
do sieci, dopóki sam nie włączysz trybu online AI.

## Dwa tryby narracji

| Tryb | Opis | Wymagania |
|------|------|-----------|
| **Wersja darmowa — offline** | `Procedural offline`. Narracja generowana lokalnie, **dopasowana do gatunku i epoki** wybranego świata. Działa bez internetu i bez kluczy API. | brak |
| **Wersja płatna — online AI** | Pełna rozmowa z modelem językowym: `Ollama/Bielik` (model lokalny) albo `Claude` / `OpenAI` (usługa online). | zainstalowany model lub token API |

## Tworzenie świata

Przy nowej opowieści gracz definiuje m.in.: **gatunek**, **epokę**, **rok/lata akcji**,
klimat, poziom nadnaturalności, główną tajemnicę, startową lokację i ton. Dostępny jest też
**szybki szablon gatunku** (fantasy, historyczny, współczesny, noir, horror, sci-fi, cyberpunk,
postapokalipsa, western, steampunk), który wstępnie wypełnia pola — każde z nich można zmienić.

Wybrany gatunek realnie wpływa na rozgrywkę także w trybie darmowym: klimat opisów,
sugerowane działania, tła scen oraz miejsca dopisywane do Kroniki są dobierane do konwencji
(np. w cyberpunku pojawia się „Bar z neonami”, a nie „Karczma”).

## Uruchomienie (Windows)

```
KRONIKARZ.exe
```
lub `URUCHOM_KRONIKARZ.bat`. Aplikacja otworzy się w oknie przeglądarki systemowej.
Dane gry (postacie, przygody, awatary) zapisują się lokalnie w katalogu `data/`.

## Budowanie ze źródeł

Wymagany **Go 1.24+**. Szczegóły i budowanie pod Windows: [`BUILD.md`](BUILD.md).

```bash
go build -o KRONIKARZ .      # bieżąca platforma
```

## Struktura projektu

```
main.go        serwer HTTP, model danych, integracje AI (Ollama/Claude/OpenAI)
narrator.go    silnik narracji proceduralnej (offline) świadomy gatunku i epoki
app/           GUI: index.html, styles.css, app.js (osadzane w binarce przez go:embed)
data/          dane runtime tworzone lokalnie (ignorowane w git)
```

## Najnowsze zmiany (rozwinięcie prototypu v2.0.8)

- Narracja **offline** dopasowana do gatunku i epoki świata (10 profili gatunkowych)
  zamiast sztywnych realiów fantasy.
- Nowe pole **Rok / lata akcji** oraz **szablony gatunku** w kreatorze świata.
- **Tła scen i sugerowane wybory** zależne od gatunku.
- Ekran **Zapisane przygody** — wczytywanie i usuwanie zapisanych kronik (sloty).
- Czytelne rozróżnienie **wersji darmowej (offline)** i **płatnej (online AI)** w ustawieniach.
- Uporządkowany projekt: `go.mod`, `.gitignore`, podział na `main.go` / `narrator.go`.
