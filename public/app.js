fetch("/data/wheels.json").then(response => {
  if (!response.ok) throw new Error("Wheel catalog could not be loaded");
  return response.json();
}).then(wheelCatalog => fetch("/data/shop.json").then(response => {
  if (!response.ok) throw new Error("Shop catalog could not be loaded");
  return response.json();
}).then(shopCatalog => fetch("/data/nouns.json").then(response => {
  if (!response.ok) throw new Error("Noun catalog could not be loaded");
  return response.json();
}).then(nounCatalog => {
wheelCatalog.wheels.push(...shopCatalog.wheels);
wheelCatalog.skins = shopCatalog.skins;
const BASE_D = wheelCatalog.wheels.find(item=>item.id==='starter').data;
let verbData = BASE_D, D = verbData, gameMode = 'verbs';
const CASES = nounCatalog.cases;
const NUMBERS = nounCatalog.numbers;
const NOUN_D = {
  isNoun: true,
  verbs: nounCatalog.nouns.map(noun=>noun.nom),
  konj: nounCatalog.nouns.map(noun=>noun.declension),
  tenses: CASES,
  pers: NUMBERS,
  nouns: nounCatalog.nouns,
  forms: nounCatalog.nouns.flatMap((noun, v)=>noun.forms.flatMap((forms, p)=>forms.map((form, t)=>[
    form, v, t, p, [[form, 'S']], noun.german[p][t]
  ])))
};
const SHOP_KEY = 'tempo-shop-stand-v1';
const wheelIds = new Set(wheelCatalog.wheels.map(item=>item.id));
const skinIds = new Set(wheelCatalog.skins.map(item=>item.id));
function readShopState(){
  try{
    const saved = JSON.parse(localStorage.getItem(SHOP_KEY)||'{}');
    const ownedWheels = [...new Set((Array.isArray(saved.ownedWheels)?saved.ownedWheels:[]).filter(id=>wheelIds.has(id)))];
    const ownedSkins = [...new Set((Array.isArray(saved.ownedSkins)?saved.ownedSkins:[]).filter(id=>skinIds.has(id)))];
    if (!ownedWheels.includes('starter')) ownedWheels.push('starter');
    if (!ownedSkins.includes('pergament')) ownedSkins.push('pergament');
    return {ownedWheels, ownedSkins,
      activeWheel: ownedWheels.includes(saved.activeWheel)?saved.activeWheel:'starter',
      activeSkin: ownedSkins.includes(saved.activeSkin)?saved.activeSkin:'pergament'};
  }catch(e){ return {ownedWheels:['starter'],ownedSkins:['pergament'],activeWheel:'starter',activeSkin:'pergament'}; }
}
let shopState = readShopState();
let palette = wheelCatalog.skins.find(item=>item.id===shopState.activeSkin).palette;
let activeWheelId = 'starter';
function saveShopState(){ try{ localStorage.setItem(SHOP_KEY,JSON.stringify(shopState)); }catch(e){} }
let NV = D.verbs.length, VS = 360/NV;   // Anzahl Verben, Winkel pro Verb (bei eigenen Verben veränderlich)
const R_OUT=99, R_AB=78, R_BC=57;           // breite Griffringe (viewBox-Einheiten)
const wheel = document.getElementById('wheel');
const NS='http://www.w3.org/2000/svg';
const el=(tag,attrs,parent)=>{const e=document.createElementNS(NS,tag);for(const k in attrs)e.setAttribute(k,attrs[k]);if(parent)parent.appendChild(e);return e;};
const P=(r,a)=>{a=a*Math.PI/180;return [r*Math.sin(a),-r*Math.cos(a)];};
function sector(r1,r2,a1,a2){const[x1,y1]=P(r2,a1),[x2,y2]=P(r2,a2),[x3,y3]=P(r1,a2),[x4,y4]=P(r1,a1);const L=(a2-a1)>180?1:0;
  return `M${x1},${y1}A${r2},${r2} 0 ${L} 1 ${x2},${y2}L${x3},${y3}A${r1},${r1} 0 ${L} 0 ${x4},${y4}Z`;}
let pid=0;
const FLIP=[];   // Beschriftungen, die in der unteren Hälfte umgedreht werden (immer aufrecht lesbar)
function arcText(g,txt,r,ang,span,cls,ring,cap=4.4,rflip=null){
  const mk=(flip)=>{
    const id='ap'+(pid++), rr = flip ? (rflip ?? r+cap) : r;
    const [x1,y1]=P(rr,flip?ang+span:ang-span), [x2,y2]=P(rr,flip?ang-span:ang+span);
    el('path',{id,d:`M${x1},${y1}A${rr},${rr} 0 0 ${flip?0:1} ${x2},${y2}`,fill:'none'},g);
    const tx=el('text',{class:cls},g), tp=el('textPath',{href:'#'+id,startOffset:'50%','text-anchor':'middle'},tx); tp.textContent=txt;
    return tx;
  };
  const a=mk(false), b=mk(true); b.style.display='none';
  FLIP.push({a,b,ang,ring});
  return {setAttribute:(k,v)=>{a.setAttribute(k,v);b.setAttribute(k,v);a.style.setProperty(k,v);b.style.setProperty(k,v);}};
}
function updateFlip(){
  for (const f of FLIP){
    const abs = mod(f.ang + (rot[f.ring]||0), 360), down = abs>95 && abs<265;
    f.a.style.display = down?'none':''; f.b.style.display = down?'':'none';
  }
}
function buildWheel(){
  const gA=document.getElementById('gA'), gB=document.getElementById('gB'), gC=document.getElementById('gC'), gF=document.getElementById('gFix');
  gA.innerHTML=''; gB.innerHTML=''; gC.innerHTML=''; gF.innerHTML=''; FLIP.length=0;
  // Ring A: Tempora bei Verben, Kasus bei Substantiven
  D.tenses.forEach((name,t)=>{
    const th=60*t, g=D.isNoun || t<3;
    el('path',{d:sector(R_AB,R_OUT,th-30,th+30),fill:g?palette.present:palette.perfect},gA);
    el('path',{d:sector(R_AB,R_OUT,th+29.7,th+30.3),fill:palette.paper},gA);
    arcText(gA,name,87.2,th,40,'lblA','A').setAttribute('fill',g?palette.presentInk:palette.perfectInk);
    el('path',{d:`M${P(R_AB,th)}L${P(R_AB+4.2,th-2.6)}L${P(R_AB+4.2,th+2.6)}Z`,fill:g?palette.presentInk:palette.perfectInk},gA);
  });
  el('circle',{r:R_OUT,fill:'none',stroke:palette.rim,'stroke-width':0.6},gA);
  buildRingB();
  // innere Scheibe (fest), Farbton folgt der ausgewählten Achse
  el('circle',{id:'cdisc',r:R_BC,fill:palette.paper},gC);
  el('circle',{r:R_BC-1.6,fill:'none',stroke:palette.inner,'stroke-width':0.7,opacity:.55},gC);
  // fester Zeiger auf 12 Uhr
  el('path',{d:`M0,${-R_BC-0.2}L-3.6,${-R_BC+5.4}L3.6,${-R_BC+5.4}Z`,fill:palette.inner},gF);
}
function buildRingB(){
  const gB=document.getElementById('gB');
  gB.innerHTML=''; for (let i=FLIP.length-1;i>=0;i--) if (FLIP[i].ring==='B') FLIP.splice(i,1);
  NV = D.verbs.length; VS = 360/Math.max(NV,1);
  D.verbs.forEach((vb,v)=>{
    const th=VS*v;
    const name=D.isNoun ? D.nouns[v].nom : vb.split(' ')[0];
    const de=D.isNoun ? D.nouns[v].meaning : vb.split('(')[1].replace(')','');
    const fillB = v%2?palette.ringOdd:palette.ringEven;
    if (VS>=180){ el('path',{d:sector(R_BC,R_AB,th-VS/2,th),fill:fillB},gB); el('path',{d:sector(R_BC,R_AB,th,th+VS/2),fill:fillB},gB); }
    else el('path',{d:sector(R_BC,R_AB,th-VS/2,th+VS/2),fill:fillB},gB);
    el('path',{d:sector(R_BC,R_AB,th+VS/2-0.3,th+VS/2+0.3),fill:palette.paper},gB);
    arcText(gB,name,70.0,th,Math.min(VS*0.62,80),'lblB','B',4.3,64.0).setAttribute('fill',palette.ringText);
    arcText(gB,de,64.4,th,Math.min(VS*0.62,80),'lblB2','B',3.3,68.6).setAttribute('fill',palette.ringSub);
    const category=D.isNoun
      ? `${D.nouns[v].declension[0]}.${D.nouns[v].declension.includes('i-Stamm')?' i':''}`
      : D.konj[v];
    arcText(gB,category,59.4,th,Math.min(VS*0.62,80),'lblB3','B',2.8,72.8).setAttribute('fill',palette.ringKonj);
    el('path',{d:`M${P(R_AB,th)}L${P(R_AB-2.8,th-2.4)}L${P(R_AB-2.8,th+2.4)}Z`,fill:palette.ringText},gB);
  });
}
buildWheel();
const rings = {A: document.getElementById('gA'), B: document.getElementById('gB')};
let rot = {A:0, B:0};
let sel = -1, rightRow = null, shownKey = '';
const revealed = new Set();
const mod = (x,m)=>((x%m)+m)%m;
const near = (x,step)=>Math.round(x/step)*step;
function render(){
  for (const k in rings) rings[k].style.transform = `rotate(${rot[k]}deg)`;
  updateFlip();
  readout();
}
function state(){
  const v = mod(Math.round(-rot.B/VS),NV), t = mod(Math.round(-rot.A/60),6);
  const ok = Math.abs(mod(rot.B+VS*v+180,360)-180)<4 && Math.abs(mod(rot.A+60*t+180,360)-180)<4;
  return {v,t,ok};
}
const MICO = {ghost:'👻', camel:'🐪'};
const seg = f=>f[4].map(([s,k])=>{
  const fm = f[7] || (D.futmn && D.futmn[f[1]]);
  const ico = (k==='T' && f[2]===2 && MICO[fm]) ? `<span class="tico" aria-hidden="true">${MICO[fm]}</span>` : '';
  return `${ico}<span class="k-${k}${k==='T'?((f[2]===2||f[2]===5)?' fut':' imp'):''}">${s}</span>`;
}).join('');

// ---------- Eselsbrücken fürs Futur I ----------
const MN = {
  ghost: {ico:'👻', short:'Futur-Gespenst: -b-ō, -bi-, -bu-', long:'Das <b>Futur-Gespenst</b> ruft: „<b>bō – bi – bu!</b>“ – Tempuszeichen <b>-b-ō, -bi-</b> (2. Sg. bis 2. Pl.), <b>-bu-nt</b> (a- und e-Konjugation, auch īre)'},
  camel: {ico:'🐪', short:'Futur-Kamel: K-<b>a</b>-m-<b>e</b>-l', long:'Das <b>Futur-Kamel</b>: K-<b>a</b>-m-<b>e</b>-l – erst <b>-a-</b> (1. Sg.), dann <b>-ē-/-e-</b> (i-, konsonantische und gemischte Konjugation)'}
};
function mnem(v){ return D.futmn ? MN[D.futmn[v]] : null; }

function pfLine(v){
  if (D.nopfline || !D.pft || !D.pft[v]) return '';   // bei esse & Co. ausgeblendet (wäre schon die Lösung)
  const p1 = D.forms.find(f=>f[1]===v && f[2]===3 && f[3]===0), pr = (D.stamm[v]||'').split(',')[1];
  return `<div class="pfline"><b>${D.pft[v]}</b>: <span class="lat">${seg(p1)}</span></div>`;
}
function readout(){
  const {v,t,ok} = state();
  const tc = D.isNoun || t<3?'g':'r';
  const itemLabel=D.isNoun
    ? `${D.nouns[v].nom}, ${D.nouns[v].gen} (${D.nouns[v].gender})`
    : D.verbs[v];
  const categoryLabel=D.isNoun ? D.nouns[v].declension : D.konj[v];
  document.getElementById('readout').innerHTML = `${itemLabel} <span class="kj">${categoryLabel}</span> · <span class="t ${tc}">${D.tenses[t]}</span>`;
  const mn = t===2 && mnem(v);
  const wheelLabel=D.isNoun ? `${D.nouns[v].nom}, ${D.nouns[v].gen} (${D.nouns[v].gender})` : D.verbs[v].split(' ')[0];
  document.getElementById('whead').innerHTML = `${wheelLabel} · <span class="t ${tc}">${D.tenses[t]}</span>` +
     (!D.isNoun && mn ? `<div class="mnem"><span class="mico">${mn.ico}</span> ${mn.short}</div>` : '') + (!D.isNoun && t>=3 ? pfLine(v) : '');
  const cd = document.getElementById('cdisc'); if (cd) cd.setAttribute('fill', D.isNoun ? palette.paper : t<3 ? palette.presentDisc : palette.perfectDisc);
  const key = v+'-'+t;
  if (key !== shownKey){ shownKey = key; revealed.clear(); sel = -1; if (rightRow && rightRow[1]===v && rightRow[2]===t){ revealed.add(rightRow[3]); sel = rightRow[3]; } }
  document.getElementById('wtab').innerHTML = D.forms.filter(f=>f[1]===v && f[2]===t)
     .map(f=>{ const r = rightRow && rightRow[1]===f[1] && rightRow[2]===f[2] && rightRow[3]===f[3];
       const body = revealed.has(f[3]) ? seg(f)+`<button class="say" type="button" data-say="${f[0]}" aria-label="vorlesen">🔊</button>` : '<span class="cover" aria-label="verdeckt – antippen">antippen</span>';
       return `<tr data-p="${f[3]}" class="${sel===f[3]&&revealed.has(f[3])?'sel':''}${r?' right':''}"><td class="p">${D.pers[f[3]]}</td><td>${body}${r?'<span class="tick">✓</span>':''}</td></tr>`; }).join('');
  const w = document.getElementById('wtr'), ff = revealed.has(sel) && D.forms.find(f=>f[1]===v && f[2]===t && f[3]===sel);
  if (ff){ w.textContent = '„' + ff[0] + '“ = ' + ff[5]; w.classList.add('on'); }
  else { w.textContent = 'Zeile antippen = Form aufdecken'; w.classList.remove('on'); }
  document.getElementById('win').classList.toggle('off', !ok);
  fitWin();
}

// ---------- Fenster-Inhalt immer innerhalb des inneren Kreises halten ----------
function fitWin(){
  const win = document.getElementById('win'); if (!win) return;
  const W = wheel.getBoundingClientRect(); if (!W.width) return;
  const cx = W.left + W.width/2, cy = W.top + W.height/2, R = (R_BC-3.2)/200*W.width;  // etwas Abstand zur roten Linie
  let k = 1; wheel.style.setProperty('--k', 1);
  for (let pass=0; pass<3; pass++){
    let s = 1;
    const rects = [];
    const tw = document.createTreeWalker(win, NodeFilter.SHOW_TEXT);
    while (tw.nextNode()){ const n = tw.currentNode; if (!n.nodeValue.trim()) continue;
      const rg = document.createRange(); rg.selectNodeContents(n); for (const r of rg.getClientRects()) rects.push(r); }
    win.querySelectorAll('.cover, .k-T, #wtab tr.sel td:last-child, #wtab tr.right td:last-child').forEach(e=>{ for (const r of e.getClientRects()) rects.push(r); });
    for (const r of rects){
      if (!r.width) continue;
      const dx = Math.max(Math.abs(r.left-cx), Math.abs(r.right-cx)), dy = Math.max(Math.abs(r.top-cy), Math.abs(r.bottom-cy));
      const d = Math.hypot(dx, dy); if (d > R) s = Math.min(s, R/d);
    }
    if (s >= 0.995) break;
    k *= s*0.985; wheel.style.setProperty('--k', k);
  }
}
function snapAll(which){
  if (!document.getElementById('snap').checked) return;
  wheel.classList.add('snap');
  if (which==='A') rot.A = near(rot.A, 60); else rot.B = near(rot.B, VS);
  render();
  setTimeout(()=>wheel.classList.remove('snap'), 260);
}
let drag=null;
function polar(e){
  const r = wheel.getBoundingClientRect();
  const x = e.clientX - (r.left + r.width/2), y = e.clientY - (r.top + r.height/2);
  const k = 200 / r.width;
  return {ang: Math.atan2(x, -y)*180/Math.PI, rmm: Math.hypot(x,y)*k};
}
document.getElementById('wtab').addEventListener('click', e=>{
  const sb = e.target.closest('.say'); if (sb){ e.stopPropagation(); speak([sb.dataset.say]); return; }
  const tr = e.target.closest('tr'); if (!tr) return;
  const p = +tr.dataset.p;
  if (!state().ok){ readout(); return; }
  if (revealed.has(p)){            // erneutes Antippen: wieder verdecken (zählt nicht als Antwort)
    revealed.delete(p); if (sel===p) sel = -1; readout(); return;
  }
  revealed.add(p); peek(); sel = p; readout();
  { const {v,t} = state(), f = D.forms.find(x=>x[1]===v && x[2]===t && x[3]===p); if (f) speak([f[0]]); }
  if (dq) checkWheelClick(p);
});
document.getElementById('wall').addEventListener('click', ()=>{
  if (!state().ok) return;
  for (let i=0;i<D.pers.length;i++) revealed.add(i); peek(); readout();
});
document.getElementById('wnone').addEventListener('click', ()=>{
  revealed.clear(); sel = -1; readout();
});
// Wer bei offener Aufgabe aufdeckt, bekommt keinen Längen-Bonus mehr
function peek(){ if (typeof dq!=='undefined' && dq && !ddone) dpeek = true; }
wheel.addEventListener('pointerdown', e=>{
  const p = polar(e);
  if (p.rmm > R_OUT + 3 || p.rmm < R_BC - 1) return;
  drag = {which: p.rmm > R_AB ? 'A' : 'B', last:p.ang};
  wheel.classList.remove('snap'); wheel.classList.add('drag');
  wheel.setPointerCapture(e.pointerId);
  e.preventDefault();
});
wheel.addEventListener('pointermove', e=>{
  if (!drag) return;
  const p = polar(e);
  const da = mod(p.ang - drag.last + 180, 360) - 180;
  drag.last = p.ang;
  rot[drag.which] += da;
  render();
});
function end(){ if (!drag) return; const w = drag.which; drag=null; wheel.classList.remove('drag'); snapAll(w); }
wheel.addEventListener('pointerup', end);
wheel.addEventListener('pointercancel', end);

// ---------- Münzkasse ----------
// 1 Aureus = 25 Denare, 1 Denar = 4 Sesterzen, 1 Sesterz = 4 Asse  (alles in Assen gezählt)
const COINS = [
  {k:'aureus', name:'Aureus', pl:'Aurei', val:1600, cls:'gold', mark:'AV'},
  {k:'denar',  name:'Denar',  pl:'Denare', val:16, cls:'silver', mark:'X'},
  {k:'sest',   name:'Sesterz',pl:'Sesterzen', val:4, cls:'brass', mark:'HS'},
  {k:'as',     name:'As',     pl:'Asse', val:1, cls:'copper', mark:'AS'},
];
let purse = 0, earned = 0;
try { purse = +localStorage.getItem('drehscheibe-asse') || 0; earned = Math.max(+localStorage.getItem('drehscheibe-verdient') || 0, purse); } catch(e){}
function split(n){ const o={}; for (const c of COINS){ o[c.k]=Math.floor(n/c.val); n%=c.val; } return o; }
function coinSVG(c, size=38){
  return `<svg class="coin ${c.cls}" width="${size}" height="${size}" viewBox="0 0 40 40" aria-hidden="true">
    <circle cx="20" cy="20" r="18.5"/><circle cx="20" cy="20" r="14.5" class="in"/>
    <text x="20" y="24.5" text-anchor="middle">${c.mark}</text></svg>`;
}
function renderPurse(){
  const s = split(purse);
  document.getElementById('purse').innerHTML = COINS.map(c=>
    `<div class="slot">${coinSVG(c)}<div><b>${s[c.k]}</b> ${s[c.k]===1?c.name:c.pl}</div></div>`).join('');
  document.getElementById('ptotal').textContent = `Gesamtwert: ${purse} ${purse===1?'As':'Asse'}`;
  document.getElementById('shopBalance').textContent = `${purse} ${purse===1?'As':'Asse'} verfügbar`;
  renderShop();
}
function penalty(asse, why){          // Abzug bei Lösung nach 4 Fehlversuchen: 1 As pro Fehlversuch
  const lost = Math.min(asse, purse);
  purse -= lost;
  try { localStorage.setItem('drehscheibe-asse', purse); } catch(e){}
  renderPurse();
  const tst = document.getElementById('toast');
  tst.classList.add('minus');
  tst.innerHTML = lost ? `−${lost} ${lost===1?'As':'Asse'} (${why})` : `Keine Münzen abgezogen – die Kasse ist leer (${why})`;
  tst.classList.remove('show'); void tst.offsetWidth; tst.classList.add('show');
  setTimeout(()=>tst.classList.remove('minus'), 3000);
  return lost;
}
function reward(asse, why){
  const before = split(purse);
  purse += asse; earned += asse; try{ localStorage.setItem('drehscheibe-verdient', earned); }catch(e){} lbDirty();
  try { localStorage.setItem('drehscheibe-asse', purse); } catch(e){}
  const after = split(purse);
  let msg = `+${asse} ${asse===1?'As':'Asse'} (${why})`, up=false;
  for (const c of COINS.slice(0,3)) if (after[c.k] > before[c.k]) { msg += ` · Umtausch: neuer ${c.name}!`; up=true; break; }
  playCoins(asse, up);
  renderPurse();
  const tst = document.getElementById('toast');
  tst.innerHTML = `<span class="chk">✓</span> ${msg}`;
  tst.classList.remove('show'); void tst.offsetWidth; tst.classList.add('show');
}
document.getElementById('preset').onclick = ()=>{
  const b = document.getElementById('preset');
  if (b.dataset.sure){ if (purse>0) playSound('empty'); purse = 0; try{localStorage.setItem('drehscheibe-asse',0);}catch(e){} renderPurse(); b.textContent='Kasse leeren'; delete b.dataset.sure; }
  else { b.dataset.sure = 1; playSound('ask'); b.textContent = 'Wirklich leeren?'; setTimeout(()=>{ b.textContent='Kasse leeren'; delete b.dataset.sure; }, 3000); }
};


// ---------- Klimpern ----------
// Der Klang wird als fertige WAV-Datei im Speicher erzeugt und über ein <audio>-Element abgespielt.
// So spielt er auch in eingebetteten Ansichten und auf iPhone/iPad (Web Audio wäre dort bei Lautlos-Schalter stumm).
let soundOn=true;
try { soundOn = localStorage.getItem('drehscheibe-ton') !== 'aus'; } catch(e){}
try { if (navigator.audioSession) navigator.audioSession.type = 'playback'; } catch(e){}
const SR = 22050;
function synth(n, upgrade, hitsIn){
  const hits = hitsIn ? hitsIn.slice() : [];
  if (!hitsIn){
    for (let i=0;i<n;i++) hits.push([i*0.13 + Math.random()*0.03, 0.9+Math.random()*0.25]);
    if (upgrade) [1.0,1.26,1.5,2.0].forEach((p,i)=>hits.push([n*0.13+0.15+i*0.09, p*1.1]));
  }
  const dur = Math.max(...hits.map(h=>h[0])) + 0.6, len = Math.ceil(dur*SR), buf = new Float32Array(len);
  for (const [t0,pitch,amp0=1] of hits){
    const s0 = Math.floor(t0*SR);
    [[1,1],[2.76,0.55],[5.40,0.3],[8.93,0.15]].forEach(([m,amp])=>{
      const f = 1850*pitch*m*(0.985+Math.random()*0.03), tau = (0.18+0.25/m)/5, ph = Math.random()*6.28;
      for (let i=0;i<0.55*SR && s0+i<len;i++){
        const tt=i/SR, env = Math.min(1, tt/0.004)*Math.exp(-tt/tau);
        buf[s0+i] += 0.2*amp*amp0*env*Math.sin(2*Math.PI*f*tt+ph);
      }
    });
    let prev=0;
    for (let i=0;i<0.03*SR && s0+i<len;i++){            // kurzer Anschlag (hochpass-gefiltertes Rauschen)
      const r=(Math.random()*2-1)*Math.pow(1-i/(0.03*SR),4); buf[s0+i]+=0.12*amp0*(r-prev); prev=r;
    }
  }
  let peak=0; for (const v of buf) peak=Math.max(peak,Math.abs(v));
  const g = peak>0 ? 0.9/peak : 1;
  const dv = new DataView(new ArrayBuffer(44+len*2)), w=(o,s)=>[...s].forEach((ch,i)=>dv.setUint8(o+i,ch.charCodeAt(0)));
  w(0,'RIFF'); dv.setUint32(4,36+len*2,true); w(8,'WAVE'); w(12,'fmt '); dv.setUint32(16,16,true);
  dv.setUint16(20,1,true); dv.setUint16(22,1,true); dv.setUint32(24,SR,true); dv.setUint32(28,SR*2,true);
  dv.setUint16(32,2,true); dv.setUint16(34,16,true); w(36,'data'); dv.setUint32(40,len*2,true);
  for (let i=0;i<len;i++) dv.setInt16(44+i*2, Math.max(-1,Math.min(1,buf[i]*g))*32767, true);
  return URL.createObjectURL(new Blob([dv.buffer],{type:'audio/wav'}));
}
const SOUNDS = {};
for (const n of [1,2,4]) for (const up of [false,true]) SOUNDS[n+'-'+up] = synth(n, up);
// Kasse leeren: Münzen rieseln aus dem Beutel – immer schneller, tiefer und leiser, zum Schluss ein dumpfes „Plopp“
(function(){
  const h=[]; let tt=0, gap=0.12;
  for (let i=0;i<16;i++){ h.push([tt, 1.3 - i*0.035 + (Math.random()-.5)*0.12, 1 - i*0.04]); tt += gap; gap = Math.max(0.035, gap*0.86); }
  h.push([tt+0.12, 0.42, 0.55]);
  SOUNDS.empty = synth(0, false, h);
  SOUNDS.ask = synth(0, false, [[0,0.62,0.8],[0.16,0.55,0.6]]);   // fragender, tiefer Doppelton
})();
function playSound(key){
  if (!soundOn || !SOUNDS[key]) return;
  try{ player.pause(); player.src = SOUNDS[key]; player.currentTime = 0; const p = player.play(); if (p && p.catch) p.catch(()=>{}); }catch(e){}
}
const player = new Audio(); player.preload='auto';
function playCoins(n, upgrade){
  if (!soundOn) return;
  const key = ([1,2,4].includes(n)?n:Math.min(4,Math.max(1,n)))+'-'+!!upgrade;
  try {
    player.pause(); player.src = SOUNDS[key]; player.currentTime = 0;
    const p = player.play(); if (p && p.catch) p.catch(()=>showSoundHint());
  } catch(e){ showSoundHint(); }
}
function showSoundHint(){
  const h=document.getElementById('shint'); if(h) h.style.display='block';
}
document.getElementById('sound').onclick = ()=>{
  soundOn = !soundOn;
  try{ localStorage.setItem('drehscheibe-ton', soundOn?'an':'aus'); }catch(e){}
  document.getElementById('sound').textContent = soundOn ? '🔊 Ton an' : '🔇 Ton aus';
  if (soundOn) playCoins(1,false);
};
document.getElementById('sound').textContent = soundOn ? '🔊 Ton an' : '🔇 Ton aus';

// ---------- Übung: Form bestimmen ----------
let q=null, qdone=false, qtries=0;
function itemShort(v){
  return D.isNoun ? `${D.nouns[v].nom}, ${D.nouns[v].gen} (${D.nouns[v].gender})` : D.verbs[v].split(' ')[0];
}
function formContext(f){ return `${D.tenses[f[2]]}, ${D.pers[f[3]]}`; }
function taskForms(form){
  return D.isNoun
    ? D.forms.filter(f=>f[1]===form[1] && f[2]===form[2] && f[3]===form[3])
    : D.forms.filter(f=>f[5]===form[5]);
}
document.getElementById('qnew').onclick = ()=>{
  q = D.forms[Math.floor(Math.random()*D.forms.length)]; qdone=false; qtries=0;
  document.getElementById('qform').textContent = q[0];
  document.getElementById('qres').textContent = '';
};
document.getElementById('qcheck').onclick = ()=>{
  const r = document.getElementById('qres');
  if (!q){ r.textContent = 'Tippe zuerst auf „Neue Form“.'; return; }
  const {v,t,ok} = state();
  const hits = D.forms.filter(f=>f[0]===q[0]);
  if (ok && hits.some(f=>f[1]===v && f[2]===t)){
    const h = hits.filter(f=>f[1]===v && f[2]===t);
    r.innerHTML = `<span class="ok big">✓ Richtig!</span> ${D.tenses[t]}, ${h.map(f=>D.pers[f[3]]).join(' / ')} – <i>${h[0][5]}</i>`;
    sel = h[0][3]; readout();
    if (!qdone){ qdone = true; reward(2, 'Form bestimmt'); }
  } else if (!ok){
    r.innerHTML = '<span class="no">Die Pfeile stehen noch nicht genau.</span> Ring einrasten lassen.';
  } else {
    if (qdone) return;
    qtries++;
    if (qtries >= MAXTRY){ const lost = penalty(MAXTRY, `${MAXTRY} Fehlversuche`); qSolution(`<span class="no">✗ Auch der ${MAXTRY}. Versuch war leider falsch – ${lost ? `−${lost} ${lost===1?'As':'Asse'}` : 'keine Münzen mehr in der Kasse'}.</span> Hier ist die Lösung:<br>`); return; }
    const left = MAXTRY - qtries, g = hits[0];
    let h;
    if (D.isNoun){
      h = hits.some(f=>f[1]===v && f[2]===t)
        ? '<span class="no">Substantiv und Kasus stimmen. Prüfe den Numerus.</span>'
        : hits.some(f=>f[1]===v)
          ? '<span class="no">Das Substantiv stimmt, aber der Kasus noch nicht.</span>'
          : '<span class="no">Noch nicht.</span> Das eingestellte Substantiv passt nicht.';
    }else{
      h = hits.some(f=>f[1]===v) ? '<span class="no">Das Verb stimmt, das Tempus noch nicht.</span> Achte auf das Tempuszeichen.'
                                 : '<span class="no">Noch nicht.</span> Das eingestellte Verb passt nicht.';
    }
    if (qtries >= 2) h += `<div class="hbx"><b>Tipp:</b> ${D.isNoun ? `Der Genitiv lautet <span class="lat">${D.nouns[g[1]].gen}</span>; daran erkennt man die Deklination.` : g[2]<3 ? 'Die Form gehört zum <b>Präsensstamm</b> (grün).' : 'Die Form gehört zum <b>Perfektstamm</b> (rot).'}</div>`;
    if (qtries >= 3) h += tzHint(g);
    h += `<div class="tries">${left===1 ? '⚠ Letzter Versuch!' : `Noch ${left} Versuche`} ${'●'.repeat(qtries)}${'○'.repeat(left)}</div>`;
    r.innerHTML = h;
  }
};
function qSolution(intro){
  qdone = true; speak([q[0]]);
  const hits = D.forms.filter(f=>f[0]===q[0]), g = hits[0];
  setWheel(g[1], g[2], g[3]); revealed.add(g[3]); readout();
  document.getElementById('qres').innerHTML = (intro||'') + hits.map(f=>`${itemShort(f[1])}: ${formContext(f)} – <i>${f[5]}</i>`).join('<br>') + ' <span class="hint">(ohne Münze)</span>';
}
document.getElementById('qshow').onclick = ()=>{ if (q) qSolution(''); };

// ---------- Übung: Deutsch -> Latein ----------
const norm = s=>s.normalize('NFD').replace(/[̀-ͯ]/g,'').toLowerCase().replace(/[^a-z]/g,'');
const segH = f=>seg(f);
let dq=null, ddone=false, dpeek=false, dwrong=0, dtries=0, dok=0, dall=0;
const MAXTRY = 4;   // 3 Versuche mit Hinweisen, ist auch der 4. falsch, kommt die Lösung
const din = document.getElementById('din'), dres = document.getElementById('dres');
function dnew(focus=true){
  dq = pickForm(); dmiss=false; ddone=false; dpeek=false; dwrong=0; dtries=0;
  document.getElementById('dprompt').textContent = D.isNoun
    ? `${dq[5]} — ${formContext(dq)}`
    : dq[5];
  din.value=''; dres.innerHTML=''; sel=-1; rightRow=null; revealed.clear(); readout();
  if (focus) din.focus({preventScroll:true});
}
document.getElementById('dnew').onclick = ()=>dnew();
document.querySelectorAll('.mac .m').forEach(b=>b.onclick=()=>{
  const s=din.selectionStart??din.value.length, e=din.selectionEnd??s;
  din.value = din.value.slice(0,s)+b.textContent+din.value.slice(e);
  din.focus(); din.setSelectionRange(s+1,s+1);
});
function setWheel(v,t,p){
  wheel.classList.add('snap');
  rot.B = rot.B + (mod(-VS*v - rot.B + 180,360)-180);
  rot.A = rot.A + (mod(-60*t - rot.A + 180,360)-180);
  sel = p; render();
  setTimeout(()=>wheel.classList.remove('snap'), 260);
  if (document.body.classList.contains('small')) wheel.scrollIntoView({behavior:'smooth',block:'center'});
}
function score(){ document.getElementById('dscore').textContent = `${dok} von ${dall} richtig`; }
function success(f, asse, why, extra=''){
  if (!ddone){ dok++; const c=onCorrect(f); reward(asse+c.b, c.why?why+' · '+c.why:why); }
  ddone = true;
  dres.innerHTML = `<span class="ok big">✓ Richtig!</span> <span class="lat">${segH(f)}</span> <button class="say" type="button" onclick="speak(['${f[0]}'])" aria-label="vorlesen">🔊</button> = ${f[5]}${extra}`;
  markRight(f); score();
  if (!(document.activeElement && document.activeElement.closest && document.activeElement.closest('#wtab'))) speak([f[0]]);
}
function markRight(f){ rightRow = f; revealed.add(f[3]); readout(); }
function wrongTip(other, g){
  if (D.isNoun){
    if (other && other[1]===g[1] && other[2]===g[2]) return 'Substantiv und Kasus stimmen, aber der Numerus nicht.';
    if (other && other[1]===g[1] && other[3]===g[3]) return 'Substantiv und Numerus stimmen, aber der Kasus nicht.';
    if (other && other[1]===g[1]) return 'Das Substantiv stimmt, prüfe Kasus und Numerus.';
    return '';
  }
  if (other && other[1]===g[1] && other[2]===g[2]) return 'Tempus stimmt – aber die Person nicht. Schau auf die Personalendung.';
  if (other && other[1]===g[1]) return `Das ist ${D.tenses[other[2]]} (${other[5]}). Gesucht ist ${D.tenses[g[2]]}.`;
  return '';
}
// Hilfe bei Fehlern: nur Stammformen + Personalendungen (keine Stamm-Tipps)
const PE_PRAES = '-ō / -m, -s, -t, -mus, -tis, -nt', PE_PERF = '-ī, -istī, -it, -imus, -istis, -ērunt';
function helpBox(g){
  if (D.isNoun){
    const noun=D.nouns[g[1]];
    const neuter=noun.gender==='n.';
    return `<div class="hbx"><b>Lemma:</b> <span class="lat">${noun.nom}, ${noun.gen} (${noun.gender})</span> · ${noun.declension}</div>`+
      `<div class="hbx"><b>Gesucht:</b> ${D.tenses[g[2]]}, ${D.pers[g[3]]}. Das Genitiv-Singular-Ende hilft, die Deklination zu erkennen.</div>`+
      (neuter?'<div class="hbx">Bei Neutra sind Nominativ, Akkusativ und Vokativ gleich; im Plural enden diese Formen oft auf <span class="lat">-a</span>.</div>':'');
  }
  const m = g[2]===2 && mnem(g[1]);
  const sf = `<div class="hbx"><b>Stammformen:</b> <span class="lat">${D.stamm[g[1]]}</span></div>` + (m ? `<div class="hbx">${m.ico} ${m.long}</div>` : '') + (g[2]>=3 && D.pft ? `<div class="hbx"><b>Perfektbildung:</b> ${D.pft[g[1]]}</div>` : '');
  let pe;
  if (g[2]===3) pe = `<b>Personalendungen im Perfekt:</b> <span class="lat">${PE_PERF}</span><br><span class="hint">anders als im Präsensstamm: ${PE_PRAES}</span>`;
  else if (g[2]<3) pe = `<b>Personalendungen im Präsensstamm:</b> <span class="lat">${PE_PRAES}</span><br><span class="hint">anders als im Perfekt: ${PE_PERF}</span>`;
  else pe = `<b>Personalendungen:</b> <span class="lat">${PE_PRAES}</span> – wie im Präsensstamm<br><span class="hint">Nur das Perfekt hat eigene Endungen: ${PE_PERF}</span>`;
  return sf + `<div class="hbx">${pe}</div>`;
}
document.getElementById('dform').addEventListener('submit', e=>{
  e.preventDefault();
  if (!dq){ dnew(); return; }
  const a = norm(din.value); if (!a){ if (ddone) dnew(); return; }
  const goal = taskForms(dq);
  if (!ddone) dall++;
  let hit = goal.find(f=>norm(f[0])===a), altHit = false;
  if (!hit){ hit = goal.find(f=>(f[6]||[]).some(x=>norm(x)===a)); altHit = !!hit; }
  if (hit){
    const typed = din.value.trim().toLowerCase();
    const exact = typed===hit[0] || (hit[6]||[]).includes(typed);
    if (altHit){ success(hit, exact&&!dpeek?4:2, 'Nebenform', `<br><span class="hint">„${(hit[6]||[])[0]}“ ist eine richtige Nebenform. Auf der Scheibe steht „${hit[0]}“.</span>`); }
    else
    if (exact && !dpeek) success(hit, 4, 'mit allen Längen');
    else if (exact) success(hit, 2, 'aufgedeckt – kein Längen-Bonus', `<br><span class="hint">Du hattest auf der Scheibe aufgedeckt. Den Längen-Bonus gibt es nur ohne Aufdecken.</span>`);
    else success(hit, 2, 'getippt', `<br><span class="hint">Mit Längen: ${hit[0]} – ohne Aufdecken und mit Längen gibt es einen ganzen Sesterz!</span>`);
    setWheel(hit[1], hit[2], hit[3]);   // Scheibe dreht sich zur richtigen Form, die Zeile wird aufgedeckt und markiert
  } else {
    const other = D.forms.find(f=>norm(f[0])===a), g = goal[0];
    if (ddone) return;
    dtries++; onWrong(dq);
    if (dtries >= MAXTRY){ const lost = penalty(MAXTRY, `${MAXTRY} Fehlversuche`); showSolution(g, `<span class="no">✗ Auch der ${MAXTRY}. Versuch war leider falsch – ${lost ? `−${lost} ${lost===1?'As':'Asse'}` : 'keine Münzen mehr in der Kasse'}.</span> Hier ist die Lösung:`); score(); return; }
    const tip = wrongTip(other, g), left = MAXTRY - dtries;
    let h = `<span class="no">✗ Noch nicht.</span> ${tip}`;
    if (dtries >= 2) h += helpBox(g);              // 2. Fehlversuch: Stammformen, Endungen, Merkhilfen
    if (dtries >= 3) h += tzHint(g);               // 3. Fehlversuch: zusätzlich das Tempuszeichen
    h += `<div class="tries">${left===1 ? '⚠ Letzter Versuch!' : `Noch ${left} Versuche`} ${'●'.repeat(dtries)}${'○'.repeat(left)}</div>`;
    dres.innerHTML = h;
    score();
  }
});
// Antwort durch Einstellen der Scheibe und Antippen der Zeile
function checkWheelClick(p){
  const {v,t,ok} = state();
  if (!ok){ dres.innerHTML = '<span class="no">Erst einrasten lassen</span>, dann die Zeile antippen.'; return; }
  const f = D.forms.find(x=>x[1]===v && x[2]===t && x[3]===p);
  if (ddone) return;
  const correct=D.isNoun
    ? f[1]===dq[1] && f[2]===dq[2] && f[3]===dq[3]
    : f[5]===dq[5];
  if (correct){ dall++; success(f, dwrong?1:2, dwrong?'gefunden, nach Probieren':'auf der Scheibe gefunden'); }
  else {
    dwrong++; onWrong(dq);
    const g = taskForms(dq)[0], tip = wrongTip(f, g);
    dres.innerHTML = `Auf der Scheibe angetippt: „${f[0]}“ = <i>${f[5]}</i> – passt noch nicht zur Aufgabe. ${tip}` + helpBox(g);
  }
}
function showSolution(g, intro){
  if (!ddone) onWrong(dq); ddone = true; rightRow = null;
  setWheel(g[1],g[2],g[3]); revealed.add(g[3]); readout();
  dres.innerHTML = `${intro ? intro+'<br>' : 'Lösung: '}<span class="lat">${segH(g)}</span> <button class="say" type="button" onclick="speak(['${g[0]}'])" aria-label="vorlesen">🔊</button> = ${g[5]} – auf der Scheibe markiert (ohne Münze). <span class="hint">Weiter mit „Neue Aufgabe“.</span>`;
  speak([g[0]]);
}
function tzHint(g){
  if (D.isNoun){
    const noun=D.nouns[g[1]];
    return `<div class="hbx"><b>Tipp:</b> Gesucht ist <b>${D.tenses[g[2]]} ${D.pers[g[3]]}</b>. ${noun.gender==='n.'?'Bei einem Neutrum sind Nominativ, Akkusativ und Vokativ gleich.':'Vergleiche die Endung mit dem Genitiv-Stamm.'}</div>`;
  }
  const T = g[4].filter(s=>s[1]==='T').map(s=>s[0]);
  const txt = T.length ? `Das Tempuszeichen hier ist <span class="k-T ${(g[2]===2||g[2]===5)?'fut':'imp'}">-${T.join('-')}-</span>.`
                       : (g[2]===3 ? 'Im Perfekt gibt es kein Tempuszeichen – nur Perfektstamm + Perfektendung.' : 'Im Präsens gibt es kein Tempuszeichen – nur Stamm + Personalendung.');
  return `<div class="hbx"><b>Tipp:</b> ${txt}</div>`;
}
document.getElementById('dshow').onclick = ()=>{
  if (!dq) return;
  showSolution(taskForms(dq)[0]);
};

// ---------- Layout: alles auf einen Bildschirm ----------
document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('.tab').forEach(x=>x.classList.toggle('on',x===b));
  document.querySelectorAll('.tp').forEach(x=>x.classList.toggle('on',x.id===b.dataset.tab));
  document.body.classList.toggle('editing', b.dataset.tab==='t4');
  if (b.dataset.tab==='t5') lbLoad();
  if (b.dataset.tab==='shop') renderShop();
});
function setGameMode(mode){
  if (mode!=='verbs' && mode!=='nouns' || mode===gameMode) return;
  if (gameMode==='verbs') verbData=D;
  const activeTab=document.querySelector('.tab.on');
  gameMode=mode;
  D=gameMode==='nouns' ? NOUN_D : verbData;
  if (activeTab && activeTab.dataset.tab==='t4') document.querySelector('.tab[data-tab="t1"]').click();
  document.body.classList.toggle('noun-mode', D.isNoun);
  document.querySelectorAll('.word-mode').forEach(button=>{
    const active=button.dataset.mode===gameMode;
    button.classList.toggle('on',active);
    button.setAttribute('aria-pressed',String(active));
  });
  document.querySelectorAll('.verb-tab-label').forEach(label=>label.hidden=D.isNoun);
  document.querySelectorAll('.noun-tab-label').forEach(label=>label.hidden=!D.isNoun);
  document.getElementById('tab4').hidden=D.isNoun || !D.custom;
  document.getElementById('exerciseHint').textContent=D.isNoun
    ? 'Bilde die gesuchte Form mit richtiger Endung – oder stelle Kasus und Substantiv auf der Scheibe ein und tippe Singular oder Plural an.'
    : 'Aus dem Kopf eintippen – oder auf der Scheibe einstellen und die richtige Zeile antippen.';
  document.getElementById('identifyHint').textContent=D.isNoun
    ? 'Stelle Substantiv und Kasus auf der Scheibe ein; wähle Singular oder Plural in der passenden Zeile.'
    : 'Stelle Verb und Tempus auf der Scheibe so ein, dass die Form passt, dann „Prüfen“.';
  document.getElementById('tfilter').setAttribute('aria-label', D.isNoun?'Kasusfilter':'Tempusfilter');
  buildWheel();
  rot={A:0,B:0}; rightRow=null; revealed.clear(); shownKey=''; sel=-1;
  buildTF(); renderStats(); dnew(false); document.getElementById('qnew').click(); render();
}
document.querySelectorAll('.word-mode').forEach(button=>button.addEventListener('click',()=>setGameMode(button.dataset.mode)));
function isTyping(){ const a=document.activeElement; return !!a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName) && a.type!=='checkbox'; }
function layout(){
  if (isTyping() && document.body.classList.length && (document.body.classList.contains('fit')||document.body.classList.contains('small'))) { keepVisible(); return; }   // Tastatur offen: Layout nicht umbauen
  const W = window.innerWidth, H = window.innerHeight, body = document.body;
  const hh = document.querySelector('header').offsetHeight;
  body.style.setProperty('--hh', hh+'px');
  body.classList.remove('fit','land','port','small');
  let size;
  if (W < 640 || H < 560){
    body.classList.add('small'); size = Math.min(W - 24, 440, Math.max(280, H * 0.48));
  } else if (W/H > 1.05){
    body.classList.add('fit','land');
    const side = Math.max(330, Math.min(440, W*0.36));
    size = Math.min(H - hh - 24, W - side - 48);
    body.style.setProperty('--side', side+'px');
  } else {
    body.classList.add('fit','port');
    const ph = Math.max(300, Math.min(390, H*0.34));
    size = Math.min(W - 28, H - hh - ph - 30);
    body.style.setProperty('--ph', ph+'px');
    body.style.setProperty('--ww', Math.min(W-28, 900)+'px');
  }
  if (!body.classList.contains('small')) body.classList.remove('wheel-collapsed');
  updateWheelToggle();
  wheel.style.width = size+'px';
  wheel.style.setProperty('--u', size/100+'px');
  if (typeof fitWin==='function') fitWin();
}
const wheelToggle = document.getElementById('wheelToggle');
function updateWheelToggle(){
  const expanded = !document.body.classList.contains('wheel-collapsed');
  wheelToggle.setAttribute('aria-expanded', String(expanded));
  wheelToggle.textContent = expanded ? 'Scheibe einklappen' : 'Scheibe anzeigen';
}
wheelToggle.addEventListener('click', ()=>{
  document.body.classList.toggle('wheel-collapsed');
  updateWheelToggle();
  (document.body.classList.contains('wheel-collapsed') ? document.getElementById('panel') : wheel)
    .scrollIntoView({behavior:'smooth', block:'start'});
});
window.addEventListener('resize', layout);
// ---------- Tastatur: Eingabefeld immer sichtbar halten ----------
let kbShift = 0;
function keepVisible(){
  const main = document.getElementById('main'), el = document.activeElement;
  if (!isTyping()){ if (kbShift){ kbShift = 0; main.style.transform = ''; } document.body.classList.remove('typing'); return; }
  document.body.classList.add('typing');
  const vv = window.visualViewport, top = vv ? vv.offsetTop : 0, bottom = vv ? vv.offsetTop + vv.height : window.innerHeight;
  const r = el.getBoundingClientRect(), margin = 14;
  // Ziel: Feld (plus etwas Platz für Hinweise darunter) sitzt oberhalb der Tastatur
  const want = Math.min(r.height + 90, (bottom - top) * 0.45);
  if (document.body.classList.contains('small')){
    if (r.bottom + want > bottom - margin || r.top < top + 50) window.scrollBy({top: r.top - top - 70, behavior:'smooth'});
  } else {
    const over = (r.bottom + want) - (bottom - margin);
    if (over > 0 || kbShift){
      kbShift = Math.max(0, kbShift + Math.max(over, -kbShift));
      kbShift = Math.min(kbShift, Math.max(0, r.top + kbShift - top - 60));   // nicht über den oberen Rand hinaus
      main.style.transition = 'transform .25s ease-out';
      main.style.transform = kbShift ? `translateY(${-kbShift}px)` : '';
    }
  }
}
document.addEventListener('focusin', ()=>{ setTimeout(keepVisible, 60); setTimeout(keepVisible, 420); });
document.addEventListener('focusout', ()=>setTimeout(()=>{ if (!isTyping()){ keepVisible(); layout(); } }, 120));
if (window.visualViewport){ visualViewport.addEventListener('resize', ()=>setTimeout(keepVisible, 30)); visualViewport.addEventListener('scroll', ()=>setTimeout(keepVisible, 30)); }
window.addEventListener('orientationchange', ()=>setTimeout(layout,150));
layout();

// ---------- Vorlesen (klassische Aussprache: c = k, v = w, lange Vokale gedehnt) ----------
// Lateinische Stimmen gibt es kaum; eine deutsche Stimme liest eine Lautschrift-Umschreibung.
function respell(w){
  let s = w.toLowerCase();
  // 1. Hiat: zwei Vokale = zwei Silben, ohne eingeschobenen Laut (monu-ī, fu-ī, audi-ē-bam, i-ī, e-unt)
  s = s.replace(/u([eēiī])/g,'u-$1').replace(/i([eēiī])/g,'i-$1').replace(/eu/g,'e-u');
  // 2. Konsonanten: c immer k, v immer w
  s = s.replace(/c/g,'k').replace(/v/g,'w');
  // 3. kurzes e voll als offenes e (ä) – sonst verschluckt die deutsche Stimme es zum „ə“ (es, est, estis, monent, eram …)
  s = s.replace(/e/g,'ä');
  // 4. lange Vokale gedehnt
  s = s.replace(/ā/g,'ah').replace(/ē/g,'eh').replace(/ī/g,'ih').replace(/ō/g,'oh').replace(/ū/g,'uh');
  return s;
}
const FEM = /(anna|petra|helena|hedda|katja|marlene|vicki|sandy|shelley|grandma|amala|seraphina|elke|gisela|ingrid|louisa|maja|klara|leni|tanja|sabine|martina|female|weiblich|google deutsch)/i;
const MASC = /(markus|yannick|stefan|conrad|viktor|martin|hans|reed|rocko|grandpa|eddy|jonas|killian|florian|flo\b|ralf|daniel|klaus|bernd|thomas|dieter|male|männlich)/i;
let vgender = 'off';   // Standard: Vorlesen aus
try { vgender = localStorage.getItem('drehscheibe-vorlesen') || 'off'; } catch(e){}
let vstyle = 'heiter';
try { vstyle = localStorage.getItem('drehscheibe-klang') || 'heiter'; } catch(e){}
// jung und freundlich klingende Stimmen (je nach Gerät vorhanden)
const YOUNG = /(gisela|amala|seraphina|sandy|shelley|florian|\bflo\b|eddy|killian|jonas|vicki|leni|maja)/i;
let vname = '';
try { vname = localStorage.getItem('drehscheibe-stimmname') || ''; } catch(e){}
const deVoices = ()=> (window.speechSynthesis ? speechSynthesis.getVoices() : []).filter(v=>/^de/i.test(v.lang));
// bevorzugt hochwertige, weich klingende Stimmen (Premium/Erweitert/Natural)
function quality(v){ return (vstyle==='heiter' && YOUNG.test(v.name) ? 4 : 0) + (/premium/i.test(v.name)?3:0) + (/enhanced|erweitert|natural|neural|online/i.test(v.name)?2:0) + (/google/i.test(v.name)?1:0) + (v.localService?0:0.5); }
function pickVoice(){
  const vs = deVoices();
  if (vname){ const chosen = vs.find(v=>v.name===vname); if (chosen) return {voice:chosen, exact:true}; }
  const g = vgender==='off' ? 'f' : vgender;
  const want = g==='m' ? MASC : FEM, other = g==='m' ? FEM : MASC;
  const cand = vs.filter(v=>want.test(v.name) && !other.test(v.name)).sort((a,b)=>quality(b)-quality(a));
  const best = cand[0] || vs.slice().sort((a,b)=>quality(b)-quality(a))[0] || null;
  return {voice: best, exact: !!cand[0]};
}
function fillVoiceList(){
  const sel = document.getElementById('vlist'); if (!sel) return;
  const vs = deVoices().sort((a,b)=>quality(b)-quality(a));
  sel.innerHTML = '<option value="">automatisch (beste passende)</option>' +
    vs.map(v=>`<option value="${v.name}"${v.name===vname?' selected':''}>${v.name}${quality(v)>=2?' ★':''}</option>`).join('');
  document.getElementById('vcount').textContent = vs.length ? `${vs.length} deutsche Stimme(n) auf diesem Gerät` : 'Keine deutsche Stimme gefunden';
}
function speak(words){
  if (vgender==='off') return;   // nur sprechen, wenn Vorlesen eingeschaltet ist
  if (!('speechSynthesis' in window)){ toastMsg('Vorlesen wird von diesem Browser nicht unterstützt.'); return; }
  speechSynthesis.cancel();
  const {voice, exact} = pickVoice();
  words.forEach((w,i)=>{
    const u = new SpeechSynthesisUtterance(respell(w) + '.');   // Punkt: Endkonsonanten (-s, -t, -nt) werden nicht abgeschnitten
    u.lang = 'de-DE'; if (voice) u.voice = voice;
    if (vstyle==='heiter'){            // jünger und freundlicher: etwas höher, lebendiger
      u.rate = 0.78; u.volume = 1;
      u.pitch = exact ? (vgender==='m' ? 1.12 : 1.22) : (vgender==='m' ? 0.95 : 1.3);
    } else {                           // ruhig: langsamer, etwas tiefer
      u.rate = 0.7; u.volume = 0.9;
      u.pitch = exact ? 0.97 : (vgender==='m' ? 0.8 : 1.12);
    }
    speechSynthesis.speak(u);
  });
}
window.speak = speak;
function toastMsg(m){ const tst=document.getElementById('toast'); tst.textContent=m; tst.classList.remove('show'); void tst.offsetWidth; tst.classList.add('show'); }
function setVoiceButtons(){ document.querySelectorAll('.vbtn').forEach(b=>b.classList.toggle('on', b.dataset.g===vgender)); document.body.classList.toggle('mute', vgender==='off'); }
document.querySelectorAll('.vbtn').forEach(b=>b.onclick=()=>{
  vgender = b.dataset.g; try{ localStorage.setItem('drehscheibe-vorlesen', vgender); }catch(e){}
  setVoiceButtons();
  const {v,t} = state(), cur = revealed.has(sel) && D.forms.find(f=>f[1]===v && f[2]===t && f[3]===sel);
  if (cur) speak([cur[0]]);
});
if (window.speechSynthesis){ speechSynthesis.onvoiceschanged = fillVoiceList; setTimeout(fillVoiceList, 300); }
function setKlang(){ document.querySelectorAll('.kbtn').forEach(b=>b.classList.toggle('on', b.dataset.k===vstyle)); }
document.querySelectorAll('.kbtn').forEach(b=>b.onclick=()=>{
  vstyle = b.dataset.k; try{ localStorage.setItem('drehscheibe-klang', vstyle); }catch(e){}
  setKlang(); fillVoiceList();
  const {v,t} = state(), cur = revealed.has(sel) && D.forms.find(f=>f[1]===v && f[2]===t && f[3]===sel);
  if (cur) speak([cur[0]]);
});
setKlang();
document.getElementById('vlist').addEventListener('change', e=>{
  vname = e.target.value; try{ localStorage.setItem('drehscheibe-stimmname', vname); }catch(err){}
});
document.getElementById('vtest').addEventListener('click', ()=>{
  const {v,t} = state(), cur = revealed.has(sel) && D.forms.find(f=>f[1]===v && f[2]===t && f[3]===sel);
  if (vgender==='off'){ toastMsg('Erst oben bei „Vorlesen“ weiblich oder männlich wählen.'); return; }
  if (!cur){ toastMsg('Erst eine Form im Fenster aufdecken – die wird dann vorgelesen.'); return; }
  speak([cur[0]]);
});
setVoiceButtons();
document.getElementById('wspeak').addEventListener('click', ()=>{
  const {v,t} = state();
  const ws = D.forms.filter(f=>f[1]===v && f[2]===t && revealed.has(f[3])).map(f=>f[0]);
  if (!ws.length){ toastMsg('Erst Formen aufdecken – verdeckte Formen werden nicht vorgelesen.'); return; }
  speak(ws);
});

// ---------- Vollbild ----------
(function(){
  const b = document.getElementById('fs'), de = document.documentElement;
  const req = de.requestFullscreen || de.webkitRequestFullscreen, ex = document.exitFullscreen || document.webkitExitFullscreen;
  if (!req){ b.style.display='none'; return; }
  b.onclick = ()=>{
    try{
      if (document.fullscreenElement || document.webkitFullscreenElement){ ex.call(document); }
      else { const p = req.call(de); if (p && p.catch) p.catch(()=>{ b.style.display='none'; toastMsg('Vollbild ist hier nicht erlaubt – Seite im Browser öffnen.'); }); }
    }catch(e){ b.style.display='none'; }
  };
  const upd = ()=>{ b.textContent = (document.fullscreenElement||document.webkitFullscreenElement) ? '✕' : '⛶'; setTimeout(layout,120); };
  document.addEventListener('fullscreenchange', upd); document.addEventListener('webkitfullscreenchange', upd);
})();
if (document.fonts && document.fonts.ready) document.fonts.ready.then(()=>fitWin());

// ---------- Einführung beim ersten Öffnen ----------
const INTRO_KEY = 'drehscheibe-intro-' + document.title;
function showIntro(){
  const box = document.getElementById('intro'); box.hidden = false;
  const c = box.querySelector('.icard'); box.querySelector('.iwrap').style.setProperty('--ih', c.offsetHeight + 'px');
  document.getElementById('igo').focus({preventScroll:true});
}
function closeIntro(){
  document.getElementById('intro').hidden = true;
  try{ localStorage.setItem(INTRO_KEY, '1'); }catch(e){}
  if (typeof playCoins==='function') playCoins(1, true);           // kleines „Tadaa“
  // kurze Vorführung: die Ringe drehen sich einmal ein Stück und zurück
  const a0 = rot.A, b0 = rot.B;
  wheel.classList.add('snap'); rot.A = a0 - 60; rot.B = b0 + VS; render();
  setTimeout(()=>{ rot.A = a0; rot.B = b0; render(); setTimeout(()=>wheel.classList.remove('snap'), 320); }, 650);
}
document.getElementById('igo').onclick = closeIntro;
document.getElementById('introagain').onclick = showIntro;
const ib = document.getElementById('introBtn'); if (ib) ib.onclick = showIntro;
document.getElementById('intro').addEventListener('click', e=>{ if (e.target.id==='intro') closeIntro(); });
document.addEventListener('keydown', e=>{ if (e.key==='Escape' && !document.getElementById('intro').hidden) closeIntro(); });
showIntro();   // erscheint bei jedem Öffnen

// ================= Eigene Verben =================
// Bildet aus den Stammformen alle Formen (regelmäßige Verben der a-, e-, i-, kons. und gemischten Konjugation)
const PRON_DE=['ich','du','er (sie, es)','wir','ihr','sie'];
const WERD=['werde','wirst','wird','werden','werdet','werden'], HAB=['habe','hast','hat','haben','habt','haben'],
      HATT=['hatte','hattest','hatte','hatten','hattet','hatten'], BIN=['bin','bist','ist','sind','seid','sind'], WAR=['war','warst','war','waren','wart','waren'];
const S=(x)=>[x,'S'], E=(x)=>[x,'E'], T=(x)=>[x,'T'], B=(x)=>[x,'B'], HY=['-','H'];
const J=(...p)=>{ const o=[]; p.forEach((x,i)=>{ if(i) o.push(HY); o.push(x); }); return o; };
function latin(inf, pr, pf, nm){
  inf=inf.trim().toLowerCase(); pr=pr.trim().toLowerCase(); pf=pf.trim().toLowerCase();
  const plain=s=>s.normalize('NFD').replace(/[̀-ͯ]/g,'');
  const pI=plain(inf), pP=plain(pr), pF=plain(pf);
  if (!/o$/.test(pP)) throw 'Die 1. Sg. Präsens muss auf -ō enden (z. B. laudō).';
  if (!/i$/.test(pF)) throw 'Die 1. Sg. Perfekt muss auf -ī enden (z. B. laudāvī).';
  const root = pr.slice(0,-1);                  // Präsens ohne -ō
  const pst = pf.slice(0,-1);                   // Perfektstamm
  let PS = [S(pst)], pk = '';                     // Perfektstamm-Segmente (mit Perfektzeichen v/u, falls erkennbar)
  let k, F=[];
  const PE=['m','s','t','mus','tis','nt'], PO=['ō','s','t','mus','tis','nt'];
  if (/are$/.test(pI)){ k='a';
    const st=root+'ā', sh=root+'a';
    F[0]=[J(S(root),E('ō')),J(S(st),E('s')),J(S(sh),E('t')),J(S(st),E('mus')),J(S(st),E('tis')),J(S(sh),E('nt'))];
    F[1]=PE.map((e,i)=>J(S(st),T([0,2,5].includes(i)?'ba':'bā'),E(e)));
    F[2]=PO.map((e,i)=>J(S(st),T(['b','bi','bi','bi','bi','bu'][i]),E(e)));
  } else if (/ere$/.test(pI) && /eo$/.test(pP)){ k='e';
    const base=root.slice(0,-1), st=base+'ē', sh=root;   // mone-/monē-
    F[0]=[J(S(sh),E('ō')),J(S(st),E('s')),J(S(sh),E('t')),J(S(st),E('mus')),J(S(st),E('tis')),J(S(sh),E('nt'))];
    F[1]=PE.map((e,i)=>J(S(st),T([0,2,5].includes(i)?'ba':'bā'),E(e)));
    F[2]=PO.map((e,i)=>J(S(st),T(['b','bi','bi','bi','bi','bu'][i]),E(e)));
  } else if (/ire$/.test(pI) && /io$/.test(pP)){ k='i';
    const base=root.slice(0,-1), st=base+'ī', sh=root;   // audi-/audī-
    F[0]=[J(S(sh),E('ō')),J(S(st),E('s')),J(S(sh),E('t')),J(S(st),E('mus')),J(S(st),E('tis')),J(S(sh),B('u'),E('nt'))];
    F[1]=PE.map((e,i)=>J(S(sh),T([0,2,5].includes(i)?'ēba':'ēbā'),E(e)));
    F[2]=PE.map((e,i)=>J(S(sh),T(['a','ē','e','ē','ē','e'][i]),E(e)));
  } else if (/ere$/.test(pI) && /io$/.test(pP)){ k='m';
    const sh=root;                                         // capi-
    F[0]=[J(S(sh),E('ō')),J(S(sh),E('s')),J(S(sh),E('t')),J(S(sh),E('mus')),J(S(sh),E('tis')),J(S(sh),B('u'),E('nt'))];
    F[1]=PE.map((e,i)=>J(S(sh),T([0,2,5].includes(i)?'ēba':'ēbā'),E(e)));
    F[2]=PE.map((e,i)=>J(S(sh),T(['a','ē','e','ē','ē','e'][i]),E(e)));
  } else if (/ere$/.test(pI) && /[^ei]o$/.test(pP)){ k='k';
    const sh=root;                                         // vinc-
    F[0]=[J(S(sh),E('ō')),J(S(sh),B('i'),E('s')),J(S(sh),B('i'),E('t')),J(S(sh),B('i'),E('mus')),J(S(sh),B('i'),E('tis')),J(S(sh),B('u'),E('nt'))];
    F[1]=PE.map((e,i)=>J(S(sh),T([0,2,5].includes(i)?'ēba':'ēbā'),E(e)));
    F[2]=PE.map((e,i)=>J(S(sh),T(['a','ē','e','ē','ē','e'][i]),E(e)));
  } else throw 'Konjugation nicht erkannt. Infinitiv auf -āre, -ēre, -īre oder -ere und passende 1. Sg. (laudō, moneō, audiō, vincō, capiō).';
  // Perfektbildung erkennen: v-, u-, s-Perfekt, Reduplikations-, Dehnungs-, Stammperfekt
  const pl = s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'');
  const r0 = pl(root), base = (k==='a'||k==='k') ? r0 : r0.slice(0,-1), pp = pl(pst);
  if (/^([^aeiou])[aeiou]\1/.test(pp) && !r0.startsWith(pp.slice(0,3))){ PS=[['' + pst.slice(0,2),'P'],HY,S(pst.slice(2))]; pk='Reduplikationsperfekt'; }
  else if (/v$/.test(pp)){ PS=[S(pst.slice(0,-1)),HY,['v','P']]; pk='v-Perfekt'; }
  else if (/u$/.test(pp)){ PS=[S(pst.slice(0,-1)),HY,['u','P']]; pk='u-Perfekt'; }
  else if (/x$/.test(pp) || (/s$/.test(pp) && !/s$/.test(r0))){ PS=[S(pst.slice(0,-1)),HY,[pst.slice(-1),'P']]; pk='s-Perfekt'; }
  else if (nm && (pp===r0 || pp===base)) pk='Stamm- oder Dehnungsperfekt (Längen fehlen)';
  else if ((pp===r0 || pp===base) && (pst===root || pst===root.replace(/i$/,''))) pk='Stammperfekt';
  else if (/[āēīōū]/.test(pst)) pk='Dehnungsperfekt';
  else pk='Perfekt mit eigenem Stamm';
  const JP=(...rest)=>{ const o=[...PS]; rest.forEach(x=>{ o.push(HY); o.push(x); }); return o; };
  F[3]=['ī','istī','it','imus','istis','ērunt'].map(e=>JP(E(e)));
  F[4]=PE.map((e,i)=>JP(T([0,2,5].includes(i)?'era':'erā'),E(e)));
  F[5]=PO.map((e,i)=>JP(T(i===0?'er':'eri'),E(e)));
  const KONJ={a:'a-Konjugation',e:'e-Konjugation',i:'i-Konjugation',k:'konsonantische Konjugation',m:'kons. Konjugation mit i-Erweiterung'};
  return {forms:F, konj:KONJ[k], fut:(k==='a'||k==='e')?'ghost':'camel', pft:pk};
}
function german(inf, er, pt, p2, aux, o={}){
  inf=inf.trim(); er=er.trim(); pt=pt.trim(); p2=p2.trim();
  const sep = o.sep||''; if (sep && inf.startsWith(sep)) inf = inf.slice(sep.length);   // trennbares Präfix: „kommt … an“
  if (!inf||!er||!pt||!p2) throw 'Bitte alle deutschen Felder ausfüllen.';
  let stem = inf.replace(/e?n$/,''), ich = stem+'e', ihr = /([dt]|[^lrhmnaeiouäöü][mn])$/.test(stem) ? stem+'et' : stem+'t';
  if (/[^aeiouäöü](eln|ern)$/.test(inf)){ stem = inf.slice(0,-1); ihr = stem+'t';           // sammeln, wandern
    ich = /eln$/.test(inf) ? inf.slice(0,-3)+'le' : inf.slice(0,-1)+'e'; }
  const du = /(s|ß|z|x)t$/.test(er) ? er : er.replace(/t$/,'st');
  const pr=[o.ich||ich, o.du||du, er, inf, ihr, inf];
  if (o.all) o.all.forEach((x,i)=>pr[i]=x);
  let ptF;
  if (/te$/.test(pt)) ptF=[pt, pt+'st', pt, pt+'n', pt+'t', pt+'n'];
  else if (/e$/.test(pt)) ptF=[pt, pt+'st', pt, pt+'n', pt+'t', pt+'n'];
  else { const sz=/(s|ß|z|x)$/.test(pt), td=/[td]$/.test(pt); ptF=[pt, pt+(sz||td?'est':'st'), pt, pt+'en', pt+(td?'et':'t'), pt+'en']; }
  const A1 = aux==='sein'?BIN:HAB, A2 = aux==='sein'?WAR:HATT;
  const S2 = sep ? ' '+sep : '', IN = sep + inf, RF = ['mich','dich','sich','uns','euch','sich'];
  return t=>p=>{ const P=PRON_DE[p], r = o.refl ? ' '+RF[p] : '';
    return [`${P} ${pr[p]}${r}${S2}`, `${P} ${ptF[p]}${r}${S2}`, `${P} ${WERD[p]}${r} ${IN}`, `${P} ${A1[p]}${r} ${p2}`, `${P} ${A2[p]}${r} ${p2}`, `${P} ${WERD[p]}${r} ${p2} ${aux}`][t]; };
}

