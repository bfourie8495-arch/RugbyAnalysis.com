import json,re,collections,base64
R=json.load(open('club_raw.json'));TB=json.load(open('club_tables.json'))
PW=json.load(open('pwr_raw.json'))
CUP={(d,h,a):sec for d,h,a,sec in json.load(open('pwr_cup.json'))}
for r in PW['rows']:
    sec=CUP.get((r[2],r[4],r[6]))
    if sec=='PWR Next Gen Cup': continue
    if sec: r[17]='Cup: '+r[17]
    R.append(r)
for se,T in PW['tabs'].items(): TB['PWR'+se]=T
CLUBS=[
# id, name, short, league, country, p, onp, s(accent light), ad (accent dark), city, tz
('leinster','Leinster','LEI','URC','Ireland','#0B3D91','#FFFFFF','#1352C2','#7FA8F5','Dublin','Europe/Dublin'),
('munster','Munster','MUN','URC','Ireland','#B5121B','#FFFFFF','#B5121B','#FF7A7F','Limerick & Cork','Europe/Dublin'),
('ulster','Ulster','ULS','URC','Ireland','#F4F4F2','#1B2A4A','#C8102E','#FF6B76','Belfast','Europe/London'),
('connacht','Connacht','CON','URC','Ireland','#006B3F','#FFFFFF','#00804A','#56D69A','Galway','Europe/Dublin'),
('glasgow','Glasgow Warriors','GLA','URC','Scotland','#14265B','#FFFFFF','#2A4DB0','#8EB2FF','Glasgow','Europe/London'),
('edinburgh','Edinburgh','EDI','URC','Scotland','#1A1A1A','#FFFFFF','#B3121F','#FF6F79','Edinburgh','Europe/London'),
('cardiff','Cardiff','CAR','URC','Wales','#0E0E0E','#9CC9EE','#2F7FC1','#9CC9EE','Cardiff','Europe/London'),
('ospreys','Ospreys','OSP','URC','Wales','#101010','#FFFFFF','#555B63','#C9CED4','Swansea','Europe/London'),
('scarlets','Scarlets','SCA','URC','Wales','#B3121B','#FFFFFF','#B3121B','#FF7A80','Llanelli','Europe/London'),
('dragons','Dragons','DRA','URC','Wales','#1B1B1B','#F2B233','#C8102E','#FF7A80','Newport','Europe/London'),
('benetton','Benetton','BEN','URC','Italy','#0B6B3A','#FFFFFF','#0B7A42','#5FD394','Treviso','Europe/Rome'),
('zebre','Zebre Parma','ZEB','URC','Italy','#151515','#FFFFFF','#2E5AAC','#9DB9F0','Parma','Europe/Rome'),
('bulls','Bulls','BUL','URC','South Africa','#0A5EB0','#FFFFFF','#0A5EB0','#7DB8F2','Pretoria','Africa/Johannesburg'),
('stormers','Stormers','STO','URC','South Africa','#16306B','#FFFFFF','#2350B5','#8FB0FF','Cape Town','Africa/Johannesburg'),
('sharks','Sharks','SHA','URC','South Africa','#0D0D0D','#FFFFFF','#1C8FC7','#7CCBF0','Durban','Africa/Johannesburg'),
('lions','Lions','LIO','URC','South Africa','#C0101F','#FFFFFF','#C0101F','#FF7A83','Johannesburg','Africa/Johannesburg'),
('bath','Bath','BAT','PREM','England','#0B2F5B','#FFFFFF','#1B5AA8','#8AB8F0','Bath','Europe/London'),
('bristol','Bristol Bears','BRI','PREM','England','#0B1F3F','#FFFFFF','#C8102E','#FF7A83','Bristol','Europe/London'),
('exeter','Exeter Chiefs','EXE','PREM','England','#111111','#E2C16B','#8A6A12','#E2C16B','Exeter','Europe/London'),
('gloucester','Gloucester','GLO','PREM','England','#B01C2E','#FFFFFF','#B01C2E','#FF7A88','Gloucester','Europe/London'),
('harlequins','Harlequins','HAR','PREM','England','#8FC8EA','#2B1A12','#B0006B','#FF6FBA','London','Europe/London'),
('leicester','Leicester Tigers','LEI','PREM','England','#00533A','#FFFFFF','#00714F','#4FD6A6','Leicester','Europe/London'),
('londonirish','London Irish','LIR','PREM','England','#00703C','#FFFFFF','#00804A','#5FD39A','London','Europe/London'),
('newcastle','Newcastle Red Bulls','NEW','PREM','England','#0B1E3F','#FFFFFF','#D7143F','#FF7A97','Newcastle','Europe/London'),
('northampton','Northampton Saints','NOR','PREM','England','#0E4D2C','#E0B54A','#0E6B3C','#E0B54A','Northampton','Europe/London'),
('sale','Sale Sharks','SAL','PREM','England','#0B2A55','#FFFFFF','#1A64B8','#8ABBF0','Salford','Europe/London'),
('saracens','Saracens','SAR','PREM','England','#111111','#FFFFFF','#C8102E','#FF7A83','London','Europe/London'),
('wasps','Wasps','WAS','PREM','England','#111111','#F5D000','#8A7400','#F5D000','Coventry','Europe/London'),
('worcester','Worcester Warriors','WOR','PREM','England','#0C2451','#F2A900','#1C4BA0','#F2A900','Worcester','Europe/London'),
('glos-hartpury','Gloucester-Hartpury','GLH','PWR','England','#B01C2E','#FFFFFF','#B01C2E','#FF7A88','Gloucester','Europe/London'),
('saracens-w','Saracens Women','SAR','PWR','England','#111111','#FFFFFF','#C8102E','#FF7A83','London','Europe/London'),
('exeter-w','Exeter Chiefs Women','EXE','PWR','England','#111111','#E2C16B','#8A6A12','#E2C16B','Exeter','Europe/London'),
('bristol-w','Bristol Bears Women','BRI','PWR','England','#0B1F3F','#FFFFFF','#C8102E','#FF7A83','Bristol','Europe/London'),
('harlequins-w','Harlequins Women','HAR','PWR','England','#8FC8EA','#2B1A12','#B0006B','#FF6FBA','London','Europe/London'),
('loughborough','Loughborough Lightning','LOU','PWR','England','#4B1E77','#FFD200','#6A2FB0','#C9A6FF','Loughborough','Europe/London'),
('trailfinders-w','Trailfinders Women','TRA','PWR','England','#0B5B3A','#FFFFFF','#0B7A4B','#5FD39A','Ealing, London','Europe/London'),
('leicester-w','Leicester Tigers Women','LEI','PWR','England','#00533A','#FFFFFF','#00714F','#4FD6A6','Leicester','Europe/London'),
('sale-w','Sale Sharks Women','SAL','PWR','England','#0B2A55','#FFFFFF','#1A64B8','#8ABBF0','Salford','Europe/London'),
('worcester-w','Worcester Warriors Women','WOR','PWR','England','#0C2451','#F2A900','#1C4BA0','#F2A900','Worcester','Europe/London'),
('wasps-w','Wasps Women','WAS','PWR','England','#111111','#F5D000','#8A7400','#F5D000','Coventry','Europe/London'),
('dmp','DMP Sharks','DMP','PWR','England','#1B5FA8','#FFFFFF','#1B5FA8','#8AB8F0','Darlington','Europe/London'),
]
CAN={'Gloucester-Hartpury':'glos-hartpury','Gloucester–Hartpury':'glos-hartpury','Saracens Women':'saracens-w','Exeter Chiefs Women':'exeter-w','Bristol Bears Women':'bristol-w','Harlequins Women':'harlequins-w','Loughborough Lightning (rugby union)':'loughborough','Loughborough Lightning':'loughborough','Trailfinders Women':'trailfinders-w','Leicester Tigers Women':'leicester-w','Sale Sharks Women':'sale-w','Worcester Warriors Women':'worcester-w','Wasps Women':'wasps-w','Darlington Mowden Park Sharks':'dmp','Bath Rugby':'bath','Bath':'bath','Bristol Bears':'bristol','Exeter Chiefs':'exeter','Gloucester Rugby':'gloucester','Harlequin F.C.':'harlequins','Leicester Tigers':'leicester','London Irish':'londonirish','Newcastle Falcons':'newcastle','Newcastle Red Bulls':'newcastle','Northampton Saints':'northampton','Sale Sharks':'sale','Saracens F.C.':'saracens','Wasps RFC':'wasps','Worcester Warriors':'worcester','Benetton Rugby':'benetton','Benetton':'benetton','Bulls (rugby union)':'bulls','Bulls':'bulls','Cardiff Rugby':'cardiff','Cardiff':'cardiff','Connacht Rugby':'connacht','Connacht':'connacht','Dragons':'dragons','Dragons (rugby union)':'dragons','Dragons RFC':'dragons','Edinburgh Rugby':'edinburgh','Edinburgh':'edinburgh','Glasgow Warriors':'glasgow','Leinster Rugby':'leinster','Leinster':'leinster','Lions (United Rugby Championship)':'lions','Lions':'lions','Munster Rugby':'munster','Munster':'munster','Ospreys':'ospreys','Ospreys (rugby union)':'ospreys','Scarlets':'scarlets','Sharks (rugby union)':'sharks','Sharks':'sharks','Stormers':'stormers','Stormers (rugby union)':'stormers','Ulster Rugby':'ulster','Ulster':'ulster','Zebre Parma':'zebre'}
from clubs_extra import EXTRA,ALIAS
CLUBS=CLUBS+EXTRA;CAN.update(ALIAS)
ids=[c[0] for c in CLUBS];ix={c:i for i,c in enumerate(ids)}
LGS=['URC','PREM','PWR','T14','SR','CC','NPC','JL1','ECC','EPC']
X=json.load(open('xcomp_raw.json'))
JUNK=('Pro D2','Top 14')
for r in X['rows']:
    if r[4] in JUNK or r[6] in JUNK or 'Rugby Football Union' in r[4]+r[6]: continue
    if r[4] not in CAN or r[6] not in CAN: print('unknown',r[0],r[4],r[6]); continue
    R.append(r)
