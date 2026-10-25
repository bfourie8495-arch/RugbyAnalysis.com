"""Adds a "For you" box (pick up to 4 teams) and a Latest tournaments strip to the Sevens page.
Runs after build_site.py, edits site/sevens.html in place, safe to re-run (markers)."""
import os, re, json

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, '..', 'site', 'sevens.html')
CAL = json.load(open(os.path.join(HERE, 'sevens_calendar.json'), encoding='utf-8'))

CSS = """
.sf{padding-block:0 4px;min-width:0}
.sf-box,.sf-lt{border:1px solid var(--line);border-radius:16px;background:var(--card);padding:16px 20px 18px;margin-top:20px;min-width:0}
.sf-hd{display:flex;align-items:center;justify-content:space-between;gap:10px 16px;flex-wrap:wrap}
.sf-hd h2{margin:0;font-size:20px;letter-spacing:-.01em}
.sf-sel select{font:600 14px/1.2 var(--body);padding:8px 10px;border-radius:10px;border:1px solid var(--line);background:var(--bg);color:var(--ink);min-width:0;max-width:100%}
.sf-hint,.sf-empty,.sf-note{margin:10px 0 0;color:var(--ink2);font-size:14px}
.sf-note{font-size:12px;color:var(--muted)}
.sf-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.sf-chip{display:inline-flex;align-items:center;border-radius:999px;border:1px solid var(--line);background:var(--bg);color:var(--ink);font:600 13px/1 var(--body);overflow:hidden}
.sf-chip img,.sf-row img{width:18px;height:18px;border-radius:50%;object-fit:cover;flex:none}
.sf-open,.sf-x{font:inherit;background:none;border:0;color:inherit;cursor:pointer;display:inline-flex;align-items:center;gap:6px}
.sf-open{padding:6px 6px 6px 8px}.sf-x{padding:6px 11px 6px 4px;color:var(--ink2);font-size:16px;line-height:1}
.sf-open:hover,.sf-x:hover{text-decoration:underline}
.sf-cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(260px,100%),1fr));gap:18px 24px;margin-top:14px}
.sf-sub{margin:0 0 8px;font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
.sf-card{border-top:3px solid var(--acc-l);padding-top:10px;min-width:0}
.sf-card h3{margin:0 0 4px;font-size:16px;display:flex;align-items:center;gap:6px}
.sf-card h3 img{width:20px;height:20px;border-radius:50%;object-fit:cover}
.sf-card p{margin:0 0 2px;font-size:13px;color:var(--ink2);line-height:1.45}
.sf-next{margin-top:16px;padding-top:12px;border-top:1px solid var(--line)}
.sf-next b{color:var(--ink)}
.sf-list{display:grid;gap:0;margin-top:8px}
.sf-row{display:flex;align-items:center;flex-wrap:wrap;gap:4px 10px;padding:9px 0;border-top:1px solid var(--line);font-size:14px;min-width:0}
.sf-row:first-child{border-top:0}
.sf-row time{flex:0 0 74px;color:var(--muted);font-size:12px;letter-spacing:.04em;text-transform:uppercase}
.sf-row .t{flex:1 1 200px;min-width:0;color:var(--ink2)}
.sf-row .w{display:inline-flex;align-items:center;gap:6px;font-weight:600;color:var(--ink)}
.sf-row .sc{font-variant-numeric:tabular-nums;color:var(--ink2);white-space:nowrap}
"""

HTML = ('<!--sf:start--><div class="sf" id="sf">'
  '<section class="sf-box" id="sfBox"><div class="sf-hd"><h2>For you</h2>'
  '<div class="sf-sel"><select id="sfSel" aria-label="Add a team"></select></div></div>'
  '<div class="sf-chips" id="sfChips"></div><div id="sfOut"></div></section>'
  '<section class="sf-lt" id="sfLt"><div class="sf-hd"><h2 id="sfLtH">Latest tournaments</h2></div>'
  '<div class="sf-list" id="sfLtOut"></div></section></div><!--sf:end-->')

