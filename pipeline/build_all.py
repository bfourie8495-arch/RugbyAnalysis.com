"""Rebuild every page of the site from the data files in this folder."""
import os, runpy, sys
os.chdir(os.path.dirname(os.path.abspath(__file__)))
for step in ['build_stats.py', 'build_players.py', 'build_clubs.py', 'build.py', 'build_site.py', 'align_clubs.py', 'align_sevens.py', 'stories.py']:
    print(f'--- {step}', flush=True)
    runpy.run_path(step, run_name='__main__')
# The app's feeds are extra: if one fails, warn and keep its previous file rather than stop the site build.
for step in ['build_analysis.py', 'build_tournaments.py']:
    print(f'--- {step}', flush=True)
    try:
        runpy.run_path(step, run_name='__main__')
    except Exception as e:
        print(f'::warning::{step} failed ({type(e).__name__}: {e}); keeping the previous app feed')
print('Site rebuilt in ../site/')
