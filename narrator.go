package main

// narrator.go — silnik narracji proceduralnej (tryb OFFLINE / DARMOWY).
//
// W przeciwieństwie do prototypu, w którym narracja offline zawsze brzmiała
// jak fantasy (karczma, flaszka, las), tutaj świat tworzony przez gracza —
// jego GATUNEK, EPOKA i LATA — realnie wpływa na klimat opisów, sugerowane
// wybory i miejsca dopisywane do Kroniki.

import (
	"fmt"
	mrand "math/rand"
	"strings"
)

// genreProfile opisuje słownictwo i klimat jednego gatunku świata.
type genreProfile struct {
	key   string
	label string
	scene string // podpowiedź tła sceny dla GUI (mapowana w app.js/styles.css)

	ambient []string // zdania budujące tło zmysłowe (dźwięki, zapachy, światło)
	look    []string // reakcja, gdy gracz obserwuje / bada / szuka
	talk    []string // reakcja, gdy gracz rozmawia / pyta / negocjuje
	move    []string // reakcja, gdy gracz się przemieszcza / skrada / ucieka
	fight   []string // reakcja, gdy gracz atakuje / walczy / broni się
	filler  []string // ogólne pchnięcie sceny do przodu

	socialHub Location // lokalny punkt spotkań (bar/karczma/mesa...)
	edge      Location // dzikie / peryferyjne obrzeże świata
	depth     Location // podziemie / wnętrze / głębia
}

var closingPrompts = []string{"Co robisz?", "Jaki masz plan?", "Co teraz?", "Jak reagujesz?", "Na co się decydujesz?"}

