"""Adds the social banner, the "The data in 60 seconds" strip and footer social links to site/index.html.

Runs last in build_all.py, after the main page is built. Content lives in pipeline/stories.json:
each item names a video in site/stories/<id>.mp4 (with a <id>.jpg poster) and the date it goes out
on social media. An item only appears on the site from that date, so the strip refreshes itself
as the scheduled posts go out. To add one: drop <id>.mp4 and <id>.jpg into site/stories/ and add a
line to stories.json.
"""
import datetime as dt
import html
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SITE = os.path.join(HERE, '..', 'site')
SHOW = 8  # newest items shown in the strip

IG_SVG = '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="17.4" cy="6.6" r="1.3" fill="currentColor"/></svg>'
FB_SVG = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M13.5 21v-7.5h2.6l.4-3h-3V8.6c0-.9.3-1.5 1.5-1.5h1.6V4.4c-.3 0-1.2-.1-2.3-.1-2.3 0-3.9 1.4-3.9 4v2.2H7.8v3h2.6V21h3.1z"/></svg>'
PLAY_SVG = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M8 5.5v13l11-6.5z"/></svg>'

CSS = """
.sx-bar{border-bottom:1px solid var(--line);background:color-mix(in oklab,#C9A24B 14%,var(--bg))}
.sx-bar .wrap{display:flex;align-items:center;gap:10px 16px;flex-wrap:wrap;padding-block:9px}
.sx-bar p{margin:0;font-size:14px;color:var(--ink);flex:1 1 260px;min-width:0}
.sx-bar p b{font-weight:650}
.sx-btns{display:flex;gap:8px;flex-wrap:wrap}
.sx-btn{display:inline-flex;align-items:center;gap:7px;padding:6px 12px;border-radius:999px;border:1px solid var(--line);background:var(--card);color:var(--ink);font:600 13px/1 var(--body);text-decoration:none;white-space:nowrap}
.sx-btn:hover{border-color:var(--ink2)}
.sx-btn svg{width:16px;height:16px}
.sx-x{margin-left:auto;background:none;border:0;color:var(--ink2);font-size:20px;line-height:1;padding:4px 6px;cursor:pointer}
.sx{padding-block:28px 24px}
.nx,.sx{min-width:0;max-width:100%;width:100%;box-sizing:border-box}
.nx{padding-block:24px 0}
.nx details{border:1px solid var(--line);border-radius:16px;background:var(--card)}
.nx summary{cursor:pointer;list-style:none;display:flex;align-items:center;justify-content:space-between;gap:12px;padding:16px 20px}
.nx summary::-webkit-details-marker{display:none}
.nx summary h2{margin:0;font-size:20px;letter-spacing:-.01em}
.nx summary span{font-size:13px;color:var(--ink2);white-space:nowrap}
.nx details[open] summary span .o{display:none}.nx details:not([open]) summary span .c{display:none}
.nx-lede{margin:0 20px 14px;color:var(--ink2);font-size:15px;max-width:70ch}
.nx-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(220px,100%),1fr));gap:12px;padding:0 20px 18px}
.nx-step{border-top:3px solid #C9A24B;padding-top:10px;min-width:0}
.nx-step b{display:block;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);margin-bottom:4px}
.nx-step h3{margin:0 0 6px;font-size:16px}
.nx-step p{margin:0 0 6px;font-size:14px;line-height:1.5;color:var(--ink)}
.nx-step p.s{color:var(--ink2);font-size:13px}
.nx-next{margin:0 20px 18px;padding:12px 14px;border-radius:12px;background:color-mix(in oklab,#C9A24B 14%,var(--card));font-size:14px}
.nx-next a{color:inherit;font-weight:600}
.sx-hd{display:flex;align-items:end;justify-content:space-between;gap:12px;flex-wrap:wrap;margin-bottom:14px}
.sx-hd h2{margin:0;font-size:22px;letter-spacing:-.01em}
.sx-hd p{margin:4px 0 0;color:var(--ink2);font-size:14px;max-width:60ch}
.sx-row{display:grid;grid-auto-flow:column;grid-auto-columns:minmax(200px,230px);gap:14px;overflow-x:auto;padding-bottom:10px;scroll-snap-type:x mandatory;overscroll-behavior-x:contain}
.sx-card{scroll-snap-align:start;display:flex;flex-direction:column;gap:8px;min-width:0}
.sx-media{position:relative;aspect-ratio:9/16;border-radius:14px;overflow:hidden;background:#0E1B30;max-width:100%}
.sx-media img,.sx-media video{width:100%;height:100%;object-fit:cover;display:block}
.sx-play{position:absolute;inset:0;display:grid;place-items:center;background:linear-gradient(transparent 55%,rgba(14,27,48,.55));border:0;cursor:pointer;color:#0E1B30}
.sx-play span{width:54px;height:54px;border-radius:50%;background:#C9A24B;display:grid;place-items:center;box-shadow:0 4px 18px rgba(0,0,0,.35)}
.sx-play svg{width:24px;height:24px;margin-left:3px}
.sx-card h3{margin:0;font-size:15px;line-height:1.3}
.sx-card p{margin:0;font-size:13px;color:var(--ink2);line-height:1.4}
.sx-card time{font-size:12px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
.sx-cta{scroll-snap-align:start;border:1px dashed var(--line);border-radius:14px;padding:18px;display:flex;flex-direction:column;justify-content:center;gap:12px;aspect-ratio:9/16}
.sx-cta h3{margin:0;font-size:17px}
.sx-cta p{margin:0;font-size:13px;color:var(--ink2)}
.sx-cta .sx-btns{flex-direction:column}
.sx-foot{display:flex;align-items:center;gap:10px;flex-wrap:wrap;padding-block:6px 28px;font-size:14px;color:var(--ink2)}
"""

