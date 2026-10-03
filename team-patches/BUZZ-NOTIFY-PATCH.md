# Buzz 데스크톱 알림 패치 — 재현·유지 가이드

> **이 문서를 받은 AI 에이전트(Claude Code / Codex)에게**
> 이 문서만 있으면 Buzz(block/buzz) 데스크톱 앱의 알림 문제를 고친 로컬 빌드를 똑같이 만들고, 공식 업데이트가 와도 패치가 유지되게 설정할 수 있다.
> 아래 "실행 절차"를 순서대로 따르라. 패치 원문은 **부록 A**, 유지 스크립트는 **부록 B**에 있다.
> 패치가 새 버전과 충돌하면 **"변경 내용과 의도"** 절을 기준으로 같은 동작을 직접 다시 구현하라.
>
> **사람에게:** 에이전트에게 "이 md대로 Buzz 알림 패치 적용해줘"라고 하면 된다. 도중에 두 번 직접 해야 하는 일이 있다. 키체인 창에서 **로그인 암호 + "항상 허용"** 누르기(빌드마다 한 번), 그리고 자동 유지를 원하면 LaunchAgent 설치 승인.

- 검증 기준 버전: Buzz Desktop **v0.5.25** (태그 `desktop-v0.5.25`). 2026-09-29 기준 upstream `main`에도 충돌 없이 적용되고 타입 검사를 통과한다.
- 대상: **Apple Silicon macOS** (`aarch64-apple-darwin`). Intel 맥은 `TARGET`을 `x86_64-apple-darwin`으로 바꾸면 된다(검증 안 됨).
- 실측 테스트: desktop 단위 테스트 전부 통과. 실사용 확인 완료: 멘션 배너, 일반 채널 메시지 배너(All messages), 다른 커뮤니티 알림, 재실행 시 키체인 재질문 없음.
- 함께 쓰는 패치: `@everyone`/`@all` 그룹 멘션은 별도 문서 `BUZZ-GROUP-MENTION-PATCH.md`(`20-group-mentions.patch`). 두 패치는 각각 따로 적용해도 되고 같이 적용해도 된다.

---

## 1. 증상

1. 알림이 왔다 안 왔다 한다.
2. DM 알림은 잘 뜨는데, 채널에서 온 메시지는 **알림 카드(배너) 없이 독 아이콘만 튄다.**
3. Buzz 창이 맨 앞에 있으면(다른 채널을 보고 있어도) 배너가 안 뜬다.
4. 다른 커뮤니티를 선택해 두면 원래 커뮤니티의 알림이 전혀 안 온다.
5. 잠자기에서 깨어난 뒤, 또는 처음 DM을 보낸 사람의 메시지는 알림이 빠진다.

## 2. 원인 (코드로 확인함)

