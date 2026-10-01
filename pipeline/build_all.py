"""Rebuild every page of the site from the data files in this folder."""
import os, runpy, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
for step in ['build_stats.py', 'build_players.py', 'build_clubs.py', 'build.py', 'build_site.py']:
    print(f'--- {step}', flush=True)
    runpy.run_path(step, run_name='__main__')
print('Site rebuilt in ../site/')