JS = """
(function(){
  try{if(localStorage.getItem('sxBarHidden')==='1'){var b=document.getElementById('sxBar');if(b)b.hidden=true}}catch(e){}
  var x=document.getElementById('sxX');
  if(x)x.addEventListener('click',function(){document.getElementById('sxBar').hidden=true;try{localStorage.setItem('sxBarHidden','1')}catch(e){}});
  var nd=document.querySelector('#nx details');
  if(nd){try{if(localStorage.getItem('nxClosed')==='1')nd.open=false}catch(e){}
    nd.addEventListener('toggle',function(){try{localStorage.setItem('nxClosed',nd.open?'0':'1')}catch(e){}})}
  document.querySelectorAll('.sx-play').forEach(function(btn){
    btn.addEventListener('click',function(){
      var m=btn.parentNode,v=document.createElement('video');
      v.src=btn.dataset.src;v.poster=btn.dataset.poster;v.controls=true;v.playsInline=true;v.muted=true;v.autoplay=true;v.setAttribute('playsinline','');
      m.innerHTML='';m.appendChild(v);var p=v.play();if(p&&p.catch)p.catch(function(){});
      document.querySelectorAll('.sx-media video').forEach(function(o){if(o!==v)o.pause()});
    });
  });
})();
"""


# (wrong, right) pairs. The third item in a TMET entry marks "lower is better"; tries carried a stray "t",
# so "more tries" was described as "an edge for" the other side.
FIXES = [('["tries","tries a game","t"]', '["tries","tries a game"]'),
         # venue record: say who actually leads (was "Japan lead Fiji 1–2")
         ('t:`${vk.lab[0].toUpperCase()+vk.lab.slice(1)}, ${H} lead ${A} ${r.w}–${r.l}${r.d?` with ${r.d} drawn`:""}.`',
          't:`${vk.lab[0].toUpperCase()+vk.lab.slice(1)}, ${r.w>r.l?`${H} lead ${A} ${r.w}–${r.l}`:r.w<r.l?`${A} lead ${H} ${r.l}–${r.w}`:`${H} and ${A} are level at ${r.w}–${r.l}`}${r.d?` with ${r.d} drawn`:""}.`')]


def fmt_date(d):
    return d.strftime('%-d %b')


T10 = {'Argentina', 'Australia', 'England', 'France', 'Ireland', 'Italy', 'New Zealand', 'Scotland', 'South Africa', 'Wales'}