var genreProfiles = map[string]genreProfile{
	"fantasy": {
		key: "fantasy", label: "Fantasy", scene: "village",
		ambient:   []string{"W powietrzu wisi zapach dymu z palenisk i wilgotnej ziemi.", "Gdzieś w oddali bije samotny dzwon, a cienie wydłużają się między chatami.", "Wiatr niesie strzępy pieśni i szczęk kutego żelaza."},
		look:      []string{"Wśród codziennych szczegółów wypatrujesz coś, co nie pasuje: świeży znak wyryty w drewnie, ślad, którego nikt nie zdążył zetrzeć.", "Im dłużej się przyglądasz, tym wyraźniej widzisz, że ktoś próbował tu coś ukryć."},
		talk:      []string{"Rozmówca waży każde słowo, jakby bał się powiedzieć za dużo.", "Pada odpowiedź, ale w oczach twojego rozmówcy widać, że przemilcza to, co najważniejsze."},
		move:      []string{"Ruszasz naprzód; deski i błoto skrzypią pod stopami, a kilka głów odwraca się w twoją stronę.", "Przemieszczasz się ostrożnie — droga prowadzi w miejsce, o którym miejscowi mówią półgłosem."},
		fight:     []string{"Dłoń sama sięga po broń. Napięcie pęka, a najbliższe sekundy zadecydują o wszystkim.", "Rozgrywa się krótka, brutalna wymiana ciosów; kurz i krzyk mieszają się w jedno."},
		filler:    []string{"Kronika dopisuje nowy wers — a ktoś w pobliżu reaguje na twój ruch zbyt szybko, jakby na niego czekał.", "Scena drży: pojawia się drobny szczegół, którego wcześniej nie było, i zmienia układ sił."},
		socialHub: Location{"Karczma", "Miejsce plotek, pierwszych tropów i niepewnych sojuszy."},
		edge:      Location{"Czarny Las", "Niepokojące obrzeże znanego świata, gdzie kończą się ścieżki."},
		depth:     Location{"Podziemia", "Sieć starych korytarzy związanych z główną tajemnicą."},
	},
	"historyczny": {
		key: "historyczny", label: "Historyczny", scene: "old-town",
		ambient:   []string{"Bruk lśni od wilgoci, a nad dachami snuje się dym z kominów.", "Z rynku dobiega turkot wozów i nawoływania przekupniów.", "Kościelny zegar wybija godzinę, a gołębie zrywają się do lotu."},
		look:      []string{"Uważne oko wyławia detal, który nie pasuje do epoki: coś nowego w miejscu, gdzie wszystko jest stare.", "Wśród zwykłego zgiełku dostrzegasz spojrzenie, które śledzi każdy twój krok."},
		talk:      []string{"Rozmówca mówi ostrożnie — czasy są niepewne, a nieznajomym nie ufa się od razu.", "W odpowiedzi słychać wykręt; ktoś tu ma więcej do ukrycia niż do powiedzenia."},
		move:      []string{"Przeciskasz się przez zaułki; miasto ma swoje reguły, a ty właśnie wkraczasz na cudzy teren.", "Idziesz dalej, a wąskie uliczki zwężają się, jakby prowadziły cię tam, gdzie ktoś sobie zaplanował."},
		fight:     []string{"Napięcie zamienia się w gwałtowne szarpnięcie — w takich czasach spór rozstrzyga się szybko i twardo.", "Wybucha zamieszanie; w ciżbie trudno odróżnić przyjaciela od wroga."},
		filler:    []string{"Bieg wydarzeń nabiera tempa: to, co robisz, zaczyna zwracać uwagę niewłaściwych ludzi.", "Coś się przesuwa w tle historii — drobny gest, który za chwilę okaże się ważny."},
		socialHub: Location{"Gospoda", "Izba, gdzie schodzą się wieści, interesy i podejrzane układy."},
		edge:      Location{"Rogatki miasta", "Granica, za którą kończy się prawo i zaczyna niepewność."},
		depth:     Location{"Lochy", "Wilgotne podziemia pod starą częścią miasta."},
	},
	"noir": {
		key: "noir", label: "Kryminał / Noir", scene: "city-night",
		ambient:   []string{"Deszcz bębni o parapety, a neon nad drzwiami sączy czerwone światło na mokry chodnik.", "Gdzieś zawodzi saksofon, a z rynsztoka unosi się para.", "Reflektory samochodu przecinają mrok i znikają za rogiem."},
		look:      []string{"W szczegółach kryje się pierwszy fałsz: coś tu nie gra, a ty właśnie zaczynasz to widzieć.", "Twój wzrok zatrzymuje się na drobiazgu, który dla kogoś jest wart znacznie za dużo, by go zostawić."},
		talk:      []string{"Rozmówca uśmiecha się gładko, ale kłamie — pytanie tylko, w której części zdania.", "Odpowiedź brzmi zbyt równo, jakby ktoś ją wcześniej wyćwiczył."},
		move:      []string{"Idziesz dalej trzymając się cienia; w tym mieście uwaga jest kosztowna.", "Ruszasz przez mokre ulice, czując, że ktoś dotrzymuje ci kroku pół przecznicy z tyłu."},
		fight:     []string{"Sytuacja robi się brzydka — pięść albo spust, i to w ułamku sekundy.", "Cios pada nagle; w takim mieście przemoc nie zapowiada się grzecznie."},
		filler:    []string{"Sprawa się rozrasta: to, co robisz, właśnie pociągnęło za nitkę, której lepiej było nie ruszać.", "W tle miasta coś zgrzyta — trop, który prowadzi głębiej, niż chciałeś."},
		socialHub: Location{"Nocny bar", "Zadymiony lokal, gdzie kupuje się drinki i przemilczenia."},
		edge:      Location{"Doki", "Ciemne nabrzeże, gdzie znikają ludzie i ładunki."},
		depth:     Location{"Piwnice", "Zapomniane podziemia pod starą dzielnicą."},
	},
	"horror": {
		key: "horror", label: "Groza / Horror", scene: "dark",
		ambient:   []string{"Cisza jest zbyt gęsta, a każdy twój oddech brzmi za głośno.", "Gdzieś skrzypi deska, choć nikogo tam nie ma. Potem znowu — bliżej.", "Zimno wpełza pod ubranie, a światło drży, jakby czegoś się bało."},
		look:      []string{"Im uważniej patrzysz, tym mniej chcesz widzieć: coś tu było przed tobą i zostawiło ślad.", "W półmroku dostrzegasz zarys, który nie powinien się poruszać — a jednak drgnął."},
		talk:      []string{"Odpowiedź pada szeptem, urwana w połowie, jakby ktoś nakazał milczeć.", "Rozmówca patrzy za twoje ramię, blednie i nie kończy zdania."},
		move:      []string{"Robisz krok naprzód; ciemność zdaje się cofać dokładnie o tyle, byś szedł dalej.", "Idziesz, a podłoga pod tobą jest lepka, zimna i cicho oddaje każdy krok echem."},
		fight:     []string{"Panika i instynkt biorą górę — bijesz na oślep w coś, co nie reaguje jak człowiek.", "To nie jest walka, to ucieczka do przodu; liczy się tylko, byś przetrwał następną chwilę."},
		filler:    []string{"Coś się zmienia w powietrzu — jesteś pewny, że nie jesteś tu sam.", "Kronika grozy dopisuje wers: to, co robisz, właśnie ściągnęło na ciebie czyjąś uwagę."},
		socialHub: Location{"Opuszczony dom", "Miejsce, które udaje bezpieczne schronienie."},
		edge:      Location{"Mgła za osadą", "Granica, za którą znika droga powrotna."},
		depth:     Location{"Piwnica", "Zimne podziemie, z którego dobiega dźwięk."},
	},
	"scifi": {
		key: "scifi", label: "Science fiction", scene: "station",
		ambient:   []string{"Pod pokładem miarowo pulsuje reaktor, a powietrze pachnie metalem i chłodziwem.", "Na ścianach mrugają diody, a przez iluminator widać powolny obrót gwiazd.", "System wentylacji szumi jednostajnie, aż nagle na moment cichnie."},
		look:      []string{"Skan i własne oczy zgadzają się co do jednego: te dane nie powinny tak wyglądać.", "Wśród rutynowych odczytów wyłapujesz anomalię, którą ktoś próbował ukryć w logach."},
		talk:      []string{"Rozmówca odpowiada rzeczowo, ale interfejs zdradza mikroopóźnienie — waha się.", "Pada odpowiedź, jednak protokół, na który się powołuje, dawno przestał obowiązywać."},
		move:      []string{"Ruszasz korytarzem; grodzie rozsuwają się z sykiem, a echo kroków niesie się daleko.", "Przemieszczasz się przez sekcję, w której część świateł jest wygaszona — i nie wiadomo, przez kogo."},
		fight:     []string{"Sytuacja eskaluje w ułamku sekundy — w zamkniętej przestrzeni nie ma gdzie uciec.", "Rozgrywa się gwałtowne starcie; alarmy zawodzą, a grawitacja nie ułatwia zadania."},
		filler:    []string{"Systemy notują zmianę: twoje działanie właśnie uruchomiło coś w tle.", "Coś przesuwa się w danych stacji — sygnał, którego nikt nie zaplanował."},
		socialHub: Location{"Mesa załogi", "Wspólna przestrzeń, gdzie krążą plotki i nieoficjalne wersje wydarzeń."},
		edge:      Location{"Sektor zewnętrzny", "Peryferie konstrukcji, gdzie kończy się zasięg czujników."},
		depth:     Location{"Ładownia", "Mroczne wnętrze pełne kontenerów i cieni."},
	},
	"cyberpunk": {
		key: "cyberpunk", label: "Cyberpunk", scene: "neon",
		ambient:   []string{"Neony ociekają na mokry beton, a holoreklamy krzyczą w językach, których nikt już nie słucha.", "W tle dudni bas z klubu piętro niżej, a implanty wyłapują szum obcych sieci.", "Deszcz miesza się z parą z ulicznych kuchni; miasto nigdy nie śpi."},
		look:      []string{"Nakładka AR podświetla to, co reszta tłumu ignoruje: ślad w danych, który ktoś zostawił przez pomyłkę.", "Twój wzrok — własny i ten wzmocniony — łapie niespójność, wartą więcej niż całe piętro tej dzielnicy."},
		talk:      []string{"Rozmówca handluje informacją jak każdą inną — pytanie brzmi, ile naprawdę kosztuje prawda.", "Odpowiedź jest gładka i skorporowana; gdzieś pod nią pływa drugie dno."},
		move:      []string{"Wtapiasz się w tłum i neon; w tym mieście anonimowość trwa tylko tak długo, jak twój ślad w sieci.", "Ruszasz zaułkiem między wieżowcami — tu prawo kończy się tam, gdzie zaczyna się cudza działka."},
		fight:     []string{"Wszystko przyspiesza: implanty, adrenalina i spust reagują szybciej niż myśl.", "Starcie jest krótkie i elektryczne; w tej dzielnicy przegrany nie dostaje drugiej szansy."},
		filler:    []string{"Sieć drgnęła: twoje działanie właśnie zostawiło ślad, który ktoś na pewno odczyta.", "Coś porusza się w cieniu danych — kontrakt, który zaczyna cię obejmować."},
		socialHub: Location{"Bar z neonami", "Lokal, gdzie kupuje się drinki, dane i cudze sekrety."},
		edge:      Location{"Zapomniana dzielnica", "Strefa poza zasięgiem korporacyjnych kamer."},
		depth:     Location{"Podziemia sieci", "Serwerownie i tunele pod świecącym miastem."},
	},
	"postapo": {
		key: "postapo", label: "Postapokalipsa", scene: "wasteland",
		ambient:   []string{"Wiatr niesie pył i skrzypienie blachy; świat dawno przestał być taki, jak go pamiętano.", "Słońce wisi rdzawo nad ruinami, a każdy dźwięk niesie się za daleko.", "Gdzieś stuka luźna płyta, a licznik w głowie odlicza to, czego nie widać."},
		look:      []string{"Wśród gruzu wypatrujesz coś wartościowego — albo ślad, że ktoś był tu przed chwilą.", "Im dłużej patrzysz, tym jaśniej widzisz: to miejsce nie jest tak opuszczone, jak udaje."},
		talk:      []string{"Rozmówca mierzy cię wzrokiem, licząc, czy bardziej się opłacasz żywy, czy martwy.", "Odpowiedź pada skąpo — słowa też są tu towarem deficytowym."},
		move:      []string{"Ruszasz przez pustkowie, trzymając się osłon; otwarta przestrzeń to zaproszenie do kłopotów.", "Przemieszczasz się między wrakami, a każdy krok wzbija pył, który cię zdradza."},
		fight:     []string{"Tu nie ma zasad — liczy się to, kto pierwszy i kto celniej.", "Wybucha brutalne starcie o to, co jeszcze zostało; przegrany nie zabiera niczego."},
		filler:    []string{"Pustkowie reaguje: twój ruch obudził coś albo kogoś, kto właśnie rusza w twoją stronę.", "Coś zmienia się na horyzoncie — kurz, który wzbija się nie od wiatru."},
		socialHub: Location{"Schronienie ocalałych", "Prowizoryczna osada, gdzie handluje się wszystkim."},
		edge:      Location{"Pustkowie", "Skażona, otwarta przestrzeń pełna wraków i zagrożeń."},
		depth:     Location{"Tunele metra", "Podziemia, w których chroni się to, co nie chce być widziane."},
	},
	"western": {
		key: "western", label: "Western", scene: "frontier",
		ambient:   []string{"Kurz wisi nad pustą ulicą, a szyld saloonu skrzypi na gorącym wietrze.", "Gdzieś rży koń, a ostrogi dzwonią o deski chodnika.", "Słońce praży bezlitośnie, a cień pod okapem jest jedynym schronieniem."},
		look:      []string{"Pod maską sennego miasteczka dostrzegasz napięcie: ktoś tu na coś czeka.", "Twój wzrok wyłapuje detal — ślad koni, świeży, prowadzący tam, gdzie nie powinien."},
		talk:      []string{"Rozmówca cedzi słowa spod ronda kapelusza, mierząc, ile możesz być wart.", "Odpowiedź jest krótka jak strzał; reszta zostaje przemilczana."},
		move:      []string{"Ruszasz środkiem ulicy; w takim miejscu każdy krok jest deklaracją.", "Przemieszczasz się dalej, a spojrzenia zza okien odprowadzają cię jak lufy."},
		fight:     []string{"Dłoń zawisa nad kolbą — tu spory rozstrzyga szybkość i zimna krew.", "Huk wystrzału rozdziera ciszę; kurz jeszcze nie opadł, a układ sił już się zmienił."},
		filler:    []string{"Miasteczko zapamiętuje twój ruch — a wieść rozchodzi się szybciej niż jeździec.", "Coś się napina w tle: to, co robisz, właśnie naraziło cię komuś wpływowemu."},
		socialHub: Location{"Saloon", "Serce miasteczka: whisky, karty i zbyt wiele broni."},
		edge:      Location{"Preria", "Bezkresna, niczyja ziemia za ostatnimi zabudowaniami."},
		depth:     Location{"Kopalnia", "Opuszczone sztolnie skrywające cudze tajemnice."},
	},
	"steampunk": {
		key: "steampunk", label: "Steampunk", scene: "industrial",
		ambient:   []string{"Para syczy z mosiężnych zaworów, a zębatki obracają się gdzieś w ścianach miasta.", "W powietrzu unosi się węglowy dym, a dyliżans parowy dudni po bruku.", "Zegary tykają nierówno, a nad dachami sunie sterowiec."},
		look:      []string{"Wśród trybów i rur dostrzegasz mechanizm, który zmontowano wbrew wszelkim regułom sztuki.", "Twoje oko wyławia detal: coś tu naprawiono naprędce, żeby ukryć, co naprawdę się stało."},
		talk:      []string{"Rozmówca dobiera słowa precyzyjnie jak inżynier, ale unika jednego tematu.", "Odpowiedź brzmi uczenie, tyle że mija się z tym, co widać na własne oczy."},
		move:      []string{"Ruszasz przez zaułki pełne pary i iskier; miasto pracuje, a ty wchodzisz w jego tryby.", "Przemieszczasz się po skrzypiących pomostach — w dole huczą maszyny, których nikt nie zatrzymuje."},
		fight:     []string{"Starcie wybucha w kłębach pary; mosiądz i pięść liczą się tak samo.", "Rozgrywa się gwałtowna szamotanina wśród rozgrzanych rur i zaworów."},
		filler:    []string{"Mechanizm miasta reaguje: twój ruch poruszył tryb, który pociągnie kolejne.", "Coś zgrzyta w tle — szczegół, który za chwilę okaże się kluczowy."},
		socialHub: Location{"Herbaciarnia parowa", "Lokal, gdzie przy trybikach i herbacie wymienia się plotki."},
		edge:      Location{"Fabryczne przedmieścia", "Dymiące obrzeża, gdzie kończy się porządek."},
		depth:     Location{"Kotłownia", "Rozgrzane trzewia miasta pełne rur i cieni."},
	},
	"modern": {
		key: "modern", label: "Współczesność", scene: "city",
		ambient:   []string{"Miasto szumi ruchem, a ekrany i szyby odbijają nerwowe światło dnia.", "Z ulicy dobiega klakson i strzępy rozmów, a telefon w kieszeni znów wibruje.", "Zapach kawy miesza się ze spalinami; wszyscy gdzieś się spieszą."},
		look:      []string{"Wśród codziennego zgiełku wyłapujesz szczegół, który nie pasuje — drobiazg nie na miejscu.", "Im uważniej patrzysz, tym pewniej wiesz, że ktoś obserwuje to samo co ty."},
		talk:      []string{"Rozmówca odpowiada uprzejmie, ale coś w tonie zdradza, że mówi mniej, niż wie.", "Pada gładka odpowiedź; dopiero potem uświadamiasz sobie, że nie odpowiada na pytanie."},
		move:      []string{"Ruszasz dalej, wtapiając się w tłum; w mieście łatwo zniknąć i łatwo dać się śledzić.", "Przemieszczasz się przez ulice, a znajome otoczenie zaczyna wydawać się subtelnie nie takie."},
		fight:     []string{"Sytuacja wymyka się spod kontroli — przemoc wybucha nagle, między zwykłymi ludźmi.", "Krótkie, chaotyczne szarpnięcie; wokół rozlegają się krzyki i trzask upadających rzeczy."},
		filler:    []string{"Sprawa się rozrasta: twój ruch właśnie zwrócił czyjąś uwagę, której wolałbyś uniknąć.", "Coś przesuwa się w tle codzienności — szczegół, który zmienia znaczenie całej sceny."},
		socialHub: Location{"Kawiarnia", "Zwykłe miejsce spotkań, gdzie padają niezwykłe słowa."},
		edge:      Location{"Obrzeża miasta", "Pustostany i nieużytki, gdzie kończy się miejski porządek."},
		depth:     Location{"Parking podziemny", "Betonowa głębia pod miastem, pełna echa."},
	},
}

