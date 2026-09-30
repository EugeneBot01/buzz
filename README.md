# Buzz — team build

This branch holds only what the team adds on top of official Buzz
([block/buzz](https://github.com/block/buzz)):

- `team-patches/` — patches applied to an official `desktop-vX.Y.Z` tag
- `.github/workflows/team-release.yml` — builds the patched macOS app
  (Apple Silicon + Intel) and publishes it as a release here

Team apps check `releases/download/team-latest/latest.json` for updates.

## Release a new build

Actions → **Team Release** → Run workflow:

- `upstream_version`: official version, e.g. `0.5.26`
- `build_number`: `1` for the first team build of that version, then `2`, `3`, ...
- `publish`: off = test build only; on = team apps get it as an update