def next_up(today):
    """The next Test between two top-ten nations, from the fixtures the daily refresh writes."""
    try:
        fx = json.load(open(os.path.join(HERE, 'fixtures.json'), encoding='utf-8'))
    except (FileNotFoundError, ValueError):
        return ''
    for f in sorted(fx, key=lambda f: f.get('ko') or f.get('d') or ''):
        d = (f.get('ko') or f.get('d') or '')[:10]
        if d and d >= today.isoformat() and f.get('h') in T10 and f.get('a') in T10 and f.get('g') != 'w':
            when = dt.date.fromisoformat(d).strftime('%a %-d %b')
            comp = f' ({html.escape(f["c"])})' if f.get('c') and f['c'] != 'Test match' else ''
            return f'<b>Next big Test:</b> {html.escape(f["h"])} v {html.escape(f["a"])}{comp}, {when}. '
    return ''


# dated headline events for the "what's next" line; each drops off once it has passed
LATER = [('2026-11-29', 'the Nations Championship finals at Twickenham (27–29 Nov)'),
         ('2027-11-13', 'the 2027 Rugby World Cup in Australia')]


def later(today):
    ev = [t for d, t in LATER if d >= today.isoformat()]
    return f'<b>Then:</b> {" and ".join(ev)}. ' if ev else ''


def intro(today):
    nxt = next_up(today)
    return (
        '<section class="nx" id="nx" aria-labelledby="nxH"><details open>'
        '<summary><h2 id="nxH">New to rugby? Start here</h2><span><span class="c">Hide</span><span class="o">Show</span></span></summary>'
        '<p class="nx-lede">Rugby union is one of the world\'s great team sports. Here\'s the two-minute version, '
        'and where this site fits in.</p><div class="nx-grid">'
        '<div class="nx-step"><b>1 · The game</b><h3>Run it, pass it back, ground it</h3>'
        '<p>Two teams of 15 play for 80 minutes. You can run or kick the ball forward, but you may only pass it backwards or sideways.</p>'
        '<p class="s">Ground the ball over the line for a try (5 points) and kick the conversion (2). Penalties and drop goals are worth 3. '
        'When a player is tackled, both sides fight for the ball on the ground, so play keeps flowing.</p></div>'
        '<div class="nx-step"><b>2 · How it differs</b><h3>Not league, not gridiron</h3>'
        '<p>Rugby league has 13 players, hands the ball over after six tackles, and a try is worth 4. '
        'American football allows forward passes, blocking and helmets, and stops after every play.</p>'
        '<p class="s">Sevens is the same game with 7 a side and 14-minute matches, and it\'s the version played at the Olympics.</p></div>'
        '<div class="nx-step"><b>3 · Where it\'s played</b><h3>From Auckland to Dublin</h3>'
        '<p>The strongest nations are New Zealand, South Africa, Ireland, France, England, Australia, Scotland, Argentina, Wales and Italy. '
        'Fiji, Samoa, Tonga, Japan and Georgia are rising.</p>'
        '<p class="s">The big events are the Six Nations in Europe (Feb–Mar), the Rugby Championship in the south (Aug–Oct) '
        'and the Rugby World Cup every four years. The next one is in Australia in 2027.</p></div>'
        '<div class="nx-step"><b>4 · This site</b><h3>Every Test since 1871</h3>'
        '<p>A match between two nations is called a Test. We hold every result back to the first one, Scotland v England in 1871, '
        'plus rankings, head-to-heads, trophies and player stats.</p>'
        '<p class="s">Start with the 60-second videos below, then pick a team from the menu to dig in.</p></div>'
        f'</div><p class="nx-next">{nxt}{later(today)}<a href="#fixtures">All fixtures &rarr;</a></p>'
        '</details></section>')


