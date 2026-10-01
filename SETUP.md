# One-time setup (about 20 minutes)

## 1. Put the files on GitHub
1. Sign up or sign in at github.com.
2. Top right "+" → New repository. Name it `rugbyanalysis`. Private is fine. Create.
3. On the new repo page click "uploading an existing file".
4. Unzip `rugbyanalysis-repo.zip`, open the folder, select everything inside it
   (site, pipeline, README.md, SETUP.md, wrangler.jsonc) and drag it onto the page.
   Click "Commit changes".

## 2. Add the daily schedule
GitHub's uploader skips folders whose names start with a dot, so add this one by hand:
1. In the repo: "Add file" → "Create new file".
2. Name it exactly: `.github/workflows/update.yml`
3. Open `.github/workflows/update.yml` from the zip (on a Mac press Cmd+Shift+. in
   Finder to show hidden folders), copy everything, paste it in. "Commit changes".
4. Settings → Actions → General → Workflow permissions → "Read and write permissions" → Save.

## 3. Let Cloudflare deploy from GitHub
1. Cloudflare dashboard → Workers & Pages → your Worker `dry-limit-ba4f`.
2. Settings → Build → Git repository → Connect. Authorise GitHub and pick `rugbyanalysis`.
3. Branch: `main`. Build command: leave empty. Deploy command: `npx wrangler deploy`.
   Root directory: `/`. Save. Cloudflare deploys straight away.
4. Your custom domain rugbyanalysis.com stays attached; nothing to change there.

## 4. Check it works
1. GitHub repo → Actions → "Daily data refresh" → "Run workflow".
2. After about 5 minutes the run turns green. If there was new data, a commit called
   "Data refresh <date>" appears and Cloudflare redeploys a minute later.
From then on it runs every day at 05:30 UTC on its own.
