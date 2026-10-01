import json,pandas as pd,datetime as dt
K=['tackles','missedTackles','cleanBreaks','defendersBeaten','offload','metres','runs','passes','kicksFromHand','possession','territory','penaltiesConceded','totalFreeKicksConceded','scrumsTotal','scrumsWon','totalLineouts','lineoutsWon','lineoutWonSteal','maulsTotal','maulsWon','rucksTotal','rucksWon','turnoversConceded','turnoverKnockOn','yellowCards','redCards','tries']
s=json.load(open('espn_tests.json'))
def load(f):
  d=pd.read_csv(f,sep=';');d['date']=pd.to_datetime(d.date.str.replace('/','-'));return d.sort_values('date',kind='stable').reset_index(drop=True)
M=load('RugbyResults_AllNations_Detailed.csv');W=load('WomensRugbyResults_Detailed.csv')
def nm(x):x=x.replace(' Women','');x='United States' if x in('USA','United States of America') else x;return x
def idx(d):
  ix={}
  for i,r in enumerate(d.itertuples()):ix.setdefault(frozenset([r.home_team,r.away_team]),[]).append((r.date,i,r.home_team))
  return ix
IM,IW=idx(M),idx(W)
out={'m':{},'w':{}};miss=[]
for lg,eid,date,h,a,hs,as_,hv,av in s:
  if not (hv[0] or av[0]): continue
  for v in (hv,av):
    for k in ('possession','territory'):
      if not v[K.index(k)]: v[K.index(k)]=None
  women=lg=='289237' or h.endswith(' Women')
  H,A=nm(h),nm(a);ix=IW if women else IM;d0=pd.Timestamp(date)
  cand=[c for c in ix.get(frozenset([H,A]),[]) if abs((c[0]-d0).days)<=1]
  if not cand: miss.append((date,h,a));continue
  _,i,home=cand[0]
  if home!=H: hv,av=av,hv
  out['w' if women else 'm'][i]=[hv,av]
# women's index must match pack() order in build.py (sorted by date stable) -> same as here
print('matched m',len(out['m']),'w',len(out['w']),'missed',len(miss))
from collections import Counter;print(Counter((m[1],m[2]) for m in miss).most_common(8))
json.dump({'k':K,'m':out['m'],'w':out['w']},open('stats_tests.json','w'),separators=(',',':'))