// ---- Deutsche Formen automatisch (mit Tabelle unregelmäßiger Verben) ----
// Eintrag: [er-Form Präsens, ich-Form Präteritum, Partizip II, Hilfsverb]
const DE_IRR = {
 befehlen:['befiehlt','befahl','befohlen'], beginnen:['beginnt','begann','begonnen'], beißen:['beißt','biss','gebissen'],
 bergen:['birgt','barg','geborgen'], biegen:['biegt','bog','gebogen'], bieten:['bietet','bot','geboten'], binden:['bindet','band','gebunden'],
 bitten:['bittet','bat','gebeten'], blasen:['bläst','blies','geblasen'], bleiben:['bleibt','blieb','geblieben','sein'], braten:['brät','briet','gebraten'],
 brechen:['bricht','brach','gebrochen'], brennen:['brennt','brannte','gebrannt'], bringen:['bringt','brachte','gebracht'], denken:['denkt','dachte','gedacht'],
 dringen:['dringt','drang','gedrungen','sein'], empfehlen:['empfiehlt','empfahl','empfohlen'], essen:['isst','aß','gegessen'], fahren:['fährt','fuhr','gefahren','sein'],
 fallen:['fällt','fiel','gefallen','sein'], fangen:['fängt','fing','gefangen'], finden:['findet','fand','gefunden'], fliegen:['fliegt','flog','geflogen','sein'],
 fliehen:['flieht','floh','geflohen','sein'], fließen:['fließt','floss','geflossen','sein'], fressen:['frisst','fraß','gefressen'], frieren:['friert','fror','gefroren'],
 geben:['gibt','gab','gegeben'], gehen:['geht','ging','gegangen','sein'], gelingen:['gelingt','gelang','gelungen','sein'], gelten:['gilt','galt','gegolten'],
 genießen:['genießt','genoss','genossen'], geschehen:['geschieht','geschah','geschehen','sein'], gewinnen:['gewinnt','gewann','gewonnen'], gießen:['gießt','goss','gegossen'],
 gleichen:['gleicht','glich','geglichen'], graben:['gräbt','grub','gegraben'], greifen:['greift','griff','gegriffen'], halten:['hält','hielt','gehalten'],
 heben:['hebt','hob','gehoben'], heißen:['heißt','hieß','geheißen'], helfen:['hilft','half','geholfen'], kennen:['kennt','kannte','gekannt'],
 klingen:['klingt','klang','geklungen'], kommen:['kommt','kam','gekommen','sein'], kriechen:['kriecht','kroch','gekrochen','sein'], laden:['lädt','lud','geladen'],
 lassen:['lässt','ließ','gelassen'], laufen:['läuft','lief','gelaufen','sein'], leiden:['leidet','litt','gelitten'], leihen:['leiht','lieh','geliehen'],
 lesen:['liest','las','gelesen'], liegen:['liegt','lag','gelegen'], lügen:['lügt','log','gelogen'], meiden:['meidet','mied','gemieden'], messen:['misst','maß','gemessen'],
 nehmen:['nimmt','nahm','genommen'], nennen:['nennt','nannte','genannt'], preisen:['preist','pries','gepriesen'], raten:['rät','riet','geraten'],
 reißen:['reißt','riss','gerissen'], reiten:['reitet','ritt','geritten','sein'], rennen:['rennt','rannte','gerannt','sein'], riechen:['riecht','roch','gerochen'],
 rufen:['ruft','rief','gerufen'], schaffen:['schafft','schuf','geschaffen'], scheiden:['scheidet','schied','geschieden'], scheinen:['scheint','schien','geschienen'],
 schieben:['schiebt','schob','geschoben'], schießen:['schießt','schoss','geschossen'], schlafen:['schläft','schlief','geschlafen'], schlagen:['schlägt','schlug','geschlagen'],
 schleichen:['schleicht','schlich','geschlichen','sein'], schließen:['schließt','schloss','geschlossen'], schneiden:['schneidet','schnitt','geschnitten'],
 schreiben:['schreibt','schrieb','geschrieben'], schreien:['schreit','schrie','geschrien'], schreiten:['schreitet','schritt','geschritten','sein'],
 schweigen:['schweigt','schwieg','geschwiegen'], schwimmen:['schwimmt','schwamm','geschwommen','sein'], schwören:['schwört','schwor','geschworen'],
 sehen:['sieht','sah','gesehen'], senden:['sendet','sandte','gesandt'], singen:['singt','sang','gesungen'], sinken:['sinkt','sank','gesunken','sein'],
 sitzen:['sitzt','saß','gesessen'], sprechen:['spricht','sprach','gesprochen'], springen:['springt','sprang','gesprungen','sein'], stechen:['sticht','stach','gestochen'],
 stehen:['steht','stand','gestanden'], stehlen:['stiehlt','stahl','gestohlen'], steigen:['steigt','stieg','gestiegen','sein'], sterben:['stirbt','starb','gestorben','sein'],
 stoßen:['stößt','stieß','gestoßen'], streiten:['streitet','stritt','gestritten'], tragen:['trägt','trug','getragen'], treffen:['trifft','traf','getroffen'],
 treiben:['treibt','trieb','getrieben'], treten:['tritt','trat','getreten'], trinken:['trinkt','trank','getrunken'], tun:['tut','tat','getan'],
 vergessen:['vergisst','vergaß','vergessen'], verlieren:['verliert','verlor','verloren'], wachsen:['wächst','wuchs','gewachsen','sein'], waschen:['wäscht','wusch','gewaschen'],
 weichen:['weicht','wich','gewichen','sein'], weisen:['weist','wies','gewiesen'], wenden:['wendet','wandte','gewandt'], werben:['wirbt','warb','geworben'],
 werden:['wird','wurde','geworden','sein'], werfen:['wirft','warf','geworfen'], wiegen:['wiegt','wog','gewogen'], ziehen:['zieht','zog','gezogen'],
 zwingen:['zwingt','zwang','gezwungen'], verschwinden:['verschwindet','verschwand','verschwunden','sein'], erscheinen:['erscheint','erschien','erschienen','sein'], verstehen:['versteht','verstand','verstanden'], besitzen:['besitzt','besaß','besessen'], haben:['hat','hatte','gehabt'], sein:['ist','war','gewesen','sein'],
 können:['kann','konnte','gekonnt'], dürfen:['darf','durfte','gedurft'], mögen:['mag','mochte','gemocht'], müssen:['muss','musste','gemusst'],
 sollen:['soll','sollte','gesollt'], wollen:['will','wollte','gewollt'], wissen:['weiß','wusste','gewusst']
};
// besondere Präsensformen (ich, du)
const DE_PRES = { können:['kann','kannst'], dürfen:['darf','darfst'], mögen:['mag','magst'], müssen:['muss','musst'], sollen:['soll','sollst'],
  wollen:['will','willst'], wissen:['weiß','weißt'], werden:[null,'wirst'], sein:['bin','bist'] };
