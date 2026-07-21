package main

import (
    "bytes"
    "context"
    "crypto/rand"
    "embed"
    "encoding/hex"
    "encoding/json"
    "errors"
    "fmt"
    "io"
    "log"
    "mime/multipart"
    "net"
    "net/http"
    "os"
    "os/exec"
    "path/filepath"
    "runtime"
    "sort"
    "strings"
    "sync"
    "time"
)

//go:embed app/*
var appFS embed.FS

const version = "2.0.9-genre-aware"

type Settings struct {
    AIMode          string  `json:"aiMode"`
    OllamaModel     string  `json:"ollamaModel"`
    BielikModel      string  `json:"bielikModel"`
    ClaudeBaseURL    string  `json:"claudeBaseUrl"`
    ClaudeModel      string  `json:"claudeModel"`
    ClaudeToken      string  `json:"claudeToken,omitempty"`
    ClaudeAuthType   string  `json:"claudeAuthType"`
    OpenAIEndpoint   string  `json:"openAiEndpoint"`
    OpenAIModel      string  `json:"openAiModel"`
    OpenAIAPIKey     string  `json:"openAiApiKey,omitempty"`
    Temperature      float64 `json:"temperature"`
    WindowMode       string  `json:"windowMode"`
}

type Attributes struct {
    Strength   int `json:"strength"`
    Dexterity  int `json:"dexterity"`
    Condition  int `json:"condition"`
    Mind       int `json:"mind"`
    Perception int `json:"perception"`
    Charisma   int `json:"charisma"`
    Will       int `json:"will"`
    Luck       int `json:"luck"`
    Technique  int `json:"technique"`
    Survival   int `json:"survival"`
}

type Character struct {
    ID          string     `json:"id"`
    Name        string     `json:"name"`
    Age         string     `json:"age"`
    Gender      string     `json:"gender"`
    Race        string     `json:"race"`
    Class       string     `json:"class"`
    Origin      string     `json:"origin"`
    Goal        string     `json:"goal"`
    Flaw        string     `json:"flaw"`
    Strength    string     `json:"strength"`
    Secret      string     `json:"secret"`
    AvatarPath  string     `json:"avatarPath"`
    Level       int        `json:"level"`
    XP          int        `json:"xp"`
    HP          int        `json:"hp"`
    AttributePt int        `json:"attributePoints"`
    Attributes  Attributes `json:"attributes"`
    Inventory   []string   `json:"inventory"`
    History     []string   `json:"history"`
    UpdatedAt   string     `json:"updatedAt"`
}

type World struct {
    ID             string   `json:"id"`
    Name           string   `json:"name"`
    Genre          string   `json:"genre"`
    GenreKind      string   `json:"genreKind"`
    Year           string   `json:"year"`
    Climate        string   `json:"climate"`
    Era            string   `json:"era"`
    Supernatural   string   `json:"supernatural"`
    Mystery        string   `json:"mystery"`
    StartLocation  string   `json:"startLocation"`
    StartDescription string `json:"startDescription"`
    Avoid          string   `json:"avoid"`
    Tone           string   `json:"tone"`
    Rules          []string `json:"rules"`
}

type Message struct {
    Role string `json:"role"`
    Text string `json:"text"`
    Time string `json:"time"`
}

type Quest struct { Title, Note, Status string }
type Relation struct { Name, Status string; Value int; AvatarPath string }
type Discovery struct { Title, Type, Time string }
type Location struct { Name, Description string }

type Adventure struct {
    ID          string      `json:"id"`
    Title       string      `json:"title"`
    CharacterID string      `json:"characterId"`
    World       World       `json:"world"`
    Location    string      `json:"location"`
    Chapter     int         `json:"chapter"`
    Mood        string      `json:"mood"`
    Log         []Message   `json:"log"`
    Quests      []Quest     `json:"quests"`
    Relations   []Relation  `json:"relations"`
    Discoveries []Discovery `json:"discoveries"`
    Locations   []Location  `json:"locations"`
    Inventory   []string    `json:"inventory"`
    UpdatedAt   string      `json:"updatedAt"`
}

type DB struct {
    Version           string       `json:"version"`
    Settings          Settings     `json:"settings"`
    Characters        []Character  `json:"characters"`
    Adventures        []Adventure  `json:"adventures"`
    ActiveCharacterID string       `json:"activeCharacterId"`
    ActiveAdventureID string       `json:"activeAdventureId"`
}