JS = """<!--sf:js:start--><script>(function(){
var CAL=__CAL__,MAXT=4;
function keyF(){return"ra.sevens."+state.g}
function load(){try{var a=JSON.parse(localStorage.getItem(keyF())||"[]");return Array.isArray(a)?a.filter(function(t){return typeof t==="string"}).slice(0,MAXT):[]}catch(e){return[]}}
function save(a){try{localStorage.setItem(keyF(),JSON.stringify(a))}catch(e){}}
function evs(){return D.events.filter(function(e){return e.g===state.g}).slice().sort(function(a,b){return a.ym<b.ym?1:a.ym>b.ym?-1:0})}
function teams(){var s={};D.events.forEach(function(e){if(e.g===state.g){if(e.ch)s[e.ch]=1;if(e.ru)s[e.ru]=1}});return Object.keys(s).sort()}
function lastFinal(t){var l=evs();for(var i=0;i<l.length;i++){if(l[i].ch===t||l[i].ru===t)return l[i]}return null}
function score(e){return e.s1!=null&&e.s2!=null?e.s1+"–"+e.s2:""}
function fmtD(s,e){var a=s.split("-"),b=e.split("-");var m=MONS[a[1]-1],d1=+a[2],d2=+b[2];return d1+"–"+d2+" "+(a[1]===b[1]?m:m+"/"+MONS[b[1]-1])+" "+a[0]}
function nextEv(){var t=new Date().toISOString().slice(0,10);return CAL.events.filter(function(e){return e.end>=t})[0]||null}
function card(t){var e=lastFinal(t),h='<div class="sf-card"><h3>'+fl(t)+esc(t)+'</h3>';
  if(!e)h+='<p>No tournament final on record yet.</p>';
  else{var win=e.ch===t,opp=win?e.ru:e.ch;
    h+='<p><b>'+(win?'Won':'Runner-up')+'</b> at '+esc(e.title)+'</p>'+
       '<p>'+(win?'Beat ':'Lost to ')+esc(opp||"")+(score(e)?' '+(win?score(e):e.s2+"–"+e.s1):"")+' · '+esc(ymTxt(e.ym))+'</p>';}
  return h+'</div>'}
function renderFor(){var sel=$("sfSel"),mine=load(),all=teams();
  sel.innerHTML='<option value="">Add a team…</option>'+all.filter(function(t){return mine.indexOf(t)<0}).map(function(t){return'<option value="'+esc(t)+'">'+esc(t)+'</option>'}).join("");
  sel.disabled=mine.length>=MAXT;
  $("sfChips").innerHTML=mine.map(function(t){return'<span class="sf-chip"><button class="sf-open" data-o="'+esc(t)+'">'+fl(t)+esc(t)+'</button><button class="sf-x" data-t="'+esc(t)+'" aria-label="Remove '+esc(t)+'">×</button></span>'}).join("");
  var out=$("sfOut");
  if(!mine.length){out.innerHTML='<p class="sf-empty">Pick up to '+MAXT+' teams to see how they last fared. Tap a team to open its full page.</p>';return}
  var n=nextEv(),h='<p class="sf-hint">Tap a team to open its full page.</p><div class="sf-cols">'+mine.map(card).join("")+'</div>';
  if(n)h+='<div class="sf-next"><p class="sf-sub">Next on the calendar</p><p><b>'+esc(n.name)+'</b> · '+fmtD(n.start,n.end)+' · '+esc(n.venue)+'</p><p class="sf-note">Dates from World Rugby\\'s 2026/27 schedule. Check the official site for the men\\'s and women\\'s draws.</p></div>';
  out.innerHTML=h}
function renderLatest(){var l=evs().slice(0,6);$("sfLtH").textContent="Latest "+(state.g==="w"?"women's":"men's")+" tournaments";
  $("sfLtOut").innerHTML=l.map(function(e){var sc=score(e);return'<div class="sf-row"><time>'+esc(ymTxt(e.ym))+'</time><span class="t">'+esc(e.title)+'</span><span class="w">'+fl(e.ch)+esc(e.ch||"")+'</span><span class="sc">'+(e.ru?'beat '+esc(e.ru)+(sc?' '+sc:''):'')+'</span></div>'}).join("")}
function openTeam(t){state.team=t;state.tfAll=false;buildPicker();go();scrollTo({top:0})}
$("sf").addEventListener("click",function(ev){var o=ev.target.closest(".sf-open"),x=ev.target.closest(".sf-x");
  if(o){openTeam(o.dataset.o);return}
  if(x){save(load().filter(function(t){return t!==x.dataset.t}));renderFor()}});
$("sfSel").addEventListener("change",function(){var v=this.value;if(!v)return;var a=load();if(a.indexOf(v)<0&&a.length<MAXT)a.push(v);save(a);renderFor()});
var _render=render;render=function(){var r=_render.apply(this,arguments);try{renderFor();renderLatest()}catch(e){}return r};
try{renderFor();renderLatest()}catch(e){}
})();</script><!--sf:js:end-->"""

def build():
    h = open(PATH, encoding='utf-8').read()
    h = re.sub(r'<!--sf:start-->.*?<!--sf:end-->', '', h, flags=re.S)
    h = re.sub(r'<!--sf:js:start-->.*?<!--sf:js:end-->', '', h, flags=re.S)
    h = re.sub(r'<style id="sfcss">.*?</style>', '', h, flags=re.S)
    anchor = '<main class="wrap" id="ov">'
    if anchor not in h:
        print('align_sevens: layout anchor not found, skipped'); return
    js = JS.replace('__CAL__', json.dumps(CAL, ensure_ascii=False))
    h = h.replace('</head>', '<style id="sfcss">' + CSS + '</style></head>', 1)
    h = h.replace(anchor, anchor + HTML, 1)
    h = h.replace('</body>', js + '</body>', 1)
    open(PATH, 'w', encoding='utf-8').write(h)
    print('align_sevens: For you + Latest tournaments added')

if __name__ == '__main__':
    build()