const DE_WEAK_SEIN = /^(reisen|wandern|eilen|landen|segeln|folgen|begegnen|klettern|reisen|stolpern|joggen|rudern)$/;
const DE_INSEP_EXC = /^(ernten|erben|beten|beben|bellen|bessern|betteln|geigen|gerben|enden|erden|bergen|beugen|beuteln|meißeln)$/;
const DE_AUX_SEIN = /^(aufstehen|entstehen|einschlafen|aufwachen|erwachen|verschwinden|entkommen|erscheinen|zerfallen|verfallen|entfliehen|ertrinken|vergehen|entgehen|aufwachsen|umziehen|zurückkehren|heimkehren|einkehren|eintreten|zurückkehren)$/;
const SEP = ['zurück','heraus','herein','hinaus','hinein','vorbei','entgegen','weiter','zusammen','fort','weg','los','nach','mit','vor','zu','an','auf','aus','ab','bei','ein','her','hin','dar','fest','teil','statt'];
const INSEP = ['miss','emp','ent','ver','zer','be','er','ge'];
function autoGerman(inf){
  inf = inf.trim().toLowerCase();
  if (!inf) throw 'Bitte die deutsche Bedeutung angeben (z. B. „– schicken“).';
  let refl = false; if (/^sich\s+\S+$/.test(inf)){ refl = true; inf = inf.replace(/^sich\s+/,''); }
  if (/\s/.test(inf)) throw 'Bitte als Bedeutung ein einzelnes Verb angeben (z. B. „schicken“ oder „sich freuen“).';
  let pre = '', sep = '', base = inf;
  if (!DE_IRR[inf]){
    for (const p of SEP){ const r = inf.slice(p.length); if (inf.startsWith(p) && r.length>=3 && (DE_IRR[r] || /[^aeiou]en$|[^aeiou](el|er)n$/.test(r))){ sep = p; base = r; break; } }
    if (!sep) for (const p of INSEP){ const r = inf.slice(p.length); if (inf.startsWith(p) && DE_IRR[r]){ pre = p; base = r; break; } }
    if (!sep && !pre && !DE_INSEP_EXC.test(inf)) for (const p of INSEP){ const r = inf.slice(p.length); if (inf.startsWith(p) && r.length>=4){ pre = p; base = r; break; } }
  }
  let er, pt, p2, aux = 'haben', ich = null, du = null, all = null;
  const irr = DE_IRR[base];
  if (base === 'sein') all = ['bin','bist','ist','sind','seid','sind'];
  if (irr){
    [er, pt, p2] = irr; aux = irr[3] || 'haben';
    if (DE_PRES[base]){ [ich, du] = DE_PRES[base]; }
    if (pre){ p2 = pre + p2.replace(/^ge/,''); er = pre + er; pt = pre + pt; aux = 'haben'; }
  } else {
    const stem = (pre+base).replace(/e?n$/,'');
    const et = /([dt]|[^lrhmnaeiouäöü][mn])$/.test(stem);
    er = stem + (et?'et':'t'); pt = stem + (et?'ete':'te');
    const noGe = /ieren$/.test(base) || pre;
    p2 = (noGe?'':'ge') + stem + (et?'et':'t');
    if (DE_WEAK_SEIN.test(base)) aux = 'sein';
    if (pre) aux = 'haben';
  }
  if (sep) p2 = sep + p2;
  if (DE_AUX_SEIN.test(inf)) aux = 'sein';
  return {dInf:inf, dEr:er, dPt:pt, dP2:p2, aux, sep, ich, du, all, refl};
}
// ---- eine Zeile zerlegen: „mittere, mittō, mīsī(, missum) – schicken“ ----
function parseOne(line){
  let s = line.replace(/[—–]/g,' – ').replace(/\s+/g,' ').trim();
  let lat, de = '';
  const m = s.match(/^(.*?)(?:\s[–-]\s|\s*[:=]\s*)(.*)$/);
  if (m){ lat = m[1]; de = m[2]; } else lat = s;
  let tok = lat.split(/[,;\s]+/).map(x=>x.replace(/[:.]+$/,'')).filter(Boolean);
  if (!m){ // ohne Trennzeichen: nach den lateinischen Formen folgt das Deutsche
    let n = 3; if (tok[3] && /(um|us)$/.test(tok[3].normalize('NFD').replace(/[̀-ͯ]/g,''))) n = 4;
    de = tok.slice(n).join(' '); tok = tok.slice(0,n);
  }
  if (tok.length < 3) throw 'Bitte Infinitiv, 1. Sg. Präsens und 1. Sg. Perfekt angeben – z. B. „mittere, mittō, mīsī – schicken“.';
  let [inf, pr, pf] = tok;
  // fehlende Längen am Wortende ergänzen
  const P = x=>x.normalize('NFD').replace(/[̀-ͯ]/g,'');
  if (/o$/.test(pr)) pr = pr.slice(0,-1)+'ō';
  if (/i$/.test(pf)) pf = pf.slice(0,-1)+'ī';
  if (/are$/.test(inf)) inf = inf.replace(/are$/,'āre');
  else if (/ire$/.test(inf) && /io$/.test(P(pr))) inf = inf.replace(/ire$/,'īre');
  else if (/ere$/.test(inf) && /eo$/.test(P(pr))) inf = inf.replace(/ere$/,'ēre');
  if (/āre$/.test(inf)) pf = pf.replace(/avī$/,'āvī');
  if (/īre$/.test(inf)) pf = pf.replace(/ivī$/,'īvī');
  if (/ēre$/.test(inf)) pf = pf.replace(/evī$/,'ēvī');
  return {inf, pr, pf, de: de.replace(/^\(|\)$/g,'').trim(), nm: !/[āēīōū]/.test(line)};
}
function buildVerb(e){
  const L = latin(e.inf, e.pr, e.pf, e.nm), G = german(e.dInf, e.dEr, e.dPt, e.dP2, e.aux, {sep:e.sep, ich:e.ich, du:e.du, all:e.all, refl:e.refl});
  return {e, L, G};
}
function applyVerbs(list){
  const forms=[], verbs=[], konj=[], stamm=[], futmn=[], pft=[];
  list.forEach((e,vi)=>{
    const {L,G}=buildVerb(e);
    verbs.push(`${e.inf.trim()} (${e.dInf.trim()})`); konj.push(L.konj); futmn.push(L.fut); pft.push(L.pft);
    stamm.push(`${e.inf.trim()}, ${e.pr.trim()}, ${e.pf.trim()}`);
    for (let t=0;t<6;t++) for (let p=0;p<6;p++){
      const segs=L.forms[t][p], w=segs.filter(s=>s[1]!=='H').map(s=>s[0]).join('');
      forms.push([w,vi,t,p,segs,G(t)(p)]);
    }
  });
  Object.assign(D,{verbs,konj,stamm,futmn,pft,forms});
}

