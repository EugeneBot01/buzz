# 50-team-calendar.patch — 팀 캘린더

커뮤니티 멤버 모두가 함께 보고 고치는 월 달력. 사이드바 위쪽 메뉴의 **캘린더**를 누르면 창이 열린다.

- 기준: `desktop-v0.5.27` + `10`~`40` 패치 위에 적용.
- 범위: 일정 추가·수정·삭제(제목, 시작·종료 날짜, 시작·종료 시간 선택, 색, 메모 선택). 여러 날에 걸친 일정은 달력 위에 이어진 색 막대로 그린다. 참석자 지정, 반복 일정, 일정 알림, 모임 날짜 투표, 채팅 메시지에서 일정 만들기가 있다. 외부 캘린더 연동은 없다.
- 권한: 커뮤니티 멤버 누구나 모든 일정을 고칠 수 있다.

## 1. 동작 방식

팀 섹션(30번)과 같은 공유 모델이다. 릴레이에서는 남의 이벤트를 덮어쓸 수 없으므로, 멤버마다 자기 좌표 `(pubkey, kind 30078, d)`에 **그 달의 합쳐진 사본**을 평문 JSON으로 올리고, 읽는 쪽이 모든 멤버의 사본을 합친다.

- `d = "team-calendar:<정규화한 릴레이 주소>:<YYYY-MM>"`. 커뮤니티와 달을 `d`에 넣어, 같은 호스팅의 다른 커뮤니티와 섞이지 않고 한 달이 이벤트 크기 한도(약 60KB)를 넘겨도 다른 달에 영향이 없다.
- 내용: `{ v: 1, entries: { <id>: { title, date, time?, endDate?, endTime?, color?, note?, updatedAt, updatedBy, deleted? } } }`.
- 기간: `date`/`time`이 시작, `endDate`/`endTime`이 끝이다. `endDate`가 없으면 하루짜리다(예전 일정이 그대로 열린다). `endTime`은 `time`이 있을 때만 쓴다. 최대 28일.
- 저장 위치: 일정은 **시작하는 달**의 문서에 둔다. 화면은 보는 달의 앞뒤 한 달씩 모두 3개월을 읽어서(`monthsAround`), 달을 넘는 일정도 이어 그린다. 28일 상한은 이 3개월 안에 시작일이 항상 들어오게 하려는 값이다.
- 색: `color`는 `red orange green blue purple pink gray` 중 하나이고, 없으면 기본색이다.
- 병합: 일정 단위 last-writer-wins(`updatedAt`, 같으면 `updatedBy`). 삭제는 `deleted: true`인 일정으로 남겨 예전 사본이 되살리지 못하게 한다.
- 읽기: `{ kinds: [30078], "#d": [d], limit: 200 }`로 전원의 이벤트를 받고, 같은 필터를 라이브 구독한다. 재연결 때 다시 읽는다.
- 쓰기: 로컬에 먼저 반영하고, 내 이벤트에 없는 변경이 있을 때만 내 사본을 다시 올린다. 발행은 한 번에 하나씩 하고, 스코프가 정리되면(커뮤니티 전환, 달 이동, 창 닫기) 전송하지 않는다.
- 다른 달로 날짜를 옮기면 새 달에 먼저 쓰고 원래 달에서 지운다(중간에 실패하면 중복이 남지 유실되지 않는다). 달 문서를 합쳐 보일 때는 id로 병합하지 않고(옛 달에 남은 삭제 표시가 옮긴 일정을 가린다) 삭제 표시를 건너뛰며, 두 달에 살아 있는 사본이 남았으면 최신 것을 쓴다(`combineMonths`).
- 병합 동점: 수정 시각과 작성자가 같으면 기간·색을 가진 사본이 이긴다. 이 기능이 없는 옛 앱이 일정을 기간·색 없이 다시 올려도 진짜 사본을 가리지 못하게 하기 위해서다.
- 릴레이 변경은 없다. 일정은 평문이라 커뮤니티 멤버 누구나 읽을 수 있다.

## 1-1. 참석자·반복·알림·투표·메시지에서 추가

