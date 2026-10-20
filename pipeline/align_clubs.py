"""Adds the home-page style "For you" box and a Recent results strip to the Club page.
Runs after build_site.py, edits site/clubs.html in place, and is safe to re-run (markers)."""
import os, re

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, '..', 'site', 'clubs.html')

CSS = """
.cf{padding-block:0 4px;min-width:0}
.cf-box{border:1px solid var(--line);border-radius:16px;background:var(--card);padding:16px 20px 18px;margin-top:20px;min-width:0}
.cf-hd{display:flex;align-items:center;justify-content:space-between;gap:10px 16px;flex-wrap:wrap}
.cf-hd h2{margin:0;font-size:20px;letter-spacing:-.01em}
.cf-sel{display:flex;align-items:center;gap:8px;min-width:0}
.cf-sel select{font:600 14px/1.2 var(--body);padding:8px 10px;border-radius:10px;border:1px solid var(--line);background:var(--bg);color:var(--ink);min-width:0;max-width:100%}
.cf-hint,.cf-empty{margin:10px 0 0;color:var(--ink2);font-size:14px}
.cf-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.cf-chip{display:inline-flex;align-items:center;border-radius:999px;border:1px solid var(--line);background:var(--bg);color:var(--ink);font:600 13px/1 var(--body);overflow:hidden}
.cf-chip:hover{border-color:var(--ink2)}
.cf-open,.cf-x{font:inherit;background:none;border:0;color:inherit;cursor:pointer;display:inline-flex;align-items:center;gap:6px}
.cf-open{padding:6px 6px 6px 8px}.cf-x{padding:6px 11px 6px 4px;color:var(--ink2);font-size:16px;line-height:1}
.cf-open:hover,.cf-x:hover{text-decoration:underline}
.cf-cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(280px,100%),1fr));gap:18px 24px;margin-top:14px}
.cf-sub{margin:0 0 8px;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.cf-stack{display:grid;gap:12px}
.cf-fx{border-top:3px solid #C9A24B;padding-top:10px;min-width:0}
.cf-fx time{display:block;font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--muted);margin-bottom:4px}
.cf-fx h3{margin:0 0 4px;font-size:16px;display:flex;align-items:center;flex-wrap:wrap;gap:4px 6px}
.cf-fx h3 b{color:var(--ink)}
.cf-fx p{margin:0;font-size:13px;color:var(--ink2);line-height:1.45}
.cr{margin-top:20px;display:block!important}.cr .cf-hd{margin-bottom:6px}
.cr-row{display:grid;grid-template-columns:52px 1fr auto 1fr;gap:2px 10px;align-items:center;padding:9px 0;border-top:1px solid var(--line);font-size:14px}
.cr-row:first-child{border-top:0}.cr-row time{color:var(--muted);font-size:12px}
.cr-t{background:none;border:0;padding:0;font:inherit;color:var(--ink2);cursor:pointer;min-width:0;display:inline-flex;align-items:center;gap:6px}
.cr-t.w{color:var(--ink);font-weight:650}.cr-t:hover{text-decoration:underline}
.cr-h{justify-content:flex-end;text-align:right}.cr-a{justify-content:flex-start;text-align:left}
.cr-s{display:inline-flex;gap:3px;align-items:baseline;font-variant-numeric:tabular-nums;white-space:nowrap;color:var(--ink2)}.cr-s .sc.w{color:var(--ink);font-weight:650}
.cr-c{grid-column:2/-1;font-size:12px;color:var(--muted)}
@media(max-width:520px){.cr-row{grid-template-columns:44px 1fr auto 1fr;gap:2px 6px;font-size:13px}.cr-t .mono{display:none}}
"""

HTML = """<!--cf:start--><div class="cf" id="cf"><section class="cf-box" id="cfBox" aria-label="Your clubs">
<div class="cf-hd"><h2>For you</h2><div class="cf-sel"><select id="cfSel" aria-label="Add a club"><option value="">Add a club</option></select></div></div>
<div class="cf-chips" id="cfChips"></div><div id="cfOut"></div></section>
<section class="panel cr" id="cr"><div class="cf-hd"><h2>Recent results</h2></div><div id="crOut"></div></section></div><!--cf:end-->"""

