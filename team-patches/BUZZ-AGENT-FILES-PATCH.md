# Agent files patch (99)

Agents can now hand people the files they make, in the chat.

## What changes

- **`buzz` CLI upload** (`crates/buzz-cli/src/client.rs`): besides jpeg/png/gif/webp
  images and mp4 video, generic files are accepted — documents, sheets, slides,
  PDF, archives, text (anything the relay stores as a download), up to 100 MB.
  Other images, other video and audio are refused with a hint to zip them (the
  relay refuses them too). Active web content and executables are refused (the
  relay's `BLOCKED_FILE_MIME_TYPES`). `upload_kind(mime)` decides.
- **`buzz messages send --file`** (`commands/messages.rs`): a generic file gets an
  imeta `filename <name>` and a `[name](url)` line in the body, exactly like a
  file attached in the desktop app, so it shows as a file card with download,
  "열기" and the files window.
- **Agent base prompt** (`crates/buzz-acp/src/base_prompt.md`): "Deliver files as
  attachments" — attach what you make with `--file`; never just name a local path.
- **DeckCraft preset** (`mcpCatalog.ts`): "PPT (DeckCraft)" next to WordCraft and
  GridCraft. `install-artcraft.sh` now installs DeckCraft by default.

## Notes

- DeckCraft's and GridCraft's MCP servers have no folder limits (WordCraft's do).
- Rust code here is only compiled in the full build (the check-only run does not
  build Rust).
