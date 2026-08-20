# Klatki animacji otwarcia księgi

Wrzuć tu kolejne klatki jako pliki `png`, `jpg` lub `webp`. Odtwarzacz sam je
znajduje i **sortuje po nazwie**, więc numeruj z zerem wiodącym:

```
open_01.png, open_02.png, … open_40.png
```

Zasady:

- **Ostatnia klatka musi być tym samym kadrem, co `assets/ui/plate_menu.png`.**
  Wtedy animacja przechodzi w menu bez przeskoku.
- Liczba klatek jest dowolna — czas trwania ustawia się w Ustawieniach, a gra
  dzieli go równo między klatki. 40 klatek w 1,6 s to 25 kl./s.
- Rozdzielczość: najlepiej 1280×720. Gra rysuje się w przestrzeni 1672×941
  i klatka zostanie nieznacznie powiększona, czego w ruchu nie widać, a pamięć
  i waga paczki spadają ponad dwukrotnie.
- Katalog może zostać pusty — wtedy gra po prostu startuje od razu w menu.