JS = """<!--cf:js:start--><script>
(function(){
var box=document.getElementById("cfBox");if(!box||typeof D==="undefined"||typeof M==="undefined")return;
var KEY="ra.clubs",MAXT=4;
function ld(k){try{return localStorage.getItem(k)}catch(e){return null}}
function sv(k,v){try{localStorage.setItem(k,v)}catch(e){}}
var sel=document.getElementById("cfSel"),chips=document.getElementById("cfChips"),out=document.getElementById("cfOut"),ro=document.getElementById("crOut");
var byId={};C.forEach(function(c,i){byId[c.id]=i});
var dD=new Intl.DateTimeFormat(undefined,{weekday:"short",day:"numeric",month:"short"}),dS=new Intl.DateTimeFormat(undefined,{day:"numeric",month:"short"}),dT=new Intl.DateTimeFormat(undefined,{hour:"2-digit",minute:"2-digit",timeZoneName:"short"});
var used={};M.forEach(function(m){used[m.h]=1;used[m.a]=1});
var groups=LEAGUES.map(function(L,li){return {L:L,list:C.map(function(c,i){return i}).filter(function(i){return LIDX[C[i].lg]===li&&used[i]}).sort(function(a,b){return nm(a).localeCompare(nm(b))})}}).filter(function(g){return g.list.length});
sel.innerHTML='<option value="">Add a club</option>'+groups.map(function(g){return '<optgroup label="'+esc(g.L.short)+'">'+g.list.map(function(i){return '<option value="'+esc(C[i].id)+'">'+esc(nm(i))+'</option>'}).join("")+'</optgroup>'}).join("");
var teams=[];try{teams=JSON.parse(ld(KEY)||"[]")}catch(e){teams=[]}
teams=teams.filter(function(t){return byId[t]!==undefined}).slice(0,MAXT);
function openClub(i){var li=LIDX[C[i].lg];state.lg=li;state.g=LEAGUES[li].g;state.s=defSeason(li);state.prev=-2;buildPicker();state.club=i;state.opp=-1;go();scrollTo({top:0})}
function lg(m){var s=stageTxt(m);return LEAGUES[m.lg].short+(s?" · "+s:"")}
function when(m){var k=m.time?koUTC(m):null;return k?dD.format(k)+" · "+dT.format(k):dD.format(new Date(m.date+"T12:00:00"))+" · time TBC"}
function resCard(m,i){var v=view(m,i),tag=v.res==="W"?"Won":v.res==="L"?"Lost":"Drew";
  return '<article class="cf-fx"><time>'+esc(nm(i))+' · '+tag+' · '+dS.format(new Date(m.date+"T12:00:00"))+'</time><h3>'+mono(m.h,"sm")+' '+esc(nm(m.h))+' <b>'+m.hs+'–'+m.as+'</b> '+esc(nm(m.a))+' '+mono(m.a,"sm")+'</h3><p>'+esc(lg(m))+'</p></article>'}
function renderFor(){
  chips.innerHTML=teams.map(function(t){var i=byId[t];return '<span class="cf-chip"><button type="button" class="cf-open" data-o="'+esc(t)+'" aria-label="Open the '+esc(nm(i))+' page">'+mono(i,"sm")+' '+esc(nm(i))+'</button><button type="button" class="cf-x" data-t="'+esc(t)+'" aria-label="Remove '+esc(nm(i))+'">&times;</button></span>'}).join("");
  if(!teams.length){out.innerHTML='<p class="cf-hint">Add up to '+MAXT+' clubs to see what they play next and how they last got on. Tap a club to open its full page. Your picks stay on this device.</p>';return}
  var ids=teams.map(function(t){return byId[t]}),now=Date.now();
  var up=M.filter(function(m){return !played(m)&&!m.nd&&(ids.indexOf(m.h)>=0||ids.indexOf(m.a)>=0)&&(koUTC(m)||new Date(m.date+"T23:00:00Z"))>now-3*36e5})
    .sort(function(a,b){return a.date.localeCompare(b.date)||(a.time||"").localeCompare(b.time||"")}).slice(0,4);
  var upH=up.length?up.map(function(m){return '<article class="cf-fx"><time>'+esc(when(m))+'</time><h3>'+mono(m.h,"sm")+' '+esc(nm(m.h))+' v '+esc(nm(m.a))+' '+mono(m.a,"sm")+'</h3><p>'+esc(lg(m))+(m.venue&&!/^(TBC|TBA)$/i.test(m.venue)?' · '+esc(m.venue):'')+'</p></article>'}).join(""):'<p class="cf-empty">No confirmed fixtures for your clubs yet. This updates daily.</p>';
  var seen={},last=ids.map(function(i){var g=M.filter(function(m){return played(m)&&!m.nd&&(m.h===i||m.a===i)}).sort(function(a,b){return b.date.localeCompare(a.date)||(b.time||"").localeCompare(a.time||"")});
    var m=g[0];if(!m||seen[m.k])return "";seen[m.k]=1;return resCard(m,i)}).join("");
  out.innerHTML='<div class="cf-cols"><div><h3 class="cf-sub">Next up</h3><div class="cf-stack">'+upH+'</div></div><div><h3 class="cf-sub">Last time out</h3><div class="cf-stack">'+(last||'<p class="cf-empty">No results found.</p>')+'</div></div></div>'}
function renderRecent(){
  var today=new Date().toISOString().slice(0,10),all=M.filter(function(m){return played(m)&&!m.nd&&m.date<=today&&LEAGUES[m.lg].g===state.g})
    .sort(function(a,b){return b.date.localeCompare(a.date)||(b.time||"").localeCompare(a.time||"")});
  var cut=new Date(Date.now()-7*864e5).toISOString().slice(0,10),pick=all.filter(function(m){return m.date>=cut}).slice(0,8);
  if(pick.length<4)pick=all.slice(0,6);
  ro.innerHTML=pick.map(function(m){var hw=m.hs>m.as,aw=m.as>m.hs;
    return '<div class="cr-row"><time>'+dS.format(new Date(m.date+"T12:00:00"))+'</time><button type="button" class="cr-t cr-h'+(hw?' w':'')+'" data-i="'+m.h+'">'+esc(nm(m.h))+' '+mono(m.h,"sm")+'</button><span class="cr-s"><span class="sc'+(hw?' w':'')+'">'+m.hs+'</span><span>&ndash;</span><span class="sc'+(aw?' w':'')+'">'+m.as+'</span></span><button type="button" class="cr-t cr-a'+(aw?' w':'')+'" data-i="'+m.a+'">'+mono(m.a,"sm")+' '+esc(nm(m.a))+'</button><span class="cr-c">'+esc(lg(m))+'</span></div>'}).join("")||'<p class="cf-empty">No recent results yet.</p>'}
function save(){sv(KEY,JSON.stringify(teams));renderFor()}
sel.addEventListener("change",function(){var v=sel.value;sel.value="";if(!v||teams.indexOf(v)>=0)return;if(teams.length>=MAXT)teams.shift();teams.push(v);save()});
chips.addEventListener("click",function(e){var o=e.target.closest("button[data-o]");if(o){openClub(byId[o.getAttribute("data-o")]);return}
  var b=e.target.closest("button[data-t]");if(!b)return;teams=teams.filter(function(t){return t!==b.getAttribute("data-t")});save()});
ro.addEventListener("click",function(e){var b=e.target.closest("button[data-i]");if(b)openClub(+b.getAttribute("data-i"))});
var _render=render;render=function(){var r=_render.apply(this,arguments);try{renderRecent()}catch(e){}return r};
renderFor();renderRecent();
})();
</script><!--cf:js:end-->"""

def build():
    h = open(PATH, encoding='utf-8').read()
    h = re.sub(r'<!--cf:start-->.*?<!--cf:end-->', '', h, flags=re.S)
    h = re.sub(r'<!--cf:js:start-->.*?<!--cf:js:end-->', '', h, flags=re.S)
    h = re.sub(r'<style id="cfcss">.*?</style>', '', h, flags=re.S)
    anchor = '<main class="wrap" id="lgView">'
    if anchor not in h:
        print('align_clubs: layout anchor not found, skipped'); return
    h = h.replace('</head>', '<style id="cfcss">' + CSS + '</style></head>', 1)
    h = h.replace(anchor, anchor + HTML, 1)
    h = h.replace('</body>', JS + '</body>', 1)
    open(PATH, 'w', encoding='utf-8').write(h)
    print('align_clubs: For you + Recent results added')

if __name__ == '__main__':
    build()