TF_CSS = """
.tf{padding-block:24px 0;min-width:0;max-width:100%;width:100%;box-sizing:border-box}
.tf-box{border:1px solid var(--line);border-radius:16px;background:var(--card);padding:16px 20px 18px}
.tf-hd{display:flex;align-items:center;justify-content:space-between;gap:10px 16px;flex-wrap:wrap}
.tf-hd h2{margin:0;font-size:20px;letter-spacing:-.01em}
.tf-sel{display:flex;align-items:center;gap:8px;min-width:0}
.tf-sel label{font-size:13px;color:var(--ink2)}
.tf-sel select{font:600 14px/1.2 var(--body);padding:8px 10px;border-radius:10px;border:1px solid var(--line);background:var(--bg);color:var(--ink);min-width:0;max-width:100%}
.tf-hint,.tf-empty{margin:10px 0 0;color:var(--ink2);font-size:14px}
.tf-list{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(250px,100%),1fr));gap:12px;margin-top:14px}
.tf-fx{border-top:3px solid #C9A24B;padding-top:10px;min-width:0}
.tf-fx time{display:block;font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin-bottom:4px}
.tf-fx h3{margin:0 0 4px;font-size:16px}
.tf-fx h3 b{color:var(--ink)}
.tf-fx p{margin:0;font-size:13px;color:var(--ink2);line-height:1.45}
.tf-fx .pk{margin-top:6px;font-size:13px;color:var(--ink)}
.tf-fx .tr{margin-top:8px;font-size:13px;color:var(--ink)}.tf-fact{margin-top:4px!important;font-size:12.5px!important;font-style:italic}
.tf-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.tf-chip{display:inline-flex;align-items:center;gap:6px;padding:6px 10px;border-radius:999px;border:1px solid var(--line);background:var(--bg);color:var(--ink);font:600 13px/1 var(--body);cursor:pointer}
.tf-chip{padding:0;gap:0;overflow:hidden;cursor:default}.tf-open,.tf-x{font:inherit;background:none;border:0;color:inherit;cursor:pointer;display:inline-flex;align-items:center;gap:6px}.tf-open{padding:7px 6px 7px 11px}.tf-x{padding:7px 11px 7px 4px;color:var(--ink2);font-size:16px;line-height:1}.tf-open:hover,.tf-x:hover{text-decoration:underline}.tf-chip:hover{border-color:var(--ink2)}.tf-chip img{height:14px;width:auto;border-radius:2px;vertical-align:-2px}
.tf-cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(280px,100%),1fr));gap:18px 24px;margin-top:14px}
.tf-sub{margin:0 0 8px;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.tf-stack{display:grid;gap:12px}.tf-stack .tf-fx h3 img,.tf-fx h3 img{height:15px;width:auto;border-radius:2px;vertical-align:-2px}
.tf-two{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(360px,100%),1fr));gap:0 20px;align-items:start;min-width:0}
.tf-two>*{min-width:0}.tf-two .panel{margin:24px 0 0;height:auto}
.rr{padding-block:24px 0}.rr-row{display:grid;grid-template-columns:52px 1fr auto 1fr;gap:2px 10px;align-items:center;padding:9px 0;border-top:1px solid var(--line);font-size:14px}
.rr-row:first-child{border-top:0}.rr-row time{color:var(--muted);font-size:12px}
.rr-t{background:none;border:0;padding:0;font:inherit;color:var(--ink2);cursor:pointer;min-width:0}.rr-t.w{color:var(--ink);font-weight:650}
.rr-h{text-align:right}.rr-a{text-align:left}.rr-t:hover{text-decoration:underline}
.rr-t img{height:13px;width:auto;border-radius:2px;vertical-align:-2px}
.rr-s{font-variant-numeric:tabular-nums;white-space:nowrap;color:var(--ink2)}.rr-s b.w{color:var(--ink)}
.rr-c{grid-column:2/-1;font-size:12px;color:var(--muted)}
.tf-more{margin:12px 0 0;font-size:14px}.tf-more a{color:inherit;font-weight:600}
"""