if (D.custom){
  const KEY='drehscheibe-meineverben', MAXV=8;
  { const li=document.createElement('li'); li.innerHTML='<span class="ico">✚</span><div><b>Eigene Verben</b><br>Im Reiter „Meine Verben“ trägst du Stammformen und die deutsche Bedeutung ein – die Scheibe bildet alle Formen. Bitte die Vorschau prüfen. Mit „Teilen“ bekommt die ganze Klasse dieselbe Liste.</div>';
    document.querySelector('.isteps').prepend(li); }
  const DEFAULT=[
    {inf:'laudāre',pr:'laudō',pf:'laudāvī',dInf:'loben',dEr:'lobt',dPt:'lobte',dP2:'gelobt',aux:'haben'},
    {inf:'dūcere',pr:'dūcō',pf:'dūxī',dInf:'führen',dEr:'führt',dPt:'führte',dP2:'geführt',aux:'haben'}];
  let list = DEFAULT;
  try{ const s = JSON.parse(localStorage.getItem(KEY)||'null'); if (Array.isArray(s) && s.length) list = s; }catch(e){}
  document.getElementById('tab4').hidden = false;
  const $ = id=>document.getElementById(id);
  const msg = (m,ok)=>{ $('nMsg').innerHTML = m ? `<span class="${ok?'ok':'no'}">${m}</span>` : ''; };
  function refresh(){
    try{ applyVerbs(list); }catch(err){ list = DEFAULT; applyVerbs(list); }
    try{ localStorage.setItem(KEY, JSON.stringify(list)); }catch(e){}
    buildRingB(); rot.B = 0; rightRow=null; revealed.clear(); shownKey=''; sel=-1;
    render(); dnew(false); renderList();
    $('shareCode').value = btoa(unescape(encodeURIComponent(JSON.stringify(list))));
  }
  function renderList(){
    $('mylist').innerHTML = `<div class="hint mini">${list.length} von ${MAXV} Verben auf der Scheibe</div>` + list.map((e,i)=>
      `<div class="vrow"><span><b>${e.inf}</b>, ${e.pr}, ${e.pf} – ${e.dInf}<br><small>${D.konj[i]}</small></span>`+
      `<button type="button" class="del" data-i="${i}" title="entfernen">✕ entfernen</button></div>`).join('');
    $('mylist').querySelectorAll('.del').forEach(b=>b.onclick=()=>{
      if (list.length<=1){ msg('Mindestens ein Verb muss auf der Scheibe bleiben.'); return; }
      list = list.filter((_,i)=>i!==+b.dataset.i); refresh();
    });
  }
  let auto = null, lastDe = '';
  function entry(){
    const L = parseOne($('nOne').value);
    if (L.de !== lastDe){ lastDe = L.de; auto = null;
      try{ auto = autoGerman(L.de); $('dEr').value=auto.dEr; $('dPt').value=auto.dPt; $('dP2').value=auto.dP2; $('dAux').value=auto.aux; }
      catch(err){ ['dEr','dPt','dP2'].forEach(id=>$(id).value=''); throw err; } }
    return {inf:L.inf, pr:L.pr, pf:L.pf, dInf:(auto?auto.dInf:L.de.toLowerCase()), dEr:$('dEr').value, dPt:$('dPt').value, dP2:$('dP2').value, aux:$('dAux').value,
            sep:auto?auto.sep:'', ich:auto?auto.ich:null, du:auto?auto.du:null, all:auto?auto.all:null, refl:auto?auto.refl:false, nm:L.nm};
  }
  function preview(){
    if (!$('nOne').value.trim()){ $('nPreview').innerHTML=''; msg(''); return null; }
    let e;
    try{
      e = entry();
      const {L,G} = buildVerb(e);
      const rows = [0,1,2,3,4,5].map(p=>`<tr><th>${D.pers[p]}</th>`+[0,1,2,3,4,5].map(t=>{
        const segs=L.forms[t][p]; return `<td><span class="lat">${seg([null,-1,t,p,segs,'',[],L.fut])}</span><br><small>${G(t)(p)}</small></td>`; }).join('')+'</tr>').join('');
      $('nPreview').innerHTML = `<div class="hint mini"><b>${e.inf}, ${e.pr}, ${e.pf}</b> – ${e.dInf} · ${L.konj} · ${L.pft} – bitte kurz prüfen:${e.nm?'<br>Tipp: Mit Längenstrichen im Stamm (z. B. mīsī, vēnī) werden die Formen genauer.':''}</div><div style="overflow-x:auto"><table><tr><th></th>${D.tenses.map(x=>`<th>${x}</th>`).join('')}</tr>${rows}</table></div>`;
      msg(''); return e;
    }catch(err){ $('nPreview').innerHTML=''; msg(typeof err==='string'?err:'Eingabe prüfen.'); return null; }
  }
  let tmr = null;
  $('nOne').addEventListener('input', ()=>{ clearTimeout(tmr); tmr = setTimeout(preview, 450); });
  ['dEr','dPt','dP2','dAux'].forEach(id=>$(id).addEventListener('input', ()=>{ clearTimeout(tmr); tmr = setTimeout(preview, 450); }));
  $('dAux').addEventListener('change', preview);
  $('nOne').addEventListener('keydown', e=>{ if (e.key==='Enter'){ e.preventDefault(); $('nAdd').click(); } });
  $('nAdd').onclick = ()=>{
    const e = preview(); if (!e) return;
    if (list.length>=MAXV){ msg(`Höchstens ${MAXV} Verben – bitte erst eines entfernen.`); return; }
    if (list.some(x=>x.inf.trim()===e.inf.trim())){ msg('Dieses Verb ist schon auf der Scheibe.'); return; }
    list = list.concat([e]); refresh();
    $('nOne').value=''; lastDe=''; auto=null; ['dEr','dPt','dP2'].forEach(id=>$(id).value=''); $('deBox').open=false;
    $('nPreview').innerHTML=''; msg(`„${e.inf}“ ist jetzt auf der Scheibe.`, true);
    setWheel(list.length-1, 0, -1);
  };
  document.querySelectorAll('.nm').forEach(b=>b.onclick=()=>{
    const el=$('nOne'), s=el.selectionStart??el.value.length, en=el.selectionEnd??s;
    el.value = el.value.slice(0,s)+b.textContent+el.value.slice(en); el.focus(); el.setSelectionRange(s+1,s+1);
    clearTimeout(tmr); tmr=setTimeout(preview,300);
  });
  $('copyCode').onclick = ()=>{ try{ navigator.clipboard.writeText($('shareCode').value).then(()=>toastMsg('Code kopiert'),()=>{ $('shareCode').select(); toastMsg('Code markiert – jetzt kopieren'); }); }catch(e){ $('shareCode').select(); } };
  $('loadCode').onclick = ()=>{
    try{
      const l = JSON.parse(decodeURIComponent(escape(atob($('shareCode').value.trim()))));
      if (!Array.isArray(l) || !l.length) throw 0;
      l.slice(0,MAXV).forEach(buildVerb);           // prüft jede Eingabe
      list = l.slice(0,MAXV); refresh(); toastMsg('Verbliste geladen');
    }catch(e){ toastMsg('Der Code ist ungültig.'); }
  };
  refresh();
}
/* ===== Tweaks: Serie, Schwächentraining, Tempus-Filter, Schnelleingabe, Tagesziel ===== */
var GOAL = 10, dmiss = false, tenseOn = new Set();
var ST = {streak:0, best:0, day:'', count:0, goal:false, weak:{}};
try{ Object.assign(ST, JSON.parse(localStorage.getItem('drehscheibe-stats')||'{}')); }catch(e){}
function saveST(){ try{ localStorage.setItem('drehscheibe-stats', JSON.stringify(ST)); }catch(e){} }
function rollDay(){ const d=new Date().toISOString().slice(0,10); if (ST.day!==d){ ST.day=d; ST.count=0; ST.goal=false; saveST(); } }
function wkey(f){ return itemShort(f[1])+'|'+f[2]+'|'+f[3]; }
function pickForm(){                       // Wackelformen kommen öfter dran; Filter nach Kasus oder Tempus
  let pool = D.forms;
  if (tenseOn.size) pool = pool.filter(f=>tenseOn.has(f[2]));
  if (!pool.length) pool = D.forms;
  const w = pool.map(f=>1+3*Math.min(ST.weak[wkey(f)]||0, 3));
  let r = Math.random()*w.reduce((a,b)=>a+b,0);
  for (let i=0;i<pool.length;i++){ r-=w[i]; if (r<=0) return pool[i]; }
  return pool[pool.length-1];
}
function onCorrect(f){
  rollDay(); ST.streak++; ST.best=Math.max(ST.best,ST.streak); ST.count++;
  const k=wkey(f); if (!dmiss && ST.weak[k]){ ST.weak[k]--; if (!ST.weak[k]) delete ST.weak[k]; }
  let b=0; const why=[];
  if (ST.streak%5===0){ b+=2; why.push('Serie '+ST.streak); }
  if (!ST.goal && ST.count>=GOAL){ ST.goal=true; b+=5; why.push('Tagesziel!'); }
  saveST(); renderStats(); lbDirty(); return {b, why:why.join(' · ')};
}
function onWrong(f){
  if (dmiss || !f) return; dmiss=true; ST.streak=0;
  const k=wkey(f); ST.weak[k]=Math.min((ST.weak[k]||0)+1, 3); saveST(); renderStats();
}
function renderStats(){
  const el=document.getElementById('dstats'); if (!el) return; rollDay();
  const pct=Math.min(100, Math.round(ST.count/GOAL*100)), nw=Object.keys(ST.weak).length;
  el.innerHTML = `<span>🔥 Serie <b>${ST.streak}</b> <small>(Rekord ${ST.best})</small></span><span>🎯 Tagesziel <b>${Math.min(ST.count,GOAL)}/${GOAL}</b>${ST.goal?' ✓':''}</span>`+(nw?`<span title="Diese Formen kommen öfter dran">🧩 ${nw} Wackelform${nw===1?'':'en'}</span>`:'')+`<div class="gbar"><i style="width:${pct}%"></i></div>`;
}
function buildTF(){
  const box=document.getElementById('tfilter'); if (!box) return;
  const key=D.isNoun?'drehscheibe-kasus':'drehscheibe-tempora';
  try{ const s=JSON.parse(localStorage.getItem(key)||'null'); if (Array.isArray(s)) tenseOn=new Set(s); else tenseOn.clear(); }catch(e){ tenseOn.clear(); }
  box.innerHTML = `<span class="hint mini" title="nichts gewählt = alle ${D.isNoun?'Kasus':'Zeiten'}">Üben:</span>` + D.tenses.map((n,t)=>`<button type="button" class="chip2" data-t="${t}">${n}</button>`).join('');
  const paint=()=>box.querySelectorAll('.chip2').forEach(b=>b.classList.toggle('on', tenseOn.has(+b.dataset.t)));
  box.onclick=e=>{ const b=e.target.closest('.chip2'); if (!b) return; const t=+b.dataset.t;
    tenseOn.has(t) ? tenseOn.delete(t) : tenseOn.add(t);
    try{ localStorage.setItem(key, JSON.stringify([...tenseOn])); }catch(err){} paint(); };
  paint();
}
{ const MC={a:'ā',e:'ē',i:'ī',o:'ō',u:'ū',A:'Ā',E:'Ē',I:'Ī',O:'Ō',U:'Ū'};   // Schnelleingabe: a- → ā
  din.addEventListener('input', ()=>{ const v=din.value, m=v.replace(/([aeiouAEIOU])[-_]/g,(_,c)=>MC[c]);
    if (m!==v){ const p=Math.max(0, din.selectionStart-(v.length-m.length)); din.value=m; din.setSelectionRange(p,p); } }); }

