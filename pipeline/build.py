import pandas as pd, json, base64, re
s=open('template.html').read()
d=pd.read_csv('RugbyResults_AllNations_Detailed.csv',sep=';')
d['date']=pd.to_datetime(d.date.str.replace('/','-'))
d=d.sort_values('date',kind='stable')
T10=['Argentina','Australia','England','France','Ireland','Italy','New Zealand','Scotland','South Africa','Wales']
oth=json.load(open('others.json'))
others=sorted(oth)
names=T10+others
slug=lambda n:re.sub(r'[^a-z0-9]+','-',n.lower().replace('é','e').replace('ç','c')).strip('-')
idx={n:i for i,n in enumerate(names)}
def pack(d):
  comps=sorted(d.competition.fillna('').unique()); venues=sorted((d.stadium.fillna('')+'|'+d.city.fillna('')).unique())
  rows=[[r.date.strftime('%Y-%m-%d'),idx[r.home_team],idx[r.away_team],int(r.home_score),int(r.away_score),comps.index(r.competition if isinstance(r.competition,str) else ''),venues.index((r.stadium if isinstance(r.stadium,str) else '')+'|'+(r.city if isinstance(r.city,str) else '')),int(bool(r.neutral)),int(bool(r.world_cup))] for r in d.itertuples()]
  def iv(v):
      return None if pd.isna(v) or v=='' else int(float(v))
  refs=sorted(set(x for x in d.referee.fillna('') if x));ridx={r:i for i,r in enumerate(refs)}
  det=[]
  for r in d.itertuples():
      sc=[iv(getattr(r,k)) for k in ['home_tries','away_tries','home_cons','away_cons','home_cons_att','away_cons_att','home_pens','away_pens','home_pens_att','away_pens_att','home_drops','away_drops']]
      cd=[iv(getattr(r,k)) for k in ['home_yellow','away_yellow','home_red','away_red']]
      ref=r.referee if isinstance(r.referee,str) and r.referee else None;att=iv(r.attendance)
      if sc[0] is None and cd[0] is None and ref is None and att is None: det.append(0);continue
      det.append([sc if sc[0] is not None else 0,cd if cd[0] is not None else 0,ridx[ref] if ref else -1,att or 0,r.home_try_scorers if isinstance(r.home_try_scorers,str) else '',r.away_try_scorers if isinstance(r.away_try_scorers,str) else ''])
  return json.dumps({'c':comps,'v':venues,'m':rows,'det':det,'refs':refs},separators=(',',':'),ensure_ascii=False),len(rows),rows[-1][0]
data,nr,last=pack(d)
dw=pd.read_csv('WomensRugbyResults_Detailed.csv',sep=';')
dw['date']=pd.to_datetime(dw.date.str.replace('/','-'))
dw=dw.sort_values('date',kind='stable')
miss=set(dw.home_team)|set(dw.away_team);miss-=set(idx);assert not miss,miss
dataw,nw,lastw=pack(dw)
rankw={slug(n):{'pos':p,'pts':v} for n,(p,v) in json.load(open('rankw.json')).items()}
rk=[l.split('|') for l in open('rank30.txt').read().strip().split('\n')]
rank={slug(n):{'pos':int(p),'pts':float(v)} for p,n,v in rk}
t10flags={slug(n):'data:image/png;base64,'+base64.b64encode(open(f'flags/{slug(n)}.png','rb').read()).decode() for n in T10}
O=[{'id':slug(n),'name':n,**{k:v for k,v in oth[n].items()}} for n in others]
s=s.replace('__FIX__',open('fixtures.json').read())
s=s.replace('__STATS__',open('stats_tests.json').read()).replace('__PLAYERS__',open('players.json').read())
s=s.replace('/*__REDESIGN__*/',open('redesign.css').read())
# Match Centre landing page and two-team head-to-head (kept in their own files)
s=s.replace('/*__MATCHDAY_CSS__*/',open('matchday.css').read()).replace('/*__MATCHDAY_JS__*/',open('matchday.js').read())
open('rugby.html','w').write(s.replace('__DATA__',data).replace('__DATAW__',dataw).replace('__RANKW__',json.dumps(rankw)).replace('__LINEAL__',open('lineal.json').read()).replace('__TROPHIES__',json.dumps(json.load(open('trophies.json')),ensure_ascii=False)).replace('__RANK__',json.dumps(rank)).replace('__FLAGS__',json.dumps(t10flags)).replace('__OTHERS__',json.dumps(O,ensure_ascii=False)))
print(nr,last,nw,lastw,len(names))
