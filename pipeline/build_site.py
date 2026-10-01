import json,base64,urllib.parse,os,shutil
P=''
svg=open(P+'logo/icon.svg').read().strip()
b=lambda f:'data:image/png;base64,'+base64.b64encode(open(f,'rb').read()).decode()
ICONS=f'''<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,{urllib.parse.quote(svg)}">
<link rel="icon" type="image/png" sizes="32x32" href="{b(P+'logo/icon-32.png')}">
<link rel="apple-touch-icon" sizes="180x180" href="{b(P+'logo/icon-180.png')}">
<meta name="application-name" content="Rugby Analysis">
<meta name="apple-mobile-web-app-title" content="Rugby Analysis">'''
flags={k:b(P+f'flags/{k}.png') for k in ['ireland','scotland','wales','italy','south-africa','england','france','new-zealand','australia']}
_o=json.load(open(P+'others.json'))
for nm_,k in [('Fiji','fiji'),('Samoa','samoa'),('Japan','japan'),('Georgia','georgia')]: flags[k]=_o[nm_]['flag']
t=open(P+'clubs_template.html').read()
t=t.replace('/*__REDESIGN__*/',open(P+'redesign.css').read()).replace('__CSS__',open(P+'shared_style.css').read()).replace('__ICONS__',ICONS).replace('__FLAGS__',json.dumps(flags)).replace('__DATA__',open(P+'clubs_data.json').read())
open(P+'clubs.html','w').write(t)
logo=open(P+'logo/icon.svg').read().strip().replace('<svg ','<svg aria-hidden="true" ')
sv=open(P+'sevens_template.html').read().replace('/*__REDESIGN__*/',open(P+'redesign.css').read()).replace('__CSS__',open(P+'shared_style.css').read()).replace('__ICONS__',ICONS).replace('__LOGO__',logo).replace('__DATA__',open(P+'sevens_data.json').read())
open(P+'sevens.html','w').write(sv)
# standalone site
site='../site/'
old=open(site+'index.html').read()
head=old[:old.index('<body>\n')+7]
body=open(P+'rugby.html').read().replace('<title>Rugby Union Results</title>\n','',1)
open(site+'index.html','w').write(head+body+'\n</body>\n</html>\n')
shutil.copy(P+'clubs.html',site+'clubs.html');shutil.copy(P+'sevens.html',site+'sevens.html')
print(len(t),os.path.getsize(site+'index.html'))
