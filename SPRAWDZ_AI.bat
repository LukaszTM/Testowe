@echo off
chcp 65001 >nul
echo Sprawdzanie Ollama...
where ollama >nul 2>nul
if errorlevel 1 (
  echo Ollama nie jest zainstalowana albo nie jest w PATH.
) else (
  ollama --version
  echo.
  echo Dostepne modele:
  ollama list
)
echo.
echo Sprawdzanie lokalnego API Ollama:
curl http://localhost:11434/api/tags
pause
