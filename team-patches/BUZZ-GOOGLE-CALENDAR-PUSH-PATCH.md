# 91-google-calendar-push.patch — 팀 캘린더 → 구글 캘린더 보내기

강은서 요청(10/8) ② 구글 공동 캘린더 연동. 다른 세션이 만든 `91-calendar-notices.patch`에서 **구글 보내기 부분만** 떼어 왔다. 자동 공지는 `55-weekly-digest.patch`가 맡는다(두 공지 구현을 같이 넣으면 글이 두 번 올라가서 하나만 쓴다).

- 기준: `desktop-v0.5.28` + `10`~`90` 패치 위에 적용(팀 캘린더 파일만 건드려서 60~90과 겹치지 않는다).

## 1. 범위

- 팀 캘린더 창에 **구글 캘린더** 탭. 팀 캘린더의 추가·수정·삭제를 구글 캘린더에 반영한다(Buzz → 구글 한 방향). 반복 일정은 구글 반복 일정으로 만든다.
- 앱은 구글에 로그인하지 않는다. 구글 캘린더 주인이 **Apps Script 웹 앱**(탭 안 "구글 쪽 스크립트 보기"에서 복사)을 배포하고, 주소와 비밀문구를 **한 사람의 Buzz**에 넣는다. 그 기기만 보낸다(설정은 그 기기 localStorage, 다른 멤버에게 안 보임).

## 2. 동작

- 지난달~3달 뒤 + 반복 문서를 읽어, 일정마다 마지막으로 보낸 `updatedAt`과 다르면 보낸다(한 번에 40개). 보낸 적 없는 일정의 삭제는 보내지 않는다. 옮긴 일정은 살아 있는 쪽을 쓴다.
- 스크립트는 Buzz id → 구글 이벤트 id를 스크립트 속성에 두고, upsert는 "있으면 지우고 새로 만들기"(같은 걸 두 번 보내도 결과가 같다).
- 요청은 `text/plain` POST(CORS 사전요청 없음). 응답을 못 읽으면 `no-cors`로 한 번 더 보내고 "보냄(확인 못 함)"으로 표시. 실패하면 30초부터 두 배씩(최대 30분) 늦춰 재시도.

## 3. 의도 (패치가 안 맞을 때 다시 만드는 기준)

캘린더 데이터 모델은 건드리지 않는다. 이미 있는 `useTeamCalendarMonth`·`REPEAT_DOC`만 읽는다. 연결은 두 곳: `TeamCalendarDialog.tsx`(탭 하나), `TeamCalendarSidebarEntry.tsx`(`useGoogleCalendarSync` 훅 한 줄).

## 4. 파일

- 추가: `lib/googleSync.ts`(보낼 작업 계산, Apps Script 코드) + `googleSync.test.mjs`(스크립트 문법 검사 포함), `lib/useGoogleCalendarSync.ts`(기기 설정·보내는 훅), `ui/GoogleSyncSection.tsx`(탭 화면).
- 수정: `ui/TeamCalendarDialog.tsx`, `ui/TeamCalendarSidebarEntry.tsx`.

## 5. 한계

- 보내기는 설정한 사람의 Buzz가 켜져 있어야 한다.
- 반복 일정의 "이 날만 빼기"는 구글에 반영하지 않는다. 구글에서 고친 내용은 Buzz로 안 온다(양방향은 별도 패치 예정).
- 실제 구글 계정으로는 아직 확인하지 않았다(문법·로직 테스트만).
