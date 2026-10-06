// ===== Match Centre (the landing page) and the two-team head-to-head page =====
// Inserted into template.html by build.py. Everything here is computed in the browser
// from the same data the rest of the dashboard uses (results, ESPN stats, squads,
// rankings, trophies and fixtures.json), so it refreshes with the daily data run.
const slugOf=i=>ALL[i].id;
const fxTime=f=>f.ko?new Date(f.ko):new Date(f.d+"T12:00:00Z");
// Fixtures carry g:"w" for women's Tests (men's have no g); the Match Centre shows the side picked with the Men / Women toggle
const GX=()=>WOMEN()?"w":"m";
function upcoming(){const now=Date.now();return FIX.filter(f=>(f.g||"m")===GX()).map(f=>({...f,t:fxTime(f),tbc:!f.ko,hi:idx(f.h),ai:idx(f.a)})).filter(f=>f.hi>=0&&f.ai>=0&&f.t.getTime()+3*36e5>now).sort((a,b)=>a.t-b.t)}
const h2hHref=(a,b)=>"#h2h/"+slugOf(a)+"-v-"+slugOf(b);
const meetings=(Ms,a,b)=>Ms.filter(m=>(m.h===a&&m.a===b)||(m.h===b&&m.a===a));
const lastN=(Ms,i,n)=>Ms.filter(m=>m.h===i||m.a===i).slice(-n).map(m=>view(m,i));
const dots=(g,tipFor)=>`<span class="mdots">${g.map(x=>`<i class="${x.res}" data-tip="${esc(tipFor(x))}">${x.res}</i>`).join("")}</span>`;
const yrsAgo=d=>(Date.parse(TODAY)-Date.parse(d))/YR;

// Venues: fixtures and results spell grounds differently ("Allianz Stadium, Twickenham" v "Twickenham Stadium|London")
const VK=[[/eden park/i,"Eden Park"],[/twickenham(?! stoop)|allianz stadium.*london/i,"Twickenham"],[/murrayfield/i,"Murrayfield"],[/stade de france/i,"the Stade de France"],[/stadium australia|accor stadium|anz stadium|telstra stadium/i,"Stadium Australia"],[/principality|millennium stadium/i,"the Principality Stadium"],[/aviva stadium|lansdowne road/i,"Lansdowne Road"]];
function vkey(s){for(const[re,k]of VK)if(re.test(s))return{k,lab:"at "+k};const c=s.split(/[,|]/).pop().trim();return{k:c.toLowerCase(),lab:"in "+c}}

// World Rugby ranking exchange (rating gap capped at 10, +3 for the home side)
function wrSwing(h,a,neutral){const H=slugOf(h),A=slugOf(a),rh=RANK[H],ra=RANK[A];if(!rh||!ra)return null;
  const Dg=Math.max(-10,Math.min(10,rh.pts+(neutral?0:3)-ra.pts));
  const pos=(id,adj)=>{const t=Object.entries(RANK).map(([k,v])=>[k,v.pts+(adj[k]||0)]).sort((x,y)=>y[1]-x[1]);return t.findIndex(x=>x[0]===id)+1};
  const hw=1-Dg/10,aw=1+Dg/10;
  return{rh,ra,hw:{g:hw,p:pos(H,{[H]:hw,[A]:-hw})},aw:{g:aw,p:pos(A,{[A]:aw,[H]:-aw})}}}

// Team-level ESPN numbers over a side's last 10 Tests with match stats
const TMET=[["tries","tries a game","t"],["metres","metres carried a game"],["cleanBreaks","line breaks a game"],["defendersBeaten","defenders beaten a game"],["missedTackles","missed tackles a game",1],["penaltiesConceded","penalties conceded a game",1],["turnoversConceded","turnovers conceded a game",1]];
function teamAvg(i){const g=M.filter(m=>(m.h===i||m.a===i)&&m.ms).slice(-10);if(g.length<5)return null;const o={n:g.length};
  TMET.forEach(([k])=>{const v=g.map(m=>m.ms[m.h===i?0:1][SI[k]]).filter(x=>x!=null);o[k]=v.length>=5?avg(v):null});return o}

