extends Node

# Baza profili gatunkowych. Świat tworzony przez gracza — jego gatunek, epoka
# i lata — realnie wpływa na słownictwo narracji, sugerowane działania,
# archetypy postaci i miejsca dopisywane do Kroniki.
#
# Profile rozwinięto względem prototypu: doszły podpowiedzi scen (suggestions),
# archetypy postaci i szablony wypełniające kreator świata.

const CLOSERS := [
	"Co robisz?", "Jaki masz plan?", "Co teraz?", "Jak reagujesz?", "Na co się decydujesz?",
]

# Kolejność wyświetlania w kreatorze świata.
const ORDER := ["fantasy", "historyczny", "wspolczesny", "noir", "horror",
	"scifi", "cyberpunk", "postapo", "western", "steampunk"]

var profiles: Dictionary = {}

func _ready() -> void:
	_build()

func label(key: String) -> String:
	return profiles.get(key, profiles["fantasy"]).get("label", "Fantasy")

func labels_in_order() -> Array:
	var out: Array = []
	for k in ORDER:
		out.append(profiles[k]["label"])
	return out

func key_at(index: int) -> String:
	return ORDER[clampi(index, 0, ORDER.size() - 1)]

func profile(key: String) -> Dictionary:
	return profiles.get(key, profiles["fantasy"])

# Klasyfikuje wolny opis świata na jeden z obsługiwanych profili.
func detect(text: String) -> String:
	var s := text.to_lower()
	var rules := [
		["cyberpunk", ["cyberpunk", "neon", "korporac", "augment", "cybernet", "netrunner", "implant", "hologram"]],
		["scifi", ["sci-fi", "science fiction", "kosmos", "kosmiczn", "galakt", "orbit", "gwiezd", "android", "reaktor", "międzygwiezd", "planet", "stacja"]],
		["postapo", ["postapo", "post-apo", "apokalip", "nuklearn", "pustkowi", "zombie", "skażen", "wasteland", "zagład", "katastrof"]],
		["steampunk", ["steampunk", "parow", "wiktoriańsk", "sterowiec", "zębatk", "mosiądz"]],
		["western", ["western", "dziki zachód", "rewolwer", "kowboj", "preri", "szeryf", "saloon"]],
		["noir", ["noir", "kryminał", "detektyw", "gangster", "prohibicj", "mafia", "śledztw", "zbrodni", "morderstw"]],
		["horror", ["horror", "groza", "upiór", "upior", "duch", "nawiedz", "koszmar", "demon", "potwór", "potwor", "makabr"]],
		["fantasy", ["fantasy", "magia", "magicz", "smok", "elf", "krasnolud", "czarodziej", "czarnoksięż", "baśni", "mityczn"]],
		["historyczny", ["historyczn", "średniowiecz", "starożytn", "antyk", "rzym", "wiking", "napoleon", "renesans", "barok", "międzywoj", "wojn", "prl"]],
		["wspolczesny", ["współczes", "wspolczes", "nowożytn", "dzisiejsz", "teraźniejsz", "metropol", "miejsk", "sensacyjn", "thriller"]],
	]
	for rule in rules:
		for needle in rule[1]:
			if s.contains(needle):
				return rule[0]
	return "fantasy"

# Szablon wypełniający pola kreatora dla danego gatunku.
func template(key: String) -> Dictionary:
	return profiles.get(key, profiles["fantasy"]).get("template", {})

func _p(key, label, scene, ambient, look, talk, move, fight, filler, hub, edge, depth, sugg, arch, tmpl) -> void:
	profiles[key] = {
		"key": key, "label": label, "scene": scene,
		"ambient": ambient, "look": look, "talk": talk, "move": move,
		"fight": fight, "filler": filler,
		"hub": hub, "edge": edge, "depth": depth,
		"suggestions": sugg, "archetypes": arch, "template": tmpl,
	}

