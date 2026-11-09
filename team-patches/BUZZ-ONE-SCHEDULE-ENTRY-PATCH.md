# 109-one-schedule-entry.patch — '캘린더'와 '일정' 입구 하나로 합치기

사이드바의 **캘린더**(창)와 **일정**(본문 전체)이 같은 화면을 보여 줘서, 링크 탭까지 있는 **일정** 하나만 남긴다.

- 기준: `desktop-v0.5.28` + `10`~`108` 패치.

## 1. 동작
- 사이드바에서 **캘린더** 버튼과 그 창을 뺀다. 일정 알림·주간 공지·구글 보내기·"메시지에서 캘린더에 추가"는 같은 컴포넌트에서 계속 돈다.
- 팀 기능 → 주간 공지는 창 대신 `/schedule?panel=digest`로 일정 화면의 주간 공지 탭을 연다. `at` 값으로 같은 탭을 다시 눌러도 다시 열린다.
- 사용법 목록의 "일정 창"·"팀 캘린더" 두 줄을 "일정" 한 줄로, 처음 안내의 '캘린더'를 '일정'으로 바꾼다.

## 2. 의도
저장 모델과 화면 내용은 그대로이고 입구만 줄인다. `TeamCalendarDialog`의 창 모드 코드는 기존 테스트가 쓰고 있어 남긴다(앱에서는 열리지 않는다).

## 3. 파일
`features/team-calendar/ui/TeamCalendarSidebarEntry.tsx`, `lib/calendarNavigation.ts`, `features/team-hub/`, `features/team-schedule/ui/TeamScheduleScreen.tsx`·`TeamScheduleView.tsx`, `features/team-welcome/ui/WelcomeGuide.tsx`, `app/routes/schedule.tsx`, `app/navigation/useAppNavigation.ts`, `tests/e2e/team12.spec.ts`.