for k,T in X['tabs'].items():
    if not k.startswith(('CC','NPC','ECC','EPC')): TB[k]=T
for k,v in X['wt'].items():
    if k in X['tabs']: continue
    H=[h.lower() for h in v['heads']]
    def col(*names):
        for n in names:
            for i,h in enumerate(H):
                if n in h: return i-2
        return None
    out=[]
    for row in v['rows']:
        nums=row['nums'];g=lambda i:nums[i] if i is not None and 0<=i<len(nums) else 0
        out.append({'nm':row['nm'],'W':g(col('won')),'D':g(col('drawn')),'L':g(col('lost')),'PF':g(col('points for')),'PA':g(col('points against')),'TF':0,'TA':0,'TB':g(col('try bonus')),'LB':g(col('losing bonus')),'Pts':g(len(H)-3)})
    TB[k]=out

# ---- merge results and fixtures pulled from ESPN by update.py (club_espn.json)
import os,datetime as _dt,unicodedata as _ud
from zoneinfo import ZoneInfo as _Z
ESPN_MAP={'Cardiff Blues':'cardiff','Benetton Treviso':'benetton','Zebre':'zebre','Bristol Rugby':'bristol','Gloucester Rugby':'gloucester','Newcastle Falcons':'newcastle',
 'Montpellier Herault':'montpellier','Stade Francais Paris':'stadefrancais','Bordeaux Begles':'bordeaux','Clermont Auvergne':'clermont','New South Wales Waratahs':'waratahs',
 'Western Force':'force','Queensland Reds':'reds','Fijian Drua':'drua','Moana Pasifika':'moana','Black Lion':'blacklion','Cheetahs':'cheetahs','Racing 92':'racing92',
 'La Rochelle':'larochelle','LOU Rugby':'lyon','RC Vannes':'vannes','Lyon':'lyon','Vannes':'vannes','Stade Toulousain':'toulouse','Castres Olympique':'castres','US Montauban':'montauban'}