| # | 원인 | 위치 (v0.5.25) |
|---|---|---|
| A | macOS 알림 델리게이트가 앱이 앞에 있을 때 `UNNotificationPresentationOptions::List`만 반환한다. 알림센터에만 쌓이고 배너가 안 뜬다. | `desktop/src-tauri/src/macos_notifications.rs` `will_present_notification` |
| B | 채널 일반 메시지는 **설계상** `requestDockBounce()`만 호출한다. 카드는 DM·@멘션·팔로우한 스레드 답글에만 뜬다. 채널별 알림 레벨 설정도 없다(upstream PR #3233이 있지만 미머지 상태이고, 그 PR도 일반 글 배너는 후속 과제로 미룸). | `desktop/src/app/useAppShellDesktopNotifications.ts` `handleChannelNotification` |
| C | DM: 재연결(잠자기 해제·네트워크 끊김)이나 채널 목록이 바뀔 때마다 "구독 시작 시각"이 now로 리셋된다. 끊긴 동안 온 DM을 릴레이가 재전송해도 전부 버린다. | `desktop/src/features/channels/useLiveChannelUpdates.ts` `dmSubscriptionStartedAtRef` |
| D | 처음 DM을 보낸 사람의 경우, 그 DM 채널이 목록에 새로 생긴 뒤 `since=now`로 구독한다. 채널을 만든 첫 메시지를 놓친다. | 같은 파일 `subscribeLive({... since })` |
| E | 멘션 카드는 홈 피드 diff로만 뜬다. 앱이 백그라운드면 피드 폴링이 멈추고, 라이브 신호로 한 번만 재조회한다. 그 조회가 릴레이 인덱싱보다 빠르면 놓칠 수 있다(**추정**, 방어 코드만 넣음). | `desktop/src/app/AppShell.tsx` `refetchHomeFeedFromLiveSignal` |
| F | 라이브 구독은 **활성 커뮤니티 하나만** 연다. 비활성 커뮤니티는 30초마다 레일 unread 점만 조회하고 알림은 만들지 않는다. | `desktop/src/features/communities/useCommunityUnread.ts` |
| — | (못 고침) 호스티드 릴레이에서 구독이 조용히 끊기는 서버 버그가 보고돼 있다(upstream issue #4743). 클라이언트 패치 범위 밖. | 서버 |

## 3. 변경 내용과 의도 (충돌 시 이 기준으로 재구현)

1. **포그라운드 배너**: `will_present_notification`의 반환값을 `Banner | List`로 바꾼다. 지금 보고 있는 채널은 프런트엔드가 이미 걸러내므로(`notifyWhileViewing` 설정), 여기까지 온 알림은 보여줄 가치가 있는 알림이다.
2. **채널 알림 레벨(디스코드식)**: 새 저장소 `desktop/src/features/notifications/lib/channelAllMessageAlerts.ts`.
   - 레벨은 `"all" | "mentions"`. "Nothing"은 기존 채널 음소거(`useChannelMutes`)를 그대로 쓴다.
   - 전역 기본값 `defaultLevel`은 **"all"**. 채널별 override는 `{ [channelId]: level }`. 실효 레벨은 `override ?? default`.
   - localStorage 키 `buzz-channel-alert-levels.v2:<pubkey>`. `useSyncExternalStore`로 컴포넌트 간 동기화한다.
3. **UI**
   - 사이드바 채널 우클릭 → `Notifications` 서브메뉴: `Default (현재 기본값)` / `All messages` / `Only @mentions` / `Nothing`. 트리거 옆에 현재 상태(All/@/Off)를 표시한다. DM에는 기존 Mute 토글을 유지한다. (`ChannelContextMenu.tsx`)
   - 설정 → Notifications에 "Channel notifications" 그룹 추가: 전역 기본값 버튼 2개 + "Apply default to all channels"(override 전부 삭제). (`NotificationSettingsCard.tsx`)
   - 사운드 슬롯에 `channel_message`("Channel messages") 추가: 소리 선택과 전체 끄기 스위치. (`sound.ts`, `notificationFormat.ts`의 source 추가)
4. **채널 일반 메시지 카드**: `handleChannelNotification`에서 다음 조건이 모두 맞으면 DM과 같은 형식의 카드를 보내고, 그다음 기존처럼 dock bounce한다. (`useAppShellDesktopNotifications.ts`)
   - 실효 레벨이 all
   - `channel_message` 슬롯이 켜져 있음
   - DM 채널이 아님(DM 경로가 따로 있음)
   - 보고 있는 채널이 아님(`notifyWhileViewing`이면 예외)
   - @멘션이 아님(홈피드 경로가 담당하므로 중복 방지)
   - 10분 이내 메시지
   - 이를 위해 훅에 `activeChannelId`를 넘긴다(AppShell).
5. **DM 누락 방지**: `MISSED_MESSAGE_ALERT_WINDOW_SECONDS = 600`을 export한다. DM 백로그 판정을 `created_at < startedAt - 600`으로 완화해, 끊긴 동안 온 10분 이내 메시지는 알림을 보낸다. 더 오래된 것은 한꺼번에 쏟아지지 않도록 조용히 둔다. 재전송 중복은 기존 seen-set이 막는다.
6. **새 채널 백필**: 첫 동기화 이후에 새로 나타난 채널은 `since = now - 120`으로 구독한다(첫 DM 누락 방지).
7. **멘션 재조회**: 라이브 멘션 신호가 오면 즉시 재조회하고, 3초 뒤에 한 번 더 조회한다.
8. **비활성 커뮤니티 알림**: 새 파일 `inactiveCommunityAlerts.ts`.
   - 비활성 커뮤니티마다 30초 간격으로 `withReadOnlyRelayClient` 조회를 한다.
   - 채널 목록·이름·음소거는 5분 캐시.
   - 새 메시지를 분류한다(`classifyInactiveCommunityEvent`): DM → dm, @멘션 → mention(음소거 무시), 음소거 채널 → 무시, 스레드 답글 → 팔로우·참여 여부, 그 외 → 실효 레벨 all일 때 channel_message.
   - 카드 제목 끝에 ` · 커뮤니티이름`을 붙인다.
   - 처음 관측할 때는 now부터 시작해 과거 메시지가 쏟아지지 않게 한다. 방금 떠난 커뮤니티는 기준 시각을 리셋한다.
   - `useAppShellDesktopNotifications` 안에서 마운트한다. `communityUnreadObserver.ts`의 `defaultReadThreadRelationships`를 export로 바꾼다.
   - 단위 테스트 `inactiveCommunityAlerts.test.mjs` 5개.

부하: 유휴 상태 실측 CPU 0%, 메모리 약 130MB. 알림 폴링은 30초마다 가벼운 조회 한 번이다.

## 4. 사전 조건·주의

- **저장공간 여유 20GB 이상**: 빌드 중 target 폴더가 수 GB까지 커진다. 스크립트가 설치 후 삭제한다.
- **시간**: 첫 빌드 15~25분(Rust 툴체인·크레이트 다운로드 포함). 이후 재빌드 15~20분. 빌드 중에는 CPU를 많이 쓴다.
- **툴체인은 저장소 내장 hermit으로**: `source bin/activate-hermit`로 pnpm·node·rustup(1.95 고정)을 쓴다. Homebrew의 rustc/cargo는 `rust-toolchain.toml`을 무시하니 쓰지 말 것.
- **개인키 안전**: Buzz는 개인키를 키체인 `buzz-desktop / secrets`에 저장한다. 비밀 저장소는 서명과 무관하게 공식 앱과 로컬 빌드가 같은 항목을 공유하도록 설계돼 있다. 키체인 접근을 거부하더라도 새 신원을 몰래 만들지 않고 "잠김/복구" 화면으로 멈춘다(fail-closed, `app_state.rs`에서 확인). 그래도 작업 전에 앱 설정에서 개인키(nsec) 백업을 권장한다. **에이전트는 개인키나 키체인 비밀값을 절대 읽거나 옮기지 않는다.**
- **사이드카 바이너리**: `pnpm tauri build`는 `desktop/src-tauri/binaries/<이름>-<target>`에 사이드카 6개가 있어야 한다. 직접 빌드하지 않고 **설치된 공식 앱의 `Contents/MacOS/`에서 그대로 복사**한다(버전 일치 보장).
- **업데이터**: 패치본에도 Tauri 업데이터가 살아 있다. 공식 업데이트가 오면 앱을 덮어쓰고, 그때 부록 B 스크립트가 다시 패치한다.

## 5. 실행 절차 (에이전트용)

```bash
# 0) 설치된 버전 확인
V=$(defaults read /Applications/Buzz.app/Contents/Info.plist CFBundleShortVersionString)   # 예: 0.5.25

# 1) 소스 준비
mkdir -p ~/Projects && cd ~/Projects
[ -d buzz ] || git clone --depth 50 https://github.com/block/buzz.git
cd buzz && git fetch -q origin tag desktop-v$V --depth 1 && git checkout -q -B local/patched-$V desktop-v$V

# 2) 패치 적용 — 부록 A의 diff를 ~/Projects/buzz-patch/10-notifications.patch 로 저장한 뒤
mkdir -p ~/Projects/buzz-patch
for p in ~/Projects/buzz-patch/*.patch; do git apply --3way "$p"; done   # 폴더의 패치 전부(이름순)
#    충돌 시: 3절 "변경 내용과 의도"대로 해당 부분을 직접 구현

# 3) 의존성 + 검증
source bin/activate-hermit
pnpm install --frozen-lockfile
cd desktop && ./node_modules/.bin/tsc --noEmit && pnpm test     # 전부 통과해야 함
cd ..

# 4) 사이드카 복사
mkdir -p desktop/src-tauri/binaries
for b in buzz-acp buzz-agent buzz-backend-kubernetes buzz-dev-mcp git-credential-nostr buzz; do
  cp /Applications/Buzz.app/Contents/MacOS/$b desktop/src-tauri/binaries/$b-aarch64-apple-darwin
done

# 5) 빌드 (백그라운드 권장, 15~25분)
cd desktop && pnpm tauri build --features mesh-llm --target aarch64-apple-darwin --bundles app
B=~/Projects/buzz/desktop/src-tauri/target/aarch64-apple-darwin/release/bundle/macos/Buzz.app

# 6) (선택) 고정 인증서 서명 — 6절 참고. 쓰지 않으면 이 단계 생략
# SIGN_ID="인증서 이름"
# find "$B/Contents" -type f -perm -111 ! -path "*/MacOS/buzz-desktop" -print0 | xargs -0 -n1 codesign --force --preserve-metadata=entitlements,flags,runtime --sign "$SIGN_ID"
# codesign --force --preserve-metadata=entitlements,requirements,flags,runtime --sign "$SIGN_ID" "$B"
codesign --verify --deep --strict "$B" && echo verify-ok

# 7) 공식 앱 백업 → 교체 → 실행 (사용자 동의 후)
mkdir -p ~/Applications && ditto /Applications/Buzz.app ~/Applications/Buzz-official-$V.app
osascript -e 'quit app "Buzz"'; sleep 4; pkill -x buzz-desktop || true
rm -rf /Applications/Buzz.app && ditto "$B" /Applications/Buzz.app
shasum -a 256 /Applications/Buzz.app/Contents/MacOS/buzz-desktop | cut -d' ' -f1 > ~/Projects/buzz-patch/installed.sha
open /Applications/Buzz.app

# 8) 정리
rm -rf ~/Projects/buzz/desktop/src-tauri/target
```

실행 후 **키체인 창**("Buzz이(가) 'buzz-desktop'에 저장된 비밀 정보를 사용하려고 합니다")이 뜬다. 사람이 **로그인 암호 입력 → "항상 허용"**을 누른다. "허용"을 누르면 그 한 번만 통과되고 매번 다시 묻는다.

## 6. 키체인 질문에 대해 (실측 결과)

- macOS는 "항상 허용"을 **빌드된 실행파일 단위**로 기억한다. 같은 빌드는 재실행해도 다시 묻지 않지만(확인함), **재빌드하면 한 번 다시 묻는다.** 자체 서명 인증서로 서명해도 새 빌드에서 다시 물었다(확인함). 즉 업데이트로 재빌드될 때마다 한 번씩은 누르는 구조다.
- 이 질문을 완전히 없애려면 키체인 항목의 접근 규칙을 바꾸거나 비밀값을 다시 저장해야 한다. 개인키를 다루는 일이므로 **하지 않는다.**
- 자체 서명 인증서(`BUZZ_SIGN_ID`)는 선택 사항이다. 서명 신원이 빌드마다 고정되는 장점은 있지만 위 동작을 바꾸지는 못했다. 쓴다면 반드시 **내부 실행파일 → 앱 순서**로 서명한다. `codesign --deep` 한 번으로 서명하면 "nested code is modified or invalid"로 검증이 실패한다(겪음).

## 7. 업데이트돼도 유지되게 (부록 B)

1. 부록 B를 `~/Projects/buzz-patch/rebuild.sh`로 저장하고 `chmod +x`. 부록 A 패치는 같은 폴더의 `10-notifications.patch`로 둔다. 그룹 멘션 패치(`20-group-mentions.patch`)도 쓰면 같은 폴더에 둔다. 스크립트가 폴더의 `*.patch`를 이름순으로 전부 적용한다.
2. 동작: 설치본 해시가 `installed.sha`와 같으면 즉시 종료(1초 미만). 다르면(= 공식 업데이트가 덮어씀) 새 버전 태그에 패치 적용 → 빌드 → 교체 → 맥 알림 표시. 충돌 시 맥 알림 "패치 충돌" → 에이전트에게 3절 기준으로 재구현을 요청한다.
3. 자동 실행(LaunchAgent). **사람이 직접 설치**한다. Claude Code auto 모드에서는 LaunchAgent 쓰기가 "무단 지속성"으로 차단된다(겪음).

```bash
cat > ~/Library/LaunchAgents/local.buzz-patch.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.buzz-patch</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$HOME/Projects/buzz-patch/rebuild.sh</string></array>
  <key>WatchPaths</key><array><string>/Applications/Buzz.app/Contents/Info.plist</string></array>
  <key>StartInterval</key><integer>3600</integer>
  <key>ThrottleInterval</key><integer>120</integer>
  <key>RunAtLoad</key><false/>
  <key>Nice</key><integer>10</integer>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>
</dict></plist>
EOF
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.buzz-patch.plist
```

- **반드시 패치본을 설치한 뒤에** 켤 것. 먼저 켜면 공식 앱을 보자마자 재빌드를 시작한다.
- 끄기: `launchctl bootout gui/$(id -u)/local.buzz-patch`
- 로그: `~/Projects/buzz-patch/rebuild.log`
- 수동 실행: `~/Projects/buzz-patch/rebuild.sh --force`

## 8. 검증 체크리스트

- [ ] 키체인 "항상 허용" 뒤 Buzz를 껐다 켜도 암호를 다시 묻지 않는다.
- [ ] 설정 → Notifications에 "Channel notifications" 그룹이 있고 기본이 All messages다.
- [ ] 채널 우클릭 → Notifications 서브메뉴가 4개 항목으로 보인다.
- [ ] 다른 앱 사용 중, 다른 사람의 **일반 채널 메시지**에 배너가 뜬다.
- [ ] Buzz가 맨 앞이지만 **다른 채널**을 보고 있을 때도 배너가 뜬다.
- [ ] @멘션 배너가 **한 번만** 뜬다(중복 없음).
- [ ] **다른 커뮤니티를 선택한 상태**에서 원래 커뮤니티의 DM·멘션 배너가 30초 안에 뜬다. 제목 끝에 ` · 커뮤니티이름`이 붙는다.
- [ ] 음소거(Nothing) 채널은 조용하다(@멘션만 예외).
- 배너가 안 보이면 먼저 확인: 시스템 설정 → 알림 → Buzz가 "배너"(또는 "알림")로 허용돼 있는지, 집중 모드가 꺼져 있는지. 몇 초 뒤 사라지는 게 배너, 닫을 때까지 남는 게 "알림" 스타일이다.

## 9. 함정 기록 (겪은 것)

- `rustup`이 툴체인 다운로드 중 멈출 수 있다. 해당 프로세스를 죽이고 `rustup toolchain install 1.95.0`을 다시 실행하면 된다.
- zsh에서 `rm -rf ~/Applications/Buzz-official-*.app`은 대상이 없으면 "no matches found" 에러가 난다. 스크립트는 bash로 돌린다.
- 빌드 결과물 경로는 `desktop/src-tauri/target/...`이다(저장소 루트 `target/` 아님).
- `pnpm exec tsc`가 워크트리에서 pnpm 의존성 검사로 죽으면 `./node_modules/.bin/tsc`를 직접 실행한다.
- 파일 크기 제한 검사(`just file-size-check`)는 upstream CI 규칙이라 로컬 빌드에는 영향이 없다. upstream PR로 올릴 때는 `AppShell.tsx`에 줄을 추가하면 걸릴 수 있다.

## 10. 되돌리기

```bash
osascript -e 'quit app "Buzz"'; sleep 3
launchctl bootout gui/$(id -u)/local.buzz-patch 2>/dev/null
rm -rf /Applications/Buzz.app && ditto ~/Applications/Buzz-official-*.app /Applications/Buzz.app
open /Applications/Buzz.app
```
또는 GitHub Releases(`block/buzz`, 태그 `desktop-vX.Y.Z`)의 공식 `Buzz_X.Y.Z_aarch64.dmg`를 다시 설치한다. 채널 레벨 설정(localStorage)은 공식 앱에서는 무시될 뿐 해가 없다.

---

## 부록 A — 패치 (`10-notifications.patch`, 기준 `desktop-v0.5.25`)

아래 코드 블록의 내용을 그대로 `~/Projects/buzz-patch/10-notifications.patch`로 저장한다(펜스 줄 제외).

````diff
diff --git a/desktop/src-tauri/src/macos_notifications.rs b/desktop/src-tauri/src/macos_notifications.rs
index dde4ae1d..dfe5183b 100644
--- a/desktop/src-tauri/src/macos_notifications.rs
+++ b/desktop/src-tauri/src/macos_notifications.rs
@@ -79,9 +79,12 @@ define_class!(
             _notification: &objc2_user_notifications::UNNotification,
             completion_handler: &Block<dyn Fn(UNNotificationPresentationOptions)>,
         ) {
-            // Preserve the prior macOS behavior: keep foreground notifications
-            // in Notification Center without interrupting the user with a banner.
-            completion_handler.call((UNNotificationPresentationOptions::List,));
+            // The frontend already suppresses alerts for the channel being
+            // viewed, so anything that reaches here should be visible even
+            // while Buzz is frontmost (another channel open, window behind).
+            completion_handler
+                .call((UNNotificationPresentationOptions::Banner
+                    | UNNotificationPresentationOptions::List,));
         }
 
         #[unsafe(method(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:))]
diff --git a/desktop/src/app/AppShell.tsx b/desktop/src/app/AppShell.tsx
index b4c20390..82b51683 100644
--- a/desktop/src/app/AppShell.tsx
+++ b/desktop/src/app/AppShell.tsx
@@ -244,6 +244,10 @@ export function AppShell() {
   );
   const refetchHomeFeedFromLiveSignal = React.useEffectEvent(() => {
     void homeFeedQuery.refetch();
+    // Home-feed polling pauses while the app is unfocused, so this live
+    // signal is the only trigger for mention cards in the background. Retry
+    // once in case the feed query raced the relay's indexing of the event.
+    window.setTimeout(() => void homeFeedQuery.refetch(), 3_000);
   });
   useLiveHomeFeedActions(
     identityQuery.data?.pubkey,
@@ -352,6 +356,7 @@ export function AppShell() {
     handleDmNotification,
     handleThreadReplyDesktopNotification,
   } = useAppShellDesktopNotifications({
+    activeChannelId: activeChannel?.id ?? null,
     channels,
     enabled: !isHuddleRoom,
     goChannel,
diff --git a/desktop/src/app/useAppShellDesktopNotifications.ts b/desktop/src/app/useAppShellDesktopNotifications.ts
index b86b9536..bdf14d0f 100644
--- a/desktop/src/app/useAppShellDesktopNotifications.ts
+++ b/desktop/src/app/useAppShellDesktopNotifications.ts
@@ -5,7 +5,10 @@ import {
   createDesktopNotificationActivationQueue,
   shouldBounceForChannelNotification,
 } from "@/app/AppShell.helpers";
+import { MISSED_MESSAGE_ALERT_WINDOW_SECONDS } from "@/features/channels/useLiveChannelUpdates";
 import { useCommunityJoinAlerts } from "@/features/community-members/useCommunityJoinAlerts";
+import { useChannelAllMessageAlerts } from "@/features/notifications/lib/channelAllMessageAlerts";
+import { useInactiveCommunityNotifications } from "@/features/notifications/lib/inactiveCommunityAlerts";
 import { hasMentionForEvent } from "@/features/notifications/lib/shouldNotify";
 import type { NotificationSettings } from "@/features/notifications/hooks";
 import {
@@ -25,6 +28,7 @@ import { useNotificationSenderName } from "@/features/notifications/useNotificat
 import type { Channel, RelayEvent } from "@/shared/api/types";
 
 export function useAppShellDesktopNotifications({
+  activeChannelId,
   channels,
   enabled,
   goChannel,
@@ -34,6 +38,7 @@ export function useAppShellDesktopNotifications({
   pubkey,
   silentChannelIds,
 }: {
+  activeChannelId?: string | null;
   channels: Channel[];
   enabled: boolean;
   goChannel: (
@@ -57,12 +62,66 @@ export function useAppShellDesktopNotifications({
   });
 
   const resolveSenderName = useNotificationSenderName();
+  const allMessageChannelIds = useChannelAllMessageAlerts(pubkey);
+  useInactiveCommunityNotifications({
+    allMessageChannelIds,
+    enabled,
+    notificationSettings,
+    pubkey,
+  });
+
+  // Channels opted into "All messages" get a DM-style card for every new
+  // top-level post. Mentions stay on the home-feed path and DMs on their own
+  // path, so neither can double-notify from here.
+  const sendChannelMessageNotification = (
+    channelId: string,
+    event: RelayEvent,
+  ): boolean => {
+    if (!allMessageChannelIds.has(channelId)) return false;
+    if (!notificationSettings.slotAlertsEnabled.channel_message) return false;
+    const channel = channels.find((c) => c.id === channelId);
+    if (!channel || channel.channelType === "dm") return false;
+    if (
+      channelId === activeChannelId &&
+      !notificationSettings.notifyWhileViewing
+    )
+      return false;
+    const normalizedPubkey = pubkey?.trim().toLowerCase() ?? "";
+    if (hasMentionForEvent(event, normalizedPubkey)) return false;
+    const nowSeconds = Math.floor(Date.now() / 1_000);
+    if (event.created_at < nowSeconds - MISSED_MESSAGE_ALERT_WINDOW_SECONDS)
+      return false;
+
+    const channelName = channel.name?.trim() || null;
+    const { title, body } = formatMessageNotification({
+      source: "channel_message",
+      senderName: resolveSenderName(event.pubkey),
+      channelName,
+      content: event.content,
+    });
+    void sendDesktopNotification({
+      title,
+      body,
+      target: buildEventNotificationTarget(event, {
+        id: channelId,
+        name: channelName,
+      }),
+    }).then((didSend) => {
+      if (didSend && shouldPlayNotificationSound(channelId, silentChannelIds)) {
+        playNotificationSound(
+          resolveSlotSound(notificationSettings, "channel_message"),
+        );
+      }
+    });
+    return true;
+  };
 
   const handleChannelNotification = React.useEffectEvent(
-    (_channelId: string, event: RelayEvent) => {
+    (channelId: string, event: RelayEvent) => {
       if (!enabled) return;
       if (!shouldBounceForChannelNotification(event.tags)) return;
       if (!notificationSettings.desktopEnabled) return;
+      sendChannelMessageNotification(channelId, event);
       void requestDockBounce();
     },
   );
diff --git a/desktop/src/features/channels/useLiveChannelUpdates.ts b/desktop/src/features/channels/useLiveChannelUpdates.ts
index 3bb9fe39..d869fa0a 100644
--- a/desktop/src/features/channels/useLiveChannelUpdates.ts
+++ b/desktop/src/features/channels/useLiveChannelUpdates.ts
@@ -128,6 +128,16 @@ function retireLiveChannel(entry: LiveChannelEntry) {
 
 const SEEN_NOTIFICATION_EVENT_LIMIT = 5_000;
 
+// Reconnect replay (sleep/wake, network blips) backfills messages missed while
+// disconnected. Still alert for recent ones; older backlog stays silent so a
+// long sleep doesn't unleash a flood of cards.
+export const MISSED_MESSAGE_ALERT_WINDOW_SECONDS = 10 * 60;
+
+// A channel that appears after the initial sync (e.g. a brand-new DM whose
+// first message is what created it) is subscribed slightly in the past so the
+// message that caused it to appear is not lost.
+const NEW_CHANNEL_BACKFILL_SECONDS = 120;
+
 export function trackSeenEvent(
   seenEventIds: Set<string>,
   eventId: string,
@@ -214,7 +224,10 @@ export function useLiveChannelUpdates(
 
       // Suppress backlog events that predate our subscription — these are
       // historical replays, not live messages.
-      if (event.created_at < dmSubscriptionStartedAtRef.current) {
+      if (
+        event.created_at <
+        dmSubscriptionStartedAtRef.current - MISSED_MESSAGE_ALERT_WINDOW_SECONDS
+      ) {
         return;
       }
 
@@ -381,6 +394,7 @@ export function useLiveChannelUpdates(
   );
 
   const liveSubsRef = React.useRef(new Map<string, LiveChannelEntry>());
+  const hasInitialChannelSyncRef = React.useRef(false);
 
   React.useEffect(() => {
     let isCancelled = false;
@@ -404,6 +418,12 @@ export function useLiveChannelUpdates(
         dmSubscriptionStartedAtRef.current = Math.floor(Date.now() / 1000);
       }
 
+      const nowSeconds = Math.floor(Date.now() / 1_000);
+      const since = hasInitialChannelSyncRef.current
+        ? nowSeconds - NEW_CHANNEL_BACKFILL_SECONDS
+        : nowSeconds;
+      if (targetIds.size > 0) hasInitialChannelSyncRef.current = true;
+
       const pending = Array.from(targetIds).map((channelId) => {
         const existing = activeSubs.get(channelId);
         if (existing) return existing.pending;
@@ -419,7 +439,7 @@ export function useLiveChannelUpdates(
               kinds: [...CHANNEL_EVENT_KINDS],
               "#h": [channelId],
               limit: 1000,
-              since: Math.floor(Date.now() / 1_000),
+              since,
             },
             (event) => {
               if (activeSubs.get(channelId) === entry) {
diff --git a/desktop/src/features/communities/communityUnreadObserver.ts b/desktop/src/features/communities/communityUnreadObserver.ts
index e729831e..6cd78e28 100644
--- a/desktop/src/features/communities/communityUnreadObserver.ts
+++ b/desktop/src/features/communities/communityUnreadObserver.ts
@@ -73,7 +73,9 @@ function readFollowedRootIds(pubkey: string): Set<string> {
   }
 }
 
-function defaultReadThreadRelationships(pubkey: string): ThreadRelationships {
+export function defaultReadThreadRelationships(
+  pubkey: string,
+): ThreadRelationships {
   return {
     participatedRootIds: participationStore.read(pubkey),
     followedRootIds: readFollowedRootIds(pubkey),
diff --git a/desktop/src/features/notifications/lib/channelAllMessageAlerts.ts b/desktop/src/features/notifications/lib/channelAllMessageAlerts.ts
new file mode 100644
index 00000000..172c63d9
--- /dev/null
+++ b/desktop/src/features/notifications/lib/channelAllMessageAlerts.ts
@@ -0,0 +1,156 @@
+import * as React from "react";
+
+/**
+ * Discord-style channel notification levels. "Nothing" is the existing
+ * channel mute; this store tracks the remaining two levels: a global default
+ * ("All messages" unless changed) plus explicit per-channel overrides. A
+ * channel whose effective level is "all" raises a notification card for every
+ * new post; "mentions" keeps the default Buzz behavior (only @mentions,
+ * followed thread replies and DMs). Device-local, keyed by pubkey.
+ */
+export type ChannelAlertLevel = "all" | "mentions";
+
+export type ChannelAlertPrefs = {
+  defaultLevel: ChannelAlertLevel;
+  overrides: Readonly<Record<string, ChannelAlertLevel>>;
+};
+
+export type ChannelIdMatcher = { has(channelId: string): boolean };
+
+const STORAGE_KEY = "buzz-channel-alert-levels.v2";
+const DEFAULT_PREFS: ChannelAlertPrefs = { defaultLevel: "all", overrides: {} };
+
+const listeners = new Set<() => void>();
+const cache = new Map<string, ChannelAlertPrefs>();
+
+function storageKey(pubkey: string) {
+  return `${STORAGE_KEY}:${pubkey}`;
+}
+
+function normalize(pubkey: string | undefined) {
+  return pubkey?.trim().toLowerCase() ?? "";
+}
+
+function isLevel(value: unknown): value is ChannelAlertLevel {
+  return value === "all" || value === "mentions";
+}
+
+function read(pubkey: string): ChannelAlertPrefs {
+  const cached = cache.get(pubkey);
+  if (cached) return cached;
+
+  let prefs = DEFAULT_PREFS;
+  try {
+    const raw = window.localStorage.getItem(storageKey(pubkey));
+    const parsed = raw ? (JSON.parse(raw) as Record<string, unknown>) : null;
+    if (parsed && typeof parsed === "object") {
+      const overrides: Record<string, ChannelAlertLevel> = {};
+      const rawOverrides = parsed.overrides;
+      if (rawOverrides && typeof rawOverrides === "object") {
+        for (const [id, level] of Object.entries(rawOverrides)) {
+          if (isLevel(level)) overrides[id] = level;
+        }
+      }
+      prefs = {
+        defaultLevel: isLevel(parsed.defaultLevel)
+          ? parsed.defaultLevel
+          : DEFAULT_PREFS.defaultLevel,
+        overrides,
+      };
+    }
+  } catch {
+    prefs = DEFAULT_PREFS;
+  }
+  cache.set(pubkey, prefs);
+  return prefs;
+}
+
+function write(pubkey: string | undefined, next: ChannelAlertPrefs) {
+  const key = normalize(pubkey);
+  if (!key || typeof window === "undefined") return;
+  cache.set(key, next);
+  try {
+    window.localStorage.setItem(storageKey(key), JSON.stringify(next));
+  } catch {
+    // Best effort — the in-memory prefs still apply for this session.
+  }
+  for (const listener of listeners) listener();
+}
+
+function subscribe(listener: () => void) {
+  listeners.add(listener);
+  const handleStorage = (event: StorageEvent) => {
+    if (event.key?.startsWith(STORAGE_KEY)) {
+      cache.clear();
+      listener();
+    }
+  };
+  window.addEventListener("storage", handleStorage);
+  return () => {
+    listeners.delete(listener);
+    window.removeEventListener("storage", handleStorage);
+  };
+}
+
+export function effectiveChannelAlertLevel(
+  prefs: ChannelAlertPrefs,
+  channelId: string,
+): ChannelAlertLevel {
+  return prefs.overrides[channelId] ?? prefs.defaultLevel;
+}
+
+/** Set (or with `null`, clear back to the global default) one channel's level. */
+export function setChannelAlertOverride(
+  pubkey: string | undefined,
+  channelId: string,
+  level: ChannelAlertLevel | null,
+) {
+  const key = normalize(pubkey);
+  if (!key) return;
+  const current = read(key);
+  const overrides = { ...current.overrides };
+  if (level === null) delete overrides[channelId];
+  else overrides[channelId] = level;
+  write(key, { ...current, overrides });
+}
+
+export function setDefaultChannelAlertLevel(
+  pubkey: string | undefined,
+  defaultLevel: ChannelAlertLevel,
+) {
+  const key = normalize(pubkey);
+  if (!key) return;
+  write(key, { ...read(key), defaultLevel });
+}
+
+/** Drop every per-channel override so all channels follow the global default. */
+export function resetChannelAlertOverrides(pubkey: string | undefined) {
+  const key = normalize(pubkey);
+  if (!key) return;
+  write(key, { ...read(key), overrides: {} });
+}
+
+export function useChannelAlertPrefs(
+  pubkey: string | undefined,
+): ChannelAlertPrefs {
+  const key = normalize(pubkey);
+  return React.useSyncExternalStore(
+    subscribe,
+    () => (key && typeof window !== "undefined" ? read(key) : DEFAULT_PREFS),
+    () => DEFAULT_PREFS,
+  );
+}
+
+/** Channels whose effective level is "All messages". */
+export function useChannelAllMessageAlerts(
+  pubkey: string | undefined,
+): ChannelIdMatcher {
+  const prefs = useChannelAlertPrefs(pubkey);
+  return React.useMemo(
+    () => ({
+      has: (channelId: string) =>
+        effectiveChannelAlertLevel(prefs, channelId) === "all",
+    }),
+    [prefs],
+  );
+}
diff --git a/desktop/src/features/notifications/lib/inactiveCommunityAlerts.test.mjs b/desktop/src/features/notifications/lib/inactiveCommunityAlerts.test.mjs
new file mode 100644
index 00000000..03cf683e
--- /dev/null
+++ b/desktop/src/features/notifications/lib/inactiveCommunityAlerts.test.mjs
@@ -0,0 +1,81 @@
+import assert from "node:assert/strict";
+import test from "node:test";
+
+import { classifyInactiveCommunityEvent } from "./inactiveCommunityAlerts.ts";
+
+const ME = "a".repeat(64);
+const OTHER = "b".repeat(64);
+const CHANNEL = "chan-1";
+const EMPTY = new Set();
+const relationships = {
+  participatedRootIds: EMPTY,
+  followedRootIds: EMPTY,
+  authoredRootIds: EMPTY,
+  mutedRootIds: EMPTY,
+};
+
+function event(overrides = {}) {
+  return {
+    id: "e1",
+    pubkey: OTHER,
+    kind: 9,
+    content: "hi",
+    created_at: 1,
+    sig: "",
+    tags: [["h", CHANNEL]],
+    ...overrides,
+  };
+}
+
+function classify(ev, channelType = "stream", opts = {}) {
+  return classifyInactiveCommunityEvent(
+    ev,
+    { name: "general", channelType },
+    ME,
+    {
+      allMessageChannelIds: opts.all ?? EMPTY,
+      mutedChannelIds: opts.muted ?? EMPTY,
+      relationships,
+      channelId: CHANNEL,
+    },
+  );
+}
+
+test("own messages never alert", () => {
+  assert.equal(classify(event({ pubkey: ME }), "dm"), null);
+});
+
+test("DMs alert as dm", () => {
+  assert.equal(classify(event(), "dm")?.slot, "dm");
+});
+
+test("mentions alert even in muted channels", () => {
+  const ev = event({
+    tags: [
+      ["h", CHANNEL],
+      ["p", ME],
+    ],
+  });
+  assert.equal(
+    classify(ev, "stream", { muted: new Set([CHANNEL]) })?.slot,
+    "mention",
+  );
+});
+
+test("plain posts alert only for All-messages channels", () => {
+  assert.equal(classify(event()), null);
+  assert.equal(
+    classify(event(), "stream", { all: new Set([CHANNEL]) })?.slot,
+    "channel_message",
+  );
+});
+
+test("muted channel suppresses All-messages posts", () => {
+  assert.equal(
+    classify(event(), "stream", {
+      all: new Set([CHANNEL]),
+      muted: new Set([CHANNEL]),
+    }),
+    null,
+  );
+});
diff --git a/desktop/src/features/notifications/lib/inactiveCommunityAlerts.ts b/desktop/src/features/notifications/lib/inactiveCommunityAlerts.ts
new file mode 100644
index 00000000..5cc1508d
--- /dev/null
+++ b/desktop/src/features/notifications/lib/inactiveCommunityAlerts.ts
@@ -0,0 +1,337 @@
+import * as React from "react";
+
+import type { ChannelIdMatcher } from "@/features/notifications/lib/channelAllMessageAlerts";
+import { DM_NOTIFIABLE_EVENT_KINDS } from "@/features/channels/isDmNotifiableKind";
+import {
+  defaultReadThreadRelationships,
+  fetchObservedChannels,
+} from "@/features/communities/communityUnreadObserver";
+import type { Community } from "@/features/communities/types";
+import { useCommunities } from "@/features/communities/useCommunities";
+import type { NotificationSettings } from "@/features/notifications/hooks";
+import { sendDesktopNotification } from "@/features/notifications/lib/desktop";
+import {
+  formatMessageNotification,
+  type MessageNotificationSource,
+} from "@/features/notifications/lib/notificationFormat";
+import {
+  hasMentionForEvent,
+  shouldNotifyForEvent,
+} from "@/features/notifications/lib/shouldNotify";
+import {
+  playNotificationSound,
+  resolveSlotSound,
+  type SoundSlot,
+} from "@/features/notifications/lib/sound";
+import { isThreadReply } from "@/features/messages/lib/threading";
+import {
+  mutedChannelIdsFromStore,
+  parseMutePayload,
+} from "@/features/sidebar/lib/channelMutesStorage";
+import { withReadOnlyRelayClient } from "@/shared/api/readOnlyRelayClient";
+import { nip44DecryptFromSelf } from "@/shared/api/tauri";
+import type { RelayEvent } from "@/shared/api/types";
+import { KIND_CHANNEL_MUTES } from "@/shared/constants/kinds";
+
+/**
+ * Only the active community holds a live relay subscription; the rest are
+ * polled for the rail's unread dot and never alerted. This poller fills that
+ * gap: every POLL_MS (30s) it asks each inactive community's relay for new messages
+ * and raises the same cards the active community would (DMs, @mentions,
+ * followed thread replies, "All messages" channels).
+ */
+const POLL_MS = 30_000;
+const MAX_EVENT_AGE_SECONDS = 10 * 60;
+const FETCH_LIMIT = 100;
+const KIND_NIP29_GROUP_METADATA = 39000;
+const KIND_PROFILE = 0;
+
+type ChannelInfo = { name: string | null; channelType: string };
+
+export type InactiveAlert = {
+  slot: SoundSlot;
+  source: MessageNotificationSource;
+  event: RelayEvent;
+  channelName: string | null;
+};
+
+export function classifyInactiveCommunityEvent(
+  event: RelayEvent,
+  channel: ChannelInfo,
+  pubkey: string,
+  ctx: {
+    allMessageChannelIds: ChannelIdMatcher;
+    mutedChannelIds: ReadonlySet<string>;
+    relationships: ReturnType<typeof defaultReadThreadRelationships>;
+    channelId: string;
+  },
+): Pick<InactiveAlert, "slot" | "source"> | null {
+  if (event.pubkey.toLowerCase() === pubkey) return null;
+  if (channel.channelType === "dm") return { slot: "dm", source: "dm" };
+  if (hasMentionForEvent(event, pubkey)) {
+    return { slot: "mention", source: "mention" };
+  }
+  if (ctx.mutedChannelIds.has(ctx.channelId)) return null;
+  if (isThreadReply(event.tags)) {
+    const notify = shouldNotifyForEvent(event, pubkey, {
+      ...ctx.relationships,
+      mutedChannelIds: ctx.mutedChannelIds,
+      channelId: ctx.channelId,
+    });
+    return notify ? { slot: "thread_reply", source: "thread_reply" } : null;
+  }
+  if (ctx.allMessageChannelIds.has(ctx.channelId)) {
+    return { slot: "channel_message", source: "channel_message" };
+  }
+  return null;
+}
+
+function channelIdOf(event: RelayEvent): string | null {
+  return event.tags.find((tag) => tag[0] === "h")?.[1] ?? null;
+}
+
+function profileName(event: RelayEvent): string | null {
+  try {
+    const profile = JSON.parse(event.content) as Record<string, unknown>;
+    for (const key of ["display_name", "displayName", "name"]) {
+      const value = profile[key];
+      if (typeof value === "string" && value.trim()) return value.trim();
+    }
+  } catch {
+    // Malformed profile — fall back to neutral copy.
+  }
+  return null;
+}
+
+type CommunityChannelSnapshot = {
+  channels: Awaited<ReturnType<typeof fetchObservedChannels>>;
+  channelNames: Map<string, string>;
+  mutedChannelIds: Set<string>;
+  fetchedAt: number;
+};
+
+// Channel membership, names and mutes change rarely; refetching them on every
+// poll is what makes the poller expensive, so they are cached per community.
+const SNAPSHOT_TTL_MS = 5 * 60_000;
+const snapshots = new Map<string, CommunityChannelSnapshot>();
+
+type RelayFetcher = Parameters<typeof fetchObservedChannels>[0];
+
+async function loadSnapshot(
+  client: RelayFetcher,
+  community: Community,
+  pubkey: string,
+): Promise<CommunityChannelSnapshot> {
+  const cached = snapshots.get(community.id);
+  if (cached && Date.now() - cached.fetchedAt < SNAPSHOT_TTL_MS) return cached;
+
+  const channels = await fetchObservedChannels(client, pubkey);
+  const channelIds = channels.map((channel) => channel.id);
+  const [metadataEvents, mutesEvents] =
+    channelIds.length === 0
+      ? [[], []]
+      : await Promise.all([
+          client.fetchEvents({
+            kinds: [KIND_NIP29_GROUP_METADATA],
+            "#d": channelIds,
+            limit: channelIds.length + 50,
+          }),
+          client.fetchEvents({
+            kinds: [KIND_CHANNEL_MUTES],
+            authors: [pubkey],
+            "#d": ["channel-mutes"],
+            limit: 1,
+          }),
+        ]);
+
+  const channelNames = new Map<string, string>();
+  for (const event of metadataEvents) {
+    const id = event.tags.find((tag) => tag[0] === "d")?.[1];
+    const name = event.tags.find((tag) => tag[0] === "name")?.[1];
+    if (id && name) channelNames.set(id, name);
+  }
+
+  let mutedChannelIds = new Set<string>();
+  if (mutesEvents.length > 0) {
+    try {
+      const store = parseMutePayload(
+        JSON.parse(await nip44DecryptFromSelf(mutesEvents[0].content)),
+      );
+      if (store) mutedChannelIds = mutedChannelIdsFromStore(store);
+    } catch {
+      // Undecryptable mutes → treat as none muted.
+    }
+  }
+
+  const snapshot = {
+    channels,
+    channelNames,
+    mutedChannelIds,
+    fetchedAt: Date.now(),
+  };
+  snapshots.set(community.id, snapshot);
+  return snapshot;
+}
+
+async function collectCommunityAlerts(
+  community: Community,
+  pubkey: string,
+  since: number,
+  allMessageChannelIds: ChannelIdMatcher,
+): Promise<{ alerts: InactiveAlert[]; names: Map<string, string> }> {
+  return withReadOnlyRelayClient(community.relayUrl, async (client) => {
+    const { channels, channelNames, mutedChannelIds } = await loadSnapshot(
+      client,
+      community,
+      pubkey,
+    );
+    if (channels.length === 0) return { alerts: [], names: new Map() };
+
+    const events = await client.fetchEvents({
+      kinds: [...DM_NOTIFIABLE_EVENT_KINDS],
+      "#h": channels.map((channel) => channel.id),
+      since,
+      limit: FETCH_LIMIT,
+    });
+
+    const relationships = defaultReadThreadRelationships(pubkey);
+    const alerts: InactiveAlert[] = [];
+    for (const event of events) {
+      const channelId = channelIdOf(event);
+      const channel = channels.find((candidate) => candidate.id === channelId);
+      if (!channelId || !channel) continue;
+      const decision = classifyInactiveCommunityEvent(
+        event,
+        {
+          name: channelNames.get(channelId) ?? null,
+          channelType: channel.channelType,
+        },
+        pubkey,
+        { allMessageChannelIds, mutedChannelIds, relationships, channelId },
+      );
+      if (decision) {
+        alerts.push({
+          ...decision,
+          event,
+          channelName:
+            channel.channelType === "dm"
+              ? null
+              : (channelNames.get(channelId) ?? null),
+        });
+      }
+    }
+
+    const names = new Map<string, string>();
+    const authors = [...new Set(alerts.map((alert) => alert.event.pubkey))];
+    if (authors.length > 0) {
+      const profiles = await client.fetchEvents({
+        kinds: [KIND_PROFILE],
+        authors,
+        limit: authors.length * 2,
+      });
+      for (const profile of profiles) {
+        const name = profileName(profile);
+        if (name) names.set(profile.pubkey, name);
+      }
+    }
+    return { alerts, names };
+  });
+}
+
+export function useInactiveCommunityNotifications({
+  allMessageChannelIds,
+  enabled,
+  notificationSettings,
+  pubkey,
+}: {
+  allMessageChannelIds: ChannelIdMatcher;
+  enabled: boolean;
+  notificationSettings: NotificationSettings;
+  pubkey?: string;
+}) {
+  const { communities, activeCommunity } = useCommunities();
+  const normalizedPubkey = pubkey?.trim().toLowerCase() ?? "";
+  const activeCommunityId = activeCommunity?.id ?? null;
+  const inactive = React.useMemo(
+    () => communities.filter((community) => community.id !== activeCommunityId),
+    [communities, activeCommunityId],
+  );
+
+  const latest = React.useRef({ allMessageChannelIds, notificationSettings });
+  latest.current = { allMessageChannelIds, notificationSettings };
+  const sinceByCommunity = React.useRef(new Map<string, number>());
+  const seenEventIds = React.useRef(new Set<string>());
+  const previousActiveId = React.useRef<string | null>(null);
+
+  React.useEffect(() => {
+    if (!enabled || !normalizedPubkey || inactive.length === 0) return;
+    // The community we just left was covered by the live path until now;
+    // restart its window so nothing it already alerted is re-sent.
+    if (previousActiveId.current) {
+      sinceByCommunity.current.delete(previousActiveId.current);
+    }
+    previousActiveId.current = activeCommunityId;
+    let cancelled = false;
+    let timer: number | undefined;
+
+    const poll = async () => {
+      const nowSeconds = Math.floor(Date.now() / 1_000);
+      for (const community of inactive) {
+        if (cancelled) return;
+        // First observation of a community starts "now" — no backlog flood.
+        const since = sinceByCommunity.current.get(community.id) ?? nowSeconds;
+        try {
+          const { alerts, names } = await collectCommunityAlerts(
+            community,
+            normalizedPubkey,
+            since,
+            latest.current.allMessageChannelIds,
+          );
+          sinceByCommunity.current.set(community.id, nowSeconds - 5);
+          if (cancelled) return;
+          const settings = latest.current.notificationSettings;
+          for (const alert of alerts.sort(
+            (a, b) => a.event.created_at - b.event.created_at,
+          )) {
+            if (seenEventIds.current.has(alert.event.id)) continue;
+            seenEventIds.current.add(alert.event.id);
+            if (alert.event.created_at < nowSeconds - MAX_EVENT_AGE_SECONDS)
+              continue;
+            if (!settings.desktopEnabled) continue;
+            if (!settings.slotAlertsEnabled[alert.slot]) continue;
+            const { title, body } = formatMessageNotification({
+              source: alert.source,
+              senderName: names.get(alert.event.pubkey) ?? null,
+              channelName: alert.channelName,
+              content: alert.event.content,
+            });
+            const didSend = await sendDesktopNotification({
+              title: `${title} · ${community.name}`,
+              body,
+            });
+            if (didSend) {
+              playNotificationSound(resolveSlotSound(settings, alert.slot));
+            }
+          }
+          if (seenEventIds.current.size > 2_000) {
+            seenEventIds.current = new Set(
+              [...seenEventIds.current].slice(-1_000),
+            );
+          }
+        } catch (error) {
+          console.debug(
+            `[InactiveCommunityAlerts] poll failed community=${community.id}:`,
+            error,
+          );
+        }
+      }
+      if (!cancelled) timer = window.setTimeout(() => void poll(), POLL_MS);
+    };
+
+    void poll();
+    return () => {
+      cancelled = true;
+      if (timer !== undefined) window.clearTimeout(timer);
+    };
+  }, [activeCommunityId, enabled, inactive, normalizedPubkey]);
+}
diff --git a/desktop/src/features/notifications/lib/notificationFormat.ts b/desktop/src/features/notifications/lib/notificationFormat.ts
index 04c951c3..d5e79fe9 100644
--- a/desktop/src/features/notifications/lib/notificationFormat.ts
+++ b/desktop/src/features/notifications/lib/notificationFormat.ts
@@ -53,7 +53,8 @@ export type MessageNotificationSource =
   | "approval"
   | "needs_action"
   | "dm"
-  | "thread_reply";
+  | "thread_reply"
+  | "channel_message";
 
 const MESSAGE_BODY_FALLBACKS: Record<MessageNotificationSource, string> = {
   mention: "Something in Buzz needs your attention.",
@@ -61,6 +62,7 @@ const MESSAGE_BODY_FALLBACKS: Record<MessageNotificationSource, string> = {
   needs_action: "Something in Buzz needs your attention.",
   dm: "New message",
   thread_reply: "New reply",
+  channel_message: "New message",
 };
 
 /**
@@ -106,7 +108,9 @@ export function formatMessageNotification(opts: {
           ? senderName
             ? `${senderName} replied`
             : "Reply"
-          : (senderName ?? "Needs Action");
+          : source === "channel_message"
+            ? (senderName ?? "New message")
+            : (senderName ?? "Needs Action");
 
   return { title: formatNotificationTitle({ prefix, channelLabel }), body };
 }
diff --git a/desktop/src/features/notifications/lib/sound.ts b/desktop/src/features/notifications/lib/sound.ts
index 3371658a..fd06bc6d 100644
--- a/desktop/src/features/notifications/lib/sound.ts
+++ b/desktop/src/features/notifications/lib/sound.ts
@@ -26,6 +26,7 @@ export const SOUND_SLOTS = [
   "dm",
   "mention",
   "thread_reply",
+  "channel_message",
   "needs_action",
   "job_accepted",
   "job_progress",
@@ -38,6 +39,7 @@ export const SLOT_LABELS: Record<SoundSlot, string> = {
   dm: "Direct messages",
   mention: "@Mentions",
   thread_reply: "Thread replies",
+  channel_message: "Channel messages",
   needs_action: "Needs action",
   job_accepted: "Agent: job accepted",
   job_progress: "Agent: progress update",
@@ -60,6 +62,8 @@ export const SLOT_DESCRIPTIONS: Record<SoundSlot, string> = {
   dm: "When someone messages you directly.",
   mention: "When someone tags you in a channel.",
   thread_reply: "When someone replies in a thread you follow or posted in.",
+  channel_message:
+    'Every new message in channels set to "All messages" (right-click a channel → Notifications).',
   needs_action: "When an approval or reminder is waiting on you.",
   job_accepted: "When an agent picks up a job.",
   job_progress: "While an agent works through a job.",
@@ -71,6 +75,7 @@ export const RECOMMENDED_SOUND_BY_SLOT: Record<SoundSlot, SoundName> = {
   dm: "unison",
   mention: "ping",
   thread_reply: "doop",
+  channel_message: "unison",
   needs_action: "doodone",
   job_accepted: "boo",
   job_progress: "dng",
@@ -84,6 +89,7 @@ export const DEFAULT_SLOT_SOUNDS: SlotSounds = {
   dm: "flutter",
   mention: "flutter",
   thread_reply: "flutter",
+  channel_message: "flutter",
   needs_action: "flutter",
   job_accepted: "flutter",
   job_progress: "flutter",
@@ -96,6 +102,7 @@ export const DEFAULT_SLOT_ALERTS_ENABLED: Record<SoundSlot, boolean> = {
   dm: true,
   mention: true,
   thread_reply: true,
+  channel_message: true,
   needs_action: true,
   job_accepted: true,
   job_progress: false,
diff --git a/desktop/src/features/settings/ui/NotificationSettingsCard.tsx b/desktop/src/features/settings/ui/NotificationSettingsCard.tsx
index dcab32f0..faedb637 100644
--- a/desktop/src/features/settings/ui/NotificationSettingsCard.tsx
+++ b/desktop/src/features/settings/ui/NotificationSettingsCard.tsx
@@ -14,6 +14,13 @@ import {
   type SoundName,
   type SoundSlot,
 } from "@/features/notifications/lib/sound";
+import {
+  resetChannelAlertOverrides,
+  setDefaultChannelAlertLevel,
+  useChannelAlertPrefs,
+  type ChannelAlertLevel,
+} from "@/features/notifications/lib/channelAllMessageAlerts";
+import { useIdentityQuery } from "@/shared/api/hooks";
 import { cn } from "@/shared/lib/cn";
 import { Button } from "@/shared/ui/button";
 import { Switch } from "@/shared/ui/switch";
@@ -25,6 +32,78 @@ import {
 import { SettingsSectionHeader } from "./SettingsSectionHeader";
 import { SoundPicker } from "./SoundPicker";
 
+const CHANNEL_LEVEL_OPTIONS: ReadonlyArray<{
+  level: ChannelAlertLevel;
+  label: string;
+}> = [
+  { level: "all", label: "All messages" },
+  { level: "mentions", label: "Only @mentions" },
+];
+
+/**
+ * Global default for channel notification levels, plus a reset that drops
+ * every per-channel override (right-click a channel → Notifications).
+ */
+function ChannelMessageDefaultGroup() {
+  const pubkey = useIdentityQuery().data?.pubkey;
+  const prefs = useChannelAlertPrefs(pubkey);
+  const overrideCount = Object.keys(prefs.overrides).length;
+
+  return (
+    <SettingsOptionGroup title="Channel notifications">
+      <SettingsOptionRow>
+        <div className="min-w-0">
+          <span className="text-sm font-medium">Default for all channels</span>
+          <p
+            className="text-sm font-normal text-muted-foreground/70"
+            data-settings-subcopy
+          >
+            "All messages" shows a banner for every new post. Muted channels
+            stay silent.
+          </p>
+        </div>
+        <span className="flex shrink-0 gap-1">
+          {CHANNEL_LEVEL_OPTIONS.map(({ level, label }) => (
+            <Button
+              data-testid={`channel-default-level-${level}`}
+              key={level}
+              onClick={() => setDefaultChannelAlertLevel(pubkey, level)}
+              size="sm"
+              type="button"
+              variant={prefs.defaultLevel === level ? "default" : "secondary"}
+            >
+              {label}
+            </Button>
+          ))}
+        </span>
+      </SettingsOptionRow>
+      <SettingsOptionRow>
+        <div className="min-w-0">
+          <span className="text-sm font-medium">Per-channel overrides</span>
+          <p
+            className="text-sm font-normal text-muted-foreground/70"
+            data-settings-subcopy
+          >
+            {overrideCount === 0
+              ? "Every channel follows the default."
+              : `${overrideCount} channel${overrideCount === 1 ? "" : "s"} set individually.`}
+          </p>
+        </div>
+        <Button
+          data-testid="channel-level-reset"
+          disabled={overrideCount === 0}
+          onClick={() => resetChannelAlertOverrides(pubkey)}
+          size="sm"
+          type="button"
+          variant="secondary"
+        >
+          Apply default to all channels
+        </Button>
+      </SettingsOptionRow>
+    </SettingsOptionGroup>
+  );
+}
+
 export function NotificationSettingsCard({
   isUpdatingDesktopNotifications,
   notificationErrorMessage,
@@ -172,6 +251,8 @@ export function NotificationSettingsCard({
               </SettingsOptionRow>
             </SettingsOptionGroup>
 
+            <ChannelMessageDefaultGroup />
+
             {anyAlertsOn ? (
               <div className="space-y-4">
                 <SettingsOptionGroup title="Alert sounds">
diff --git a/desktop/src/features/sidebar/ui/ChannelContextMenu.tsx b/desktop/src/features/sidebar/ui/ChannelContextMenu.tsx
index 78f3929f..49f0b8f5 100644
--- a/desktop/src/features/sidebar/ui/ChannelContextMenu.tsx
+++ b/desktop/src/features/sidebar/ui/ChannelContextMenu.tsx
@@ -21,6 +21,11 @@ import {
   useChannelMembersQuery,
 } from "@/features/channels/hooks";
 import { useChannelModerationCapabilities } from "@/features/channels/ui/ChannelManagementModerationActions";
+import {
+  effectiveChannelAlertLevel,
+  setChannelAlertOverride,
+  useChannelAlertPrefs,
+} from "@/features/notifications/lib/channelAllMessageAlerts";
 import type { ChannelSection } from "@/features/sidebar/lib/useChannelSections";
 import {
   ContextMenuIconSlot,
@@ -103,6 +108,91 @@ function MoveToSectionSubmenu({
   );
 }
 
+type ChannelMenuLevel = "default" | "all" | "mentions" | "nothing";
+
+const LEVEL_LABELS: Record<"all" | "mentions", string> = {
+  all: "All messages",
+  mentions: "Only @mentions",
+};
+
+/**
+ * Discord-style per-channel notification level. "Default" follows the global
+ * setting (Settings → Notifications); "Nothing" is the existing channel mute.
+ */
+function ChannelNotificationsSubmenu({
+  channelId,
+  isMuted,
+  onMuteChannel,
+  onUnmuteChannel,
+}: {
+  channelId: string;
+  isMuted: boolean;
+  onMuteChannel: (channelId: string) => void;
+  onUnmuteChannel: (channelId: string) => void;
+}) {
+  const pubkey = useIdentityQuery().data?.pubkey;
+  const prefs = useChannelAlertPrefs(pubkey);
+  const override = prefs.overrides[channelId];
+  const current: ChannelMenuLevel = isMuted
+    ? "nothing"
+    : (override ?? "default");
+  const options: ReadonlyArray<{ level: ChannelMenuLevel; label: string }> = [
+    {
+      level: "default",
+      label: `Default (${LEVEL_LABELS[prefs.defaultLevel]})`,
+    },
+    { level: "all", label: LEVEL_LABELS.all },
+    { level: "mentions", label: LEVEL_LABELS.mentions },
+    { level: "nothing", label: "Nothing" },
+  ];
+
+  const apply = (level: ChannelMenuLevel) => {
+    if (level !== "nothing") {
+      setChannelAlertOverride(
+        pubkey,
+        channelId,
+        level === "default" ? null : level,
+      );
+    }
+    if (level === "nothing" && !isMuted) onMuteChannel(channelId);
+    if (level !== "nothing" && isMuted) onUnmuteChannel(channelId);
+  };
+
+  const effectiveAll =
+    !isMuted && effectiveChannelAlertLevel(prefs, channelId) === "all";
+
+  return (
+    <ContextMenuSub>
+      <ContextMenuSubTrigger>
+        <ContextMenuIconSlot>
+          {isMuted ? (
+            <BellOff className="h-4 w-4" />
+          ) : (
+            <Bell className="h-4 w-4" />
+          )}
+        </ContextMenuIconSlot>
+        <span>Notifications</span>
+        <span className="ml-auto pl-3 text-xs text-muted-foreground">
+          {isMuted ? "Off" : effectiveAll ? "All" : "@"}
+        </span>
+      </ContextMenuSubTrigger>
+      <ContextMenuSubContent>
+        {options.map(({ level, label }) => (
+          <ContextMenuItem
+            key={level}
+            onSelect={() => deferMenuAction(() => apply(level))}
+          >
+            <ContextMenuIconSlot>
+              {current === level ? <Check className="h-4 w-4" /> : null}
+            </ContextMenuIconSlot>
+            <span>{label}</span>
+          </ContextMenuItem>
+        ))}
+      </ContextMenuSubContent>
+    </ContextMenuSub>
+  );
+}
+
 /**
  * The channel/DM context menu's Copy actions, grouped under a single
  * "Copy" submenu (channel name / channel ID).
@@ -276,7 +366,14 @@ export function ChannelContextMenuItems({
         </ContextMenuItem>
       ) : null}
       {showMuteToggle || showStar ? <ContextMenuSeparator /> : null}
-      {showMuteToggle ? (
+      {showMuteToggle && channel.channelType !== "dm" ? (
+        <ChannelNotificationsSubmenu
+          channelId={channel.id}
+          isMuted={Boolean(isMuted)}
+          onMuteChannel={onMuteChannel ?? (() => {})}
+          onUnmuteChannel={onUnmuteChannel ?? (() => {})}
+        />
+      ) : showMuteToggle ? (
         isMuted ? (
           <ContextMenuItem
             onSelect={() =>
````

## 부록 B — `rebuild.sh`

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

## 5. 35-call-notifications.patch — 통화·손 흔들기 알림을 읽을 수 있게

**문제**: 누가 DM으로 통화(허들)를 걸면 알림 본문에 `{"ephemeral_channel_id":"8a7f…"}` 같은 내부 데이터가 그대로 떴다. 손 흔들기는 `<!-- buzz:wave:v1 --> … waved at you.`처럼 코드 표시가 섞였다. 알림 제목·기본 문구도 전부 영어였다.

**수정** (`notificationFormat.ts` 한 곳 + 호출부 4곳에 `kind` 전달):
- 통화 시작(kind 48100): 제목 `📞 ○○님의 전화`(채널이면 `📞 ○○님이 #채널에서 통화를 시작했어요`), 본문 `눌러서 통화에 참여하세요.`
- 손 흔들기: `👋 ○○님이 손을 흔들었어요.`
- 그 밖에 본문이 JSON이거나 HTML 주석이 섞이면 원문 대신 기본 문구(`새 메시지` 등)
- 알림 문구 언어: 맥 언어가 한국어면 한국어, Buzz UI를 영어로 바꿨으면(`buzz-ui-locale=en`) 영어. 한국어 UI 패치(40)와 독립.

**의도 (충돌 시 재구현 기준)**: 알림 본문에 프로토콜 데이터가 나가지 않게 한다. 형식 결정은 `formatMessageNotification` 한 곳에서만 한다.

**검증**: notifications·app 단위 테스트 116개 통과(통화/손 흔들기/JSON/한국어 제목 테스트 4개 추가), `tsc` 통과. `desktop-v0.5.26` + 10·20·30 위에 `git apply --3way` 확인.