TF_JS = """
(function(){
var FX=__FX__,KEY="ra.teams",MAXT=4,box=document.getElementById("tfBox");if(!box)return;
function ld(k){try{return localStorage.getItem(k)}catch(e){return null}}
function sv(k,v){try{localStorage.setItem(k,v)}catch(e){}}
var sel=document.getElementById("tfSel"),chips=document.getElementById("tfChips"),out=document.getElementById("tfOut");
var N=(typeof ALL!=="undefined")?ALL:null,nt=(typeof NT!=="undefined")?NT:(N?N.length:0);
function idx(n){return N?N.findIndex(function(t){return t.name===n}):-1}
function isW(){try{return state.g==="w"}catch(e){return false}}
function isTop(i){return isW()?(typeof TOPW!=="undefined"&&TOPW.has(i)):i<nt}
var names=[];
function opt(t){return '<option>'+t+'</option>'}
function buildSel(){var top=[],rest=[];
if(N){for(var i=0;i<N.length;i++){(isTop(i)?top:rest).push(N[i].name)}}
if(!isW()){FX.forEach(function(f){[f.h,f.a].forEach(function(t){if(top.indexOf(t)<0&&!(N&&idx(t)>=nt))top.push(t)})})}
top.sort();rest.sort();names=top.concat(rest);
sel.innerHTML='<option value="">Add a team</option><optgroup label="Top teams">'+top.map(opt).join("")+'</optgroup>'+(rest.length?'<optgroup label="More nations">'+rest.map(opt).join("")+'</optgroup>':'')}
buildSel();
function flg(n){try{var i=idx(n);return i>=0&&typeof fl==="function"?fl(i):""}catch(e){return ""}}
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]})}
var fD=new Intl.DateTimeFormat(undefined,{weekday:"short",day:"numeric",month:"short"}),fS=new Intl.DateTimeFormat(undefined,{day:"numeric",month:"short"}),fT=new Intl.DateTimeFormat(undefined,{hour:"2-digit",minute:"2-digit",timeZoneName:"short"});
function cmp(c){return /rugby union internationals/.test(c||"")?"Test match":(c||"Test match")}
var teams=[];try{teams=JSON.parse(ld(KEY)||"[]")}catch(e){teams=[]}
if(!teams.length){var old=ld("ra.team");if(old)teams=[old]}
teams=teams.filter(function(t){return names.indexOf(t)>=0}).slice(0,MAXT);
function trophy(f){if(!f.tr)return "";return '<p class="tr"><b>Trophy on the line:</b> '+esc(f.tr.n)+(f.tr.y?' (since '+f.tr.y+')':'')+'</p>'+(f.tr.f?'<p class="tf-fact">'+esc(f.tr.f)+'</p>':'')}
function lastRes(t){if(typeof M==="undefined"||!N)return null;for(var k=M.length-1;k>=0;k--){var m=M[k];if(N[m.h].name===t||N[m.a].name===t)return m}return null}
function resCard(m,t){var h=N[m.h].name,a=N[m.a].name,mine=h===t?m.hs-m.as:m.as-m.hs,tag=mine>0?"Won":mine<0?"Lost":"Drew";
  return '<article class="tf-fx"><time>'+esc(t)+' · '+tag+' · '+fS.format(new Date(m.date+"T12:00:00"))+'</time><h3>'+flg(h)+' '+esc(h)+' <b>'+m.hs+'–'+m.as+'</b> '+esc(a)+' '+flg(a)+'</h3><p>'+esc(cmp(m.comp))+'</p></article>'}
function render(){
  chips.innerHTML=teams.map(function(t){return '<span class="tf-chip"><button type="button" class="tf-open" data-o="'+esc(t)+'" aria-label="Open the '+esc(t)+' page">'+flg(t)+' '+esc(t)+'</button><button type="button" class="tf-x" data-t="'+esc(t)+'" aria-label="Remove '+esc(t)+'">&times;</button></span>'}).join("");
  if(!teams.length){out.innerHTML='<p class="tf-hint">Add up to '+MAXT+' teams to see what they play next and how they last got on. Tap a team to open its full page. Your picks stay on this device.</p>';return}
  var now=Date.now();
  var items=isW()?[]:FX.filter(function(f){return teams.indexOf(f.h)>=0||teams.indexOf(f.a)>=0}).map(function(f){var tbc=!f.ko;return {f:f,tbc:tbc,t:tbc?new Date(f.d+"T12:00:00Z"):new Date(f.ko)}})
    .filter(function(x){return x.t.getTime()+3*36e5>now}).sort(function(a,b){return a.t-b.t}).slice(0,4);
  var up=items.length?items.map(function(x){var f=x.f,pick=f.p>=.5?[f.h,f.p]:[f.a,1-f.p];
    var when=x.tbc?fD.format(new Date(f.d+"T12:00:00"))+" · time TBC":fD.format(x.t)+" · "+fT.format(x.t);
    return '<article class="tf-fx"><time>'+esc(when)+'</time><h3>'+flg(f.h)+' '+esc(f.h)+' v '+esc(f.a)+' '+flg(f.a)+'</h3><p>'+esc(f.c||"Test match")+(f.v?' · '+esc(f.v):'')+'</p><p class="pk">Model pick: <b>'+esc(pick[0])+'</b> '+Math.round(pick[1]*100)+'%</p>'+trophy(f)+'</article>'}).join(""):(isW()?'<p class="tf-empty">We do not have a women Test fixture list yet.</p>':'<p class="tf-empty">No confirmed Tests for your teams in our fixture list yet. It updates daily.</p>');
  var seen={},last=teams.map(function(t){var m=lastRes(t);if(!m)return "";var key=m.date+m.h+m.a;if(seen[key])return "";seen[key]=1;return resCard(m,t)}).join("");
  out.innerHTML='<div class="tf-cols"><div><h3 class="tf-sub">Next up</h3><div class="tf-stack">'+up+'</div></div><div><h3 class="tf-sub">Last time out</h3><div class="tf-stack">'+(last||'<p class="tf-empty">No results found.</p>')+'</div></div></div><p class="tf-more"><a href="#fixtures">All fixtures &rarr;</a></p>'}
function save(){sv(KEY,JSON.stringify(teams));render()}
sel.addEventListener("change",function(){var v=sel.value;sel.value="";if(!v||teams.indexOf(v)>=0)return;if(teams.length>=MAXT)teams.shift();teams.push(v);save()});
chips.addEventListener("click",function(e){var o=e.target.closest("button[data-o]");if(o){var i=idx(o.getAttribute("data-o"));if(i>=0&&typeof setTeam==="function"){setTeam(i);scrollTo({top:0})}return}
  var b=e.target.closest("button[data-t]");if(!b)return;teams=teams.filter(function(t){return t!==b.getAttribute("data-t")});save()});
render();

/* Recent results strip */
var ro=document.getElementById("rrOut");
function buildRecent(){try{if(!(ro&&typeof M!=="undefined"&&N))return;
var today=new Date().toISOString().slice(0,10),all=[];
  for(var k=M.length-1;k>=0&&all.length<40;k--){var m=M[k];if(m.date>today)continue;if(!isTop(m.h)||!isTop(m.a))continue;all.push(m)}
  all.sort(function(x,y){return x.date<y.date?1:x.date>y.date?-1:0});
  var cut=new Date(Date.now()-10*864e5).toISOString().slice(0,10),pick=all.filter(function(m){return m.date>=cut}).slice(0,8);
  if(pick.length<4)pick=all.slice(0,6);
  ro.innerHTML=pick.map(function(m){var h=N[m.h].name,a=N[m.a].name,hw=m.hs>m.as,aw=m.as>m.hs;
    return '<div class="rr-row"><time>'+fS.format(new Date(m.date+"T12:00:00"))+'</time><button type="button" class="rr-t rr-h'+(hw?' w':'')+'" data-i="'+m.h+'">'+esc(h)+' '+flg(h)+'</button><span class="rr-s"><b class="'+(hw?'w':'')+'">'+m.hs+'</b>&ndash;<b class="'+(aw?'w':'')+'">'+m.as+'</b></span><button type="button" class="rr-t rr-a'+(aw?' w':'')+'" data-i="'+m.a+'">'+flg(a)+' '+esc(a)+'</button><span class="rr-c">'+esc(cmp(m.comp))+(m.venue&&m.venue[1]?' · '+esc(m.venue[1]):'')+'</span></div>'}).join("")||'<p class="tf-empty">No recent results yet.</p>';
}catch(e){}}
buildRecent();
try{if(ro)ro.addEventListener("click",function(e){var b=e.target.closest("button[data-i]");if(!b||typeof setTeam!=="function")return;setTeam(+b.getAttribute("data-i"));scrollTo({top:0})})}catch(e){}
try{if(typeof setGender==="function"){var _sg=setGender;setGender=function(){var r=_sg.apply(this,arguments);try{buildSel();render();buildRecent()}catch(e){}return r}}}catch(e){}

/* Home order: your teams, results + coming up, videos, previews, then the beginner guide */
try{var md=document.getElementById("matchday"),g=function(i){return document.getElementById(i)},nx=g("nx"),later=g("mdLaterWrap"),rr=g("rr"),sx=g("sx"),cards=g("mdCards"),src=g("mdSrc");
if(md&&nx&&rr&&later){var wrap=document.createElement("div");wrap.className="tf-two";md.insertBefore(wrap,nx);wrap.appendChild(rr);wrap.appendChild(later);if(src)md.insertBefore(src,nx);if(sx)md.insertBefore(sx,nx);if(cards)md.insertBefore(cards,nx)}
var det=nx&&nx.querySelector("details");if(det){if(ld("ra.seen"))det.open=false;sv("ra.seen","1")}}catch(e){}
})();
"""


