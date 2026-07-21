KRONIKARZ 2.0 Preview v2.0.6

Hotfix:
- naprawiono wgrywanie awatara postaci
- awatar można wgrać z kreatora postaci, biblioteki postaci i karty postaci
- zachowywanie awatara po edycji postaci
- dodano odświeżanie portretu po wgraniu pliku
- dodano czytelniejsze komunikaty błędów przy wgrywaniu awatara

Uruchomienie:
KRONIKARZ.exe
albo URUCHOM_KRONIKARZ.bat

v2.0.7 hotfix:
- naprawiono Anuluj w oknie Nowa postać, już nie wymaga imienia
- poprawiono przycisk Edytuj w Bibliotece postaci
- poprawiono dodawanie / zmianę awatara postaci z Biblioteki i Karty postaci
- poprawiono układ przycisku wyboru pliku awatara


Hotfix v2.0.8:
- przywrócono brakujące funkcje JavaScript: graj postacią, nowa przygoda, wyślij, rzut kością, ustawienia, test AI, okna informacji.
- zabezpieczono zachowanie tokenów przy zapisie ustawień, jeśli pola hasła są puste.


Rozwinięcie v2.0.9 (narracja świadoma gatunku i epoki):
- tryb offline (darmowy) dopasowuje narrację do gatunku i epoki tworzonego świata
  (10 profili: fantasy, historyczny, współczesny, noir, horror, sci-fi, cyberpunk,
  postapokalipsa, western, steampunk) zamiast sztywnych realiów fantasy.
- w kreatorze świata dodano pole "Rok / lata akcji" oraz szablony gatunku.
- tła scen i sugerowane wybory zależą teraz od gatunku świata.
- nowy ekran "Zapisane przygody": wczytywanie i usuwanie zapisanych kronik (sloty).
- w ustawieniach czytelnie rozdzielono wersję darmową (offline) i płatną (online AI).
- projekt uporządkowany do budowania ze źródeł (go.mod, .gitignore, main.go + narrator.go);
  budowanie opisane w BUILD.md.