- 참석자: 일정의 `attendees`(pubkey 목록). 없으면 팀 전체다. 달력의 "내 일정만"은 내가 참석자인 일정만 보여 준다(따로 저장하는 개인 캘린더는 없다).
- 반복: `repeat: { every: daily|weekly|biweekly|monthly, until? }`. 반복 일정은 모든 달에 보여야 하므로 달 문서가 아니라 `d = "team-calendar:<릴레이>:repeat"` 문서에 둔다. 화면이 보는 범위만큼 펼쳐 그린다(`expandRepeats`). "이 날만 삭제"는 `skip`에 그 날짜를 더한다. 수정은 반복 전체에 적용된다. 반복 간격보다 긴 일정은 반복할 수 없다.
- 알림: 참석자에게 기본으로 하루 전·30분 전·10분 전(시간 없는 일정은 하루 전 오전 9시 기준 1개). 사람마다 일정별로 바꿀 수 있고, 그 선택은 이 기기의 localStorage에만 둔다. 앱이 켜져 있는 동안 30초마다 확인해 토스트와 데스크톱 알림을 띄운다(`useTeamCalendarReminders`, 사이드바 항목에서 한 번 마운트). 서버가 보내는 알림이 아니라서 앱이 꺼져 있으면 울리지 않고, 다시 켰을 때 아직 시작 전인 일정의 가장 가까운 알림 하나만 띄운다. 지금 보고 있는 커뮤니티의 일정만 알린다.
- 모임 날짜 투표: `d = "team-calendar-polls:<릴레이>"` 문서 하나에 멤버마다 `{ polls, answers }`를 올린다. `polls`(제목, 후보 기간, 선택적으로 시간 범위)는 일정처럼 last-writer-wins로 합치고, `answers`는 **작성자 본인의 이벤트에서만** 읽는다(남의 답을 대신 쓸 수 없다). 날짜만 고르는 투표는 최대 31일, 시간대까지 고르는 투표는 최대 14일. 끝난 지 30일이 지난 투표는 올리는 사본에서 뺀다. 가장 많이 되는 날에서 "일정으로 만들기"를 누르면 그 날짜·시간·되는 사람이 채워진 일정 입력 화면이 열린다.
- 메시지에서 추가: 메시지 더보기 메뉴의 "캘린더에 추가"(`MessageActionBar.tsx`). 메시지 글에서 날짜·시간을 읽어(`parseSchedule`, 한국어 표현) 확인 창을 띄우고, 참석자 기본값은 그 채널의 사람 멤버다. 일정 id를 메시지 id에서 만들어(`msg-…`) 같은 메시지를 다시 추가하면 새로 생기지 않고 그 일정이 고쳐진다. 메뉴와 캘린더가 화면에서 멀리 떨어져 있어 window 이벤트로 요청을 넘긴다(`addFromMessage.ts`). 에이전트가 알아서 제안하는 기능은 없다.

## 2. 파일

- `desktop/src/features/team-calendar/lib/teamCalendar.ts` — 순수 로직(달 계산, 인코딩, 병합, 크기 제한, 날짜 계산, 주별 막대 배치 `weekSegments`, 입력 검사 `validateRange`). 테스트 `teamCalendar.test.mjs`.
- `desktop/src/features/team-calendar/lib/useTeamCalendar.ts` — 한 달치 읽기·구독·발행 훅(`useTeamCalendarMonth`)과, 앞·현재·뒤 3개월을 묶어 보여주는 훅(`useTeamCalendarRange`).
- `desktop/src/features/team-calendar/ui/TeamCalendarDialog.tsx` — 달력 창(주 단위 행 위에 막대를 겹쳐 그린다. 한 칸에 막대가 3줄을 넘으면 `+N`으로 접는다).
- `desktop/src/features/team-calendar/ui/TeamCalendarSidebarEntry.tsx` — 사이드바 메뉴 항목. 달력 창은 열려 있을 때만 마운트한다. 알림 확인과 "메시지에서 추가" 창도 여기서 띄운다.
- `lib/teamPolls.ts`, `lib/useTeamPolls.ts`, `ui/PollsPanel.tsx` — 모임 날짜 투표.
- `lib/teamReminders.ts`, `lib/useTeamCalendarReminders.ts` — 알림.
- `lib/parseSchedule.ts`, `lib/addFromMessage.ts`, `ui/AddFromMessageDialog.tsx` — 메시지에서 일정 만들기.
- `lib/useTeamMembers.ts`, `ui/MemberPicker.tsx`, `ui/EntryForm.tsx` — 멤버 이름, 참석자 고르기, 일정 입력 폼.
- 테스트: `lib/teamCalendar.test.mjs`, `lib/teamExtras.test.mjs`.
- 연결 3곳: `AppSidebarPinnedHeader.tsx`(`extraItems` 추가), `AppSidebar.tsx`(항목 전달), `MessageActionBar.tsx`(메뉴 항목 하나).

## 3. 의도 (충돌 시 재구현 기준)

- 업스트림 접점은 사이드바 메뉴에 항목 하나, 메시지 메뉴에 항목 하나를 끼우는 것뿐이다. 라우트·`routeTree.gen.ts`는 건드리지 않는다(창으로 띄운다).
- 모듈 수준 캐시를 두지 않는다(커뮤니티 전환 시 상태가 남지 않게).
- 화면 문구는 한국어 고정이고 `data-no-translate`로 표시 계층 번역(40번)에서 제외한다.

## 4. 알려진 한계

- 팀 버전 맥 앱에서만 보인다(공식 앱·모바일·윈도우에는 없음).
- 시계가 크게 틀린 기기의 수정은 병합 순서에서 밀리거나 앞설 수 있다.
- 한 달에 일정이 아주 많으면(대략 수백 개) 저장을 거부한다.
- 일정 하나는 최대 28일이다. 더 긴 일정은 나눠서 넣어야 한다.
- 이 기능이 없는 옛 팀 앱에서는 기간 일정이 시작 날짜 하루로만 보이고, 옛 앱이 그 일정을 고치면 종료일·색이 사라진다.
- 알림은 앱이 켜져 있고 그 커뮤니티를 보고 있을 때만 울린다. 알림 선택은 기기마다 따로다.
- 이 기능이 없는 옛 팀 앱은 반복 일정과 투표를 보지 못하고, 참석자가 지정된 일정을 고치면 참석자 목록이 사라진다.
- 오프라인 캐시가 없다. 연결이 없으면 일정이 보이지 않는다.