/* ===== Rangliste (Cloudflare Worker + D1, siehe Ordner cloudflare/) ===== */
var LB_API = '/api/lb';        // gleiche Domain wie die Seite; nur dort erreichbar
var lbCfg = {name:'', board:'', id:''}, lbTimer = null, lbPending = false;
try{ Object.assign(lbCfg, JSON.parse(localStorage.getItem('drehscheibe-rangliste')||'{}')); }catch(e){}
function lbSaveCfg(){ try{ localStorage.setItem('drehscheibe-rangliste', JSON.stringify(lbCfg)); }catch(e){} }
function newLbId(){
  try{ return Array.from(crypto.getRandomValues(new Uint8Array(12)), b=>b.toString(16).padStart(2,'0')).join(''); }
  catch(e){ return String(Math.random()).slice(2)+Date.now(); }
}
if (!lbCfg.id){ lbCfg.id = newLbId(); lbSaveCfg(); }
const lbEl = id=>document.getElementById(id);
function lbStatus(m){ lbEl('lbStatus').textContent = m||''; }
async function lbCall(opts, qs=''){
  const r = await fetch(LB_API+qs, opts);
  if (!r.ok || !/json/.test(r.headers.get('content-type')||'')) throw new Error('lb');
  return r.json();
}
function lbDirty(){ if (!lbCfg.name || !lbCfg.board) return; lbPending=true; if (!lbTimer) lbTimer=setTimeout(lbFlush, 30000); }
async function lbFlush(){
  clearTimeout(lbTimer); lbTimer=null; if (!lbPending || !lbCfg.name || !lbCfg.board) return true; lbPending=false;
  try{ await lbCall({method:'POST', headers:{'Content-Type':'application/json'}, keepalive:true,
        body:JSON.stringify({board:lbCfg.board, id:lbCfg.id, name:lbCfg.name, score:earned})}); return true; }
  catch(e){ lbPending=true; return false; }
}
document.addEventListener('visibilitychange', ()=>{ if (document.hidden) lbFlush(); });
function lbRender(rows, offline){
  const ol=lbEl('lbList'); ol.textContent='';
  rows.forEach((r,i)=>{ const li=document.createElement('li'); if (r.name===lbCfg.name) li.className='me';
    const a=document.createElement('span'), b=document.createElement('b'), c=document.createElement('span');
    a.textContent=['🥇','🥈','🥉'][i]||(i+1)+'.'; b.textContent=r.name; c.textContent=r.score+' Asse';
    li.append(a,b,c); ol.append(li); });
  if (offline) lbStatus('Die gemeinsame Rangliste ist hier nicht erreichbar (nur auf der Cloudflare-Seite). Gezeigt wird nur dein eigener Stand.');
}
async function lbLoad(message=''){
  if (lbEl('lbName') && document.activeElement!==lbEl('lbName')) lbEl('lbName').value = lbCfg.name;
  if (lbEl('lbBoard') && document.activeElement!==lbEl('lbBoard')) lbEl('lbBoard').value = lbCfg.board;
  if (!lbCfg.board){ lbRender([{name:lbCfg.name||'Du', score:earned}]); lbStatus('Spitzname und Klassencode eintragen, dann „Mitmachen“.'); return; }
  lbStatus('lädt …');
  try{ await lbFlush(); const d=await lbCall({}, '?board='+encodeURIComponent(lbCfg.board)); lbRender(d.rows||[]); lbStatus(message || ((d.rows||[]).length?'':'Noch niemand dabei – du bist der Erste!')); }
  catch(e){ lbRender([{name:lbCfg.name||'Du', score:earned}], true); }
}
lbEl('lbRefresh').onclick = lbLoad;
lbEl('lbSave').onclick = async ()=>{
  const n=lbEl('lbName').value.trim(), b=lbEl('lbBoard').value.trim().toLowerCase();
  if (n.length<2){ lbStatus('Der Spitzname braucht mindestens 2 Zeichen.'); return; }
  if (!/^[a-z0-9_-]{1,24}$/.test(b)){ lbStatus('Klassencode: nur Buchstaben, Zahlen, - und _ (ohne Leerzeichen).'); return; }
  const button=lbEl('lbSave');
  button.disabled=true;
  lbStatus('Konto wird gesucht …');
  try{
    const result=await lbCall({}, '?board='+encodeURIComponent(b)+'&name='+encodeURIComponent(n));
    clearTimeout(lbTimer); lbTimer=null; lbPending=false;
    lbCfg.name=n; lbCfg.board=b;
    if (result.account){
      const score=Number(result.account.score);
      if (!Number.isSafeInteger(score) || score<0) throw new Error('Ungültiger Kontostand.');
      lbCfg.name=result.account.name;
      lbCfg.id=result.account.id;
      earned=score; purse=score;
      try{ localStorage.setItem('drehscheibe-verdient', earned); localStorage.setItem('drehscheibe-asse', purse); }catch(e){}
      renderPurse();
      lbSaveCfg();
      await lbLoad('Willkommen zurück! Dein Guthaben wurde aus deinem Konto geladen.');
    }else{
      lbCfg.id=newLbId();
      lbSaveCfg();
      lbPending=true;
      if (!await lbFlush()) { lbStatus('Das Konto konnte nicht gespeichert werden. Bitte prüfe die Verbindung und versuche es erneut.'); return; }
      await lbLoad('Konto angelegt – dein Guthaben wurde gespeichert.');
    }
  }catch(e){
    lbStatus(e.message==='Ungültiger Kontostand.' ? e.message : 'Anmeldung nicht möglich. Bitte prüfe die Verbindung und versuche es erneut.');
  }finally{ button.disabled=false; }
};
function priceText(price){ return `${price} ${price===1?'As':'Asse'}`; }
function renderShop(){
  const wheelGrid = document.getElementById('wheelShop');
  if (!wheelGrid) return;
  wheelGrid.innerHTML = wheelCatalog.wheels.map(item=>{
    const owned = shopState.ownedWheels.includes(item.id), active = activeWheelId===item.id;
    const action = active?'Ausgerüstet':owned?'Ausrüsten':`Kaufen · ${priceText(item.price)}`;
    return `<article class="shop-item">
      <div class="shop-item-head"><div class="shop-wheel-preview" style="--shop-present:${palette.present};--shop-perfect:${palette.perfect};--shop-rim:${palette.rim};--shop-paper:${palette.paper}" aria-hidden="true"></div>
        <div><h4>${item.name}</h4><p>${item.description}</p></div></div>
      <div class="shop-item-foot"><span class="shop-price">${owned?(active?'Aktiv':'Im Besitz'):priceText(item.price)}</span>
        <button type="button" class="sec small" data-shop-wheel="${item.id}" ${active?'disabled':''}>${action}</button></div>
    </article>`;
  }).join('');
  document.getElementById('skinShop').innerHTML = wheelCatalog.skins.map(item=>{
    const owned = shopState.ownedSkins.includes(item.id), active = shopState.activeSkin===item.id;
    const action = active?'Ausgerüstet':owned?'Ausrüsten':`Kaufen · ${priceText(item.price)}`;
    const p = item.palette;
    return `<article class="shop-item">
      <div class="shop-item-head"><div class="shop-skin-preview" aria-hidden="true"><i style="background:${p.present}"></i><i style="background:${p.perfect}"></i><i style="background:${p.ringEven}"></i></div>
        <div><h4>${item.name}</h4><p>${item.description}</p></div></div>
      <div class="shop-item-foot"><span class="shop-price">${owned?(active?'Aktiv':'Im Besitz'):priceText(item.price)}</span>
        <button type="button" class="sec small" data-shop-skin="${item.id}" ${active?'disabled':''}>${action}</button></div>
    </article>`;
  }).join('');
}
function activateWheel(id, persist=true){
  const item = wheelCatalog.wheels.find(entry=>entry.id===id);
  if (!item || !shopState.ownedWheels.includes(id)) return;
  if (gameMode!=='verbs') setGameMode('verbs');
  D = item.data || {...BASE_D};
  if (!item.data) applyVerbs(item.verbs);
  verbData=D;
  activeWheelId = item.id;
  shopState.activeWheel = item.id;
  if (persist) saveShopState();
  NV = D.verbs.length; VS = 360/NV;
  buildWheel(); rot = {A:0,B:0}; rightRow=null; revealed.clear(); shownKey=''; sel=-1;
  buildTF(); renderStats(); dnew(false); document.getElementById('qnew').click(); render(); renderShop();
}
function activateSkin(id){
  const item = wheelCatalog.skins.find(entry=>entry.id===id);
  if (!item || !shopState.ownedSkins.includes(id)) return;
  palette = item.palette; shopState.activeSkin = item.id; saveShopState();
  buildWheel(); render(); renderShop();
}
function handleShopClick(event, kind){
  const button = event.target.closest(`[data-shop-${kind}]`);
  if (!button) return;
  const id = button.dataset[`shop${kind[0].toUpperCase()}${kind.slice(1)}`];
  const list = kind==='wheel'?wheelCatalog.wheels:wheelCatalog.skins;
  const ownedKey = kind==='wheel'?'ownedWheels':'ownedSkins';
  const activeKey = kind==='wheel'?'activeWheel':'activeSkin';
  const item = list.find(entry=>entry.id===id);
  if (!item) return;
  if (shopState[ownedKey].includes(id)){
    if (shopState[activeKey]===id) return;
    if (kind==='wheel') activateWheel(id); else activateSkin(id);
    document.getElementById('shopMessage').textContent = `${item.name} ist jetzt ausgerüstet.`;
    return;
  }
  if (purse<item.price){
    document.getElementById('shopMessage').textContent = `Dafür fehlen noch ${priceText(item.price-purse)}.`;
    return;
  }
  purse -= item.price;
  shopState[ownedKey].push(id);
  try { localStorage.setItem('drehscheibe-asse',purse); } catch(e){}
  saveShopState(); renderPurse();
  document.getElementById('shopMessage').textContent = `${item.name} freigeschaltet.`;
}
document.getElementById('wheelShop').addEventListener('click',event=>handleShopClick(event,'wheel'));
document.getElementById('skinShop').addEventListener('click',event=>handleShopClick(event,'skin'));
buildTF(); renderStats();
renderPurse();
if (shopState.activeWheel!=='starter') activateWheel(shopState.activeWheel,false);
else { dnew(false); document.getElementById('qnew').click(); render(); }

})));
