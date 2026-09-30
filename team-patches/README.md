# Team patches

Kept out of `patches/`, which upstream uses for pnpm `patchedDependencies`.

Patches applied on top of an upstream `desktop-vX.Y.Z` tag, in file-name order,
with `git apply --3way`.

| File | What it does | Details |
|---|---|---|
| `10-notifications.patch` | Notification fixes (foreground banners, per-channel levels, reconnect / first-DM gaps, inactive communities) | `BUZZ-NOTIFY-PATCH.md` |
| `20-group-mentions.patch` | `@everyone` (all humans) / `@all` (humans + agents) group mentions | `BUZZ-GROUP-MENTION-PATCH.md` |

If a patch stops applying to a new upstream tag, re-implement it from section 3
("intent") of its doc.
