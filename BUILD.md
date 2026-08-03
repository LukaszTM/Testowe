# Budowanie i eksport

Kronikarz to projekt silnika **Godot 4.3+**. Nie wymaga kompilatora ani
zewnętrznych bibliotek — wystarczy edytor Godot.

## Wymagania

- Godot 4.3 lub nowszy (wersja standardowa; nie potrzeba wariantu .NET).
  Pobierz z [godotengine.org/download](https://godotengine.org/download).
- Do eksportu gotowych plików wykonywalnych: **szablony eksportu** dla danej
  wersji Godota (Editor → *Manage Export Templates* → *Download and Install*).

## Uruchomienie w edytorze

1. Uruchom Godota i wskaż plik `project.godot` (*Import*).
2. Godot zaimportuje zasoby przy pierwszym otwarciu.
3. Naciśnij **F5**, aby uruchomić grę.

Z linii poleceń:

```bash
godot --path . --headless --import   # jednorazowy import zasobów
godot --path .                       # uruchomienie gry
```

## Eksport do pliku wykonywalnego

Presety są zdefiniowane w `export_presets.cfg` (Windows Desktop oraz Linux).
Po zainstalowaniu szablonów eksportu:

```bash
# Windows (.exe z osadzonym pakietem danych)
godot --headless --export-release "Windows Desktop" dist/Kronikarz.exe

# Linux
godot --headless --export-release "Linux" dist/Kronikarz.x86_64
```

Plik wynikowy jest samowystarczalny — zawiera silnik, kod gry i zasoby.
Nie otwiera przeglądarki i nie wymaga instalacji.

## macOS

W edytorze dodaj preset *macOS* (analogicznie do istniejących), a następnie:

```bash
godot --headless --export-release "macOS" dist/Kronikarz.zip
```

## Uwaga o trybach Mistrza Gry

Żaden tryb online nie jest wymagany — offline działa w pełni samodzielnie.

**Claude API (zalecany):** hostowana usługa — nie stawiasz żadnego serwera.
Klucz wygenerujesz na [platform.claude.com](https://platform.claude.com)
(Settings → API keys) albo skorzystasz z bramki zgodnej z API Anthropic
(np. aiprimetech.io) — wtedy w polu „Adres API” wpisz adres bramki.
W grze: *Ustawienia → Mistrz Gry → Claude API*, wklej klucz i zapisz.
Usługa jest płatna za zużycie tokenów.

**Ollama (model lokalny):**

```bash
ollama pull bielik        # lub inny model, np. llama3 / mistral
ollama serve
```

Następnie w grze: *Ustawienia → Mistrz Gry → Ollama* i wskaż adres
(domyślnie `http://localhost:11434`) oraz nazwę modelu.
