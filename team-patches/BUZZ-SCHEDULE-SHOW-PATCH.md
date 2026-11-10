# Patch 110 — 일정 표시 위치 (스프린트 / 캘린더)

## 1. 왜
스프린트 보드에는 목표치만, 캘린더에는 과정(회의 등)까지 보이게 하자는 팀 요청.
103의 `sprintCells`가 반복 일정까지 펼쳐 넣어서, 정기 회의(키스탭 수 20:00 등)가
보드의 「부서 미지정」 행을 매주 덮었다.

## 2. 무엇
- `CalendarEntry.show?: "both" | "sprint" | "calendar"`.
- 필드가 없으면 `entryShow()`가 정한다: 반복 일정 → `calendar`, 나머지 → `both`.
- 스프린트 보드(`sprintCells`, `sprintRows`, 스프린트 내보내기)는 `showsOnSprint`만,
  달력·날짜 패널·달력 내보내기는 `showsOnCalendar`만 그린다. CSV 목록·주간 공지·알림은 그대로.
- 일정 창에 "어디에 보일까요" 선택 칸(부서 칸과 같은 조건, 보드에 부서가 있을 때).
- JSON 가져오기·내보내기도 `show`를 읽고 쓴다.
- 저장 형식은 그대로(kind 30078, `d=team-calendar:...`). team.13 이하 앱이 다시 저장하면
  `show`는 빠진다(103의 `dept`와 같음).

## 3. 다시 구현할 때
1. `teamCalendar.ts`: 타입·`CALENDAR_SHOW_VALUES`·`entryShow`/`showsOnSprint`/`showsOnCalendar`,
   `readEntry`에서 허용 값만 읽기, `richness`에 1점.
2. `teamSprint.ts`: `sprintRows`·`sprintCells`에서 `expandRepeats` 전에 `filter(showsOnSprint)`.
3. `TeamCalendarDialog.tsx`: 달력·날짜 패널용 entries를 `filter(showsOnCalendar)`.
4. `exportModel.ts`: 달력 페이지 내보내기 `filter(showsOnCalendar)`.
5. `useTeamCalendar.ts`(입력 타입·`inputOfEntry`·저장), `EntryForm.tsx`(초안 `show`, 선택 칸),
   `calendarImport.ts`(가져오기 검증·내보내기).
6. 테스트: `teamSprint.test.mjs`의 반복 일정 테스트는 `show: "both"`로, 새 기본값·왕복 테스트 추가.