// detectGenre klasyfikuje wolny opis świata (gatunek + epoka + rok + klimat)
// na jeden z obsługiwanych profili narracji.
func detectGenre(w World) string {
	s := strings.ToLower(strings.Join([]string{w.Genre, w.Era, w.Year, w.Climate, w.Supernatural, w.Tone}, " "))
	switch {
	case containsAny(s, "cyberpunk", "neon", "korporac", "augment", "cybernet", "netrunner", "implant", "hologram", "sieć neuro"):
		return "cyberpunk"
	case containsAny(s, "sci-fi", "science fiction", "kosmos", "kosmiczn", "galakt", "orbit", "gwiezd", "android", "reaktor", "statek kosmiczny", "międzygwiezd", "planet", "stacja kosmiczn"):
		return "scifi"
	case containsAny(s, "postapo", "post-apo", "apokalip", "nuklearn", "pustkowi", "zombie", "skażen", "wasteland", "po zagładzie", "po katastrof"):
		return "postapo"
	case containsAny(s, "steampunk", "parow", "wiktoriańsk", "sterowiec", "zębatk", "mosiądz"):
		return "steampunk"
	case containsAny(s, "western", "dziki zachód", "rewolwer", "kowboj", "preri", "szeryf", "saloon"):
		return "western"
	case containsAny(s, "noir", "kryminał", "detektyw", "gangster", "prohibicj", "mafia", "śledztw", "zbrodni", "morderstw", "prywatny detektyw"):
		return "noir"
	case containsAny(s, "horror", "groza", "upiór", "upior", "duch", "nawiedz", "koszmar", "demon", "potwór", "potwor", "przerażaj", "makabr"):
		return "horror"
	case containsAny(s, "fantasy", "magia", "magicz", "smok", "elf", "krasnolud", "czarodziej", "czarnoksięż", "miecz i magia", "baśni", "mityczn"):
		return "fantasy"
	case containsAny(s, "historyczn", "średniowiecz", "starożytn", "antyk", "rzym", "wiking", "napoleon", "renesans", "barok", "xviii", "xix wiek", "międzywoj", "ii wojn", "prl"):
		return "historyczny"
	case containsAny(s, "współczes", "wspolczes", "nowożytn", "xxi wiek", "xx wiek", "dzisiejsz", "teraźniejsz", "metropol", "miejsk", "sensacyjn", "thriller"):
		return "modern"
	default:
		return "fantasy"
	}
}