function insights(f,G){const hi=f.hi,ai=f.ai,H=tname(hi),A=tname(ai),out=[];const V=G.map(m=>view(m,hi));
  if(V.length){const last=V[V.length-1].res;let n=0;for(let k=V.length-1;k>=0&&V[k].res===last;k--)n++;
    if(last!=="D"&&n>=3){const w=last==="W"?H:A,l=last==="W"?A:H,lw=V.filter(x=>x.res===(last==="W"?"L":"W")).pop();
      out.push({s:2+n*.6,t:`<b>${w}</b> have won the last ${n} meetings with ${l}.${lw?` ${l}'s last win was ${lw.pf>lw.pa?lw.pf+"–"+lw.pa:lw.pa+"–"+lw.pf} on ${fmtDate(lw.date)}.`:""}`})}
    const r10=rec(V.slice(-10));if(r10.p>=8&&Math.max(r10.w,r10.l)>=8)out.push({s:4.2,t:`<b>${r10.w>r10.l?H:A}</b> have won ${Math.max(r10.w,r10.l)} of the last ${r10.p} Tests between the sides.`});
    const r6=V.slice(-6),tight=r6.filter(x=>Math.abs(x.pf-x.pa)<=7).length;if(r6.length>=5&&tight>=4)out.push({s:4.5,t:`${tight} of the last ${r6.length} meetings were decided by seven points or fewer.`});}
  // the ground
  const vk=vkey(f.v),VG=G.filter(m=>vkey(m.venue[0]+"|"+m.venue[1]).k===vk.k);
  if(VG.length>=3){const vv=VG.map(m=>view(m,ai)),aw=vv.filter(x=>x.res==="W"),lw=aw[aw.length-1];
    if(!aw.length)out.push({s:6+VG.length/10,t:`<b>${A}</b> have never beaten ${H} ${vk.lab}: ${VG.length} attempts, ${vv.filter(x=>x.res==="D").length} drawn.`});
    else{const y=yrsAgo(lw.date);if(y>=8)out.push({s:4+y/6,t:`<b>${A}</b> have not won ${vk.lab} against ${H} since ${lw.date.slice(0,4)}. ${H} have won ${vv.filter(x=>x.date>lw.date&&x.res==="L").length} of the ${vv.filter(x=>x.date>lw.date).length} meetings there since.`});
      else{const r=rec(VG.map(m=>view(m,hi)));out.push({s:1.5,t:`${vk.lab[0].toUpperCase()+vk.lab.slice(1)}, ${H} lead ${A} ${r.w}–${r.l}${r.d?` with ${r.d} drawn`:""}.`})}}}
  // form
  const fh=lastN(M,hi,5),fa=lastN(M,ai,5),wh=fh.filter(x=>x.res==="W").length,wa=fa.filter(x=>x.res==="W").length;
  if(Math.abs(wh-wa)>=3)out.push({s:3+Math.abs(wh-wa)/2,t:`Form guide: <b>${wh>wa?H:A}</b> have won ${Math.max(wh,wa)} of their last 5 Tests, ${wh>wa?A:H} only ${Math.min(wh,wa)}.`});
  // ESPN team stats
  const th=teamAvg(hi),ta=teamAvg(ai);
  if(th&&ta){let best=null;TMET.forEach(([k,lab,neg])=>{const a=th[k],b=ta[k];if(a==null||b==null||!Math.max(a,b))return;const rel=Math.abs(a-b)/Math.max(a,b);if(rel>=.18&&(!best||rel>best.rel))best={k,lab,neg,rel,a,b}});
    if(best){const hiS=best.a>best.b,fmt=v=>best.k==="metres"?Math.round(v):v.toFixed(1),top=hiS?H:A,bot=hiS?A:H;
      out.push({s:2.5+best.rel*4,t:`In their last 10 Tests, <b>${top}</b> average ${fmt(Math.max(best.a,best.b))} ${best.lab} to ${bot}'s ${fmt(Math.min(best.a,best.b))}${best.neg?", an edge for "+bot:""}.`})}}
  return out.sort((x,y)=>y.s-x.s)}

// What's at stake: trophies, ranking points, Nations Championship finals seeding, cap milestones
function stakes(f){const hi=f.hi,ai=f.ai,out=[];
  TROPHIES.filter(T=>T.g===GX()).forEach(T=>{
    if(T.kind==="bilateral"&&T.teams.includes(f.h)&&T.teams.includes(f.a)&&(!T.comp||new RegExp(T.comp).test(f.c))){const o=trophyState(T);
      out.push(`<b>${esc(T.name)}</b>: ${o.holder!=null&&o.holder>=0?`${tname(o.holder)} hold it.`:"currently vacant."} ${o.tx}`)}
    if(T.kind==="lineal"){const o=trophyState(T);if(o.holder===hi||o.holder===ai)out.push(`<b>${esc(T.name)}</b> (rugby's unofficial ${WOMEN()?"women's ":""}world title) is on the line: ${tname(o.holder)} hold it and keep it with a win or a draw.`)}});
  const w=wrSwing(hi,ai,false);
  if(w)out.push(`<b>World Rugby rankings</b>: victory is worth +${w.hw.g.toFixed(2)} pts to ${f.h} (${w.hw.p===w.rh.pos?`stays ${ord(w.hw.p)}`:`moves to ${ord(w.hw.p)}`}) and +${w.aw.g.toFixed(2)} pts to ${f.a} (${w.aw.p===w.ra.pos?`stays ${ord(w.aw.p)}`:`moves to ${ord(w.aw.p)}`}), 1.5× for a win by more than 15.`);
  if(!WOMEN()&&/Nations Championship/.test(f.c)&&typeof PROJ!=="undefined"){const best=n=>{let b=null;Object.entries(PROJ).forEach(([k,L])=>L.forEach(([t,p])=>{if(t===n&&(!b||p>b.p))b={k,p}}));return b};
    const s=[f.h,f.a].map(n=>{const b=best(n);return b?`${n} most likely ${ord(+b.k.slice(1))} in the ${b.k[0]==="N"?"North":"South"} (${b.p}%)`:null}).filter(Boolean);
    if(s.length)out.push(`<b>Finals weekend seeding</b>: ${s.join("; ")}. Each finishing place plays its mirror at Twickenham.`)}
  [hi,ai].forEach(i=>{(PLY.sq[GX()+":"+ALL[i].name]||[]).forEach(r=>{const c=r[3]+1;if(c>=50&&c%50===0)out.push(`<b>Milestone</b>: ${esc(r[0])} would win a ${ord(c)} cap for ${tname(i)} if selected.`)})});
  return out}

// Players to watch: from each side's latest named squad, the standout numbers in the Tests we hold player stats for
function watch(i){const sq=PLY.sq[GX()+":"+ALL[i].name];if(!sq)return[];const rows=sq.filter(r=>r[5]>=0).map(r=>({r,p:PP[r[5]]})).filter(o=>o.p[14]>=5);
  const per=(o,k)=>o.p[15][PKI[k]]/o.p[14],used=new Set(),out=[];
  const take=(lab,f,txt)=>{const c=rows.filter(o=>!used.has(o.r[0])).map(o=>({o,v:f(o)})).filter(x=>x.v>0).sort((x,y)=>y.v-x.v)[0];if(c){used.add(c.o.r[0]);out.push({lab,o:c.o,txt:txt(c.v,c.o)})}};
  take("Try threat",o=>o.p[15][PKI.tries],(v,o)=>`${v} tries in ${o.p[14]} Tests`);
  take("Ball carrier",o=>per(o,"metres"),v=>`${Math.round(v)} m carried a Test`);
  take("Defence",o=>per(o,"tackles"),v=>`${v.toFixed(1)} tackles a Test`);
  // thin player stats (common for women's sides): fall back to the most experienced names in the squad
  if(!out.length)sq.slice().sort((x,y)=>y[3]-x[3]).slice(0,3).forEach((r,k)=>out.push({lab:k?"Experience":"Most capped",o:{r},txt:r[4]?esc(r[4]):"in the squad"}));
  return out}
const watchHTML=i=>{const w=watch(i);return w.length?w.map(x=>`<div class="pw${x.o.r[5]>=0?" xp":""}" data-p="${x.o.r[5]}"${x.o.r[5]>=0?' tabindex="0" role="button"':""}><span class="pwl">${x.lab}</span><span class="pwn">${esc(x.o.r[0])}${x.o.r[6]?' <span class="wc">C</span>':""}</span><span class="pwx">${esc(POSN[x.o.r[1]]||x.o.r[1])} · ${x.o.r[3]} caps · ${x.txt}</span></div>`).join(""):`<p class="hint">No squad listed yet.</p>`};

function mdCard(f,now){const hi=f.hi,ai=f.ai,G=meetings(M,hi,ai),V=G.map(m=>view(m,hi)),r=rec(V),L=V[V.length-1];
  const pick=f.p>=.5?[f.h,f.p]:[f.a,1-f.p],rk=i=>{const x=RANK[slugOf(i)];return x?`World no. ${x.pos}`:"Unranked"};
  const fm=i=>dots(lastN(M,i,5),x=>`${x.res==="W"?"Won":x.res==="L"?"Lost":"Drew"} ${x.pf}–${x.pa} v ${tname(x.opp)}, ${fmtDate(x.date)}`);
  const ins=insights(f,G),st=stakes(f),sto=storyOf(f.h,f.a,GX());
  const when=f.tbc?`${fD.format(new Date(f.d+"T12:00:00"))} · kick-off TBC`:`${fD.format(f.t)} · ${fT.format(f.t)} ${fZ(f.t)}`;
  const cd=!f.tbc&&f.t>now?`<span class="mdcd">in ${untilTxt(f.t-now)}</span>`:"";
  const side=(i,cls)=>`<button class="mdt ${cls}" data-i="${i}"><img src="${FLAGS[ALL[i].id]}" alt=""><span class="mdn">${tname(i)}</span><span class="mdr">${rk(i)}</span>${fm(i)}</button>`;
  const hist=r.p?`<div class="mdrec"><span><b>${r.w}</b> ${f.h}</span><span><b>${r.d}</b> drawn</span><span><b>${r.l}</b> ${f.a}</span></div>
    <div class="bar" style="margin:6px 0 10px"><i class="w" style="flex:${r.w}"></i><i class="d" style="flex:${r.d}"></i><i class="l" style="flex:${r.l}"></i></div>
    <p class="mdp">${r.p} Tests since ${G[0].y}. Last meeting: ${L.res==="D"?`drawn ${L.pf}–${L.pa}`:`${L.res==="W"?f.h:f.a} won ${Math.max(L.pf,L.pa)}–${Math.min(L.pf,L.pa)}`}, ${fmtDate(L.date)}${L.venue[1]?` in ${esc(L.venue[1])}`:""}.</p>
    <div class="mdl5"><span class="hint">Last 5 meetings (${f.h})</span>${dots(V.slice(-5),x=>`${x.pf}–${x.pa}, ${fmtDate(x.date)} · ${x.venue[1]||x.venue[0]}`)}</div>`:`<p class="mdp">First ever Test between these sides.</p>`;
  return `<article class="mc">
  <div class="mchd"><span class="mcc">${esc(f.c)}</span><span class="mcw">${when}</span>${cd}</div>
  <div class="mcteams">${side(hi,"h")}<div class="mcv">v</div>${side(ai,"a")}</div>
  <div class="mcpick"><div class="mcpl">Model pick</div><div class="mcpv"><b>${pick[0]}</b> ${Math.round(pick[1]*100)}%</div>
    <div class="mcbar" title="${f.h} ${Math.round(f.p*100)}% · ${f.a} ${Math.round((1-f.p)*100)}%"><i style="width:${f.p*100}%"></i></div>
    <div class="mcbl"><span>${f.h} ${Math.round(f.p*100)}%</span><span>${f.a} ${Math.round((1-f.p)*100)}%</span></div></div>
  <div class="mcgrid">
    ${sto?`<section class="mct mcsto"><h3>The rivalry</h3><p class="mdp">${esc(sto)}</p></section>`:""}
    <section class="mct"><h3>Head to head</h3>${hist}</section>
    <section class="mct mcins"><h3>Insight from the data</h3>${ins.length?`<p class="mdlead">${ins[0].t}</p>${ins.slice(1,3).map(x=>`<p class="mdp">${x.t}</p>`).join("")}`:`<p class="hint">Not enough shared history for an insight yet.</p>`}</section>
    <section class="mct"><h3>What's on the line</h3>${st.length?`<ul class="mdst">${st.map(s=>`<li>${s}</li>`).join("")}</ul>`:`<p class="hint">Nothing beyond the result.</p>`}</section>
    <section class="mct"><h3>Players to watch</h3><div class="mdpw"><div><div class="mdpt">${fl(hi)} ${f.h}</div>${watchHTML(hi)}</div><div><div class="mdpt">${fl(ai)} ${f.a}</div>${watchHTML(ai)}</div></div></section>
  </div>
  <div class="mcft"><span class="hint">${esc(f.v)}</span><a class="mcgo" href="${h2hHref(hi,ai)}">Full head-to-head stats: ${f.h} v ${f.a} →</a></div>
</article>`}

function renderMatchday(){const now=Date.now(),items=upcoming(),Wm=WOMEN();
  $("union").textContent=`Match Centre · ${Wm?"women":"men"}'s Tests`;$("teamName").textContent="Next up";
  const nxt=items.find(f=>!f.tbc&&f.t.getTime()>now);
  // featured = the next round: everything within 8 days of the first fixture (at least two)
  const feat=items.length?items.filter((f,k)=>k<2||f.t-items[0].t<8*864e5).slice(0,8):[],rest=items.slice(feat.length);
  $("heroSub").textContent=feat.length?`Previews of the next ${feat.length===1?(Wm?"women's Test":"Test"):feat.length+(Wm?" women's Tests":" Tests")}: the model's pick, the head-to-head history, a stand-out number, what's at stake and the players to watch. Times are in your time zone (${TZ}).`:`No upcoming ${Wm?"women's ":""}Tests in the fixture list yet.`;
  $("rank").innerHTML=nxt?`<div><div class="lbl">Next kick-off</div><div class="holder" style="font-size:22px">${nxt.h} v ${nxt.a}</div><div class="pts">${fD.format(nxt.t)}, ${fT.format(nxt.t)} · in ${untilTxt(nxt.t-now)}</div></div>`:"";
  $("mdWomen").hidden=!Wm;
  $("mdCards").innerHTML=feat.map(f=>mdCard(f,now)).join("")||`<section class="panel"><p class="hint">No upcoming ${Wm?"women's ":""}fixtures yet. The daily data run adds them as soon as they are announced.${Wm?` In the meantime, the team pages and head to head cover every women's Test since 1982.`:""}</p></section>`;
  $("mdLater").innerHTML=rest.slice(0,10).map(f=>{const pick=f.p>=.5?[f.h,f.p]:[f.a,1-f.p];return `<a class="mdlr" href="${h2hHref(f.hi,f.ai)}"><span class="dt">${fD.format(f.tbc?new Date(f.d+"T12:00:00"):f.t)}</span><span class="tms">${fl(f.hi)} ${f.h} v ${f.a} ${fl(f.ai)}</span><span class="pk">Pick: <b>${pick[0]}</b> ${Math.round(pick[1]*100)}%</span><span class="go">Head to head →</span></a>`}).join("")||`<p class="hint">Nothing else scheduled yet.</p>`;
  $("mdLaterWrap").hidden=!rest.length;
  $("mdSrc").textContent=`Model picks come from World Rugby ${Wm?"women's ":""}ranking points with home advantage and are estimates, not betting advice. Players to watch are drawn from each nation's latest named squad, using the Tests we hold player stats for${Wm?" (or the most capped players when we have too few)":""}. Ranking swings use World Rugby's points-exchange formula on the current table.`;
  bindTips($("mdCards"));
  $("mdCards").querySelectorAll("button.mdt").forEach(b=>b.addEventListener("click",()=>{setTeam(+b.dataset.i);scrollTo({top:0})}));
  bindPlayerRows($("mdCards"));
}

// ===== Two-team head-to-head =====
{const n=upcoming()[0];state.pair=state.pair||(n?[n.hi,n.ai]:[idx("New Zealand"),idx("Australia")]);}state.pvAll=false;
function renderPair(){const [a,b]=state.pair,Wm=WOMEN(),era=ERAS.find(e=>e.id===state.era),Gall=meetings(M,a,b),G=Gall.filter(m=>m.y>=era.from),V=G.map(m=>view(m,a)),r=rec(V),A=tname(a),B=tname(b);
  $("union").textContent=`Head to head · ${Wm?"women's ":""}Tests`;$("teamName").textContent=`${A} v ${B}`;
  const opts=ALL.map((t,i)=>i).filter(i=>M.some(m=>m.h===i||m.a===i)).sort((x,y)=>tname(x).localeCompare(tname(y)));
  $("pvA").innerHTML=opts.map(i=>`<option value="${i}"${i===a?" selected":""}>${tname(i)}</option>`).join("");$("pvB").innerHTML=opts.map(i=>`<option value="${i}"${i===b?" selected":""}>${tname(i)}</option>`).join("");
  $("heroSub").textContent=Gall.length?`${Gall.length} ${Wm?"women's ":""}Tests since ${Gall[0].y}${era.from?`, ${G.length} of them in the ${era.label.toLowerCase()} window`:""}. Pick a different pairing below, or change the era above.`:`No ${Wm?"women's ":""}Tests between ${A} and ${B} in the dataset.`;
  const now=Date.now(),nx=upcoming().find(f=>(f.hi===a&&f.ai===b)||(f.hi===b&&f.ai===a));
  $("rank").innerHTML=nx?`<div><div class="lbl">Next meeting</div><div class="holder" style="font-size:20px">${nx.h} v ${nx.a}</div><div class="pts">${nx.tbc?fmtDate(nx.d):fD.format(nx.t)} · pick: ${nx.p>=.5?nx.h:nx.a} ${Math.round(Math.max(nx.p,1-nx.p)*100)}%</div></div>`:`<div><div class="lbl">Next meeting</div><div class="pts">None scheduled</div></div>`;
  $("pvEmpty").hidden=!!G.length;$("pvBody").hidden=!G.length;if(!G.length)return;
  const pf=V.reduce((s,x)=>s+x.pf,0),pa=V.reduce((s,x)=>s+x.pa,0),L=V[V.length-1],big=(res)=>V.filter(x=>x.res===res).sort((x,y)=>Math.abs(y.pf-y.pa)-Math.abs(x.pf-x.pa))[0];
  const ba=big("W"),bb=big("L");
  const K=[[`${A} wins`,r.w,`${pct(r.w,r.p)}% of ${r.p} Tests`,1],["Draws",r.d,r.d?`last ${fmtDate(V.filter(x=>x.res==="D").pop().date)}`:"none"],[`${B} wins`,r.l,`${pct(r.l,r.p)}%`],["Average score",`${(pf/r.p).toFixed(1)}–${(pa/r.p).toFixed(1)}`,`${A} first`],[`Biggest ${A} win`,ba?`${ba.pf}–${ba.pa}`:"–",ba?fmtDate(ba.date):""],[`Biggest ${B} win`,bb?`${bb.pa}–${bb.pf}`:"–",bb?fmtDate(bb.date):""]];
  $("pvKpis").innerHTML=K.map(([k,v,n,l])=>`<div class="kpi${l?" lead":""}"><div class="k">${esc(k)}</div><div class="v">${v}</div><div class="n">${esc(n)}</div></div>`).join("");
  // decades
  const dec={};V.forEach(x=>{const d=Math.floor(x.y/10)*10;(dec[d]=dec[d]||[]).push(x)});
  $("pvDec").innerHTML=`<div class="legend"><span><i style="background:var(--acc)"></i>${A} won</span><span><i style="background:var(--draw)"></i>Drawn</span><span><i style="background:var(--loss)"></i>${B} won</span></div>`+Object.keys(dec).map(Number).sort((x,y)=>x-y).map(d=>{const q=rec(dec[d]);return `<div class="pvd"><span class="pvdy">${d}s</span><div class="bar"><i class="w" style="flex:${q.w}"></i><i class="d" style="flex:${q.d}"></i><i class="l" style="flex:${q.l}"></i></div><span class="pvdn">${q.w}–${q.d}–${q.l}</span></div>`}).join("");
  // where
  const sp=[[`In ${A}`,V.filter(x=>x.where==="Home")],[`In ${B}`,V.filter(x=>x.where==="Away")],["Neutral venues",V.filter(x=>x.where==="Neutral")]].filter(x=>x[1].length);
  let run={res:null,n:0},best={W:0,L:0};V.forEach(x=>{run=x.res===run.res?{res:x.res,n:run.n+1}:{res:x.res,n:1};if(x.res!=="D")best[x.res]=Math.max(best[x.res],run.n)});
  $("pvVen").innerHTML=sp.map(([lab,g])=>{const q=rec(g);return `<div class="pvd"><span class="pvdy">${lab}</span><div class="bar"><i class="w" style="flex:${q.w}"></i><i class="d" style="flex:${q.d}"></i><i class="l" style="flex:${q.l}"></i></div><span class="pvdn">${q.w}–${q.d}–${q.l}</span></div>`}).join("")+
    `<div class="pvfacts"><div><span class="k">Longest ${esc(A)} run</span><b>${best.W}</b> wins</div><div><span class="k">Longest ${esc(B)} run</span><b>${best.L}</b> wins</div><div><span class="k">Current run</span><b>${run.n}</b> ${run.res==="D"?"draw":run.res==="W"?esc(A)+" win":esc(B)+" win"}${run.n>1?"s":""}</div></div>`;
  // margins chart
  {const n=V.length,w=Math.max(280,$("pvMargin").clientWidth||1000),h=w<520?160:220,mid=h/2,mx=Math.max(10,...V.map(x=>Math.abs(x.pf-x.pa))),bw=w/n;
   let s=`<svg viewBox="0 0 ${w} ${h+18}" class="pvsvg" role="img" aria-label="Winning margin in every meeting"><line x1="0" x2="${w}" y1="${mid}" y2="${mid}" stroke="var(--line)"/>`;
   V.forEach((x,k)=>{const d=x.pf-x.pa,bh=Math.max(2,Math.abs(d)/mx*(mid-6));s+=`<rect x="${k*bw+bw*.12}" width="${Math.max(1,bw*.76)}" y="${d>=0?mid-bh:mid}" height="${bh}" rx="1.5" fill="${d>0?"var(--acc)":d<0?"var(--loss)":"var(--draw)"}" data-tip="<b>${x.res==="D"?"Drawn":x.res==="W"?esc(A)+" won":esc(B)+" won"} ${Math.max(x.pf,x.pa)}–${Math.min(x.pf,x.pa)}</b><br>${fmtDate(x.date)} · ${esc(x.venue[1]||x.venue[0])}<br>${esc(x.comp||"Test")}"/>`});
   const step=Math.max(1,Math.ceil(n/Math.max(3,Math.floor(w/80))));V.forEach((x,k)=>{if(k%step===0)s+=`<text x="${k*bw+bw/2}" y="${h+14}" text-anchor="${k?"middle":"start"}">${x.y}</text>`});
   $("pvMargin").innerHTML=s+`</svg><div class="legend" style="margin-top:6px"><span><i style="background:var(--acc)"></i>${A} won (bar height = margin, up to ${mx})</span><span><i style="background:var(--loss)"></i>${B} won</span></div>`;bindTips($("pvMargin"))}
  // ESPN match stats averaged over meetings that have them
  const S=G.filter(m=>m.ms);$("pvSheetWrap").hidden=!S.length;
  if(S.length){const mean=side=>SK.map((k,j)=>{const v=S.map(m=>m.ms[(m.h===a)===(side===0)?0:1][j]).filter(x=>x!=null);return v.length?Math.round(avg(v)*(k==="possession"||k==="territory"?100:10))/(k==="possession"||k==="territory"?100:10):null});
    $("pvSheetHint").textContent=`Average per Test across the ${S.length} meeting${S.length>1?"s":""} with full match stats (since ${S[0].y}). ${A} on the left.`;
    $("pvSheet").innerHTML=sheetHTML({ms:[mean(0),mean(1)]}).replace("<b>Match stats</b>",`<b>${esc(A)} v ${esc(B)}</b>`)}
  // records
  const agg=V.slice().sort((x,y)=>(y.pf+y.pa)-(x.pf+x.pa))[0],low=V.slice().sort((x,y)=>(x.pf+x.pa)-(y.pf+y.pa))[0],crowd=G.filter(m=>m.det&&m.det[3]).sort((x,y)=>y.det[3]-x.det[3])[0];
  const first=V[0];
  $("pvRec").innerHTML=[["First meeting",`${first.res==="D"?"Drawn":first.res==="W"?A+" won":B+" won"} ${Math.max(first.pf,first.pa)}–${Math.min(first.pf,first.pa)}`,`${fmtDate(first.date)}, ${first.venue[1]||first.venue[0]}`],
    ["Highest-scoring",`${agg.pf}–${agg.pa}`,`${agg.pf+agg.pa} points, ${fmtDate(agg.date)}`],["Lowest-scoring",`${low.pf}–${low.pa}`,`${fmtDate(low.date)}`],
    crowd?["Biggest crowd",crowd.det[3].toLocaleString(),`${crowd.venue[0]}, ${fmtDate(crowd.date)}`]:null,
    ["Points scored",`${pf.toLocaleString()}–${pa.toLocaleString()}`,`${A} first`]].filter(Boolean).map(([k,v,n])=>`<div class="fact"><div class="k">${esc(k)}</div><div class="v">${esc(v)}</div><div class="n">${esc(n)}</div></div>`).join("");
  // try scorers in the fixture
  const cnt={};G.filter(m=>m.det&&m.det[0]).forEach(m=>[0,1].forEach(k=>{const tm=k?m.a:m.h;(m.det[4+k]||"").split(";").map(z=>z.trim()).filter(z=>z&&!/penalty try/i.test(z)).forEach(z=>{const mm=z.match(/^(.*?)\s*\((\d+)\)$/);const nm=(mm?mm[1]:z).trim(),c=mm?+mm[2]:1;const key=tm+"|"+nm;cnt[key]=(cnt[key]||0)+c})}));
  const ts=Object.entries(cnt).sort((x,y)=>y[1]-x[1]).slice(0,8);
  $("pvTries").innerHTML=ts.length?ts.map(([k,n],j)=>{const [t,nm]=k.split("|");return `<div class="mli"><span class="r">${j+1}</span><span>${fl(+t)}${esc(nm)}</span><b>${n}</b></div>`}).join(""):`<p class="hint">No try-scorer records for these meetings.</p>`;
  // most appearances in the fixture (line-ups we hold)
  const ap={};G.filter(m=>m.lu).forEach(m=>m.lu.forEach(row=>row.forEach(i=>{if(i>=0)ap[i]=(ap[i]||0)+1})));
  const top=Object.entries(ap).sort((x,y)=>y[1]-x[1]).slice(0,8);
  $("pvApps").innerHTML=top.length?top.map(([i,n],j)=>{const p=PP[i];return `<div class="mli xp" data-p="${i}" tabindex="0" role="button"><span class="r">${j+1}</span><span>${fl(p[1])}${esc(p[0])} <span class="x">${esc(p[3]||"")}</span></span><b>${n}</b></div>`}).join(""):`<p class="hint">No line-ups held for these meetings.</p>`;
  bindPlayerRows($("pvApps"));
  // every meeting
  const LIM=15,list=G.slice().reverse(),rows=state.pvAll?list:list.slice(0,LIM);
  $("pvMore").hidden=list.length<=LIM;$("pvMore").textContent=state.pvAll?"Show fewer":`Show all ${list.length} meetings`;
  $("pvList").innerHTML=rows.map(m=>{const hw=m.hs>m.as,aw=m.as>m.hs;return `<div class="lt xp" tabindex="0" role="button" aria-expanded="false" data-k="${M.indexOf(m)}"><div class="dt">${fmtDate(m.date)}</div><div class="hm"><span class="tm ${hw?"win":""}">${tname(m.h)} ${fl(m.h)}</span></div><div class="sc">${m.hs}–${m.as}</div><div><span class="tm ${aw?"win":""}">${fl(m.a)} ${tname(m.a)}</span></div><div class="cm">${esc(m.comp||"Test match")} · ${esc(m.venue[1]||m.venue[0])}${m.neutral?" (neutral)":""}${m.det||m.ms?' · <span class="plus">details ＋</span>':""}</div></div>`}).join("");
  bindExpand($("pvList"));
}
$("pvMore").addEventListener("click",()=>{state.pvAll=!state.pvAll;renderPair()});
const pvSet=(a,b)=>{if(a===b)return;state.pair=[a,b];state.pvAll=false;setTeam(-6)};
$("pvA").addEventListener("change",e=>pvSet(+e.target.value,state.pair[1]));
$("pvB").addEventListener("change",e=>pvSet(state.pair[0],+e.target.value));
$("pvSwap").addEventListener("click",()=>pvSet(state.pair[1],state.pair[0]));

// Match Centre chip first in the nav; links like #h2h/england-v-france route without a reload
{const b=document.createElement("button");b.className="chip";b.id="team-matchday";b.dataset.i="-5";b.setAttribute("aria-pressed","false");
 b.innerHTML=`<svg class="ball" viewBox="0 0 26 18" aria-hidden="true"><circle cx="13" cy="9" r="7.5" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M13 5v4.5l3 2" stroke="currentColor" stroke-width="1.6" fill="none" stroke-linecap="round"/></svg>Match Centre`;
 $("picker").insertBefore(b,$("team-overview"));}
// Head to head chip straight after it; opens on the pair last viewed (next fixture by default)
{const b=document.createElement("button");b.className="chip";b.id="team-h2h";b.dataset.i="-6";b.setAttribute("aria-pressed","false");
 b.innerHTML=`<svg class="ball" viewBox="0 0 26 18" aria-hidden="true"><path d="M3 6h14l-3-3M23 12H9l3 3" stroke="currentColor" stroke-width="1.6" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>Head to head`;
 $("picker").insertBefore(b,$("team-overview"));}
addEventListener("hashchange",()=>{let h=decodeURIComponent(location.hash.slice(1)),g="m";if(h.startsWith("women/")){g="w";h=h.slice(6)}else if(h==="women"){g="w";h="overview"}
  const i=h?parseId(h):-5;if(g!==state.g){state.team=i;setGender(g)}else setTeam(i);scrollTo({top:0})});
let pvRt;addEventListener("resize",()=>{if(state.team!==-6)return;clearTimeout(pvRt);pvRt=setTimeout(renderPair,150)});
