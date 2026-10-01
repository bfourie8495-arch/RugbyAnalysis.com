import json,re,unicodedata,collections,pandas as pd
P=''
A=json.load(open(P+'espn_athletes.json'));R=json.load(open(P+'espn_rosters.json'));WK=json.load(open(P+'wiki_players.json'))
T10=['Argentina','Australia','England','France','Ireland','Italy','New Zealand','Scotland','South Africa','Wales']
names=T10+sorted(json.load(open(P+'others.json')));NI={n:i for i,n in enumerate(names)}
def load(f):
  d=pd.read_csv(f,sep=';');d['date']=pd.to_datetime(d.date.str.replace('/','-'));return d.sort_values('date',kind='stable').reset_index(drop=True)
M=load('RugbyResults_AllNations_Detailed.csv');W=load('WomensRugbyResults_Detailed.csv')
ALIAS={'United States of America':'United States','USA':'United States','Bosnia-Herzegovina':'Bosnia and Herzegovina','Czechia':'Czech Republic'}
def nm(x):
  w=x.endswith(' Women');x=x.replace(' Women','');x=ALIAS.get(x,x);return x,w
def idx(d):
  ix={}
  for i,r in enumerate(d.itertuples()):ix.setdefault(frozenset([r.home_team,r.away_team]),[]).append((r.date,i,r.home_team))
  return ix
IX={'m':idx(M),'w':idx(W)}
GRP={1:'Prop',3:'Prop',2:'Hooker',4:'Lock',5:'Lock',6:'Back row',7:'Back row',8:'Back row',9:'Scrum-half',10:'Fly-half',11:'Wing',14:'Wing',12:'Centre',13:'Centre',15:'Full-back'}
BIO={'prop':'Prop','hooker':'Hooker','lock':'Lock','Flanker':'Back row','back-row':'Back row','scrum-half':'Scrum-half','Halfback':'Scrum-half','fly-half':'Fly-half','five-eighth':'Fly-half','centre':'Centre','wing':'Wing','Fullback':'Full-back','utility back':'Centre','outside back':'Wing','front-row':'Prop'}
PK=['tackles','missedTackles','metres','runs','cleanBreaks','defendersBeaten','offload','tries','tryAssists','points','turnoversConceded','penaltiesConceded','kicksFromHand','lineoutsWon','yellowCards','redCards','conversionGoals','penaltyGoals','passes']
pl={};LU={'m':{},'w':{}};miss=0
for eid,(lg,date,sides) in sorted(R.items(),key=lambda x:x[1][1]):
  if len(sides)!=2:continue
  (ha0,t0,p0),(ha1,t1,p1)=sides
  n0,w0=nm(t0);n1,w1=nm(t1);g='w' if (w0 or w1 or lg=='289237') else 'm'
  if n0 not in NI or n1 not in NI: continue
  c=[x for x in IX[g].get(frozenset([n0,n1]),[]) if abs((x[0]-pd.Timestamp(date)).days)<=1]
  if not c: miss+=1;continue
  _,mi,home=c[0]
  if mi in LU[g]:continue
  sides2=[(n0,p0),(n1,p1)] if home==n0 else [(n1,p1),(n0,p0)]
  lu=[]
  for team,ps in sides2:
    row=[None]*23
    for aid,j,sub,cap,pos,st in ps:
      if not aid or not (1<=j<=23):continue
      row[j-1]=aid
      q=pl.setdefault(aid,{'id':aid,'team':team,'g':g,'apps':0,'starts':0,'first':None,'last':None,'capt':0,'jers':collections.Counter(),'sn':0,'s':[0]*len(PK)})
      if q['team']!=team: q.setdefault('other',set()).add(team)
      played=j<=15 or sub or st
      if not played:continue
      q['apps']+=1;q['starts']+=j<=15;q['capt']+=cap;d=date
      q['first']=q['first'] or d;q['last']=d
      if j<=15:q['jers'][j]+=1
      if st and any(v for v in st if v):
        q['sn']+=1
        for k,v in enumerate(st):q['s'][k]+=v or 0
    lu.append(row)
  LU[g][mi]=lu