var (
    mu sync.Mutex
    db DB
    baseDir string
    dataDir string
    dbPath string
    logger *log.Logger
)

func main() {
    initPaths()
    loadDB()

    mux := http.NewServeMux()
    mux.HandleFunc("/", handleIndex)
    mux.HandleFunc("/app.js", handleAsset("app/app.js", "application/javascript; charset=utf-8"))
    mux.HandleFunc("/styles.css", handleAsset("app/styles.css", "text/css; charset=utf-8"))
    mux.HandleFunc("/api/state", handleState)
    mux.HandleFunc("/api/settings", handleSettings)
    mux.HandleFunc("/api/characters", handleCharacters)
    mux.HandleFunc("/api/characters/select", handleSelectCharacter)
    mux.HandleFunc("/api/characters/upload-avatar", handleAvatarUpload)
    mux.HandleFunc("/api/adventures/new", handleNewAdventure)
    mux.HandleFunc("/api/adventures/select", handleSelectAdventure)
    mux.HandleFunc("/api/adventures/delete", handleDeleteAdventure)
    mux.HandleFunc("/api/send", handleSend)
    mux.HandleFunc("/api/test-ai", handleTestAI)
    mux.HandleFunc("/api/export", handleExport)
    mux.HandleFunc("/api/shutdown", handleShutdown)
    mux.Handle("/data/", http.StripPrefix("/data/", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request){
        w.Header().Set("Cache-Control", "no-store")
        http.FileServer(http.Dir(dataDir)).ServeHTTP(w,r)
    })))

    ln, err := net.Listen("tcp", "127.0.0.1:0")
    if err != nil { panic(err) }
    url := "http://" + ln.Addr().String()
    go func(){ _ = http.Serve(ln, logging(mux)) }()
    time.Sleep(200*time.Millisecond)
    openApp(url, db.Settings.WindowMode)
    select {}
}

func logging(next http.Handler) http.Handler { return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request){ next.ServeHTTP(w,r) }) }