for c in CLUBS: CAN['#ID:'+c[0]]=c[0]
_norm=lambda x:re.sub(r'[^a-z0-9]','',_ud.normalize('NFKD',x).encode('ascii','ignore').decode().lower())
_NM={}
for c in CLUBS:
    _NM.setdefault(_norm(c[1]),c[0]);_NM.setdefault(_norm(c[0]),c[0]);_NM.setdefault(_norm(c[9]) if c[9] else '',c[0])
def _res(n):
    n=n[5:] if n.startswith('ESPN:') else n
    if n in ESPN_MAP: return ESPN_MAP[n]
    if n in CAN: return CAN[n]
    return _NM.get(_norm(n)) or _NM.get(_norm(n.replace(' Rugby','')))
TZC={c[0]:c[10] for c in CLUBS}
E=json.load(open('club_espn.json',encoding='utf-8')) if os.path.exists('club_espn.json') else []
byp=collections.defaultdict(list)
for r in R:
    try: byp[(r[0],frozenset((CAN[r[4]],CAN[r[6]])))].append(r)
    except KeyError: pass
added=[];unknown=set()
for e in E:
    eid,lg,se,d,tm,h,hl,a,al,hs,as_,bp,sc,cd,ref,att,stad,ts,stg,nd=e
    H,A=_res(h),_res(a)
    if not H or not A or H==A:
        unknown.update(x for x,y in ((h,H),(a,A)) if not y);continue
    try:
        t=_dt.datetime.fromisoformat(d+'T'+(tm or '12:00')+':00+00:00').astimezone(_Z(TZC.get(H) or 'UTC'))
        d,tm=t.date().isoformat(),t.strftime('%H:%M')
    except Exception: pass
    hit=None;best=None
    d0=_dt.date.fromisoformat(d)
    for r in byp.get((lg,frozenset((H,A))),[]):
        if r[1]!=se and not (r[2] and abs((_dt.date.fromisoformat(r[2][:10])-d0).days)<=3): continue
        same=CAN[r[4]]==H
        nd_=len(r)>18 and r[18]
        gap=0 if nd_ or not r[2] else abs((_dt.date.fromisoformat(r[2][:10])-d0).days)
        if hs is None and r[8] is not None and gap>3: continue      # a played game is never an upcoming fixture
        if hs is not None and r[8] is not None and gap>3: continue  # different meeting
        if not same and not nd_ and gap>3: continue
        score=(0 if same else 100)+gap
        if best is None or score<best: best,hit=score,r
    if hit:
        sw=CAN[hit[4]]!=H
        if hs is not None and hit[8] is None:
            hit[8],hit[9]=(as_,hs) if sw else (hs,as_)
            if sc: hit[11]=[[sc[0][1],sc[0][0]]] if sw else sc
            if cd: hit[12]=[cd[1],cd[0],cd[3],cd[2]] if sw else cd
            if att: hit[14]=att
        if not sw and (hit[8] is None or hs is not None or (len(hit)>18 and hit[18])):
            hit[2],hit[3]=d,tm          # ESPN has the current date and kick-off time
            if len(hit)>18: hit[18]=0
            if not hit[15] and stad: hit[15]=stad
        continue
    r=[lg,se,d,tm,'#ID:'+H,'','#ID:'+A,'',hs,as_,bp,sc,cd,ref,att,stad,ts,'',0]
    R.append(r);added.append(r);byp[(lg,frozenset((H,A)))].append(r)
