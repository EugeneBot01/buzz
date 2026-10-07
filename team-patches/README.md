# Team patches

Kept out of `patches/`, which upstream uses for pnpm `patchedDependencies`.

Patches applied on top of an upstream `desktop-vX.Y.Z` tag, in file-name order,
with `git apply --3way`.

| File | What it does | Details |
|---|---|---|
| `10-notifications.patch` | Notification fixes (foreground banners, per-channel levels, reconnect / first-DM gaps, inactive communities) | `BUZZ-NOTIFY-PATCH.md` |
| `20-group-mentions.patch` | `@everyone` (all humans) / `@all` (humans + agents) group mentions | `BUZZ-GROUP-MENTION-PATCH.md` |
| `30-shared-sections.patch` | Team sections: one sidebar section layout shared by, and editable by, every member | `BUZZ-SHARED-SECTIONS-PATCH.md` |

| `40-korean.patch` | Korean UI (display-layer translation, toggle in Settings → Appearance; message bodies/inputs never translated) | `BUZZ-KOREAN-PATCH.md` |
| `50-team-calendar.patch` | Team calendar: a month grid shared by, and editable by, every member of a community (sidebar → 캘린더) | `BUZZ-TEAM-CALENDAR-PATCH.md` |
| `60-channel-files.patch` | Channel files: list a channel's attachments, select several and save them into one folder; raises the single-file download cap from 50 MiB to 512 MiB | `BUZZ-CHANNEL-FILES-PATCH.md` |

| `35-call-notifications.patch` | Readable call (huddle) and wave notifications instead of raw JSON / HTML markers; Korean notification copy on Korean Macs | `BUZZ-NOTIFY-PATCH.md` §5 |
| `36-korean-transcripts.patch` | Korean live huddle transcripts (SenseVoice model) with a 한/EN toggle, and remote speech attributed to the actual speaker | `BUZZ-KOREAN-TRANSCRIPT-PATCH.md` |
| `37-huddle-invites.patch` | Discord-style huddle invites: ring a person into the running call (DM huddle card), optionally add them to the channel | `BUZZ-HUDDLE-INVITE-PATCH.md` |


If a patch stops applying to a new upstream tag, re-implement it from section 3
("intent") of its doc.