func profileFor(w World) genreProfile {
	if p, ok := genreProfiles[w.GenreKind]; ok {
		return p
	}
	return genreProfiles[detectGenre(w)]
}

func containsAny(s string, subs ...string) bool {
	for _, sub := range subs {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}

func pick(pool []string) string {
	if len(pool) == 0 {
		return ""
	}
	return pool[mrand.Intn(len(pool))]
}

// consequenceLine zamienia znacznik wyniku rzutu (dopięty do decyzji gracza)
// na literackie zdanie o konsekwencji. Zwraca pusty string, gdy brak rzutu.
func consequenceLine(low string) string {
	switch {
	case strings.Contains(low, "krytyczne niepowodzenie"):
		return "Wszystko idzie gorzej, niż powinno — drobny błąd zamienia się w problem, którego nie da się już zignorować. "
	case strings.Contains(low, "krytyczny sukces"):
		return "Udaje się ponad oczekiwania; przez chwilę los wyraźnie sprzyja właśnie tobie. "
	case strings.Contains(low, "częściowy sukces"):
		return "Osiągasz część celu, ale cena okazuje się odczuwalna. "
	case strings.Contains(low, "niepowodzenie"):
		return "Próba nie wychodzi tak, jak planowano — pojawia się komplikacja. "
	case strings.Contains(low, "sukces"):
		return "Działanie przynosi efekt i sytuacja przesuwa się na twoją korzyść. "
	}
	return ""
}

var (
	lookWords  = []string{"rozglą", "obserw", "szukam", "badam", "sprawdz", "przygląd", "nasłuch", "patrz", "zaglądam", "analiz", "wypatr", "czytam"}
	talkWords  = []string{"pyta", "mówię", "mowie", "rozmaw", "zagad", "krzycz", "proszę", "prosze", "negocj", "przekonuj", "odpowiadam", "szept", "wołam", "wolam", "gadam"}
	moveWords  = []string{"idę", "ide", "biegn", "wchodzę", "wchodze", "podchodzę", "skradam", "uciek", "cofam", "ruszam", "wspina", "przeskak", "jadę", "jade", "schodzę", "wychodzę", "chowam", "ukry", "przemyk"}
	fightWords = []string{"atak", "uderz", "walcz", "strzel", "ciosem", "dobywam", "tnę", "bronię", "bronie", "cios", "rzucam się", "duszę", "kopn", "wyrywam"}
)

// proceduralAnswer generuje odpowiedź narratora w trybie offline, dopasowaną
// do gatunku świata oraz kategorii akcji gracza.
func proceduralAnswer(a Adventure, c Character, action string, roll *Roll) string {
	low := strings.ToLower(action)
	p := profileFor(a.World)
	cons := consequenceLine(low)

	var pool []string
	switch {
	case containsAny(low, lookWords...):
		pool = p.look
	case containsAny(low, talkWords...):
		pool = p.talk
	case containsAny(low, fightWords...):
		pool = p.fight
	case containsAny(low, moveWords...):
		pool = p.move
	default:
		pool = p.filler
	}

	parts := []string{}
	if cons != "" {
		parts = append(parts, strings.TrimSpace(cons))
	}
	if body := pick(pool); body != "" {
		parts = append(parts, body)
	}
	if amb := pick(p.ambient); amb != "" {
		parts = append(parts, amb)
	}
	out := strings.Join(parts, " ")
	if out == "" {
		out = fmt.Sprintf("%s działa dalej, a świat %s reaguje na ten ruch.", c.Name, a.World.Name)
	}
	return strings.TrimSpace(out + " " + pick(closingPrompts))
}

// fallbackLocationDescription buduje opis startowej lokacji, gdy gracz jej nie podał.
func fallbackLocationDescription(w World) string {
	loc := strings.TrimSpace(w.StartLocation)
	if loc == "" {
		loc = "miejsce startowe"
	}
	p := genreProfiles[detectGenre(w)]
	genre := strings.TrimSpace(w.Genre)
	if genre == "" {
		genre = p.label
	}
	climate := strings.TrimSpace(w.Climate)
	if climate == "" {
		climate = "tajemnica i napięcie"
	}
	when := periodPhrase(w)
	return fmt.Sprintf("%s to punkt startowy przygody w konwencji %s%s. Klimat miejsca: %s. %s W pobliżu czuć ślad głównej tajemnicy: %s.",
		loc, genre, when, climate, pick(p.ambient), strings.TrimSpace(w.Mystery))
}

// periodPhrase składa czytelny opis czasu akcji z epoki i roku.
func periodPhrase(w World) string {
	era := strings.TrimSpace(w.Era)
	year := strings.TrimSpace(w.Year)
	switch {
	case era != "" && year != "":
		return " (epoka: " + era + ", rok/lata: " + year + ")"
	case era != "":
		return " (epoka: " + era + ")"
	case year != "":
		return " (rok/lata: " + year + ")"
	}
	return ""
}

// openingFallback tworzy scenę otwierającą w trybie offline, dopasowaną do gatunku.
func openingFallback(a Adventure, c Character) string {
	desc := strings.TrimSpace(a.World.StartDescription)
	if desc == "" {
		desc = fallbackLocationDescription(a.World)
	}
	p := profileFor(a.World)
	tone := strings.TrimSpace(a.World.Tone)
	if tone == "" {
		tone = "tajemniczy"
	}
	when := strings.TrimSpace(periodPhrase(a.World))
	if when == "" {
		when = "Czas i miejsce dopiero się splatają"
	} else {
		when = "Czas akcji " + strings.Trim(when, "()")
	}
	return fmt.Sprintf(`%s znajduje się w miejscu: %s. %s

To początek przygody w świecie %s (%s). Ton opowieści jest %s, a %s

%s ma przy sobie swoje doświadczenie, słabości i cel: %s. Tuż obok pojawia się pierwszy szczegół, który może stać się tropem — a jego cień pada wprost na główną tajemnicę: %s.

%s`,
		c.Name, a.Location, desc,
		a.World.Name, p.label, tone, when+".",
		c.Name, strings.TrimSpace(c.Goal), strings.TrimSpace(a.World.Mystery),
		pick(closingPrompts))
}

// updateWorldMemoryLocked dopisuje do Kroniki miejsca, wątki i relacje —
// nazwane zgodnie z gatunkiem świata, nie wyłącznie po fantasy.
func updateWorldMemoryLocked(ai int, action, answer string) {
	a := &db.Adventures[ai]
	p := profileFor(a.World)
	ctx := strings.ToLower(action + " " + answer)

	addLoc := func(l Location) {
		if l.Name == "" {
			return
		}
		for _, x := range a.Locations {
			if x.Name == l.Name {
				return
			}
		}
		a.Locations = append(a.Locations, l)
	}
	addQuest := func(t, n string) {
		for _, q := range a.Quests {
			if q.Title == t {
				return
			}
		}
		a.Quests = append(a.Quests, Quest{t, n, "aktywne"})
	}
	addDisc := func(t, ty string) {
		for _, d := range a.Discoveries {
			if d.Title == t {
				return
			}
		}
		a.Discoveries = append(a.Discoveries, Discovery{t, ty, clock()})
	}

	if containsAny(ctx, "bar", "karcz", "gospod", "saloon", "kawiar", "tawern", "knajp", "mesa", "herbaciar", "schronieni") {
		addLoc(p.socialHub)
	}
	if containsAny(ctx, "las", "puszcz", "pustkowi", "obrzeż", "preri", "dok", "przedmieś", "rogatk", "dzielnic", "mgł", "sektor") {
		addLoc(p.edge)
	}
	if containsAny(ctx, "podziem", "tunel", "piwnic", "loch", "kopal", "ładown", "kotłow", "metro", "kanał", "serwer") {
		addLoc(p.depth)
	}
	if containsAny(ctx, "klucz", "kod", "hasł", "przepustk") {
		addDisc("Klucz / kod dostępu", "Przedmiot")
	}
	if containsAny(ctx, "map", "plan", "szkic", "schemat") {
		addDisc("Mapa / plan okolicy", "Wiedza")
	}
	if containsAny(ctx, "list", "notatk", "dziennik", "log", "wiadomoś") {
		addDisc("Zapisana wiadomość", "Trop")
	}
	if containsAny(ctx, "zagin", "zniknął", "zniknęła", "porwan") {
		addQuest("Zaginiony trop", "Ustal, kto lub co zniknęło i dlaczego.")
	}
}