if unknown: print('ESPN club names not matched (add to ESPN_MAP):',sorted(unknown))
# label stages for ESPN-only rows: regular-season length per team is learnt from past seasons
def _stg(x):
    x=(x or '').lower()
    if 'round of 16' in x or 'last 16' in x: return 1
    return 1 if re.search(r'quarter|semi|final|play-off|playoff|barrage|qualifier',x) and not re.match(r'round \d',x) else 0
GREG_DEFAULT={'URC':18,'PREM':18,'T14':26,'SR':14,'NPC':10,'CC':10,'ECC':4,'EPC':4,'PWR':16,'JL1':16}
GREG={}
for lg in GREG_DEFAULT:
    cnt=collections.Counter()
    sea=sorted({r[1] for r in R if r[0]==lg and r not in added and any(_stg(q[17]) for q in R if q[0]==lg and q[1]==r[1])},key=lambda s:(int(s[:4]),s))
    if sea:
        last=sea[-1]
        for r in R:
            if r[0]==lg and r[1]==last and not _stg(r[17]) and r[8] is not None:
                cnt[CAN[r[4]]]+=1;cnt[CAN[r[6]]]+=1
    GREG[lg]=collections.Counter(cnt.values()).most_common(1)[0][0] if cnt else GREG_DEFAULT[lg]