func initPaths() {
    exe, err := os.Executable(); if err != nil { exe = "." }
    baseDir = filepath.Dir(exe)
    if strings.HasPrefix(baseDir, "/tmp") || strings.HasPrefix(baseDir, "/mnt/data") { baseDir, _ = os.Getwd() }
    dataDir = filepath.Join(baseDir, "data")
    for _, d := range []string{"characters","adventures","avatars","backgrounds","exports"} { os.MkdirAll(filepath.Join(dataDir,d),0755) }
    dbPath = filepath.Join(dataDir, "db.json")
    lf, _ := os.OpenFile(filepath.Join(baseDir, "error_log.txt"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
    logger = log.New(lf, "", log.LstdFlags)
}

func defaultSettings() Settings {
    return Settings{AIMode:"procedural", OllamaModel:"llama3.1:8b", BielikModel:"SpeakLeash/bielik-11b-v3.0-instruct:Q4_K_M", ClaudeBaseURL:"https://aiprimetech.io", ClaudeModel:"claude-sonnet-5", ClaudeAuthType:"bearer", OpenAIEndpoint:"https://api.openai.com/v1/chat/completions", OpenAIModel:"gpt-4o-mini", Temperature:0.85, WindowMode:"window"}
}

func loadDB() {
    mu.Lock(); defer mu.Unlock()
    db = DB{Version:version, Settings:defaultSettings(), Characters:[]Character{}, Adventures:[]Adventure{}}
    b, err := os.ReadFile(dbPath); if err == nil { _ = json.Unmarshal(b, &db) }
    if db.Settings.AIMode == "" { db.Settings = defaultSettings() }
    if db.Settings.WindowMode == "" { db.Settings.WindowMode = "window" }
    db.Version = version
    seedIfEmpty()
    saveDBLocked()
}

func seedIfEmpty() {
    if len(db.Characters) > 0 { return }
    c := Character{ID:newID("char"), Name:"Arlen", Age:"28", Gender:"Mężczyzna", Race:"Człowiek", Class:"Wojownik", Origin:"Niziny Velmory", Goal:"Odkryć prawdę o zaginionym bracie", Flaw:"Impulsywny i nie ufa łatwo innym", Strength:"Niezłomny i lojalny", Secret:"Nosi znak zdrady, o którym nikt nie wie", Level:3, XP:450, HP:32, AttributePt:0, Attributes:Attributes{16,14,15,12,13,11,14,10,8,12}, Inventory:[]string{"znoszony płaszcz","nóż podróżny","notatnik"}, History:[]string{"Stworzono postać startową."}, UpdatedAt:now()}
    db.Characters = append(db.Characters,c)
    db.ActiveCharacterID = c.ID
}

func saveDBLocked() { b,_:=json.MarshalIndent(db,"","  "); _=os.WriteFile(dbPath,b,0644) }
func saveDB(){ mu.Lock(); defer mu.Unlock(); saveDBLocked() }
func now() string { return time.Now().Format("2006-01-02 15:04:05") }
func clock() string { return time.Now().Format("15:04") }
func newID(prefix string) string { var b [6]byte; _,_=rand.Read(b[:]); return prefix+"_"+hex.EncodeToString(b[:]) }

func handleIndex(w http.ResponseWriter, r *http.Request) { if r.URL.Path != "/" { http.NotFound(w,r); return }; handleAsset("app/index.html", "text/html; charset=utf-8")(w,r) }
func handleAsset(name, ct string) http.HandlerFunc { return func(w http.ResponseWriter, r *http.Request){ b,err:=appFS.ReadFile(name); if err!=nil { http.NotFound(w,r); return }; w.Header().Set("Content-Type",ct); _,_=w.Write(b) } }
func writeJSON(w http.ResponseWriter, v any){ w.Header().Set("Content-Type","application/json; charset=utf-8"); _=json.NewEncoder(w).Encode(v) }
func readJSON(r *http.Request, v any) error { return json.NewDecoder(r.Body).Decode(v) }
func errJSON(w http.ResponseWriter, code int, msg string){ w.WriteHeader(code); writeJSON(w,map[string]any{"ok":false,"error":msg}) }

func handleState(w http.ResponseWriter, r *http.Request){ mu.Lock(); defer mu.Unlock(); writeJSON(w, map[string]any{"ok":true,"db":db}) }
func handleSettings(w http.ResponseWriter, r *http.Request){
    if r.Method == http.MethodGet { mu.Lock(); s:=db.Settings; mu.Unlock(); writeJSON(w,map[string]any{"ok":true,"settings":s}); return }
    var s Settings; if err:=readJSON(r,&s); err!=nil { errJSON(w,400,err.Error()); return }
    mu.Lock(); db.Settings=s; saveDBLocked(); mu.Unlock(); writeJSON(w,map[string]any{"ok":true})
}

func handleCharacters(w http.ResponseWriter, r *http.Request){
    if r.Method==http.MethodGet { mu.Lock(); chars:=db.Characters; mu.Unlock(); writeJSON(w,map[string]any{"ok":true,"characters":chars}); return }
    var c Character; if err:=readJSON(r,&c); err!=nil { errJSON(w,400,err.Error()); return }
    mu.Lock(); defer mu.Unlock()
    if c.ID=="" { c.ID=newID("char"); c.Level=1; c.XP=0; c.HP=100; if c.Attributes.Strength==0 { c.Attributes=Attributes{2,2,2,2,2,2,2,2,2,2} }; c.Inventory=[]string{"notatnik","znoszony płaszcz"}; c.History=[]string{"Postać została utworzona."} }
    c.UpdatedAt=now()
    found:=false
    for i:=range db.Characters { if db.Characters[i].ID==c.ID { db.Characters[i]=c; found=true } }
    if !found { db.Characters=append(db.Characters,c) }
    if db.ActiveCharacterID=="" { db.ActiveCharacterID=c.ID }
    saveDBLocked(); writeJSON(w,map[string]any{"ok":true,"character":c})
}

func handleSelectCharacter(w http.ResponseWriter, r *http.Request){ var in struct{ID string `json:"id"`}; if err:=readJSON(r,&in);err!=nil{errJSON(w,400,err.Error());return}; mu.Lock(); db.ActiveCharacterID=in.ID; saveDBLocked(); mu.Unlock(); writeJSON(w,map[string]any{"ok":true}) }

func handleAvatarUpload(w http.ResponseWriter, r *http.Request){
    if err:=r.ParseMultipartForm(25<<20); err!=nil { errJSON(w,400,err.Error()); return }
    id := strings.TrimSpace(r.FormValue("characterId"))
    if id=="" { errJSON(w,400,"Brak ID postaci"); return }
    file, hdr, err := r.FormFile("avatar"); if err!=nil { errJSON(w,400,err.Error()); return }; defer file.Close()
    ext := strings.ToLower(filepath.Ext(hdr.Filename)); if ext=="" { ext=".png" }
    if ext!=".png" && ext!=".jpg" && ext!=".jpeg" && ext!=".webp" { errJSON(w,400,"Dozwolone formaty: PNG, JPG, WEBP"); return }
    name := id + "_avatar" + ext
    dstPath := filepath.Join(dataDir,"avatars",name)
    dst, err := os.Create(dstPath); if err!=nil { errJSON(w,500,err.Error()); return }
    if _, err := io.Copy(dst,file); err != nil { _=dst.Close(); errJSON(w,500,err.Error()); return }
    _=dst.Close()
    rel := "/data/avatars/"+name
    mu.Lock()
    found := false
    var updated Character
    for i:=range db.Characters { if db.Characters[i].ID==id { db.Characters[i].AvatarPath=rel; db.Characters[i].UpdatedAt=now(); updated=db.Characters[i]; found=true } }
    if !found { mu.Unlock(); errJSON(w,404,"Nie znaleziono postaci do przypisania awatara"); return }
    saveDBLocked(); mu.Unlock()
    w.Header().Set("Cache-Control","no-store")
    writeJSON(w,map[string]any{"ok":true,"avatarPath":rel,"character":updated})
}


func buildOpeningPrompt(a Adventure, c Character) string {
    return fmt.Sprintf(`Jesteś KRONIKARZEM, Mistrzem Gry w polskiej tekstowej grze fabularnej.
Napisz pełną scenę otwierającą nową przygodę.

Wymagania:
- Pisz po polsku.
- Zacznij od sytuacji tu i teraz: gdzie znajduje się bohater, co widzi, co słyszy, co dzieje się wokół.
- Uwzględnij opis startowej lokacji. Jeśli jest ogólny, rozbuduj go literacko.
- Pokaż okoliczności rozpoczęcia przygody i pierwszy trop.
- Nie przejmuj kontroli nad decyzjami bohatera.
- Nie streszczaj zasad gry.
- Zakończ pytaniem "Co robisz?" albo jasną sytuacją wymagającą decyzji.
- Długość: 2-4 akapity.

BOHATER:
Imię: %s
Wiek: %s
Płeć: %s
Rasa: %s
Klasa/profesja: %s
Pochodzenie: %s
Cel: %s
Wada: %s
Zaleta: %s
Sekret: %s

ŚWIAT:
Nazwa: %s
Gatunek: %s
Klimat: %s
Epoka: %s
Rok / lata akcji: %s
Nadnaturalność: %s
Główna tajemnica: %s
Startowa lokacja: %s
Opis startowej lokacji: %s
Czego unikać: %s
Ton: %s`, c.Name,c.Age,c.Gender,c.Race,c.Class,c.Origin,c.Goal,c.Flaw,c.Strength,c.Secret,a.World.Name,a.World.Genre,a.World.Climate,a.World.Era,a.World.Year,a.World.Supernatural,a.World.Mystery,a.World.StartLocation,a.World.StartDescription,a.World.Avoid,a.World.Tone)
}

func callOpeningNarrator(ctx context.Context, s Settings, a Adventure, c Character) (string,error) {
    if s.AIMode=="" || s.AIMode=="procedural" { return openingFallback(a,c), nil }
    prompt := buildOpeningPrompt(a,c)
    switch s.AIMode {
    case "ollama", "bielik":
        model := s.OllamaModel; if s.AIMode=="bielik" { model=s.BielikModel }
        return callOllama(ctx, model, prompt)
    case "claude_proxy", "claude":
        return callClaude(ctx,s,prompt)
    case "openai":
        return callOpenAI(ctx,s,prompt)
    default:
        return openingFallback(a,c), nil
    }
}

func handleNewAdventure(w http.ResponseWriter, r *http.Request){
    var in struct{ CharacterID string `json:"characterId"`; World World `json:"world"` }
    if err:=readJSON(r,&in);err!=nil{errJSON(w,400,err.Error());return}
    if in.CharacterID=="" { errJSON(w,400,"Najpierw wybierz postać."); return }
    if in.World.Name=="" { in.World.Name="Velmora" }
    if in.World.StartLocation=="" { in.World.StartLocation="Osada Hadrin" }
    in.World.GenreKind = detectGenre(in.World)
    if strings.TrimSpace(in.World.StartDescription)=="" { in.World.StartDescription = fallbackLocationDescription(in.World) }
    if in.World.ID=="" { in.World.ID=newID("world") }
    in.World.Rules=[]string{"Świat powstaje przez rozmowę, ale zapisany kanon ma pierwszeństwo.","Nowe miejsca, postacie i tajemnice są dopisywane do Kroniki.","Unikać: "+in.World.Avoid}
    a := Adventure{ID:newID("adv"), Title:in.World.Name+" — Rozdział I", CharacterID:in.CharacterID, World:in.World, Location:in.World.StartLocation, Chapter:1, Mood:"Tajemnica", Log:[]Message{}, Quests:[]Quest{{Title:"Rozpocznij opowieść",Note:"Zbadaj pierwszy trop: "+in.World.Mystery,Status:"aktywne"}}, Relations:[]Relation{{Name:"Nieznajomy",Status:"nieznany",Value:10}}, Discoveries:[]Discovery{{Title:in.World.Mystery,Type:"Główna tajemnica",Time:clock()}}, Locations:[]Location{{Name:in.World.StartLocation,Description:in.World.StartDescription}}, Inventory:[]string{}, UpdatedAt:now()}
    hero := getChar(in.CharacterID)
    ctx, cancel := context.WithTimeout(context.Background(), 45*time.Second)
    intro, err := callOpeningNarrator(ctx, db.Settings, a, hero)
    cancel()
    if err != nil { logger.Println("opening", err); intro = openingFallback(a, hero) }
    a.Log=append(a.Log, Message{Role:"KRONIKARZ",Text:intro,Time:clock()})
    mu.Lock(); db.Adventures=append(db.Adventures,a); db.ActiveAdventureID=a.ID; db.ActiveCharacterID=in.CharacterID; saveDBLocked(); mu.Unlock()
    writeJSON(w,map[string]any{"ok":true,"adventure":a})
}

func handleSelectAdventure(w http.ResponseWriter,r *http.Request){ var in struct{ID string `json:"id"`}; if err:=readJSON(r,&in);err!=nil{errJSON(w,400,err.Error());return}; mu.Lock(); defer mu.Unlock(); for i:=range db.Adventures { if db.Adventures[i].ID==in.ID { db.ActiveAdventureID=in.ID; db.ActiveCharacterID=db.Adventures[i].CharacterID; saveDBLocked(); writeJSON(w,map[string]any{"ok":true,"db":db}); return } }; errJSON(w,404,"Nie znaleziono przygody.") }

func handleDeleteAdventure(w http.ResponseWriter,r *http.Request){
    var in struct{ID string `json:"id"`}
    if err:=readJSON(r,&in);err!=nil{errJSON(w,400,err.Error());return}
    if in.ID=="" { errJSON(w,400,"Brak ID przygody."); return }
    mu.Lock(); defer mu.Unlock()
    out := db.Adventures[:0]
    removed := false
    for _,adv := range db.Adventures { if adv.ID==in.ID { removed=true; continue }; out=append(out,adv) }
    if !removed { errJSON(w,404,"Nie znaleziono przygody."); return }
    db.Adventures = out
    if db.ActiveAdventureID==in.ID { db.ActiveAdventureID=""; if len(db.Adventures)>0 { db.ActiveAdventureID=db.Adventures[len(db.Adventures)-1].ID } }
    saveDBLocked(); writeJSON(w,map[string]any{"ok":true,"db":db})
}

func handleSend(w http.ResponseWriter, r *http.Request){
    var in struct{ Text string `json:"text"`; Roll *Roll `json:"roll"` }
    if err:=readJSON(r,&in);err!=nil{errJSON(w,400,err.Error());return}
    text:=strings.TrimSpace(in.Text); if text=="" { errJSON(w,400,"Pusta decyzja."); return }
    mu.Lock()
    ai := activeAdventureLocked(); if ai<0 { mu.Unlock(); errJSON(w,400,"Brak aktywnej przygody."); return }
    ci := charIndexLocked(db.Adventures[ai].CharacterID)
    display := text
    promptText := text
    if in.Roll!=nil { display = fmt.Sprintf("%s (rzut kością: %s, k20: %d)", text, in.Roll.Result, in.Roll.Value); promptText = display + "\nWynik rzutu jest obowiązkowy fabularnie: narrator musi pokazać konsekwencję tego wyniku." }
    db.Adventures[ai].Log=append(db.Adventures[ai].Log, Message{Role:"Ty",Text:display,Time:clock()})
    snapshot := db
    adventure := db.Adventures[ai]
    character := Character{}
    if ci>=0 { character=db.Characters[ci] }
    mu.Unlock()

    answer, err := callNarrator(context.Background(), snapshot.Settings, adventure, character, promptText)
    if err != nil { logger.Println("AI", err); answer = proceduralAnswer(adventure, character, promptText, in.Roll) }

    mu.Lock(); defer mu.Unlock()
    ai = activeAdventureLocked(); if ai>=0 {
        db.Adventures[ai].Log=append(db.Adventures[ai].Log, Message{Role:"KRONIKARZ",Text:answer,Time:clock()})
        updateWorldMemoryLocked(ai, promptText, answer)
        db.Adventures[ai].UpdatedAt=now()
        ci=charIndexLocked(db.Adventures[ai].CharacterID)
        if ci>=0 { db.Characters[ci].XP += 25; if db.Characters[ci].XP >= db.Characters[ci].Level*300 { db.Characters[ci].XP=0; db.Characters[ci].Level++; db.Characters[ci].AttributePt += 2; db.Characters[ci].History=append(db.Characters[ci].History,"Awans na poziom.") }; db.Characters[ci].UpdatedAt=now() }
        saveDBLocked()
        writeJSON(w,map[string]any{"ok":true,"answer":answer,"db":db})
        return
    }
    errJSON(w,500,"Przygoda zniknęła podczas generowania.")
}

type Roll struct{ Value int `json:"value"`; Result string `json:"result"` }

func handleTestAI(w http.ResponseWriter, r *http.Request){ mu.Lock(); s:=db.Settings; mu.Unlock(); a:=Adventure{World:World{Name:"Test",Genre:"fantasy",Climate:"test",Mystery:"test"},Location:"Test",Chapter:1}; c:=Character{Name:"Tester"}; ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second); defer cancel(); ans, err := callNarrator(ctx,s,a,c,"Napisz jedno krótkie zdanie testowe po polsku."); if err!=nil { errJSON(w,500,err.Error()); return }; writeJSON(w,map[string]any{"ok":true,"answer":ans}) }
func handleExport(w http.ResponseWriter, r *http.Request){ mu.Lock(); defer mu.Unlock(); writeJSON(w, db) }
func handleShutdown(w http.ResponseWriter, r *http.Request){ writeJSON(w,map[string]any{"ok":true}); go func(){time.Sleep(500*time.Millisecond); os.Exit(0)}() }

func activeAdventureLocked() int { for i:=range db.Adventures { if db.Adventures[i].ID==db.ActiveAdventureID { return i } }; return -1 }
func charIndexLocked(id string) int { for i:=range db.Characters { if db.Characters[i].ID==id { return i } }; return -1 }
func getChar(id string) Character { mu.Lock(); defer mu.Unlock(); for _,c:= range db.Characters { if c.ID==id { return c } }; return Character{Name:"Bohater"} }

func callNarrator(ctx context.Context, s Settings, a Adventure, c Character, action string) (string,error){
    if s.AIMode=="" || s.AIMode=="procedural" { return proceduralAnswer(a,c,action,nil),nil }
    prompt := buildPrompt(a,c,action)
    switch s.AIMode {
    case "ollama", "bielik":
        model := s.OllamaModel; if s.AIMode=="bielik" { model=s.BielikModel }
        return callOllama(ctx, model, prompt)
    case "claude_proxy", "claude":
        return callClaude(ctx,s,prompt)
    case "openai":
        return callOpenAI(ctx,s,prompt)
    default:
        return proceduralAnswer(a,c,action,nil),nil
    }
}

func buildPrompt(a Adventure, c Character, action string) string {
    recent := []string{}
    start := len(a.Log)-8; if start<0 { start=0 }
    for _,m := range a.Log[start:] { recent=append(recent, m.Role+": "+m.Text) }
    return fmt.Sprintf(`Jesteś KRONIKARZEM, Mistrzem Gry w polskiej tekstowej grze fabularnej.
Pisz po polsku, literacko, zwięźle, z konsekwencjami wyborów. Nie przejmuj kontroli nad bohaterem.
Zakończ scenę pytaniem albo sytuacją wymagającą decyzji.

ŚWIAT: %s
Gatunek: %s
Klimat: %s
Epoka: %s
Rok / lata akcji: %s
Nadnaturalność: %s
Tajemnica: %s
Opis startowej lokacji: %s
Unikać: %s

BOHATER: %s, %s, %s, %s. Cel: %s. Wada: %s. Zaleta: %s. Sekret: %s.
Lokacja: %s. Rozdział: %d. Nastrój: %s.

OSTATNIE WYDARZENIA:
%s

DECYZJA GRACZA:
%s`, a.World.Name,a.World.Genre,a.World.Climate,a.World.Era,a.World.Year,a.World.Supernatural,a.World.Mystery,a.World.StartDescription,a.World.Avoid,c.Name,c.Age,c.Race,c.Class,c.Goal,c.Flaw,c.Strength,c.Secret,a.Location,a.Chapter,a.Mood,strings.Join(recent,"\n"),action)
}

func callOllama(ctx context.Context, model, prompt string)(string,error){ if model==""{model="llama3.1:8b"}; body:=map[string]any{"model":model,"prompt":prompt,"stream":false}; b,_:=json.Marshal(body); req,_:=http.NewRequestWithContext(ctx,"POST","http://127.0.0.1:11434/api/generate",bytes.NewReader(b)); req.Header.Set("Content-Type","application/json"); client:=http.Client{Timeout:120*time.Second}; resp,err:=client.Do(req); if err!=nil{return "",err}; defer resp.Body.Close(); rb,_:=io.ReadAll(resp.Body); if resp.StatusCode>=300{return "",fmt.Errorf("ollama HTTP %d: %s",resp.StatusCode,string(rb))}; var out struct{Response string `json:"response"`}; _=json.Unmarshal(rb,&out); if out.Response==""{return "",errors.New("pusta odpowiedź Ollama")}; return out.Response,nil }

func claudeEndpoint(base string) string {
    if base==""{base="https://api.anthropic.com"}
    base=strings.TrimRight(base,"/")
    if strings.HasSuffix(base,"/v1/messages"){return base}
    if strings.HasSuffix(base,"/v1"){return base+"/messages"}
    return base+"/v1/messages"
}

func callClaude(ctx context.Context, s Settings, prompt string)(string,error){
    if s.ClaudeToken==""{return "",errors.New("brak Claude token")}
    model := strings.TrimSpace(s.ClaudeModel)
    if model == "" { model = "claude-opus-4-8" }
    maxTokens := 1200
    if strings.Contains(strings.ToLower(prompt), "jedno krótkie zdanie testowe") { maxTokens = 120 }
    body:=map[string]any{
        "model":model,
        "max_tokens":maxTokens,
        "temperature":s.Temperature,
        "stream":false,
        "system":"Jesteś KRONIKARZEM, Mistrzem Gry. Pisz po polsku.",
        "messages":[]map[string]string{{"role":"user","content":prompt}},
    }
    b,_:=json.Marshal(body)
    endpoint := claudeEndpoint(s.ClaudeBaseURL)
    req,_:=http.NewRequestWithContext(ctx,"POST",endpoint,bytes.NewReader(b))
    req.Header.Set("Content-Type","application/json")
    req.Header.Set("Accept","application/json")
    req.Header.Set("anthropic-version","2023-06-01")
    if s.ClaudeAuthType=="bearer" || strings.Contains(strings.ToLower(s.ClaudeBaseURL),"aiprimetech") {
        req.Header.Set("Authorization","Bearer "+s.ClaudeToken)
    } else {
        req.Header.Set("x-api-key",s.ClaudeToken)
    }
    client:=http.Client{Timeout:120*time.Second}
    resp,err:=client.Do(req)
    if err!=nil{return "",err}
    defer resp.Body.Close()
    rb,_:=io.ReadAll(resp.Body)
    if resp.StatusCode>=300{
        logger.Printf("Claude HTTP %d endpoint=%s body=%s", resp.StatusCode, endpoint, string(rb))
        return "",fmt.Errorf("Claude HTTP %d: %s",resp.StatusCode,string(rb))
    }
    txt := extractLLMText(rb)
    if strings.TrimSpace(txt) != "" { return strings.TrimSpace(txt), nil }
    logger.Printf("Claude empty response endpoint=%s raw=%s", endpoint, string(rb))
    return "",fmt.Errorf("pusta odpowiedź Claude. Surowa odpowiedź zapisana w error_log.txt")
}

func extractLLMText(raw []byte) string {
    var v any
    if err := json.Unmarshal(raw, &v); err != nil {
        s := strings.TrimSpace(string(raw))
        if strings.HasPrefix(s,"data:") {
            lines := strings.Split(s,"\n")
            parts := []string{}
            for _,line := range lines {
                line = strings.TrimSpace(line)
                if !strings.HasPrefix(line,"data:") { continue }
                line = strings.TrimSpace(strings.TrimPrefix(line,"data:"))
                if line=="" || line=="[DONE]" { continue }
                var ev any
                if json.Unmarshal([]byte(line), &ev)==nil {
                    if t := extractTextValue(ev); strings.TrimSpace(t)!="" { parts = append(parts,t) }
                }
            }
            return strings.TrimSpace(strings.Join(parts,""))
        }
        return s
    }
    return strings.TrimSpace(extractTextValue(v))
}

func extractTextValue(v any) string {
    switch x := v.(type) {
    case string:
        return x
    case []any:
        parts := []string{}
        for _, item := range x {
            if t := extractTextValue(item); strings.TrimSpace(t) != "" { parts = append(parts, t) }
        }
        return strings.Join(parts, "")
    case map[string]any:
        // OpenAI / gateway compatible
        if choices, ok := x["choices"]; ok {
            if t := extractTextValue(choices); strings.TrimSpace(t)!="" { return t }
        }
        // Anthropic Messages API and many Claude proxies
        for _, key := range []string{"content","completion","response","output_text","text","message","delta","output"} {
            if val, ok := x[key]; ok {
                if t := extractTextValue(val); strings.TrimSpace(t)!="" { return t }
            }
        }
    }
    return ""
}

func callOpenAI(ctx context.Context, s Settings, prompt string)(string,error){ if s.OpenAIAPIKey==""{return "",errors.New("brak OpenAI API key")}; body:=map[string]any{"model":s.OpenAIModel,"temperature":s.Temperature,"messages":[]map[string]string{{"role":"system","content":"Jesteś KRONIKARZEM, Mistrzem Gry. Pisz po polsku."},{"role":"user","content":prompt}}}; b,_:=json.Marshal(body); req,_:=http.NewRequestWithContext(ctx,"POST",s.OpenAIEndpoint,bytes.NewReader(b)); req.Header.Set("Content-Type","application/json"); req.Header.Set("Authorization","Bearer "+s.OpenAIAPIKey); client:=http.Client{Timeout:120*time.Second}; resp,err:=client.Do(req); if err!=nil{return "",err}; defer resp.Body.Close(); rb,_:=io.ReadAll(resp.Body); if resp.StatusCode>=300{return "",fmt.Errorf("OpenAI HTTP %d: %s",resp.StatusCode,string(rb))}; var out struct{Choices []struct{Message struct{Content string `json:"content"`} `json:"message"`} `json:"choices"`}; _=json.Unmarshal(rb,&out); if len(out.Choices)>0{return out.Choices[0].Message.Content,nil}; return "",errors.New("pusta odpowiedź") }

func openApp(url string, mode string){
    if runtime.GOOS=="windows" {
        if strings.EqualFold(mode, "fullscreen") {
            cmds := [][]string{{"cmd","/C","start","","msedge","--start-fullscreen","--app="+url},{"cmd","/C","start","","msedge","--kiosk",url,"--edge-kiosk-type=fullscreen"},{"cmd","/C","start","",url}}
            for _,c:= range cmds { if exec.Command(c[0], c[1:]...).Start()==nil { return } }
        }
        cmds := [][]string{{"cmd","/C","start","","msedge","--app="+url},{"cmd","/C","start","",url}}
        for _,c:= range cmds { if exec.Command(c[0], c[1:]...).Start()==nil { return } }
    } else { _=exec.Command("xdg-open",url).Start() }
}

func multipartCopy(_ *multipart.FileHeader) {}

func sortedCharacters(chars []Character) []Character { out:=append([]Character{},chars...); sort.Slice(out,func(i,j int)bool{return out[i].UpdatedAt>out[j].UpdatedAt}); return out }