func _build() -> void:
	_p("fantasy", "Fantasy", "village",
		["W powietrzu wisi zapach dymu z palenisk i wilgotnej ziemi.",
		 "Gdzieś w oddali bije samotny dzwon, a cienie wydłużają się między chatami.",
		 "Wiatr niesie strzępy pieśni i szczęk kutego żelaza."],
		["Wśród codziennych szczegółów wypatrujesz coś, co nie pasuje: świeży znak wyryty w drewnie, ślad, którego nikt nie zdążył zetrzeć.",
		 "Im dłużej się przyglądasz, tym wyraźniej widzisz, że ktoś próbował tu coś ukryć."],
		["Rozmówca waży każde słowo, jakby bał się powiedzieć za dużo.",
		 "Pada odpowiedź, ale w oczach twojego rozmówcy widać, że przemilcza to, co najważniejsze."],
		["Ruszasz naprzód; deski i błoto skrzypią pod stopami, a kilka głów odwraca się w twoją stronę.",
		 "Przemieszczasz się ostrożnie — droga prowadzi w miejsce, o którym miejscowi mówią półgłosem."],
		["Dłoń sama sięga po broń. Napięcie pęka, a najbliższe sekundy zadecydują o wszystkim.",
		 "Rozgrywa się krótka, brutalna wymiana ciosów; kurz i krzyk mieszają się w jedno."],
		["Kronika dopisuje nowy wers — a ktoś w pobliżu reaguje na twój ruch zbyt szybko, jakby na niego czekał.",
		 "Scena drży: pojawia się drobny szczegół, którego wcześniej nie było, i zmienia układ sił."],
		{"name": "Karczma", "note": "Miejsce plotek, pierwszych tropów i niepewnych sojuszy."},
		{"name": "Czarny Las", "note": "Niepokojące obrzeże znanego świata, gdzie kończą się ścieżki."},
		{"name": "Podziemia", "note": "Sieć starych korytarzy związanych z główną tajemnicą."},
		["Rozpytaj miejscowych o dziwne wydarzenia", "Zbadaj świeży ślad przy drodze",
		 "Zajrzyj do karczmy po plotki", "Sprawdź, dokąd prowadzi leśna ścieżka",
		 "Wypatruj kogoś, kto cię obserwuje"],
		[["Wędrowny rycerz", "Wędrowna wojowniczka"], ["Łotrzyk", "Łotrzyca"], ["Zielarz", "Zielarka"], ["Pieśniarz", "Pieśniarka"], ["Łowca bestii", "Łowczyni bestii"], ["Najemnik", "Najemniczka"]],
		{"era": "Średniowiecze", "climate": "surowy, pełen zabobonów świat na skraju cywilizacji",
		 "supernatural": "obecna, lecz rzadka magia", "tone": "epicki, ale przyziemny",
		 "start_location": "Rozstaje przy przydrożnej karczmie",
		 "mystery": "Z okolicznych wiosek znikają ludzie, a nocą słychać dzwon z opuszczonej wieży"})

	_p("historyczny", "Historyczny", "old-town",
		["Bruk lśni od wilgoci, a nad dachami snuje się dym z kominów.",
		 "Z rynku dobiega turkot wozów i nawoływania przekupniów.",
		 "Kościelny zegar wybija godzinę, a gołębie zrywają się do lotu."],
		["Uważne oko wyławia detal, który nie pasuje do epoki: coś nowego w miejscu, gdzie wszystko jest stare.",
		 "Wśród zwykłego zgiełku dostrzegasz spojrzenie, które śledzi każdy twój krok."],
		["Rozmówca mówi ostrożnie — czasy są niepewne, a nieznajomym nie ufa się od razu.",
		 "W odpowiedzi słychać wykręt; ktoś tu ma więcej do ukrycia niż do powiedzenia."],
		["Przeciskasz się przez zaułki; miasto ma swoje reguły, a ty właśnie wkraczasz na cudzy teren.",
		 "Idziesz dalej, a wąskie uliczki zwężają się, jakby prowadziły cię tam, gdzie ktoś sobie zaplanował."],
		["Napięcie zamienia się w gwałtowne szarpnięcie — w takich czasach spór rozstrzyga się szybko i twardo.",
		 "Wybucha zamieszanie; w ciżbie trudno odróżnić przyjaciela od wroga."],
		["Bieg wydarzeń nabiera tempa: to, co robisz, zaczyna zwracać uwagę niewłaściwych ludzi.",
		 "Coś się przesuwa w tle historii — drobny gest, który za chwilę okaże się ważny."],
		{"name": "Gospoda", "note": "Izba, gdzie schodzą się wieści, interesy i podejrzane układy."},
		{"name": "Rogatki miasta", "note": "Granica, za którą kończy się prawo i zaczyna niepewność."},
		{"name": "Lochy", "note": "Wilgotne podziemia pod starą częścią miasta."},
		["Wmieszaj się w tłum na rynku", "Wypytaj gospodarza o miejscowe układy",
		 "Sprawdź, kto cię śledzi", "Zajrzyj za rogatki miasta", "Poszukaj dokumentów w archiwum"],
		[["Kupiec", "Kupcowa"], ["Oficer", "Awanturniczka"], ["Uczony", "Uczona"], ["Szpieg", "Szpiegini"], ["Rzemieślnik", "Rzemieślniczka"], ["Duchowny", "Zakonnica"]],
		{"era": "XVIII wiek", "climate": "napięcie polityczne i intrygi dworskie",
		 "supernatural": "brak — twardy realizm", "tone": "poważny, kameralny",
		 "start_location": "Rynek prowincjonalnego miasta",
		 "mystery": "Zaufany urzędnik ginie, a jego ostatni list wskazuje na spisek sięgający dworu"})

	_p("wspolczesny", "Współczesność", "city",
		["Miasto szumi ruchem, a ekrany i szyby odbijają nerwowe światło dnia.",
		 "Z ulicy dobiega klakson i strzępy rozmów, a telefon w kieszeni znów wibruje.",
		 "Zapach kawy miesza się ze spalinami; wszyscy gdzieś się spieszą."],
		["Wśród codziennego zgiełku wyłapujesz szczegół, który nie pasuje — drobiazg nie na miejscu.",
		 "Im uważniej patrzysz, tym pewniej wiesz, że ktoś obserwuje to samo co ty."],
		["Rozmówca odpowiada uprzejmie, ale coś w tonie zdradza, że mówi mniej, niż wie.",
		 "Pada gładka odpowiedź; dopiero potem uświadamiasz sobie, że nie odpowiada na pytanie."],
		["Ruszasz dalej, wtapiając się w tłum; w mieście łatwo zniknąć i łatwo dać się śledzić.",
		 "Przemieszczasz się przez ulice, a znajome otoczenie zaczyna wydawać się subtelnie nie takie."],
		["Sytuacja wymyka się spod kontroli — przemoc wybucha nagle, między zwykłymi ludźmi.",
		 "Krótkie, chaotyczne szarpnięcie; wokół rozlegają się krzyki i trzask upadających rzeczy."],
		["Sprawa się rozrasta: twój ruch właśnie zwrócił czyjąś uwagę, której wolałbyś uniknąć.",
		 "Coś przesuwa się w tle codzienności — szczegół, który zmienia znaczenie całej sceny."],
		{"name": "Kawiarnia", "note": "Zwykłe miejsce spotkań, gdzie padają niezwykłe słowa."},
		{"name": "Obrzeża miasta", "note": "Pustostany i nieużytki, gdzie kończy się miejski porządek."},
		{"name": "Parking podziemny", "note": "Betonowa głębia pod miastem, pełna echa."},
		["Prześledź ostatnią wiadomość na telefonie", "Umów się na kawę z informatorem",
		 "Sprawdź, kto zostawił ten drobiazg", "Pojedź na obrzeża miasta", "Zgub potencjalny ogon"],
		[["Dziennikarz", "Dziennikarka"], ["Detektyw", "Detektywka"], ["Programista", "Programistka"], ["Lekarz", "Lekarka"], ["Były policjant", "Była policjantka"], ["Prawnik", "Prawniczka"]],
		{"era": "XXI wiek", "climate": "wielkomiejski thriller, wszechobecne kamery i telefony",
		 "supernatural": "brak", "tone": "napięty, sensacyjny",
		 "start_location": "Kawiarnia w centrum",
		 "mystery": "Znajoma osoba znika bez śladu, zostawiając telefon z jedną nieodczytaną wiadomością"})

	_p("noir", "Kryminał / Noir", "city-night",
		["Deszcz bębni o parapety, a neon nad drzwiami sączy czerwone światło na mokry chodnik.",
		 "Gdzieś zawodzi saksofon, a z rynsztoka unosi się para.",
		 "Reflektory samochodu przecinają mrok i znikają za rogiem."],
		["W szczegółach kryje się pierwszy fałsz: coś tu nie gra, a ty właśnie zaczynasz to widzieć.",
		 "Twój wzrok zatrzymuje się na drobiazgu, który dla kogoś jest wart znacznie za dużo, by go zostawić."],
		["Rozmówca uśmiecha się gładko, ale kłamie — pytanie tylko, w której części zdania.",
		 "Odpowiedź brzmi zbyt równo, jakby ktoś ją wcześniej wyćwiczył."],
		["Idziesz dalej trzymając się cienia; w tym mieście uwaga jest kosztowna.",
		 "Ruszasz przez mokre ulice, czując, że ktoś dotrzymuje ci kroku pół przecznicy z tyłu."],
		["Sytuacja robi się brzydka — pięść albo spust, i to w ułamku sekundy.",
		 "Cios pada nagle; w takim mieście przemoc nie zapowiada się grzecznie."],
		["Sprawa się rozrasta: to, co robisz, właśnie pociągnęło za nitkę, której lepiej było nie ruszać.",
		 "W tle miasta coś zgrzyta — trop, który prowadzi głębiej, niż chciałeś."],
		{"name": "Nocny bar", "note": "Zadymiony lokal, gdzie kupuje się drinki i przemilczenia."},
		{"name": "Doki", "note": "Ciemne nabrzeże, gdzie znikają ludzie i ładunki."},
		{"name": "Piwnice", "note": "Zapomniane podziemia pod starą dzielnicą."},
		["Postaw drinka barmanowi w zamian za plotkę", "Prześledź podejrzany trop",
		 "Zgub człowieka za plecami", "Zajrzyj nocą do doków", "Naciśnij niepewnego świadka"],
		[["Prywatny detektyw", "Prywatna detektyw"], ["Znużony gliniarz", "Znużona policjantka"], ["Dziennikarz śledczy", "Dziennikarka śledcza"], ["Adwokat", "Adwokatka"], ["Drobny gangster", "Femme fatale"], ["Barman z przeszłością", "Barmanka z przeszłością"]],
		{"era": "Lata 40. XX wieku", "climate": "deszczowa metropolia, korupcja i cień prohibicji",
		 "supernatural": "brak", "tone": "cyniczny, duszny",
		 "start_location": "Biuro detektywa nad nocnym barem",
		 "mystery": "Klientka zleca odnalezienie brata, ale już pierwsze pytanie sprawia, że ktoś chce cię uciszyć"})

	_p("horror", "Groza / Horror", "dark",
		["Cisza jest zbyt gęsta, a każdy twój oddech brzmi za głośno.",
		 "Gdzieś skrzypi deska, choć nikogo tam nie ma. Potem znowu — bliżej.",
		 "Zimno wpełza pod ubranie, a światło drży, jakby czegoś się bało."],
		["Im uważniej patrzysz, tym mniej chcesz widzieć: coś tu było przed tobą i zostawiło ślad.",
		 "W półmroku dostrzegasz zarys, który nie powinien się poruszać — a jednak drgnął."],
		["Odpowiedź pada szeptem, urwana w połowie, jakby ktoś nakazał milczeć.",
		 "Rozmówca patrzy za twoje ramię, blednie i nie kończy zdania."],
		["Robisz krok naprzód; ciemność zdaje się cofać dokładnie o tyle, byś szedł dalej.",
		 "Idziesz, a podłoga pod tobą jest lepka, zimna i cicho oddaje każdy krok echem."],
		["Panika i instynkt biorą górę — bijesz na oślep w coś, co nie reaguje jak człowiek.",
		 "To nie jest walka, to ucieczka do przodu; liczy się tylko, byś przetrwał następną chwilę."],
		["Coś się zmienia w powietrzu — jesteś pewny, że nie jesteś tu sam.",
		 "Kronika grozy dopisuje wers: to, co robisz, właśnie ściągnęło na ciebie czyjąś uwagę."],
		{"name": "Opuszczony dom", "note": "Miejsce, które udaje bezpieczne schronienie."},
		{"name": "Mgła za osadą", "note": "Granica, za którą znika droga powrotna."},
		{"name": "Piwnica", "note": "Zimne podziemie, z którego dobiega dźwięk."},
		["Nasłuchuj, skąd dobiega dźwięk", "Zabarykaduj drzwi i przeczekaj",
		 "Zejdź do piwnicy z latarką", "Sprawdź, czy ktoś jeszcze żyje", "Uciekaj przed siebie we mgłę"],
		[["Ocalały", "Ocalała"], ["Badacz zjawisk", "Badaczka zjawisk"], ["Ksiądz", "Zakonnica"], ["Pielęgniarz", "Pielęgniarka"], ["Sceptyk", "Sceptyczka"], ["Miejscowy przewodnik", "Miejscowa przewodniczka"]],
		{"era": "Współczesność", "climate": "odcięta od świata osada, coś czai się po zmroku",
		 "supernatural": "silna i wroga", "tone": "duszny, narastająca groza",
		 "start_location": "Opuszczony dom na skraju osady",
		 "mystery": "Mieszkańcy znikają jeden po drugim, a każdy świadek mówi o tym samym dźwięku"})

	_p("scifi", "Science fiction", "station",
		["Pod pokładem miarowo pulsuje reaktor, a powietrze pachnie metalem i chłodziwem.",
		 "Na ścianach mrugają diody, a przez iluminator widać powolny obrót gwiazd.",
		 "System wentylacji szumi jednostajnie, aż nagle na moment cichnie."],
		["Skan i własne oczy zgadzają się co do jednego: te dane nie powinny tak wyglądać.",
		 "Wśród rutynowych odczytów wyłapujesz anomalię, którą ktoś próbował ukryć w logach."],
		["Rozmówca odpowiada rzeczowo, ale interfejs zdradza mikroopóźnienie — waha się.",
		 "Pada odpowiedź, jednak protokół, na który się powołuje, dawno przestał obowiązywać."],
		["Ruszasz korytarzem; grodzie rozsuwają się z sykiem, a echo kroków niesie się daleko.",
		 "Przemieszczasz się przez sekcję, w której część świateł jest wygaszona — i nie wiadomo, przez kogo."],
		["Sytuacja eskaluje w ułamku sekundy — w zamkniętej przestrzeni nie ma gdzie uciec.",
		 "Rozgrywa się gwałtowne starcie; alarmy zawodzą, a grawitacja nie ułatwia zadania."],
		["Systemy notują zmianę: twoje działanie właśnie uruchomiło coś w tle.",
		 "Coś przesuwa się w danych stacji — sygnał, którego nikt nie zaplanował."],
		{"name": "Mesa załogi", "note": "Wspólna przestrzeń, gdzie krążą plotki i nieoficjalne wersje wydarzeń."},
		{"name": "Sektor zewnętrzny", "note": "Peryferie konstrukcji, gdzie kończy się zasięg czujników."},
		{"name": "Ładownia", "note": "Mroczne wnętrze pełne kontenerów i cieni."},
		["Przejrzyj logi systemowe stacji", "Wypytaj załogę w mesie",
		 "Sprawdź wygaszoną sekcję", "Zabezpiecz ładownię", "Zignoruj protokół i wejdź na zewnątrz"],
		[["Inżynier pokładowy", "Inżynierka pokładowa"], ["Nawigator", "Nawigatorka"], ["Medyk", "Medyczka"], ["Sztuczna świadomość", "Sztuczna świadomość"], ["Najemnik", "Najemniczka"], ["Naukowiec", "Naukowczyni"]],
		{"era": "Daleka przyszłość", "climate": "izolowana stacja na skraju znanej przestrzeni",
		 "supernatural": "brak, choć technologia bywa niepojęta", "tone": "chłodny, klaustrofobiczny",
		 "start_location": "Mostek stacji orbitalnej",
		 "mystery": "Reaktor notuje odczyty, których nie da się wyjaśnić, a połowa załogi nie odbiera wezwań"})

	_p("cyberpunk", "Cyberpunk", "neon",
		["Neony ociekają na mokry beton, a holoreklamy krzyczą w językach, których nikt już nie słucha.",
		 "W tle dudni bas z klubu piętro niżej, a implanty wyłapują szum obcych sieci.",
		 "Deszcz miesza się z parą z ulicznych kuchni; miasto nigdy nie śpi."],
		["Nakładka AR podświetla to, co reszta tłumu ignoruje: ślad w danych, który ktoś zostawił przez pomyłkę.",
		 "Twój wzrok — własny i ten wzmocniony — łapie niespójność, wartą więcej niż całe piętro tej dzielnicy."],
		["Rozmówca handluje informacją jak każdą inną — pytanie brzmi, ile naprawdę kosztuje prawda.",
		 "Odpowiedź jest gładka i skorporowana; gdzieś pod nią pływa drugie dno."],
		["Wtapiasz się w tłum i neon; w tym mieście anonimowość trwa tylko tak długo, jak twój ślad w sieci.",
		 "Ruszasz zaułkiem między wieżowcami — tu prawo kończy się tam, gdzie zaczyna się cudza działka."],
		["Wszystko przyspiesza: implanty, adrenalina i spust reagują szybciej niż myśl.",
		 "Starcie jest krótkie i elektryczne; w tej dzielnicy przegrany nie dostaje drugiej szansy."],
		["Sieć drgnęła: twoje działanie właśnie zostawiło ślad, który ktoś na pewno odczyta.",
		 "Coś porusza się w cieniu danych — kontrakt, który zaczyna cię obejmować."],
		{"name": "Bar z neonami", "note": "Lokal, gdzie kupuje się drinki, dane i cudze sekrety."},
		{"name": "Zapomniana dzielnica", "note": "Strefa poza zasięgiem korporacyjnych kamer."},
		{"name": "Podziemia sieci", "note": "Serwerownie i tunele pod świecącym miastem."},
		["Podłącz się do lokalnej sieci", "Kup dane od fiksera w barze",
		 "Zetrzyj swój ślad z monitoringu", "Zejdź do podziemi sieci", "Naciśnij korpo-łącznika"],
		[["Netrunner", "Netrunnerka"], ["Najemnik z augmentacjami", "Najemniczka z augmentacjami"], ["Fikser", "Fikserka"], ["Rigger", "Riggerka"], ["Uciekinier z korporacji", "Uciekinierka z korporacji"], ["Uliczny medyk", "Uliczna medyczka"]],
		{"era": "Bliska przyszłość", "climate": "korporacyjna metropolia, przepaść między wieżami a ulicą",
		 "supernatural": "brak, króluje technologia", "tone": "brudny, elektryczny, cyniczny",
		 "start_location": "Bar z neonami w dolnym mieście",
		 "mystery": "Zlecenie na pozór proste — wykraść plik — okazuje się przynętą korporacji na kogoś takiego jak ty"})

	_p("postapo", "Postapokalipsa", "wasteland",
		["Wiatr niesie pył i skrzypienie blachy; świat dawno przestał być taki, jak go pamiętano.",
		 "Słońce wisi rdzawo nad ruinami, a każdy dźwięk niesie się za daleko.",
		 "Gdzieś stuka luźna płyta, a licznik w głowie odlicza to, czego nie widać."],
		["Wśród gruzu wypatrujesz coś wartościowego — albo ślad, że ktoś był tu przed chwilą.",
		 "Im dłużej patrzysz, tym jaśniej widzisz: to miejsce nie jest tak opuszczone, jak udaje."],
		["Rozmówca mierzy cię wzrokiem, licząc, czy bardziej się opłacasz żywy, czy martwy.",
		 "Odpowiedź pada skąpo — słowa też są tu towarem deficytowym."],
		["Ruszasz przez pustkowie, trzymając się osłon; otwarta przestrzeń to zaproszenie do kłopotów.",
		 "Przemieszczasz się między wrakami, a każdy krok wzbija pył, który cię zdradza."],
		["Tu nie ma zasad — liczy się to, kto pierwszy i kto celniej.",
		 "Wybucha brutalne starcie o to, co jeszcze zostało; przegrany nie zabiera niczego."],
		["Pustkowie reaguje: twój ruch obudził coś albo kogoś, kto właśnie rusza w twoją stronę.",
		 "Coś zmienia się na horyzoncie — kurz, który wzbija się nie od wiatru."],
		{"name": "Schronienie ocalałych", "note": "Prowizoryczna osada, gdzie handluje się wszystkim."},
		{"name": "Pustkowie", "note": "Skażona, otwarta przestrzeń pełna wraków i zagrożeń."},
		{"name": "Tunele metra", "note": "Podziemia, w których chroni się to, co nie chce być widziane."},
		["Przeszukaj ruiny w poszukiwaniu zapasów", "Wytarguj informacje w osadzie",
		 "Przemknij przez otwarte pustkowie", "Zejdź do tuneli metra", "Oceń, czy nieznajomy to zagrożenie"],
		[["Zbieracz", "Zbieraczka"], ["Karawaniarz", "Karawaniarka"], ["Sanitariusz", "Sanitariuszka"], ["Były żołnierz", "Była żołnierka"], ["Radiowiec", "Radiotelegrafistka"], ["Przewodnik po pustkowiu", "Przewodniczka po pustkowiu"]],
		{"era": "Po Zagładzie", "climate": "spalony świat, walka o wodę, paliwo i zaufanie",
		 "supernatural": "mutacje i skażenie", "tone": "surowy, desperacki",
		 "start_location": "Rogatki osady ocalałych",
		 "mystery": "Karawana, do której miałeś dołączyć, znika na pustkowiu, a jedyny ślad prowadzi do metra"})

	_p("western", "Western", "frontier",
		["Kurz wisi nad pustą ulicą, a szyld saloonu skrzypi na gorącym wietrze.",
		 "Gdzieś rży koń, a ostrogi dzwonią o deski chodnika.",
		 "Słońce praży bezlitośnie, a cień pod okapem jest jedynym schronieniem."],
		["Pod maską sennego miasteczka dostrzegasz napięcie: ktoś tu na coś czeka.",
		 "Twój wzrok wyłapuje detal — ślad koni, świeży, prowadzący tam, gdzie nie powinien."],
		["Rozmówca cedzi słowa spod ronda kapelusza, mierząc, ile możesz być wart.",
		 "Odpowiedź jest krótka jak strzał; reszta zostaje przemilczana."],
		["Ruszasz środkiem ulicy; w takim miejscu każdy krok jest deklaracją.",
		 "Przemieszczasz się dalej, a spojrzenia zza okien odprowadzają cię jak lufy."],
		["Dłoń zawisa nad kolbą — tu spory rozstrzyga szybkość i zimna krew.",
		 "Huk wystrzału rozdziera ciszę; kurz jeszcze nie opadł, a układ sił już się zmienił."],
		["Miasteczko zapamiętuje twój ruch — a wieść rozchodzi się szybciej niż jeździec.",
		 "Coś się napina w tle: to, co robisz, właśnie naraziło cię komuś wpływowemu."],
		{"name": "Saloon", "note": "Serce miasteczka: whisky, karty i zbyt wiele broni."},
		{"name": "Preria", "note": "Bezkresna, niczyja ziemia za ostatnimi zabudowaniami."},
		{"name": "Kopalnia", "note": "Opuszczone sztolnie skrywające cudze tajemnice."},
		["Wypij drinka i posłuchaj w saloonie", "Prześledź świeże ślady koni",
		 "Stań twarzą w twarz z rewolwerowcem", "Wyrusz w prerię za miasto", "Zajrzyj do opuszczonej kopalni"],
		[["Rewolwerowiec", "Strzelczyni"], ["Szeryf", "Pani szeryf"], ["Poszukiwacz złota", "Poszukiwaczka złota"], ["Hazardzista", "Hazardzistka"], ["Łowca nagród", "Łowczyni nagród"], ["Farmer", "Farmerka"]],
		{"era": "Dziki Zachód, lata 70. XIX wieku", "climate": "graniczne miasteczko, prawo sięga tak daleko jak lufa",
		 "supernatural": "brak", "tone": "twardy, honorowy",
		 "start_location": "Zakurzona ulica przed saloonem",
		 "mystery": "Do miasteczka zjeżdżają obcy, a stary poszukiwacz szepcze o żyle złota, przez którą już zginęli ludzie"})

	_p("steampunk", "Steampunk", "industrial",
		["Para syczy z mosiężnych zaworów, a zębatki obracają się gdzieś w ścianach miasta.",
		 "W powietrzu unosi się węglowy dym, a dyliżans parowy dudni po bruku.",
		 "Zegary tykają nierówno, a nad dachami sunie sterowiec."],
		["Wśród trybów i rur dostrzegasz mechanizm, który zmontowano wbrew wszelkim regułom sztuki.",
		 "Twoje oko wyławia detal: coś tu naprawiono naprędce, żeby ukryć, co naprawdę się stało."],
		["Rozmówca dobiera słowa precyzyjnie jak inżynier, ale unika jednego tematu.",
		 "Odpowiedź brzmi uczenie, tyle że mija się z tym, co widać na własne oczy."],
		["Ruszasz przez zaułki pełne pary i iskier; miasto pracuje, a ty wchodzisz w jego tryby.",
		 "Przemieszczasz się po skrzypiących pomostach — w dole huczą maszyny, których nikt nie zatrzymuje."],
		["Starcie wybucha w kłębach pary; mosiądz i pięść liczą się tak samo.",
		 "Rozgrywa się gwałtowna szamotanina wśród rozgrzanych rur i zaworów."],
		["Mechanizm miasta reaguje: twój ruch poruszył tryb, który pociągnie kolejne.",
		 "Coś zgrzyta w tle — szczegół, który za chwilę okaże się kluczowy."],
		{"name": "Herbaciarnia parowa", "note": "Lokal, gdzie przy trybikach i herbacie wymienia się plotki."},
		{"name": "Fabryczne przedmieścia", "note": "Dymiące obrzeża, gdzie kończy się porządek."},
		{"name": "Kotłownia", "note": "Rozgrzane trzewia miasta pełne rur i cieni."},
		["Zbadaj dziwny mechanizm", "Wypytaj inżyniera w herbaciarni",
		 "Przejdź po pomostach nad maszynami", "Zejdź do kotłowni", "Wsiądź na pokład sterowca"],
		[["Wynalazca", "Wynalazczyni"], ["Mechanik", "Mechaniczka"], ["Aeronauta", "Aeronautka"], ["Detektyw", "Detektywka"], ["Przemytnik", "Przemytniczka"], ["Inżynier gildii", "Inżynierka gildii"]],
		{"era": "Alternatywna epoka pary, XIX wiek", "climate": "miasto-maszyna napędzane parą i mosiądzem",
		 "supernatural": "brak, lecz technologia graniczy z cudem", "tone": "wynalazczy, industrialny",
		 "start_location": "Herbaciarnia parowa przy fabrycznym placu",
		 "mystery": "Wynalazca ginie w dniu prezentacji maszyny, a jego dzieło znika z zamkniętej hali"})