for (lg,se) in {(r[0],r[1]) for r in added}:
    G=GREG.get(lg,99);rs=sorted([r for r in R if r[0]==lg and r[1]==se],key=lambda r:(r[2] or '',r[3] or ''))
    n=collections.Counter();ko=[]
    for r in rs:
        h,a=CAN[r[4]],CAN[r[6]]
        if r in added:
            if n[h]<G and n[a]<G:
                n[h]+=1;n[a]+=1;r[17]=f'Round {max(n[h],n[a])}'
            else: ko.append(r)
        elif not _stg(r[17]): n[h]+=1;n[a]+=1
    wk=sorted({_dt.date.fromisoformat(r[2]).isocalendar()[:2] for r in ko})
    lab=['Final','Semi-final','Quarter-final','Round of 16']
    for r in ko:
        i=len(wk)-1-wk.index(_dt.date.fromisoformat(r[2]).isocalendar()[:2]);r[17]=lab[i] if i<len(lab) else 'Play-off'
print('ESPN club rows merged:',len(E),'new rows',len(added),'regular-season lengths',GREG)
skey=lambda s:(int(s[:4])+(0.5 if '–' in s else 0))
SEAS=sorted({r[1] for r in R},key=skey)
def stage(s):
    s=s.lower()
    if s.startswith('cup:') or re.search(r'place play-off|^finals$',s): return 4
    if re.search(r'relegation|promotion',s): return 6
    if re.search(r'third|3rd|bronze',s): return 7
    if re.search(r'round of 16|last 16',s): return 5
    if re.search(r'quarter|qualifier|barrage|elimination|play-in',s): return 1
    if 'semi' in s: return 2
    if re.search(r'\bfinal\b',s): return 3
    return 0
refs=[];venues=[]
def gi(lst,v):
    if v not in lst: lst.append(v)
    return lst.index(v)
rows=[];seen=set()
R=[list(r) for r in R]
for r in sorted(R,key=lambda r:(r[2] or '',r[3])):
    lg,se,d,tm,h,hl,a,al,hs,as_,bp,sc,cd,ref,att,st,ts,stg=r[:18];nd=r[18] if len(r)>18 else 0
    y0=int(se[:4])
    if nd or not d: d=f'{y0}-08-01' if '–' in se else f'{y0}-01-01';nd=1
    yy,mm=int(d[:4]),int(d[5:7])
    if '–' in se and not nd:
        if yy==y0 and mm<=7: d=f'{y0+1}'+d[4:]
        elif yy==y0+1 and mm>=8: d=f'{y0}'+d[4:]
    H,A=ix[CAN[h]],ix[CAN[a]]
    key=(lg,se,d,H,A) if not nd else (lg,se,'nd',H,A)
    if key in seen: continue
    seen.add(key)
    k=stage(stg)
    rnd=(re.match(r'Round (\d+)',stg) or [None,0])[1]
    t=re.search(r'(\d{1,2})[:.](\d{2})',tm or '');tt=f'{int(t[1]):02d}:{t[2]}' if t else ''
    rows.append([LGS.index(lg),SEAS.index(se),d,tt,H,A,hs,as_,bp,sc,cd,gi(refs,ref) if ref else -1,att or 0,gi(venues,st) if st else -1,ts[0],ts[1],k,int(rnd),nd])
rows.sort(key=lambda r:(r[2],r[3]))
# official tables
tables={}
for key,T in TB.items():
    lg=[l for l in LGS if key.startswith(l)][0];se=key[len(lg):]
    if se not in SEAS: continue
    out=[]
    for t in T:
        nm=re.sub(r'^\d{4}(–\d{2})? ','',t['nm']).replace(' season','')
        if nm not in CAN: print('tbl-unknown',key,nm); continue
        cid=ix[CAN[nm]]
        if not any(str(t.get(k) or '').strip() not in ('','0') for k in ['W','D','L']) and not se.startswith('2026'): continue
        W,D,L,PF,PA,TF,TA,TBn,LB=[int(t[k] or 0) for k in ['W','D','L','PF','PA','TF','TA','TB','LB']]
        adj=int(str(t.get('ADJ') or '0').replace('+','').replace('−','-').replace('–','-') or 0)
        if t.get('BONUS'): TBn+=int(t['BONUS'] or 0)
        pts=int(t['Pts']) if t.get('Pts') else 4*W+2*D+TBn+LB+adj
        out.append([cid,W,D,L,PF,PA,TF,TA,TBn,LB,pts])
    out=list({o[0]:o for o in out}.values());out.sort(key=lambda o:(-o[10],-o[1],-(o[4]-o[5])))
    tables[f"{LGS.index(lg)}-{SEAS.index(se)}"]=out
