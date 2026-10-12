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
| `55-weekly-digest.patch` | Weekly team-calendar digest to a channel (default Mon 9:00) and same-day notices to each entry's channel with attendee mentions | `BUZZ-WEEKLY-DIGEST-PATCH.md` |
| `60-channel-files.patch` | Channel files: list a channel's attachments, select several and save them into one folder; raises the single-file download cap from 50 MiB to 512 MiB | `BUZZ-CHANNEL-FILES-PATCH.md` |
| `65-upload-pack-refused.patch` | Uploads: audio files and images other than JPEG/PNG/GIF/WebP, which the relay refuses as attachments, are packed into a one-entry zip before upload (`media_team_zip.rs`). The safety deny-list (executables, disk images) is left as it is | (this row) |
| `70-channel-connections.patch` | Channel connections: one-click shortcuts (Google Meet, Figma, any https link) in the channel header, and MCP servers for the channel's agents (passed by `buzz-acp` to any runtime) | `BUZZ-CHANNEL-CONNECTIONS-PATCH.md` |
| `80-project-names.patch` | Projects: a name written in Korean (or any non-ASCII script) gets a stable ASCII id instead of an empty one, so the project can be created; the create error shows next to the button instead of below the fold | (this row) |
| `85-send-scope.patch` | Sending: the composer and the inbox reply pass the active community as the expected relay scope, so a send is refused instead of published to another community's relay (block/buzz#7518); the two resulting errors get a Korean message that says to restart | (this row) |

| `35-call-notifications.patch` | Readable call (huddle) and wave notifications instead of raw JSON / HTML markers; Korean notification copy on Korean Macs | `BUZZ-NOTIFY-PATCH.md` §5 |
| `36-korean-transcripts.patch` | Korean live huddle transcripts (SenseVoice model) with a 한/EN toggle, and remote speech attributed to the actual speaker | `BUZZ-KOREAN-TRANSCRIPT-PATCH.md` |
| `37-huddle-invites.patch` | Discord-style huddle invites: ring a person into the running call (DM huddle card), optionally add them to the channel | `BUZZ-HUDDLE-INVITE-PATCH.md` |
| `90-render-when-covered.patch` | Opt-in per Mac (`BuzzRenderWhenCovered`): keep web views painting while covered so window captures stay current | `BUZZ-RENDER-WHEN-COVERED-PATCH.md` |
| `91-google-calendar-push.patch` | Team calendar "구글 캘린더" tab: one device pushes Buzz calendar adds/edits/deletes to a Google Calendar through an Apps Script web app (one way) | `BUZZ-GOOGLE-CALENDAR-PUSH-PATCH.md` |
| `92-zip-audio.patch` | Packed audio (`song.m4a.zip`) shows as `song.m4a` with in-chat play, and saves as the original file | `BUZZ-ZIP-AUDIO-PATCH.md` |


If a patch stops applying to a new upstream tag, re-implement it from section 3
("intent") of its doc.
