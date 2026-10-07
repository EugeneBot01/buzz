# 50-team-calendar.patch — 팀 캘린더

커뮤니티 멤버 모두가 함께 보고 고치는 월 달력. 사이드바 위쪽 메뉴의 **캘린더**를 누르면 창이 열린다.

- 기준: `desktop-v0.5.27` + `10`~`40` 패치 위에 적용.
- 범위: 일정 추가·수정·삭제(제목, 날짜, 시간 선택, 메모 선택). 알림·반복·외부 캘린더 연동은 없다.
- 권한: 커뮤니티 멤버 누구나 모든 일정을 고칠 수 있다.

## 1. 동작 방식

팀 섹션(30번)과 같은 공유 모델이다. 릴레이에서는 남의 이벤트를 덮어쓸 수 없으므로, 멤버마다 자기 좌표 `(pubkey, kind 30078, d)`에 **그 달의 합쳐진 사본**을 평문 JSON으로 올리고, 읽는 쪽이 모든 멤버의 사본을 합친다.

- `d = "team-calendar:<정규화한 릴레이 주소>:<YYYY-MM>"`. 커뮤니티와 달을 `d`에 넣어, 같은 호스팅의 다른 커뮤니티와 섞이지 않고 한 달이 이벤트 크기 한도(약 60KB)를 넘겨도 다른 달에 영향이 없다.
- 내용: `{ v: 1, entries: { <id>: { title, date, time?, note?, updatedAt, updatedBy, deleted? } } }`.
- 병합: 일정 단위 last-writer-wins(`updatedAt`, 같으면 `updatedBy`). 삭제는 `deleted: true`인 일정으로 남겨 예전 사본이 되살리지 못하게 한다.
- 읽기: `{ kinds: [30078], "#d": [d], limit: 200 }`로 전원의 이벤트를 받고, 같은 필터를 라이브 구독한다. 재연결 때 다시 읽는다.
- 쓰기: 로컬에 먼저 반영하고, 내 이벤트에 없는 변경이 있을 때만 내 사본을 다시 올린다. 발행은 한 번에 하나씩 하고, 스코프가 정리되면(커뮤니티 전환, 달 이동, 창 닫기) 전송하지 않는다.
- 다른 달로 날짜를 옮기면 새 달에 먼저 쓰고 원래 달에서 지운다(중간에 실패하면 중복이 남지 유실되지 않는다).
- 릴레이 변경은 없다. 일정은 평문이라 커뮤니티 멤버 누구나 읽을 수 있다.

## 2. 파일

- `desktop/src/features/team-calendar/lib/teamCalendar.ts` — 순수 로직(달 계산, 인코딩, 병합, 크기 제한). 테스트 `teamCalendar.test.mjs`.
- `desktop/src/features/team-calendar/lib/useTeamCalendar.ts` — 한 달치 읽기·구독·발행 훅.
- `desktop/src/features/team-calendar/ui/TeamCalendarDialog.tsx` — 달력 창.
- `desktop/src/features/team-calendar/ui/TeamCalendarSidebarEntry.tsx` — 사이드바 메뉴 항목. 창이 열려 있을 때만 구독한다.
- 연결 2곳: `AppSidebarPinnedHeader.tsx`(`extraItems` 추가), `AppSidebar.tsx`(항목 전달).

## 3. 의도 (충돌 시 재구현 기준)

- 업스트림 접점은 사이드바 메뉴에 항목 하나를 끼우는 것뿐이다. 라우트·`routeTree.gen.ts`는 건드리지 않는다(창으로 띄운다).
- 모듈 수준 캐시를 두지 않는다(커뮤니티 전환 시 상태가 남지 않게).
- 화면 문구는 한국어 고정이고 `data-no-translate`로 표시 계층 번역(40번)에서 제외한다.

## 4. 알려진 한계

- 팀 버전 맥 앱에서만 보인다(공식 앱·모바일·윈도우에는 없음).
- 시계가 크게 틀린 기기의 수정은 병합 순서에서 밀리거나 앞설 수 있다.
- 한 달에 일정이 아주 많으면(대략 수백 개) 저장을 거부한다.
- 오프라인 캐시가 없다. 연결이 없으면 일정이 보이지 않는다.