for l,lgn in enumerate(LGS):
    ss=[r[1] for r in rows if r[0]==l]
    if not ss: continue
    k=f'{l}-{max(ss)}'
    if k in tables:
        pl=collections.Counter()
        for r in rows:
            if r[0]==l and r[1]==max(ss) and r[6] is not None and r[16]==0: pl[r[4]]+=1;pl[r[5]]+=1
        if lgn in ('URC','PREM','T14','SR','CC','NPC') and sum(pl.values())>sum(t[1]+t[2]+t[3] for t in tables[k]):
            del tables[k];print('latest table out of date, recomputing',lgn,SEAS[max(ss)])
for l,lgn in enumerate(LGS):
    if lgn in ('ECC','EPC'): continue
    for si,se in enumerate(SEAS):
        k=f'{l}-{si}'
        if k in tables: continue
        G=[r for r in rows if r[0]==l and r[1]==si and r[16]==0]
        if not G: continue
        T={}
        for r in G:
            for side in (0,1):
                c=r[4+side];x=T.setdefault(c,[c,0,0,0,0,0,0,0,0,0,0])
                if r[6] is None: continue
                f,g=(r[6],r[7]) if side==0 else (r[7],r[6])
                if f>g:x[1]+=1
                elif f==g:x[2]+=1
                else:x[3]+=1
                x[4]+=f;x[5]+=g
                if r[9]:x[6]+=r[9][0][side];x[7]+=r[9][0][1-side]
                if r[9]:
                    tf,ta=r[9][0][side],r[9][0][1-side]
                    if lgn=='SR': x[8]+=1 if tf>=ta+3 else 0
                    elif lgn=='T14': x[8]+=1 if (f>g and tf>=ta+3) else 0
                    else: x[8]+=1 if tf>=4 else 0
                    if f<g and g-f<=(5 if lgn=='T14' else 7): x[9]+=1
                else:
                    bp=r[8][side]
                    if f<g and g-f<=7: x[9]+=1;x[8]+=max(0,bp-1)
                    else: x[8]+=bp
        out=[]
        for x in T.values(): x[10]=4*x[1]+2*x[2]+x[8]+x[9];out.append(x)
        out.sort(key=lambda o:(-o[10],-o[1],-(o[4]-o[5])))
        tables[k]=out;print('computed table',lgn,se,len(out))
# URC 2021-22 missing Zebre: compute
k='0-0';have={r[0] for r in tables[k]}
for cid in {r[4] for r in rows if r[0]==0 and r[1]==0}|{r[5] for r in rows if r[0]==0 and r[1]==0}:
    if cid in have: continue
    W=D=L=PF=PA=TF=TA=TBn=LB=0
    for r in rows:
        if r[0]!=0 or r[1]!=0 or r[16] or r[6] is None or cid not in (r[4],r[5]):continue
        s=0 if r[4]==cid else 1;f,g=(r[6],r[7]) if s==0 else (r[7],r[6])
        if f>g:W+=1
        elif f==g:D+=1
        else:L+=1
        PF+=f;PA+=g;TBn+=0
        if r[9]:TF+=r[9][0][s];TA+=r[9][0][1-s]
        if r[8][s]: 
            if f>=g: TBn+=r[8][s]
            else:
                # losing: could be TB or LB; split by margin
                if f-g>=-7: LB+=1; TBn+=r[8][s]-1
                else: TBn+=r[8][s]
    tables[k].append([cid,W,D,L,PF,PA,TF,TA,TBn,LB,4*W+2*D+TBn+LB])
    print('computed',ids[cid],tables[k][-1])
# validate played games vs table
for key,T in tables.items():
    l,s=map(int,key.split('-'))
    played=collections.Counter()
    for r in rows:
        if r[0]==l and r[1]==s and r[6] is not None and r[16]==0: played[r[4]]+=1;played[r[5]]+=1
    bad=[(ids[t[0]],t[1]+t[2]+t[3],played[t[0]]) for t in T if t[1]+t[2]+t[3]!=played[t[0]]]
    if bad: print('mismatch',key,bad)
data={'leagues':LGS,'clubs':[dict(zip(['id','name','code','lg','country','p','onp','al','ad','city','tz'],c)) for c in CLUBS],'seasons':SEAS,'rows':rows,'tables':tables,'refs':refs,'venues':venues,'updated':max(r[2] for r in rows if r[6] is not None)}
json.dump(data,open('clubs_data.json','w'),ensure_ascii=False,separators=(',',':'))
print(len(rows),len(json.dumps(data)),data['updated'])
