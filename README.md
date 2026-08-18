# bazzite-bc250 — your own auto-updating BC250 image

This builds a personal Bazzite image that is **stock Bazzite (daily updates) + your BC250 bits baked in**:

- `nct6687` fan driver (the one thing plain Bazzite lacks — needed for CoolerControl fan curves)
- `cyan-skillfish-governor-smu` (the GPU-clock governor)
- CoolerControl + liquidctl (fan control app)

A GitHub Action rebuilds it **every night** on top of whatever the newest Bazzite base is, so you get daily updates *and* keep the fan driver — automatically, forever.

Things that already live in `/etc` or `/var` on your box — the 8-core unlock service, your governor curve (2150 MHz), your CoolerControl fan curve — **carry over the rebase on their own**, so they are not baked in here.

---

## One-time setup (~15 min)

1. **Make a free GitHub account** (if you don't have one).
2. **Create a new repo** named `bazzite-bc250` (Public).
3. **Upload these files** into it, keeping the folder layout:
   ```
   Containerfile
   build_files/build.sh
   .github/workflows/build.yml
   README.md
   ```
   (Web UI: "Add file → Upload files", drag the folder in. Or use git.)
4. **Turn on Actions:** repo → **Actions** tab → enable workflows if prompted.
5. **Run the first build:** Actions → **build-bazzite-bc250** → **Run workflow**.
   - Takes ~15–25 min. Watch it go green. (If the `nct6687` step fails on the
     kernel-devel line, send me the log — that one line sometimes needs the
     exact Bazzite kernel-devel package name; easy fix.)
6. **Make the image public:** your GitHub profile → **Packages** → `bazzite-bc250`
   → **Package settings** → **Change visibility → Public**. (So the BC250 can pull it without a login.)

Your image now lives at:
```
ghcr.io/<your-github-username>/bazzite-bc250:latest
```

---

## Point the BC250 at it (once)

On the BC250 (root shell), rebase to your image and reboot:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/<your-github-username>/bazzite-bc250:latest
systemctl reboot
```

After it boots, verify:
```bash
rpm-ostree status                 # top deployment = your image
lsmod | grep nct6687              # fan driver loaded
systemctl is-active coolercontrold cyan-skillfish-governor-smu
nproc                             # 16 (8-core service carried over)
```

That's it. From now on it updates itself: the nightly Action rebuilds on the
latest Bazzite, and your normal `ujust update` (or Bazzite's auto-update) pulls
your fresh image. **Daily updates + fan driver, hands-off.**

Rollback any time: `rpm-ostree rollback` (or pick the previous deployment at boot).

---

## Even lazier alternative (skip building)

If you'd rather not maintain a recipe at all, **fork an existing BC250 image repo
and just turn its schedule to nightly** — you inherit a proven build:

- `github.com/Canz2/bazzite-bc250`
- `github.com/62fixolab/...` (the repo that builds the image you run now)

Fork → edit `.github/workflows/*.yml` → set the `cron:` to `0 8 * * *` → enable
Actions → make the package public → rebase to *your* fork's image. Same result,
someone else maintains the recipe.

---

## Notes

- **Signing:** this uses an unsigned rebase (`ostree-unverified-registry`) to keep
  setup simple. It's fine for a personal LAN box. If you want signed images
  (`ostree-image-signed`, like the stock ones), add a `cosign` keypair + the
  `redhat-actions/cosign` step later — ask me and I'll add it.
- **Desktop variant:** base is `bazzite-deck-gnome:stable` (boots Gaming Mode, GNOME
  desktop underneath). To use the KDE flavor instead, change the `FROM` line in
  `Containerfile` to `bazzite-deck:stable`.
- After rebasing, you can drop your old layered packages with
  `rpm-ostree reset` (optional) since governor + coolercontrol are now in the base.
