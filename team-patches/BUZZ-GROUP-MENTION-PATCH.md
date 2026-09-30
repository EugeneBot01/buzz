# Buzz 데스크톱 `@everyone` / `@all` 그룹 멘션 패치 — 재현·유지 가이드

> **이 문서를 받은 AI 에이전트(Claude Code / Codex)에게**
> 이 문서만으로 Buzz(block/buzz) 데스크톱 앱에 전원 태그 기능을 넣은 로컬 빌드를 만들고, 공식 업데이트가 와도 유지되게 할 수 있다.
> 같은 폴더 방식의 **알림 패치 문서(`BUZZ-NOTIFY-PATCH.md`)와 빌드·서명·설치·자동 유지 절차가 동일하다.** 두 문서를 모두 받았다면 패치 두 개를 같은 폴더에 두고 한 번만 빌드하라.
> 패치 원문은 **부록 A**, 유지 스크립트는 **부록 B**. 패치가 새 버전과 충돌하면 **"동작과 의도"** 절을 기준으로 재구현하라.
>
> **사람에게:** 에이전트에게 "이 md대로 Buzz 그룹 멘션 패치 적용해줘"라고 하면 된다. 직접 해야 하는 일은 두 가지다. 키체인 창에서 **로그인 암호 + "항상 허용"**(빌드마다 한 번), 그리고 자동 유지를 원하면 LaunchAgent 설치.

- 검증 기준 버전: Buzz Desktop **v0.5.25** (`desktop-v0.5.25`). 2026-09-29 upstream `main`에도 충돌 없이 적용되고 타입 검사를 통과한다. 단독 적용, 알림 패치와 함께 적용 모두 확인했다.
- 대상: Apple Silicon macOS.
- 테스트: 그룹 멘션 단위 테스트 7개 추가, desktop 전체 6,653개 통과. 실기 확인: 전송 시 수신자 p 태그 확장(@everyone → 사람 4명, @all → 사람 4명 + 에이전트 1명).

## 1. 기능

| 입력 | 누구에게 가나 |
|---|---|
| `@everyone` | 그 채널의 **사람 멤버 전원** (에이전트 제외) |
| `@all` | 그 채널의 **멤버 전원, 에이전트 포함**. 에이전트에게 요청할 때 사용 |

- `@`를 치면 자동완성 목록에 `all`(에이전트 포함 전원), `everyone`(사람 전원)이 뜬다. `@a`, `@ev`처럼 치면 맨 위에 뜨고 Tab/Enter로 넣는다. 그냥 타이핑해도 된다(대소문자 무관). 예: `@all 오늘 회의록 정리해줘`.
- 보낸 메시지에서 `@all`/`@everyone`은 멘션 칩처럼 강조된다(수신자가 실제로 붙은 메시지일 때만).
- 보내는 사람 자신은 제외한다. DM에서는 원래 모두에게 가므로 아무것도 하지 않는다.
- 다음 경우에는 동작하지 않는다(오작동 방지): `@allison`처럼 뒤에 글자가 이어질 때, `me@all.com` 같은 이메일, URL 안(`/@all`), 코드(`` `@all` ``, 코드 블록).

## 2. 동작과 의도 (충돌 시 이 기준으로 재구현)

- **보내는 쪽에서 펼친다.** 전송 직전에 채널 멤버 목록(`get_channel_members`, `ChannelMember.isAgent`)을 가져와 해당 멤버 전원을 **일반 수신자 `p` 태그**로 넣는다.
  - 받는 쪽에서는 개별 @멘션과 똑같이 보인다. 그래서 **받는 사람은 패치가 없어도** 멘션 알림을 받고, 에이전트(buzz-acp)도 멘션받은 것으로 처리해 요청에 응답한다.
  - 에이전트가 실제로 응답할지는 각 에이전트의 "누가 지시할 수 있나(respond_to)" 설정을 그대로 따른다.
  - 서버(릴레이) 변경은 없다.
