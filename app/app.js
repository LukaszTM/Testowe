const $ = (s, r=document) => r.querySelector(s);
const $$ = (s, r=document) => [...r.querySelectorAll(s)];
let state = null;
let selectedCharacterId = null;
let pendingRoll = null;

async function api(path, body){
  const opt = body !== undefined ? {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)} : {};
  const r = await fetch(path,opt); const data = await r.json().catch(()=>({ok:false,error:'Błąd JSON'}));
  if(!r.ok || data.ok===false) throw new Error(data.error || r.statusText); return data;
}
async function refresh(){ const res = await api('/api/state'); state = res.db; if(!selectedCharacterId) selectedCharacterId = state.activeCharacterId || state.characters[0]?.id; renderAll(); }
function activeCharacter(){ return state.characters.find(c=>c.id===state.activeCharacterId) || state.characters.find(c=>c.id===selectedCharacterId) || state.characters[0]; }
function selectedCharacter(){ return state?.characters?.find(c=>c.id===selectedCharacterId) || activeCharacter(); }
function activeAdventure(){ return state.adventures.find(a=>a.id===state.activeAdventureId); }
function esc(s){ return (s||'').replace(/[&<>]/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;'}[m])); }
function avatar(c, cls='portrait'){
  if(c?.avatarPath){
    const stamp = encodeURIComponent(c.updatedAt || c.id || Date.now());
    return `<img class="${cls}" src="${c.avatarPath}?v=${stamp}" onerror="this.replaceWith(Object.assign(document.createElement('div'),{className:'${cls} placeholder',textContent:'${esc((c?.name||'?')[0])}'}))">`;
  }
  return `<div class="${cls} placeholder">${esc((c?.name||'?')[0])}</div>`;
}
function attrList(attrs){ const map = [['Siła','strength'],['Zręczność','dexterity'],['Kondycja','condition'],['Umysł','mind'],['Percepcja','perception'],['Charyzma','charisma'],['Wola','will'],['Szczęście','luck'],['Technika','technique'],['Przetrwanie','survival']]; return map.map(([pl,k])=>`<div class="attr"><span>${pl}</span><div class="bar"><i style="width:${Math.min(100,(attrs?.[k]||0)*5)}%"></i></div><b>${attrs?.[k]||0}</b></div>`).join(''); }
function renderAll(){ renderHeader(); renderLog(); renderChoices(); renderPanels(); renderCharacters(); renderAdventures(); renderSettings(); }
function renderHeader(){ const a=activeAdventure(); $('#topWorld').textContent=a?.world?.name || '—'; $('#topLocation').textContent=a?.location || '—'; $('#topChapter').textContent=a ? `Rozdział ${a.chapter}` : '—'; updateScene(); }
const GENRE_SCENE={fantasy:'village',historyczny:'old-town',noir:'city-night',horror:'dark',scifi:'station',cyberpunk:'neon',postapo:'wasteland',western:'frontier',steampunk:'industrial',modern:'city'};
const SCENE_LABEL={village:'Osada / miasto',tavern:'Karczma / wnętrze',forest:'Las / ścieżka',cave:'Podziemia / jaskinia',ruins:'Ruiny / pradawne miejsce','old-town':'Stare miasto','city-night':'Miasto nocą',dark:'Mrok / nieznane',station:'Stacja / statek',neon:'Neonowa dzielnica',wasteland:'Pustkowie',frontier:'Pogranicze',industrial:'Dzielnica przemysłowa',city:'Współczesne miasto'};
function sceneKind(){ const a=activeAdventure(); const gk=a?.world?.genreKind||'fantasy'; let kind=GENRE_SCENE[gk]||'village'; const text=((a?.log||[]).slice(-1)[0]?.text||'')+' '+(a?.location||'')+' '+(a?.world?.mystery||''); const l=text.toLowerCase();
  // Doprecyzowanie sceny słowami kluczowymi (uniwersalne wnętrza/podziemia).
  if(/karcz|gospod|tawern|saloon|bar\b|kawiar|mesa|komink/.test(l)) kind='tavern';
  else if((gk==='fantasy'||gk==='historyczny') && /las|drzew|puszcz|ścież|bór/.test(l)) kind='forest';
  else if(/kopal|jask|podziem|tunel|studni|piwnic|loch|ładown|kotłow|serwer/.test(l)) kind='cave';
  else if((gk==='fantasy'||gk==='historyczny') && /ruin|świątyn|pradawn|zamek/.test(l)) kind='ruins';
  let mood='mystery'; if(/walka|atak|krew|groz|niebez|potw|pust|strzał|wystrzał|alarm|ucieka/.test(l)) mood='danger';
  return {kind,mood,label:SCENE_LABEL[kind]||'Scena'}; }
function updateScene(){ const s=sceneKind(); const el=$('#sceneBg'); el.className=`scene-bg ${s.kind} ${s.mood}`; $('#sceneLabel').textContent=`Scena: ${s.label} • Nastrój: ${s.mood}`; }
function renderLog(){ const a=activeAdventure(); const log=$('#log'); log.innerHTML=''; if(!a){ log.innerHTML = `<div class="message"><div class="avatar-dot">✒</div><div class="bubble"><h4>KRONIKARZ</h4><p>Witaj w KRONIKARZU 2.0. Najpierw utwórz lub wybierz postać w Bibliotece postaci, a potem rozpocznij nową opowieść.</p><div class="time">${new Date().toLocaleTimeString('pl-PL',{hour:'2-digit',minute:'2-digit'})}</div></div></div>`; return; }
  for(const m of a.log){ const player=m.role==='Ty'; const div=document.createElement('div'); div.className='message '+(player?'player':''); div.innerHTML = player ? `<div class="bubble"><h4>Ty</h4><p>${esc(m.text)}</p><div class="time">${m.time}</div></div><div class="avatar-dot">✦</div>` : `<div class="avatar-dot">✒</div><div class="bubble"><h4>KRONIKARZ</h4><p>${esc(m.text)}</p><div class="time">${m.time}</div></div>`; log.appendChild(div); }
  log.scrollTop=log.scrollHeight;
}
function lastNarrator(){ const a=activeAdventure(); return [...(a?.log||[])].reverse().find(m=>m.role!=='Ty')?.text || ''; }
// Uniwersalne, ale klimatyczne propozycje działań zależne od gatunku świata.
const GENRE_CHOICES={
  fantasy:['Rozglądam się uważnie za tropem, którego inni nie zauważyli.','Zagaduję kogoś miejscowego o to, co naprawdę się tu dzieje.','Ruszam ostrożnie w stronę źródła tajemnicy, gotów na kłopoty.'],
  historyczny:['Przyglądam się otoczeniu, szukając szczegółu nie na miejscu.','Wypytuję dyskretnie kogoś, kto może coś wiedzieć.','Przemieszczam się dalej, unikając niepotrzebnej uwagi.'],
  noir:['Obserwuję z ukrycia i notuję, kto tu nie pasuje.','Zadaję jedno celne pytanie i patrzę, kto skłamie.','Ruszam za tropem, trzymając się cienia.'],
  horror:['Nasłuchuję w ciszy, próbując zlokalizować dźwięk.','Sprawdzam, czy mam przy sobie cokolwiek, co da światło.','Wycofuję się powoli w stronę ostatniego bezpiecznego miejsca.'],
  scifi:['Wykonuję skan otoczenia i sprawdzam odczyty.','Pytam o dostęp do logów albo najświeższych danych.','Ruszam korytarzem w stronę anomalii, gotów na niespodzianki.'],
  cyberpunk:['Włączam nakładkę AR i szukam śladu w danych.','Handluję informacją — pytam wprost, ile kosztuje prawda.','Wtapiam się w tłum i ruszam za sygnałem.'],
  postapo:['Przeszukuję okolicę w poszukiwaniu zapasów i śladów.','Oceniam, czy rozmówca to zagrożenie, czy szansa.','Przemieszczam się między osłonami, unikając otwartej przestrzeni.'],
  western:['Lustruję ulicę, szukając, kto tu na coś czeka.','Zagaduję spod ronda kapelusza, mierząc rozmówcę.','Ruszam środkiem ulicy, gotów na wszystko.'],
  steampunk:['Przyglądam się mechanizmom, szukając usterki nie na miejscu.','Wypytuję fachowca o to, co naprawdę tu naprawiano.','Ruszam przez zaułki pary i iskier w stronę hałasu.'],
  modern:['Rozglądam się, wyłapując szczegół, który nie pasuje.','Dyskretnie wypytuję kogoś, kto wie więcej, niż mówi.','Ruszam dalej, wtapiając się w miejski tłum.'],
};
function generateChoices(){ const a=activeAdventure(); if(!a) return ['Wybierz postać z biblioteki.','Utwórz nową postać.','Otwórz ustawienia AI.']; const gk=a.world?.genreKind||'fantasy'; const t=(lastNarrator()+' '+a.location).toLowerCase();
  // Kontekstowe nadpisania działające w każdym gatunku.
  if(/mrok|ciem|syk|szelest|szept|cisza|zimno/.test(t)) return ['Nasłuchuję i próbuję ustalić, skąd dochodzi dźwięk.','Sprawdzam, czy mam czym oświetlić otoczenie.','Cofam się ostrożnie w stronę bezpiecznego miejsca.'];
  if(/karcz|gospod|tawern|saloon|bar\b|kawiar|mesa/.test(t)) return ['Pytam o najnowsze plotki i wieści.','Siadam w cieniu i obserwuję salę.','Zaczepiam kogoś, kto wygląda, jakby wiedział więcej.'];
  if(/podziem|tunel|piwnic|loch|kopal|ładown|kotłow|serwer|kanał/.test(t)) return ['Schodzę ostrożnie w stronę źródła dźwięku.','Szukam planu albo kogoś, kto zna te podziemia.','Badam najbliższe znaki i próbuję je zrozumieć.'];
  return GENRE_CHOICES[gk]||GENRE_CHOICES.fantasy; }
function renderChoices(){ const choices=generateChoices(); [1,2,3].forEach(i=>{$(`#choice${i} span`).textContent=choices[i-1]}); }
function renderPanels(){ const a=activeAdventure(), c=activeCharacter(); $('#questPanel').innerHTML=(a?.quests||[]).map(q=>`<div class="panel-line">✦ <div><b>${esc(q.Title)}</b><br><span>${esc(q.Note)}</span></div></div>`).join('')||'Brak aktywnej opowieści.'; $('#statusPanel').innerHTML=c?`<div class="panel-line">${avatar(c,'portrait')}<div><b>${esc(c.name)}</b><br>${esc(c.class)}<br>Poziom ${c.level} • XP ${c.xp}</div></div><div class="bar"><i style="width:${Math.min(100,c.xp/9)}%"></i></div>`:'Kliknij Nowa postać.'; $('#relationPanel').innerHTML=(a?.relations||[]).map(r=>`<div class="panel-line">● <div><b>${esc(r.Name)}</b> — ${esc(r.Status)} (${r.Value})</div></div>`).join('')||'—'; $('#discoveryPanel').innerHTML=(a?.discoveries||[]).slice(-4).map(d=>`<div class="panel-line">◈ <div><b>${esc(d.Title)}</b><br>${esc(d.Type)} • ${d.Time}</div></div>`).join('')||'—'; }
function renderCharacters(){
  const list=$('#characterList'); if(!list || !state) return;
  if(!state.characters?.length){ selectedCharacterId=null; list.innerHTML='<p>Brak postaci. Kliknij „Nowa postać”.</p>'; $('#characterPreview').innerHTML='<p>Brak postaci.</p>'; $('#characterProgress').innerHTML=''; $('#characterFull').innerHTML='<p>Brak postaci.</p>'; return; }
  if(!state.characters.some(c=>c.id===selectedCharacterId)) selectedCharacterId = state.activeCharacterId || state.characters[0].id;
  list.innerHTML='';
  for(const c of state.characters){
    const item=document.createElement('button');
    item.className='char-card '+(c.id===selectedCharacterId?'active':'');
    item.innerHTML=`${avatar(c)}<div><h4>${esc(c.name)}</h4><p>${esc(c.race)} • ${esc(c.class)}<br>Poziom ${c.level}</p></div>`;
    item.onclick=()=>{selectedCharacterId=c.id; renderCharacters();};
    list.appendChild(item);
  }
  const c=selectedCharacter(); const prev=$('#characterPreview'), prog=$('#characterProgress');
  if(!c){ prev.innerHTML='<p>Brak postaci.</p>'; prog.innerHTML=''; return; }
  selectedCharacterId=c.id;
  prev.innerHTML=`<div class="portrait-block">${avatar(c,'portrait big')}<button type="button" class="secondary avatar-upload-button" data-upload-avatar="${c.id}">Wybierz plik awatara</button><small class="avatar-hint">PNG, JPG lub WEBP. Plik zostanie skopiowany do profilu postaci.</small></div><div class="details"><dl><dt>Imię</dt><dd>${esc(c.name)}</dd><dt>Wiek</dt><dd>${esc(c.age)}</dd><dt>Płeć</dt><dd>${esc(c.gender)}</dd><dt>Rasa</dt><dd>${esc(c.race)}</dd><dt>Klasa</dt><dd>${esc(c.class)}</dd><dt>Pochodzenie</dt><dd>${esc(c.origin)}</dd><dt>Cel</dt><dd>${esc(c.goal)}</dd><dt>Wada</dt><dd>${esc(c.flaw)}</dd><dt>Zaleta</dt><dd>${esc(c.strength)}</dd><dt>Sekret</dt><dd>${esc(c.secret)}</dd></dl></div>`;
  prog.innerHTML=`<h3>Progresja</h3><p>Poziom <b>${c.level}</b> • XP ${c.xp}</p><div class="bar"><i style="width:${Math.min(100,c.xp/9)}%"></i></div>${attrList(c.attributes)}`;
  $('#characterFull').innerHTML = `<div class="portrait-block">${avatar(c,'portrait big')}<button type="button" class="secondary avatar-upload-button full-upload" data-upload-avatar="${c.id}">Wgraj awatar</button></div><div class="details"><dl><dt>Imię</dt><dd>${esc(c.name)}</dd><dt>Wiek</dt><dd>${esc(c.age)}</dd><dt>Płeć</dt><dd>${esc(c.gender)}</dd><dt>Rasa</dt><dd>${esc(c.race)}</dd><dt>Klasa</dt><dd>${esc(c.class)}</dd><dt>Pochodzenie</dt><dd>${esc(c.origin)}</dd><dt>Cel</dt><dd>${esc(c.goal)}</dd><dt>Wada</dt><dd>${esc(c.flaw)}</dd><dt>Zaleta</dt><dd>${esc(c.strength)}</dd><dt>Sekret</dt><dd>${esc(c.secret)}</dd></dl></div><div class="progress-card">${attrList(c.attributes)}</div>`;
}
const GENRE_LABEL={fantasy:'Fantasy',historyczny:'Historyczny',noir:'Kryminał / noir',horror:'Groza / horror',scifi:'Science fiction',cyberpunk:'Cyberpunk',postapo:'Postapokalipsa',western:'Western',steampunk:'Steampunk',modern:'Współczesność'};
function characterName(id){ return state?.characters?.find(c=>c.id===id)?.name || 'nieznana postać'; }
function renderAdventures(){
  const list=$('#adventureList'); if(!list||!state) return;
  const advs=[...(state.adventures||[])].sort((a,b)=>(b.updatedAt||'').localeCompare(a.updatedAt||''));
  if(!advs.length){ list.innerHTML='<p class="empty-hint">Brak zapisanych przygód. Wybierz postać i rozpocznij nową opowieść.</p>'; return; }
  list.innerHTML='';
  for(const a of advs){
    const active=a.id===state.activeAdventureId;
    const turns=(a.log||[]).filter(m=>m.role==='Ty').length;
    const gk=a.world?.genreKind||'fantasy';
    const card=document.createElement('div');
    card.className='adventure-card ornate'+(active?' active':'');
    card.innerHTML=`<div class="adv-main">
        <div class="adv-badge scene-${(GENRE_SCENE[gk]||'village')}">${esc(GENRE_LABEL[gk]||'Świat')}</div>
        <h3>${esc(a.title||a.world?.name||'Przygoda')}</h3>
        <p class="adv-meta">${esc(characterName(a.characterId))} • ${esc(a.location||'—')} • Rozdział ${a.chapter||1}</p>
        <p class="adv-sub">${esc([a.world?.era,a.world?.year].filter(Boolean).join(', ')||a.world?.genre||'')} • ${turns} tur • ${esc(a.updatedAt||'')}</p>
      </div>
      <div class="adv-actions">
        <button class="primary" data-continue="${a.id}">${active?'Wznów':'Wczytaj'} →</button>
        <button class="secondary danger" data-delete-adv="${a.id}">Usuń</button>
      </div>`;
    list.appendChild(card);
  }
}
async function continueAdventure(id){
  try{ const res=await api('/api/adventures/select',{id}); state=res.db; selectedCharacterId=state.activeCharacterId; renderAll(); showScreen('story'); }
  catch(err){ alert('Nie udało się wczytać przygody: '+err.message); }
}
async function deleteAdventure(id){
  const a=state?.adventures?.find(x=>x.id===id);
  if(!confirm('Usunąć przygodę „'+(a?.title||'')+'”? Tej operacji nie można cofnąć.')) return;
  try{ const res=await api('/api/adventures/delete',{id}); state=res.db; renderAll(); }
  catch(err){ alert('Nie udało się usunąć przygody: '+err.message); }
}
const WORLD_PRESETS={
  fantasy:{genre:'mroczne fantasy',era:'późne średniowiecze',year:'',climate:'samotna wędrówka, tajemnica, ruiny dawnej cywilizacji',supernatural:'niska, rzadka i niebezpieczna',mystery:'nocą spod ziemi słychać dzwony',startLocation:'Osada Hadrin',avoid:'erotyka, przesadna przemoc',tone:'mroczny, tajemniczy, przygodowy'},
  historyczny:{genre:'dramat historyczny',era:'XVII wiek',year:'1648',climate:'intrygi, wojna, niepewność',supernatural:'brak',mystery:'zaginął posłaniec z tajnym listem',startLocation:'Rynek starego miasta',avoid:'anachronizmy, erotyka',tone:'realistyczny, napięty'},
  modern:{genre:'thriller współczesny',era:'współczesność',year:'2024',climate:'wielkie miasto, pośpiech, sekrety',supernatural:'brak',mystery:'zwykły dzień urywa się jednym telefonem',startLocation:'Centrum miasta',avoid:'erotyka, drastyczna przemoc',tone:'nowoczesny, sensacyjny'},
  noir:{genre:'kryminał noir',era:'lata 40. XX wieku',year:'1947',climate:'deszcz, neony, korupcja',supernatural:'brak',mystery:'klientka znika zaraz po zleceniu sprawy',startLocation:'Biuro prywatnego detektywa',avoid:'erotyka',tone:'chłodny, cyniczny, tajemniczy'},
  horror:{genre:'horror',era:'współczesność',year:'2019',climate:'izolacja, groza, niepokój',supernatural:'obecna i wroga',mystery:'mieszkańcy znikają, a nikt tego nie pamięta',startLocation:'Odcięta od świata miejscowość',avoid:'erotyka, gore dla samego gore',tone:'przerażający, duszny'},
  scifi:{genre:'science fiction',era:'daleka przyszłość',year:'2377',climate:'przestrzeń kosmiczna, izolacja, technologia',supernatural:'brak (zjawiska naukowe)',mystery:'stacja przestała odpowiadać na sygnały',startLocation:'Pokład stacji orbitalnej',avoid:'erotyka',tone:'napięty, tajemniczy, hard sci-fi'},
  cyberpunk:{genre:'cyberpunk',era:'niedaleka przyszłość',year:'2088',climate:'neony, deszcz, korporacje, implanty',supernatural:'brak',mystery:'skradziono dane, które nie powinny istnieć',startLocation:'Zaułek w dzielnicy neonów',avoid:'erotyka',tone:'mroczny, technologiczny, buntowniczy'},
  postapo:{genre:'postapokalipsa',era:'po zagładzie',year:'20 lat po Upadku',climate:'pustkowia, walka o przetrwanie',supernatural:'brak (mutacje, skażenie)',mystery:'na horyzoncie zapłonęło światło, którego nie powinno być',startLocation:'Ruiny dawnej stacji',avoid:'erotyka',tone:'surowy, brutalny, desperacki'},
  western:{genre:'western',era:'Dziki Zachód',year:'1878',climate:'kurz, słońce, prawo rewolweru',supernatural:'brak',mystery:'do miasteczka wjechał ktoś, kto miał nie żyć',startLocation:'Główna ulica miasteczka',avoid:'erotyka',tone:'twardy, honorowy, napięty'},
  steampunk:{genre:'steampunk',era:'alternatywna epoka wiktoriańska',year:'1889',climate:'para, mosiądz, przemysł, wynalazki',supernatural:'niska, w formie dziwnych wynalazków',mystery:'wynalazca zniknął, zostawiając działającą maszynę',startLocation:'Warsztat pełen pary',avoid:'erotyka',tone:'przygodowy, tajemniczy, wynalazczy'},
};
function applyWorldPreset(key){
  const p=WORLD_PRESETS[key]; if(!p) return;
  const f=$('#worldDialog form');
  for(const [k,v] of Object.entries(p)){ if(f.elements[k]) f.elements[k].value=v; }
}
function renderSettings(){ if(!state) return; const s=state.settings; for(const [id,val] of Object.entries({aiMode:s.aiMode,bielikModel:s.bielikModel,ollamaModel:s.ollamaModel,claudeBaseUrl:s.claudeBaseUrl,claudeModel:s.claudeModel,claudeAuthType:s.claudeAuthType,openAiEndpoint:s.openAiEndpoint,openAiModel:s.openAiModel,windowMode:s.windowMode||'window'})) { const el=$('#'+id); if(el) el.value=val||''; } }
function showScreen(name){ $$('.screen').forEach(s=>s.classList.remove('active')); $('#screen'+name[0].toUpperCase()+name.slice(1))?.classList.add('active'); $$('.nav').forEach(n=>n.classList.toggle('active', n.dataset.screen===name)); }
function openCharacterDialog(c=null){ const d=$('#characterDialog'), f=d.querySelector('form'); f.reset(); f.noValidate=true; d.dataset.id=c?.id||''; $('#charDialogTitle').textContent=c?'Edytuj postać':'Nowa postać'; if(c){ for(const el of f.elements){ if(el.name && c[el.name]!==undefined) el.value=c[el.name]; } const a=c.attributes||{}; f.elements.strengthAttr.value=a.strength||2; f.elements.dexterity.value=a.dexterity||2; f.elements.condition.value=a.condition||2; f.elements.mind.value=a.mind||2; f.elements.perception.value=a.perception||2; f.elements.charisma.value=a.charisma||2; f.elements.will.value=a.will||2; f.elements.luck.value=a.luck||2; f.elements.technique.value=a.technique||2; f.elements.survival.value=a.survival||2; } d.showModal(); }
async function saveCharacter(e){
  e.preventDefault();
  const f=$('#characterDialog form');
  const id=$('#characterDialog').dataset.id||'';
  const existing=state?.characters?.find(x=>x.id===id)||{};
  const name=(f.name.value||'').trim();
  if(!name){ alert('Podaj imię postaci.'); f.name.focus(); return; }
  const c={
    ...existing,
    id,
    name,
    age:f.age.value.trim(),
    gender:f.gender.value.trim(),
    race:f.race.value.trim(),
    class:f.class.value.trim(),
    origin:f.origin.value.trim(),
    goal:f.goal.value.trim(),
    flaw:f.flaw.value.trim(),
    strength:f.strength.value.trim(),
    secret:f.secret.value.trim(),
    hp: existing.hp || 100,
    level: existing.level || 1,
    xp: existing.xp || 0,
    attributePt: existing.attributePt || 0,
    avatarPath: existing.avatarPath || '',
    inventory: existing.inventory || ['notatnik','znoszony płaszcz'],
    history: existing.history || [],
    attributes:{strength:+f.strengthAttr.value,dexterity:+f.dexterity.value,condition:+f.condition.value,mind:+f.mind.value,perception:+f.perception.value,charisma:+f.charisma.value,will:+f.will.value,luck:+f.luck.value,technique:+f.technique.value,survival:+f.survival.value}
  };
  try{
    const res=await api('/api/characters',c);
    const file=$('#avatarFile').files[0];
    if(file) await uploadAvatar(res.character.id,file,false);
    selectedCharacterId=res.character.id;
    $('#characterDialog').close();
    await refresh();
    showScreen('characters');
  }catch(err){ alert('Nie udało się zapisać postaci: '+err.message); }
}
async function uploadAvatar(id,file,rerender=true){
  if(!file) return;
  if(!id) return alert('Najpierw wybierz albo zapisz postać.');
  const allowed=['image/png','image/jpeg','image/webp'];
  const name=(file.name||'').toLowerCase();
  const looksOk = allowed.includes(file.type) || /\.(png|jpe?g|webp)$/.test(name);
  if(!looksOk) return alert('To nie wygląda na plik obrazu. Wybierz PNG, JPG albo WEBP.');
  const fd=new FormData(); fd.append('characterId',id); fd.append('avatar',file);
  const r=await fetch('/api/characters/upload-avatar',{method:'POST',body:fd});
  const out=await r.json().catch(()=>({ok:false,error:'Nieczytelna odpowiedź serwera'}));
  if(!r.ok || out.ok===false){ alert('Nie udało się wgrać awatara: '+(out.error||r.status)); return; }
  selectedCharacterId=id;
  if(rerender) await refresh();
  showScreen('characters');
}
function chooseAvatarFile(id){
  if(!id) return alert('Wybierz postać.');
  const input=document.createElement('input');
  input.type='file'; input.accept='image/png,image/jpeg,image/webp,image/*';
  input.onchange=()=>uploadAvatar(id,input.files?.[0]);
  input.click();
}
function modalData(kind){ const a=activeAdventure(); if(!a) return 'Brak aktywnej przygody.'; if(kind==='chronicle') return JSON.stringify({świat:a.world,lokacje:a.locations,odkrycia:a.discoveries},null,2); if(kind==='inventory') return [...(activeCharacter()?.inventory||[]),...(a.inventory||[])].map(x=>'• '+x).join('\n')||'Pusto.'; if(kind==='quests') return a.quests.map(q=>`• ${q.Title}\n  ${q.Note}`).join('\n\n'); if(kind==='relations') return a.relations.map(r=>`• ${r.Name}: ${r.Status} (${r.Value})`).join('\n'); }
function applyScreenModeNow(){ const mode=$('#windowMode')?.value||'window'; if(mode==='fullscreen'){ const el=document.documentElement; if(el.requestFullscreen) el.requestFullscreen().catch(()=>alert('Pełny ekran zostanie zastosowany przy następnym uruchomieniu.')); } else { if(document.fullscreenElement && document.exitFullscreen) document.exitFullscreen(); else alert('Tryb okna zostanie zastosowany przy następnym uruchomieniu.'); } }

async function selectAndPlay(){
  if(!selectedCharacterId) return alert('Wybierz postać.');
  await api('/api/characters/select',{id:selectedCharacterId});
  state.activeCharacterId=selectedCharacterId;
  $('#worldDialog').showModal();
}
async function startAdventure(e){
  if(e) e.preventDefault();
  const f=$('#worldDialog form');
  const world={name:f.name.value,genre:f.genre.value,climate:f.climate.value,era:f.era.value,year:f.year.value,supernatural:f.supernatural.value,mystery:f.mystery.value,startLocation:f.startLocation.value,startDescription:f.startDescription.value,avoid:f.avoid.value,tone:f.tone.value};
  try{
    await api('/api/adventures/new',{characterId:state.activeCharacterId||selectedCharacterId,world});
    $('#worldDialog').close();
    await refresh();
    showScreen('story');
  }catch(err){ alert('Nie udało się rozpocząć przygody: '+err.message); }
}
function roll(){
  const v=Math.floor(Math.random()*20)+1;
  const result=v===1?'krytyczne niepowodzenie':v<=8?'niepowodzenie':v<=14?'częściowy sukces':v<20?'sukces':'krytyczny sukces';
  pendingRoll={value:v,result};
  const inp=$('#playerInput');
  if(inp.value && !inp.value.includes('rzut kością')) inp.value += ` (rzut kością: ${result}, k20: ${v})`;
  else if(!inp.value) inp.value=`Próbuję wykonać akcję (rzut kością: ${result}, k20: ${v})`;
}
async function send(text=null){
  const val=(text||$('#playerInput').value).trim();
  if(!val) return;
  $('#btnSend').disabled=true;
  $('#btnSend').textContent='Piszę...';
  try{
    const res=await api('/api/send',{text:val,roll:pendingRoll});
    pendingRoll=null;
    $('#playerInput').value='';
    state=res.db;
    renderAll();
  } catch(e){ alert(e.message); }
  finally{
    $('#btnSend').disabled=false;
    $('#btnSend').textContent='Wyślij ✈';
  }
}
function showInfo(title, body){
  $('#infoTitle').textContent=title;
  $('#infoBody').textContent=body;
  $('#infoDialog').showModal();
}
async function saveSettings(){
  const current=state?.settings||{};
  const s={
    aiMode:$('#aiMode').value,
    bielikModel:$('#bielikModel').value,
    ollamaModel:$('#ollamaModel').value,
    claudeBaseUrl:$('#claudeBaseUrl').value,
    claudeModel:$('#claudeModel').value,
    claudeAuthType:$('#claudeAuthType').value,
    claudeToken:$('#claudeToken').value || current.claudeToken || '',
    openAiEndpoint:$('#openAiEndpoint').value,
    openAiModel:$('#openAiModel').value,
    openAiApiKey:$('#openAiApiKey').value || current.openAiApiKey || '',
    temperature: current.temperature || .85,
    windowMode:$('#windowMode')?.value||'window'
  };
  try{
    await api('/api/settings',s);
    await refresh();
    const out=$('#aiTestResult');
    if(out) out.textContent='Zapisano ustawienia. Tryb uruchamiania został zapamiętany.';
    if(s.windowMode==='fullscreen'){
      const el=document.documentElement;
      if(el.requestFullscreen && !document.fullscreenElement){ el.requestFullscreen().catch(()=>{}); }
    } else if(document.fullscreenElement && document.exitFullscreen){ document.exitFullscreen().catch(()=>{}); }
  }catch(err){ alert('Nie udało się zapisać ustawień: '+err.message); }
}
async function testAI(){
  $('#aiTestResult').textContent='Testuję...';
  try{
    const r=await api('/api/test-ai',{});
    $('#aiTestResult').textContent='OK: '+(r.answer||'').slice(0,120);
  }catch(e){ $('#aiTestResult').textContent='Błąd: '+e.message; }
}

function wire(){
  $$('.nav[data-screen]').forEach(b=>b.onclick=()=>showScreen(b.dataset.screen));
  $$('.nav[data-modal]').forEach(b=>b.onclick=()=>showInfo(b.textContent.trim(), modalData(b.dataset.modal)));
  $('#btnNewCharacter').onclick=()=>openCharacterDialog();
  $('#btnNewCharacter2').onclick=()=>openCharacterDialog();
  $('#btnCancelCharacter').onclick=()=>$('#characterDialog').close();
  $('#btnCancelWorld').onclick=()=>$('#worldDialog').close();
  $('#characterDialog form').addEventListener('submit', e=>e.preventDefault());
  $('#worldDialog form').addEventListener('submit', e=>e.preventDefault());
  $('#btnSaveCharacter').onclick=saveCharacter;
  $('#btnPlaySelected').onclick=selectAndPlay;
  $('#btnEditSelected').onclick=()=>{ const c=selectedCharacter(); if(!c) return alert('Wybierz postać do edycji.'); selectedCharacterId=c.id; openCharacterDialog(c); };
  $('#btnOpenCharacterLibrary').onclick=()=>showScreen('characters');
  $('#btnStartAdventure').onclick=startAdventure;
  $('#worldPreset').onchange=e=>applyWorldPreset(e.target.value);
  $('#btnNewAdventureFromList').onclick=selectAndPlay;
  $('#btnSend').onclick=()=>send();
  $('#btnRoll').onclick=roll;
  $('#playerInput').addEventListener('keydown',e=>{ if(e.key==='Enter') send(); });
  [1,2,3].forEach(i=>$('#choice'+i).onclick=()=>send($('#choice'+i+' span').textContent));
  $('#btnSettingsTop').onclick=()=>showScreen('settings');
  $('#btnSaveSettings').onclick=saveSettings;
  $('#btnApplyScreenMode').onclick=applyScreenModeNow;
  $('#btnTestAI').onclick=testAI;
  $('#btnExport').onclick=async()=>{ const r=await fetch('/api/export'); const blob=await r.blob(); const a=document.createElement('a'); a.href=URL.createObjectURL(blob); a.download='kronikarz_export.json'; a.click(); };
  $('#btnShutdown').onclick=()=>{ navigator.sendBeacon('/api/shutdown'); window.close(); };
  $('#btnScrollTop').onclick=()=>{$('#log').scrollTop=0};
  $('#btnScrollBottom').onclick=()=>{$('#log').scrollTop=$('#log').scrollHeight};
  $('#btnHelp').onclick=()=>showInfo('Pomoc','1. Stwórz lub wybierz postać.\n2. Kliknij „Graj tą postacią”.\n3. Utwórz świat i rozpocznij opowieść.\n4. Pisz decyzje, klikaj kafelki lub używaj rzutu kością.');
}
document.addEventListener('change', e=>{
  const input=e.target.closest?.('.avatar-file-input');
  if(!input) return;
  const id=input.dataset.charId || selectedCharacterId;
  uploadAvatar(id, input.files?.[0]);
});
document.addEventListener('click', e=>{
  const up=e.target.closest?.('[data-upload-avatar]');
  if(up){ e.preventDefault(); chooseAvatarFile(up.dataset.uploadAvatar); return; }
  const cont=e.target.closest?.('[data-continue]');
  if(cont){ e.preventDefault(); continueAdventure(cont.dataset.continue); return; }
  const del=e.target.closest?.('[data-delete-adv]');
  if(del){ e.preventDefault(); deleteAdventure(del.dataset.deleteAdv); return; }
});
window.addEventListener('beforeunload',()=>navigator.sendBeacon('/api/shutdown'));
wire(); refresh().then(()=>setTimeout(()=>showInfo('Wersja testowa', 'To wersja testowa. Aplikacja nie jest jeszcze podpisana certyfikatem, dlatego Windows może pokazać ostrzeżenie SmartScreen.'), 350));
