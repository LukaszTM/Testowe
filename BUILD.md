# Budowanie KRONIKARZA ze źródeł

Wymagany **Go 1.24 lub nowszy** (`go version`).

Pliki GUI z katalogu `app/` są osadzane w binarce dyrektywą `//go:embed`, więc gotowy
plik wykonywalny jest samodzielny — nie wymaga dołączania `app/` obok siebie.

## Bieżąca platforma

```bash
go build -o KRONIKARZ .
```

## Windows (z Linuksa/macOS — kompilacja skrośna)

```bash
# zwykła wersja (bez okna konsoli)
GOOS=windows GOARCH=amd64 go build -ldflags "-H=windowsgui" -o KRONIKARZ.exe .

# wersja debug (z konsolą i logami)
GOOS=windows GOARCH=amd64 go build -o KRONIKARZ_DEBUG.exe .
```

Skompilowane pliki `*.exe` są celowo pominięte w `.gitignore` — buduje się je z tego źródła.

## Szybki test lokalny

```bash
go vet ./...
go build -o /tmp/kron . && /tmp/kron
```

Serwer startuje na `127.0.0.1` na losowym porcie i otwiera GUI w przeglądarce systemowej.
Dane runtime lądują w `data/db.json` (ignorowane w git).