- **사람/에이전트 구분:** `ChannelMember.isAgent`를 쓴다. Rust `get_channel_members`에서 채널 역할이 `bot`이거나, 프로필(kind 0)에 유효한 에이전트 소유자 표시가 있으면 true다.
- **멘션 한도:** 데스크톱 Rust(`desktop/src-tauri/src/events.rs`의 `MAX_MENTIONS`)가 원래 50명으로 막혀 있었다. buzz-sdk와 맞춘 값이고, 릴레이 자체에는 한도가 없다. 이걸 **300**으로 올리고, TS에 같은 값(`MAX_GROUP_MENTION_RECIPIENTS`)을 두어 초과 시 이유가 담긴 오류를 띄운다.
- **자동완성**: `MentionSuggestion`에 `groupMention?: "all" | "everyone"` 필드를 추가했다. `useMentions`가 입력한 쿼리의 접두어가 맞으면(`matchGroupMentionKeys`) 가짜 항목을 넣는다. 쿼리가 있으면 맨 위, 빈 `@`이면 사람 목록 뒤에 둔다. DM에서는 넣지 않는다. 선택하면 `insertMention`이 멘션 맵을 건드리지 않고 `@all ` 글자만 넣는다. `MentionAutocomplete`는 팀 아이콘과 설명 문구로 표시한다.
- **본문 강조**: `resolveMentionProps`는 이벤트에 수신자 태그가 있고 본문에 그룹 토큰이 있으면 `all`/`everyone`을 mentionNames에 넣는다. `MarkdownMention`은 pubkey가 없는 이름도 그룹 라벨이면 칩으로 그린다(프로필 팝오버 없음).
- **변경 파일**
  - 신규 `desktop/src/shared/lib/groupMentions.ts`: 판정·확장·자동완성 매칭·라벨
  - 신규 `desktop/src/shared/lib/groupMentions.test.mjs`
  - `desktop/src/features/messages/lib/useMentions.ts`, `desktop/src/features/messages/ui/MentionAutocomplete.tsx`: 자동완성
  - `desktop/src/shared/lib/resolveMentionNames.ts`, `desktop/src/shared/ui/markdown/MarkdownMention.tsx`: 강조
  - `desktop/src/features/messages/hooks.ts`의 전송 mutation에서 `messageMentionPubkeys(...)` 결과를 `let`으로 받는다. DM이 아니고 그룹 멘션이 있으면 `queryClient.fetchQuery(["channels", id, "members"])`로 멤버를 가져와 합치고, 한도를 검사한다. REST와 WebSocket 두 전송 경로 모두 같은 `recipientPubkeys`를 쓴다.
  - `desktop/src-tauri/src/events.rs`의 `MAX_MENTIONS` 50 → 300

## 3. 알려진 한계