# short, sourced stories for individual trophies (shown under the fixture when that trophy is on the line)
TROPHY_FACTS = {
    'Bledisloe Cup': ('A 1932 newspaper report put the cup at 28 inches (71 cm) tall without its oak plinth, 25 inches wide and 290 oz. '
                      'Lord Bledisloe called the design the work of a New Zealand artist, but designer Nelson Isaac was born in Victoria, Australia.'),
}


def trophy_for(h, a):
    """The bilateral trophy, if any, two nations play for outside the Six Nations (from pipeline/trophies.json)."""
    try:
        tr = json.load(open(os.path.join(HERE, 'trophies.json'), encoding='utf-8'))
    except (FileNotFoundError, ValueError):
        return None
    for t in tr:
        if t.get('kind') == 'bilateral' and t.get('g') == 'm' and not t.get('comp') and {h, a} == set(t.get('teams', [])):
            out = {'n': t['name'], 'y': t.get('founded')}
            if t['name'] in TROPHY_FACTS:
                out['f'] = TROPHY_FACTS[t['name']]
            return out
    return None


def teamfix(today):
    """"Your team's next Tests" picker for the home view, from the same fixtures.json the daily refresh writes."""
    try:
        fx = json.load(open(os.path.join(HERE, 'fixtures.json'), encoding='utf-8'))
    except (FileNotFoundError, ValueError):
        return '', ''
    keep = [{k: f[k] for k in ('ko', 'd', 'h', 'a', 'c', 'v', 'p') if k in f} for f in fx
            if f.get('g') != 'w' and (f.get('ko') or f.get('d') or '')[:10] >= (today - dt.timedelta(days=1)).isoformat()]
    for k in keep:
        t = trophy_for(k['h'], k['a'])
        if t:
            k['tr'] = t
    if not keep:
        return '', ''
    block = ('<section class="tf" id="tf" aria-labelledby="tfH"><div class="tf-box" id="tfBox"><div class="tf-hd"><h2 id="tfH">For you</h2>'
             '<div class="tf-sel"><label for="tfSel">Team</label><select id="tfSel"></select></div></div><div class="tf-chips" id="tfChips"></div><div id="tfOut"></div></div></section>'
             '<section class="tf rr" id="rr" aria-labelledby="rrH"><div class="tf-box"><div class="tf-hd"><h2 id="rrH">Recent results</h2></div><div id="rrOut"></div></div></section>')
    js = TF_JS.replace('__FX__', json.dumps(keep, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/'))
    return block, js


def build(today=None):
    today = today or dt.date.today()
    cfg = json.load(open(os.path.join(HERE, 'stories.json'), encoding='utf-8'))
    ig, fb = cfg['instagram'], cfg['facebook']
    items = [i for i in cfg['items']
             if dt.date.fromisoformat(i['date']) <= today and os.path.exists(os.path.join(SITE, 'stories', i['id'] + '.mp4'))]
    items.sort(key=lambda i: i['date'], reverse=True)
    items = items[:SHOW]

    btns = (f'<a class="sx-btn" href="{ig}" target="_blank" rel="noopener">{IG_SVG}Instagram</a>'
            f'<a class="sx-btn" href="{fb}" target="_blank" rel="noopener">{FB_SVG}Facebook</a>')
    bar = (f'<div class="sx-bar" id="sxBar"><div class="wrap"><p><b>New here?</b> We turn these numbers into '
           f'60-second videos and quick reads every day.</p><div class="sx-btns">{btns}</div>'
           f'<button class="sx-x" id="sxX" aria-label="Hide this message">&times;</button></div></div>')

    cards = []
    for i in items:
        d = dt.date.fromisoformat(i['date'])
        src, poster = f"stories/{i['id']}.mp4", f"stories/{i['id']}.jpg"
        cards.append(
            f'<article class="sx-card"><div class="sx-media"><img src="{poster}" alt="" loading="lazy" width="540" height="960">'
            f'<button class="sx-play" data-src="{src}" data-poster="{poster}" aria-label="Play: {html.escape(i["title"])}">'
            f'<span>{PLAY_SVG}</span></button></div>'
            f'<time datetime="{i["date"]}">{fmt_date(d)}</time><h3>{html.escape(i["title"])}</h3>'
            f'<p>{html.escape(i["line"])}</p></article>')
    cards.append(f'<div class="sx-cta"><h3>A new one every day</h3><p>Follow us for videos like these, '
                 f'match-day previews and results the moment the whistle goes.</p><div class="sx-btns">{btns}</div></div>')
    section = ('' if not items else
               f'<section class="sx" id="sx" aria-labelledby="sxH"><div class="sx-hd"><div><h2 id="sxH">The data in 60 seconds</h2>'
               f'<p>Short videos on the stories hiding in the numbers. Tap to play.</p></div></div>'
               f'<div class="sx-row">{"".join(cards)}</div></section>')
    foot = f'<div class="wrap sx-foot" id="sxFoot"><span>Follow Rugby Analysis:</span><div class="sx-btns">{btns}</div></div>'

    path = os.path.join(SITE, 'index.html')
    page = open(path, encoding='utf-8').read()
    # remove anything a previous run inserted, so the build can run again safely
    page = re.sub(r'<!--sx:start-->.*?<!--sx:end-->', '', page, flags=re.S)
    wrap = lambda s: f'<!--sx:start-->{s}<!--sx:end-->'
    page = page.replace('</head>', wrap(f'<style>{CSS}{TF_CSS}</style>') + '</head>', 1)
    page = page.replace('</nav>', '</nav>' + wrap(bar), 1)
    tf_html, tf_js = teamfix(today)
    block = wrap(tf_html + intro(today) + section)
    # top of the Match Centre (the home view), above the match-day preview cards
    if '<div id="mdCards">' in page:
        page = page.replace('<div id="mdCards">', block + '<div id="mdCards">', 1)
    else:  # fallback if the page layout changes: straight after the hero, inside a page-width wrapper
        page = page.replace('</header>', '</header>' + wrap(f'<div class="wrap">{tf_html + intro(today) + section}</div>'), 1)
    page = re.sub(r'(<footer\b[^>]*>.*?</footer>)', lambda m: m.group(1) + wrap(foot), page, count=1, flags=re.S)
    page = page.replace('</body>', wrap(f'<script>{JS}</script>' + (f'<script>{tf_js}</script>' if tf_js else '')) + '</body>', 1)
    # small fixes to the Match Centre script (pipeline/matchday.js) applied to the built page
    for bad, good in FIXES:
        page = page.replace(bad, good)
    open(path, 'w', encoding='utf-8').write(page)
    print(f'stories: {len(items)} shown ({", ".join(i["id"] for i in items)})')


if __name__ == '__main__':
    build()