print('unmatched events',miss,'matches with lineups',len(LU['m']),len(LU['w']),'players',len(pl))
# wikipedia caps
def key(s):
  s=re.sub(r'\(c\)|\(vc\)|\[.*?\]','',s);s=unicodedata.normalize('NFKD',s).encode('ascii','ignore').decode().lower();return re.sub(r'[^a-z]','',s)
SQ={}
byname=collections.defaultdict(list)
for aid,q in pl.items():
  a=A.get(aid,{});byname[(key(a.get('fn') or a.get('n','')),q['team'],q['g'])].append(aid)
for k,v in WK['wk'].items():
  if isinstance(v,str) or not v['squad']:continue
  g,team=k.split(':');rows=[r for sec,t in v['squad'] for r in t[1:] if len(r)>=5 and r[0]!='Player']
  out=[]
  for r in rows:
    nmx=re.sub(r'\s*\((c|vc|cc)\)','',r[0]).strip();cap=re.sub(r'[^0-9]','',r[3]);cap=int(cap) if cap else 0
    dob=re.search(r'\((\d{4}-\d\d-\d\d)\)',r[2]);hit=byname.get((key(nmx),team,g),[])
    if hit:pl[hit[0]]['caps']=cap;pl[hit[0]]['club']=r[4]
    out.append([nmx,r[1],dob.group(1) if dob else '',cap,r[4],hit[0] if hit else None,1 if '(c)' in r[0] else 0])
  SQ[g+':'+team]=out
# caps leaders
CL=[]
for r in WK['caps'][1:]:
  if len(r)<6:continue
  m=re.match(r'([^(]+?)\s*\((\d+)\)',r[3]);team=(m.group(1) if m else r[3]).strip();tc=int(m.group(2)) if m else int(r[1])
  CL.append([r[2],int(r[1]),team,tc,r[4],r[5]])
# fill caps for 100+ cap players from leaders list (team caps only)
for r in WK['caps'][1:]:
  if len(r)<6:continue
  m=re.match(r'([^(]+?)\s*\((\d+)\)',r[3]);team=(m.group(1) if m else r[3]).strip();tc=int(m.group(2)) if m else int(r[1]);team=ALIAS.get(team,team)
  for g in ('m',):
    for aid in byname.get((key(r[2]),team,g),[]):
      if pl[aid].get('caps') is None or pl[aid]['caps']<tc: pl[aid]['caps']=tc
# compact player list
ids=sorted(pl,key=lambda a:(-pl[a]['apps'],a));PI={a:i for i,a in enumerate(ids)}
PL=[]
for a in ids:
  q=pl[a];b=A.get(a,{});j=q['jers'].most_common(1)
  pos=GRP[j[0][0]] if j else BIO.get(b.get('pos'),'')
  PL.append([b.get('fn') or b.get('n') or '?',NI[q['team']],q['g'],pos,b.get('h'),b.get('w'),b.get('b'),b.get('bp'),q['apps'],q['starts'],q['first'],q['last'],q.get('caps'),q['capt'],q['sn'],q['s'],q.get('club')])
LUo={g:{i:[[PI.get(x,-1) if x else -1 for x in row] for row in lu] for i,lu in d.items()} for g,d in LU.items()}
SQo={k:[r[:5]+[PI.get(r[5],-1) if r[5] else -1,r[6]] for r in v] for k,v in SQ.items()}
out={'pk':PK,'p':PL,'lu':LUo,'sq':SQo,'cl':CL}
s=json.dumps(out,separators=(',',':'),ensure_ascii=False)
open(P+'players.json','w').write(s);print('bytes',len(s),'wiki-capped matched',sum(1 for x in PL if x[12] is not None),'squad rows',sum(len(v) for v in SQ.values()))