- 강조 표시는 **패치된 앱에서만** 보인다. 패치 없는 팀원 화면에서는 `@all`이 일반 글자로 보이지만, 멘션 알림은 정상으로 간다.
- **보내는 사람만** 패치가 필요하다. 패치 없는 사람이 `@all`을 쓰면 그냥 글자로 가고 아무에게도 알림이 가지 않는다.
- 멤버가 300명을 넘는 채널에서는 오류가 뜨고 전송되지 않는다.
- upstream에도 관련 논의가 있다(issue #4970 클라이언트 자동 확장, #5862 `@everyone`, PR #3197 `@channel`/`@here`, 모두 미머지). 나중에 upstream에 정식 기능이 들어오면 충돌할 수 있다. 그때는 이 패치를 빼고 정식 기능을 쓰는 걸 먼저 검토하라.

## 4. 적용 절차 (에이전트용)

`BUZZ-NOTIFY-PATCH.md`의 5절(실행 절차)과 같다. 차이는 2단계에서 적용하는 패치뿐이다.

```bash
V=$(defaults read /Applications/Buzz.app/Contents/Info.plist CFBundleShortVersionString)
mkdir -p ~/Projects && cd ~/Projects
[ -d buzz ] || git clone --depth 50 https://github.com/block/buzz.git
cd buzz && git fetch -q origin tag desktop-v$V --depth 1 && git checkout -q -B local/patched-$V desktop-v$V

mkdir -p ~/Projects/buzz-patch   # 부록 A → ~/Projects/buzz-patch/20-group-mentions.patch 로 저장
for p in ~/Projects/buzz-patch/*.patch; do git apply --3way "$p"; done   # 알림 패치가 있으면 같이 적용됨

source bin/activate-hermit && pnpm install --frozen-lockfile
cd desktop && ./node_modules/.bin/tsc --noEmit && pnpm test && cd ..
mkdir -p desktop/src-tauri/binaries
for b in buzz-acp buzz-agent buzz-backend-kubernetes buzz-dev-mcp git-credential-nostr buzz; do
  cp /Applications/Buzz.app/Contents/MacOS/$b desktop/src-tauri/binaries/$b-aarch64-apple-darwin; done
cd desktop && pnpm tauri build --features mesh-llm --target aarch64-apple-darwin --bundles app   # 15~25분
B=~/Projects/buzz/desktop/src-tauri/target/aarch64-apple-darwin/release/bundle/macos/Buzz.app
codesign --verify --deep --strict "$B" && echo verify-ok
# 사용자 동의 후 교체
mkdir -p ~/Applications && ditto /Applications/Buzz.app ~/Applications/Buzz-official-$V.app
osascript -e 'quit app "Buzz"'; sleep 4; pkill -x buzz-desktop || true
rm -rf /Applications/Buzz.app && ditto "$B" /Applications/Buzz.app
shasum -a 256 /Applications/Buzz.app/Contents/MacOS/buzz-desktop | cut -d' ' -f1 > ~/Projects/buzz-patch/installed.sha
open /Applications/Buzz.app
rm -rf ~/Projects/buzz/desktop/src-tauri/target
```

키체인 창이 뜨면 사람이 **로그인 암호 → "항상 허용"**을 누른다. 개인키 안전, 사이드카, 저장공간, 서명 함정, 자동 유지(LaunchAgent), 되돌리기는 `BUZZ-NOTIFY-PATCH.md`의 4·6·7·9·10절을 따른다. 이 문서만 받은 경우를 위해 핵심만 적는다.
- 저장공간 20GB 이상 필요, hermit 툴체인 사용(Homebrew rustc 금지).
- 에이전트는 개인키나 키체인 비밀값을 절대 다루지 않는다.
- 자체 서명 인증서를 쓸 때는 `--deep` 금지. 내부 실행파일을 먼저 서명하고 앱을 마지막에 서명한다.
- LaunchAgent는 사람이 직접 설치하고(에이전트는 차단될 수 있음), 반드시 패치본을 설치한 뒤에 켠다. 내용은 알림 문서 7절과 같다.

## 5. 검증 체크리스트

- [ ] `@a` 입력 → 자동완성 맨 위에 `all`이 뜨고 Tab으로 들어간다. `@ev` → `everyone`.
- [ ] 보낸 메시지의 `@all`이 칩처럼 강조된다.
- [ ] 채널에서 `@everyone 테스트` 전송 → 다른 **사람** 멤버에게 멘션 알림이 간다. 에이전트는 반응하지 않는다.
- [ ] `@all 테스트` 전송 → 사람 멤버에게 멘션 알림이 가고, 채널의 **에이전트**가 멘션받은 것처럼 응답한다(에이전트가 **켜져 있고** respond_to 설정이 허용하는 경우. 꺼진 에이전트는 응답하지 않는다. 실기에서 이것 때문에 "아무 일도 안 일어난다"로 오인한 적이 있다).
- [ ] `me@all.com`, `` `@all` ``, `@allison`은 아무 일도 일으키지 않는다.
- [ ] DM에서는 동작 변화가 없다.

---

## 부록 A — 패치 (`20-group-mentions.patch`, 기준 `desktop-v0.5.25`)

아래 코드 블록의 내용을 `~/Projects/buzz-patch/20-group-mentions.patch`로 저장한다(펜스 줄 제외).

````diff
diff --git a/desktop/src-tauri/src/events.rs b/desktop/src-tauri/src/events.rs
index 70039689..93227985 100644
--- a/desktop/src-tauri/src/events.rs
+++ b/desktop/src-tauri/src/events.rs
@@ -22,8 +22,10 @@ use message_tags::{
 /// Maximum content size — matches buzz-sdk (64 KiB).
 const MAX_CONTENT_BYTES: usize = 64 * 1024;
 
-/// Maximum mention count — matches buzz-sdk.
-const MAX_MENTIONS: usize = 50;
+/// Maximum mention count. buzz-sdk caps explicit mentions at 50; the relay
+/// itself has no limit, and @everyone/@all expand to every channel member, so
+/// the desktop allows larger recipient sets.
+const MAX_MENTIONS: usize = 300;
 
 /// Maximum emoji length in characters — matches buzz-sdk.
 const MAX_EMOJI_CHARS: usize = 64;
diff --git a/desktop/src/features/messages/hooks.ts b/desktop/src/features/messages/hooks.ts
index d28f2926..6a6f965c 100644
--- a/desktop/src/features/messages/hooks.ts
+++ b/desktop/src/features/messages/hooks.ts
@@ -37,7 +37,14 @@ import {
 
 export { mergeMessages, mergeTimelineCacheMessages };
 import { splitOutgoingTags } from "@/features/messages/lib/imetaMediaMarkdown";
+import {
+  detectGroupMentions,
+  expandGroupMentionPubkeys,
+  hasGroupMention,
+  MAX_GROUP_MENTION_RECIPIENTS,
+} from "@/shared/lib/groupMentions";
 import { messageMentionPubkeys } from "@/features/messages/lib/messageMentionPubkeys";
+import { getChannelMembers } from "@/shared/api/tauriChannels";
 import { buildSentFromThreadTag } from "@/features/messages/lib/sentFromThread";
 import {
   clearTimeoutState,
@@ -544,11 +551,39 @@ export function useSendMessageMutation(
         mentionTags,
         linkPreviewTags,
       } = splitOutgoingTags(mediaTags);
-      const recipientPubkeys = messageMentionPubkeys(
+      let recipientPubkeys = messageMentionPubkeys(
         effectiveChannel,
         identity.pubkey,
         mentionPubkeys,
       );
+      // @everyone (humans) / @all (humans + agents) expand to every channel
+      // member as ordinary recipient p-tags.
+      const groupMentions = detectGroupMentions(content);
+      if (
+        effectiveChannel.channelType !== "dm" &&
+        hasGroupMention(groupMentions)
+      ) {
+        const members = await queryClient.fetchQuery({
+          queryKey: ["channels", effectiveChannel.id, "members"],
+          queryFn: () => getChannelMembers(effectiveChannel.id),
+          staleTime: 60_000,
+        });
+        recipientPubkeys = [
+          ...new Set([
+            ...recipientPubkeys,
+            ...expandGroupMentionPubkeys(
+              members,
+              groupMentions,
+              identity.pubkey,
+            ),
+          ]),
+        ];
+        if (recipientPubkeys.length > MAX_GROUP_MENTION_RECIPIENTS) {
+          throw new Error(
+            `@everyone/@all can notify at most ${MAX_GROUP_MENTION_RECIPIENTS} members (this channel has ${recipientPubkeys.length}).`,
+          );
+        }
+      }
       if (sentFromThreadRootId && parentEventId) {
         throw new Error(
           "A thread message can only be sent as a top-level message.",
diff --git a/desktop/src/features/messages/lib/useMentions.ts b/desktop/src/features/messages/lib/useMentions.ts
index 63f8aaa1..bfaccd68 100644
--- a/desktop/src/features/messages/lib/useMentions.ts
+++ b/desktop/src/features/messages/lib/useMentions.ts
@@ -57,6 +57,10 @@ import {
   type MentionPickerMode,
   useMentionSelection,
 } from "./useMentionSelection";
+import {
+  GROUP_MENTION_LABELS,
+  matchGroupMentionKeys,
+} from "@/shared/lib/groupMentions";
 import { rankMentionCandidates } from "./mentionRanking";
 import { mapMentionCandidateToSuggestion } from "./mentionSuggestionMapping";
 import { getMentionMemberPubkeys } from "./mentionMemberPubkeys";
@@ -418,12 +422,29 @@ export function useMentions(
       void userSearchQuery.fetchNextPage();
     }
   }, [userSearchQuery]);
+  const groupSuggestions = React.useMemo<MentionSuggestion[]>(() => {
+    if (mentionQuery === null || options?.channelType === "dm") return [];
+    return matchGroupMentionKeys(mentionQuery).map((key) => ({
+      displayName: GROUP_MENTION_LABELS[key],
+      groupMention: key,
+      kind: "identity",
+    }));
+  }, [mentionQuery, options?.channelType]);
   const suggestions = React.useMemo<MentionSuggestion[]>(() => {
     if (mentionQuery === null) {
       return [];
     }
+    // A typed "@a…"/"@e…" puts the group entries first; a bare "@" lists them
+    // after people so the default picker is unchanged at the top.
+    const withGroups = (people: MentionSuggestion[]) =>
+      mentionQuery.trim()
+        ? [...groupSuggestions, ...people]
+        : [...people, ...groupSuggestions];
     if (matchingSuggestions.length > 0) {
-      return matchingSuggestions;
+      return withGroups(matchingSuggestions);
+    }
+    if (groupSuggestions.length > 0 && !userSearchQuery.isFetching) {
+      return groupSuggestions;
     }
     if (userSearchQuery.isFetching) {
       return filterCachedAgentSuggestions(
@@ -433,6 +454,7 @@ export function useMentions(
     }
     return [];
   }, [
+    groupSuggestions,
     matchingSuggestions,
     mentionCandidatesWithTeams,
     mentionQuery,
@@ -494,6 +516,20 @@ export function useMentions(
         clearTimeout(debounceTimerRef.current);
         debounceTimerRef.current = null;
       }
+      if (suggestion.groupMention) {
+        // Literal token; expanded into recipients at send time.
+        mentionPickerOriginRef.current = null;
+        setMentionQuery(null);
+        setSelected(0);
+        const groupStart =
+          flushedMentionStartIndexRef.current ?? mentionStartIndex;
+        flushedMentionStartIndexRef.current = null;
+        return {
+          replaceFromOffset: groupStart,
+          replaceToOffset: selectionEnd,
+          insertText: `@${suggestion.groupMention} `,
+        };
+      }
       const [boundSuggestion] = selectedMentionLabels(
         [suggestion],
         mentionMapRef.current,
diff --git a/desktop/src/features/messages/ui/MentionAutocomplete.tsx b/desktop/src/features/messages/ui/MentionAutocomplete.tsx
index 65ae331d..5b74ba6b 100644
--- a/desktop/src/features/messages/ui/MentionAutocomplete.tsx
+++ b/desktop/src/features/messages/ui/MentionAutocomplete.tsx
@@ -24,6 +24,8 @@ export type MentionSuggestion = {
   teamId?: string;
   teamMembers?: TeamMentionMember[];
   kind?: "identity" | "persona" | "team";
+  /** @all / @everyone pseudo-entry: inserts the literal token. */
+  groupMention?: "all" | "everyone";
   displayName: string;
   avatarUrl?: string | null;
   isAgent?: boolean;
@@ -250,6 +252,9 @@ export const MentionAutocomplete = React.memo(function MentionAutocomplete({
                 ? `persona-${suggestion.personaId}`
                 : null) ??
               (suggestion.teamId ? `team-${suggestion.teamId}` : null) ??
+              (suggestion.groupMention
+                ? `group-${suggestion.groupMention}`
+                : null) ??
               suggestion.displayName;
             const hasNameCollision =
               (nameCounts.get(suggestion.displayName.toLowerCase()) ?? 0) > 1;
@@ -264,7 +269,8 @@ export const MentionAutocomplete = React.memo(function MentionAutocomplete({
                 ? safeNpub(suggestion.pubkey)
                 : null;
             const hasMetadataBeforeNpub = Boolean(
-              suggestion.kind === "team" ||
+              suggestion.groupMention ||
+                suggestion.kind === "team" ||
                 suggestion.isAgent ||
                 suggestion.role ||
                 ownerLabel ||
@@ -305,7 +311,7 @@ export const MentionAutocomplete = React.memo(function MentionAutocomplete({
                   tabIndex={-1}
                   type="button"
                 >
-                  {suggestion.kind === "team" ? (
+                  {suggestion.kind === "team" || suggestion.groupMention ? (
                     <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary/10 text-primary">
                       <Users aria-hidden="true" className="h-4 w-4" />
                     </span>
@@ -338,7 +344,14 @@ export const MentionAutocomplete = React.memo(function MentionAutocomplete({
                             : "text-muted-foreground",
                         )}
                       >
-                        {suggestion.kind === "team" ? (
+                        {suggestion.groupMention ? (
+                          <span className="inline-flex shrink-0 items-center gap-1">
+                            <Users aria-hidden="true" className="h-3.5 w-3.5" />
+                            {suggestion.groupMention === "all"
+                              ? "everyone in channel, agents included"
+                              : "all people in channel (no agents)"}
+                          </span>
+                        ) : suggestion.kind === "team" ? (
                           <span className="inline-flex shrink-0 items-center gap-1">
                             <Users aria-hidden="true" className="h-3.5 w-3.5" />
                             team · {suggestion.teamMembers?.length ?? 0} agents
diff --git a/desktop/src/shared/lib/groupMentions.test.mjs b/desktop/src/shared/lib/groupMentions.test.mjs
new file mode 100644
index 00000000..86a627c1
--- /dev/null
+++ b/desktop/src/shared/lib/groupMentions.test.mjs
@@ -0,0 +1,84 @@
+import assert from "node:assert/strict";
+import test from "node:test";
+
+import {
+  detectGroupMentions,
+  expandGroupMentionPubkeys,
+  isGroupMentionLabel,
+  matchGroupMentionKeys,
+} from "./groupMentions.ts";
+import { resolveMentionProps } from "./resolveMentionNames.ts";
+
+const SENDER = "a".repeat(64);
+const HUMAN = "b".repeat(64);
+const AGENT = "c".repeat(64);
+const members = [
+  { pubkey: SENDER, isAgent: false },
+  { pubkey: HUMAN, isAgent: false },
+  { pubkey: AGENT, isAgent: true },
+];
+
+test("detects standalone @everyone and @all, case-insensitive", () => {
+  assert.deepEqual(detectGroupMentions("hi @everyone"), {
+    everyone: true,
+    all: false,
+  });
+  assert.deepEqual(detectGroupMentions("@ALL 확인 부탁"), {
+    everyone: false,
+    all: true,
+  });
+  assert.deepEqual(detectGroupMentions("@all, @everyone!"), {
+    everyone: true,
+    all: true,
+  });
+  assert.deepEqual(detectGroupMentions("(@all)"), {
+    everyone: false,
+    all: true,
+  });
+});
+
+test("ignores lookalikes, emails and code", () => {
+  const none = { everyone: false, all: false };
+  assert.deepEqual(detectGroupMentions("@allison @everyones"), none);
+  assert.deepEqual(detectGroupMentions("mail me: me@all.com"), none);
+  assert.deepEqual(detectGroupMentions("x@all y"), none);
+  assert.deepEqual(detectGroupMentions("`@all` and ```\n@everyone\n```"), none);
+  assert.deepEqual(detectGroupMentions("https://x.com/@all"), none);
+});
+
+test("@everyone expands to humans only, excluding the sender", () => {
+  assert.deepEqual(
+    expandGroupMentionPubkeys(members, { everyone: true, all: false }, SENDER),
+    [HUMAN],
+  );
+});
+
+test("@all includes agents", () => {
+  assert.deepEqual(
+    expandGroupMentionPubkeys(members, { everyone: false, all: true }, SENDER),
+    [HUMAN, AGENT],
+  );
+});
+
+test("no group mention expands to nothing", () => {
+  assert.deepEqual(
+    expandGroupMentionPubkeys(members, { everyone: false, all: false }, SENDER),
+    [],
+  );
+});
+
+test("picker offers group entries by prefix", () => {
+  assert.deepEqual(matchGroupMentionKeys(""), ["all", "everyone"]);
+  assert.deepEqual(matchGroupMentionKeys("A"), ["all"]);
+  assert.deepEqual(matchGroupMentionKeys("ev"), ["everyone"]);
+  assert.deepEqual(matchGroupMentionKeys("bob"), []);
+  assert.equal(isGroupMentionLabel(" ALL "), true);
+  assert.equal(isGroupMentionLabel("allison"), false);
+});
+
+test("group token is highlighted only when the event carries recipients", () => {
+  const tagged = resolveMentionProps([["p", HUMAN]], {}, "@all 확인");
+  assert.ok(tagged.mentionNames?.includes("all"));
+  const untagged = resolveMentionProps([], {}, "@all 확인");
+  assert.equal(untagged.mentionNames, undefined);
+});
diff --git a/desktop/src/shared/lib/groupMentions.ts b/desktop/src/shared/lib/groupMentions.ts
new file mode 100644
index 00000000..c5311377
--- /dev/null
+++ b/desktop/src/shared/lib/groupMentions.ts
@@ -0,0 +1,76 @@
+import type { ChannelMember } from "@/shared/api/types";
+import { normalizePubkey } from "@/shared/lib/pubkey";
+
+/**
+ * Group mentions, expanded client-side at send time into ordinary recipient
+ * `p` tags so every recipient (patched or not) gets a normal @mention alert
+ * and agents treat it as being addressed:
+ *
+ * - `@everyone` — every human member of the channel
+ * - `@all`      — every member, agents included
+ *
+ * DMs already address every participant, so they are left alone.
+ */
+export type GroupMentionFlags = { everyone: boolean; all: boolean };
+
+export type GroupMentionKey = keyof GroupMentionFlags;
+
+export const GROUP_MENTION_LABELS: Record<GroupMentionKey, string> = {
+  everyone: "everyone",
+  all: "all",
+};
+
+/** Group mentions offered by the @ picker for a typed query (prefix match). */
+export function matchGroupMentionKeys(query: string): GroupMentionKey[] {
+  const normalized = query.trim().toLowerCase();
+  return (["all", "everyone"] as const).filter((key) =>
+    key.startsWith(normalized),
+  );
+}
+
+export function isGroupMentionLabel(label: string): boolean {
+  const normalized = label.trim().toLowerCase();
+  return normalized === "everyone" || normalized === "all";
+}
+
+// Standalone token: not preceded by a word char, dot or another @ (so
+// emails like a@all.com or @@all never match), and not followed by a word
+// char (so @allison / @everyones stay ordinary text).
+const GROUP_MENTION_PATTERN =
+  /(?<![\p{L}\p{N}_.@/])@(everyone|all)(?![\p{L}\p{N}_])/giu;
+
+/** Must match MAX_MENTIONS in desktop/src-tauri/src/events.rs. */
+export const MAX_GROUP_MENTION_RECIPIENTS = 300;
+
+export function detectGroupMentions(content: string): GroupMentionFlags {
+  const flags: GroupMentionFlags = { everyone: false, all: false };
+  // Inline/fenced code is literal text, not an instruction to notify.
+  const withoutCode = content
+    .replace(/```[\s\S]*?```/g, " ")
+    .replace(/`[^`\n]*`/g, " ");
+  for (const match of withoutCode.matchAll(GROUP_MENTION_PATTERN)) {
+    if (match[1].toLowerCase() === "all") flags.all = true;
+    else flags.everyone = true;
+  }
+  return flags;
+}
+
+export function hasGroupMention(flags: GroupMentionFlags): boolean {
+  return flags.everyone || flags.all;
+}
+
+export function expandGroupMentionPubkeys(
+  members: readonly Pick<ChannelMember, "pubkey" | "isAgent">[],
+  flags: GroupMentionFlags,
+  senderPubkey: string,
+): string[] {
+  if (!hasGroupMention(flags)) return [];
+  const sender = normalizePubkey(senderPubkey);
+  return [
+    ...new Set(
+      members
+        .filter((member) => flags.all || !member.isAgent)
+        .map((member) => normalizePubkey(member.pubkey)),
+    ),
+  ].filter((pubkey) => pubkey.length > 0 && pubkey !== sender);
+}
diff --git a/desktop/src/shared/lib/resolveMentionNames.ts b/desktop/src/shared/lib/resolveMentionNames.ts
index 270ee945..8620f6af 100644
--- a/desktop/src/shared/lib/resolveMentionNames.ts
+++ b/desktop/src/shared/lib/resolveMentionNames.ts
@@ -1,3 +1,4 @@
+import { detectGroupMentions, GROUP_MENTION_LABELS } from "./groupMentions";
 import { mentionOccurrences } from "./mentionOccurrences";
 import type { UserProfileSummary } from "@/shared/api/types";
 
@@ -159,6 +160,14 @@ export function resolveMentionProps(
     names.add(entry.displayName);
     if (keys.length === 1) pubkeysByName[label] = keys[0];
   }
+  // @everyone / @all expanded into recipient tags at send time: highlight the
+  // literal token too. Only when the event actually carries recipients, so an
+  // unpatched sender's plain "@all" text is not dressed up as a mention.
+  if (taggedKeys.size > 0) {
+    const groups = detectGroupMentions(content);
+    if (groups.everyone) names.add(GROUP_MENTION_LABELS.everyone);
+    if (groups.all) names.add(GROUP_MENTION_LABELS.all);
+  }
 
   return {
     mentionNames: names.size > 0 ? [...names] : undefined,
diff --git a/desktop/src/shared/ui/markdown/MarkdownMention.tsx b/desktop/src/shared/ui/markdown/MarkdownMention.tsx
index 9d9f59ad..139871bf 100644
--- a/desktop/src/shared/ui/markdown/MarkdownMention.tsx
+++ b/desktop/src/shared/ui/markdown/MarkdownMention.tsx
@@ -2,6 +2,7 @@ import type * as React from "react";
 import { AgentManagementMarker } from "@/features/agents/ui/OtherSetupAgentMarker";
 import { UserProfilePopover } from "@/features/profile/ui/UserProfilePopover";
 import { cn } from "@/shared/lib/cn";
+import { isGroupMentionLabel } from "@/shared/lib/groupMentions";
 import { formatMentionDisplayLabel } from "@/shared/lib/mentionDisplay";
 import {
   inlineChipIconClasses,
@@ -27,8 +28,10 @@ export function createMarkdownMention(interactive: boolean) {
     const mentionText = String(children ?? "");
     const mentionName = mentionText.replace(/^@/, "").trim().toLowerCase();
     const pubkey = mentionPubkeysByName?.[mentionName];
-    // Unbound literal competitors consume their full range, without a chip.
-    if (mentionPubkeysByName && !pubkey) return mentionText;
+    // Unbound literal competitors consume their full range, without a chip —
+    // except @everyone/@all, which stand for every recipient of the event.
+    if (mentionPubkeysByName && !pubkey && !isGroupMentionLabel(mentionName))
+      return mentionText;
     const isAgentMention =
       pubkey !== undefined &&
       agentMentionPubkeysByName?.[mentionName] === pubkey;
````

## 부록 B — `rebuild.sh` (알림 패치 문서와 동일)

````bash
#!/usr/bin/env bash
# Buzz 로컬 패치 유지 스크립트 (알림 · 그룹 멘션)
#
# 설치된 /Applications/Buzz.app 이 공식 업데이트로 바뀌면(설치 기록 해시와 다르면)
#   1) 설치된 버전의 태그(desktop-vX.Y.Z)를 받아 이 폴더의 *.patch 를 이름순으로 3-way 적용
#      (10-notifications.patch = 알림, 20-group-mentions.patch = @everyone/@all — 필요한 것만 두면 됨)
#   2) 새 공식 앱의 사이드카 바이너리를 그대로 가져와 번들
#   3) 빌드 → (선택) 고정 인증서로 서명 → 공식 앱 백업 → 교체 → 재실행 → 빌드 캐시 삭제
# 이미 패치본이면 즉시 종료(1초 미만).
#
# 사용:  rebuild.sh           # 필요할 때만
#        rebuild.sh --force   # 무조건 재빌드
# 환경변수:
#   BUZZ_REPO      소스 위치        (기본 ~/Projects/buzz)
#   BUZZ_PATCH_DIR 이 스크립트 폴더 (기본 ~/Projects/buzz-patch)
#   BUZZ_SIGN_ID   코드서명 인증서 이름. 비우면 Tauri 기본(ad-hoc) 서명 그대로 사용.
set -euo pipefail

REPO="${BUZZ_REPO:-$HOME/Projects/buzz}"
STATE="${BUZZ_PATCH_DIR:-$HOME/Projects/buzz-patch}"
APP="/Applications/Buzz.app"
BIN="$APP/Contents/MacOS/buzz-desktop"
SHA_FILE="$STATE/installed.sha"
LOG="$STATE/rebuild.log"
LOCK="$STATE/.lock"
TARGET="aarch64-apple-darwin"
SIGN_ID="${BUZZ_SIGN_ID:-}"

notify() { osascript -e "display notification \"$1\" with title \"Buzz 로컬 패치\"" >/dev/null 2>&1 || true; }
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') rebuild.sh $*"

mkdir "$LOCK" 2>/dev/null || { echo "already running"; exit 0; }
trap 'rmdir "$LOCK"' EXIT

[[ -x "$BIN" ]] || { echo "no app installed"; exit 0; }
shopt -s nullglob
PATCHES=("$STATE"/*.patch)
(( ${#PATCHES[@]} > 0 )) || { notify "패치 파일 없음: $STATE/*.patch"; exit 1; }
current_sha=$(shasum -a 256 "$BIN" | cut -d' ' -f1)
if [[ "${1:-}" != "--force" && -f "$SHA_FILE" && "$(cat "$SHA_FILE")" == "$current_sha" ]]; then
  echo "patched build already installed"; exit 0
fi

sleep 20  # 업데이터가 아직 파일을 쓰는 중일 수 있음
version=$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)
tag="desktop-v$version"
echo "installed=$version"
notify "Buzz $version 감지 — 로컬 패치 재적용 빌드 시작(15~20분)"

cd "$REPO"
source bin/activate-hermit >/dev/null 2>&1
git fetch -q origin tag "$tag" --depth 1 || { notify "태그 $tag 없음 — 에이전트에게 문의"; exit 1; }
git reset -q --hard
git checkout -q -B "local/notify-$version" "$tag"
for patch in "${PATCHES[@]}"; do
  if ! git apply --3way "$patch"; then
    git reset -q --hard
    notify "패치 충돌($version, $(basename "$patch")) — 에이전트에게 'Buzz 패치 충돌'이라고 말하기"
    exit 1
  fi
done

mkdir -p desktop/src-tauri/binaries
for b in buzz-acp buzz-agent buzz-backend-kubernetes buzz-dev-mcp git-credential-nostr buzz; do
  cp "$APP/Contents/MacOS/$b" "desktop/src-tauri/binaries/$b-$TARGET"
done

if [[ "${1:-}" != "--force" ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications"/Buzz-official-*.app   # 공식 앱 백업은 최신 1개만
  ditto "$APP" "$HOME/Applications/Buzz-official-$version.app"
fi

pnpm install --frozen-lockfile
(cd desktop && pnpm tauri build --features mesh-llm --target "$TARGET" --bundles app)
built="$REPO/desktop/src-tauri/target/$TARGET/release/bundle/macos/Buzz.app"
[[ -d "$built" ]] || { notify "빌드 결과물 없음 — 로그: $LOG"; exit 1; }

if [[ -n "$SIGN_ID" ]]; then
  # --deep 으로 한 번에 서명하면 검증이 깨진다. 내부 실행파일 → 앱 순서로.
  find "$built/Contents" -type f -perm -111 ! -path "*/MacOS/buzz-desktop" -print0 |
    xargs -0 -n1 codesign --force --preserve-metadata=entitlements,flags,runtime --sign "$SIGN_ID"
  codesign --force --preserve-metadata=entitlements,requirements,flags,runtime --sign "$SIGN_ID" "$built"
fi
codesign --verify --deep --strict "$built" || { notify "서명 검증 실패 — 로그: $LOG"; exit 1; }

osascript -e 'quit app "Buzz"' >/dev/null 2>&1 || true
sleep 5
pkill -x buzz-desktop 2>/dev/null || true
rm -rf "$APP"
ditto "$built" "$APP"
shasum -a 256 "$BIN" | cut -d' ' -f1 >"$SHA_FILE"
open "$APP"
rm -rf "$REPO/desktop/src-tauri/target"   # 수 GB — 저장공간 확보
echo "installed patched $version"
notify "Buzz $version 로컬 패치 적용 완료 — 키체인 창이 뜨면 '항상 허용'"
````
