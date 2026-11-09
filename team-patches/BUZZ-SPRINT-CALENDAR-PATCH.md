# 103-sprint-calendar.patch — 스프린트 보드 · 팀원 일정 · 배포(내보내기)

캘린더 창을 **스프린트 보기**와 **달력 보기** 두 가지로 나누고, 팀원 일정(되는/안 되는 시간) 입력, 가져오기, 파일로 내보내기(배포)를 더한다. 파라태권도(paratkd) 프로덕션 마스터 플랜 보드와 "빈칸" 일정 페이지를 Buzz 안으로 옮기려는 요청.

- 기준: `desktop-v0.5.28` + `10`~`102` 패치 위에 적용(50·91 캘린더 파일 위에 얹는다).

## 1. 범위

- **스프린트 보기**: 행 = 부서, 열 = 주차(W01~), 위에 단계 띠(PRE/PRODUCTION/POST). 이번 주는 노란 열, 프로덕션 주는 주황 테두리, 위에 D-day 카운터와 공지 한 줄. 칸을 누르면 그 부서·그 주(월~일)로 일정 추가, 항목을 누르면 수정·삭제.
- **달력 보기**: 기존 월 달력. 막대 색은 일정 색, 없으면 부서 색. ◆ 마감 표시, "팀원 일정 표시"를 켜면 날짜 칸에 "종일불가 N", 오른쪽에 그날 팀원별 불가/조율/가능.
- **두 보기는 같은 데이터다.** 스프린트 항목은 모두 팀 캘린더 일정(`dept`가 있는 일정)이라, 한쪽에서 고치면 다른 쪽에 바로 보인다. 선택한 날짜도 공유한다(달력에서 고른 날의 주가 스프린트에서 테두리로 표시되고, 스프린트에서 주를 누르면 달력이 그 달로 간다).
- **팀원 일정**: "빈칸" 페이지의 입력 방식 그대로 — 어떤 일정인지, 참여 불가/가능/조율 중, 날짜 하루 또는 "매주 같은 요일에 반복"(기간·빠지는 날), 종일 또는 시작~종료. 사람(이름·역할)은 Buzz 멤버가 아니어도 되고, "이 사람이 나예요"로 내 Buzz 계정과 연결한다. 누구나 누구의 일정이든 고칠 수 있다(빈칸과 같음).
- **가져오기**: `buzz-team-calendar` 형식 JSON(보드 설정·일정·팀원 일정). 미리보기 후 "가져오기"를 눌러야 저장. 파일의 id를 그대로 써서 같은 파일을 두 번 가져와도 중복되지 않는다.
- **배포**: 스프린트/달력 중 고르고, 범위(주 또는 달), 형식 PNG · PDF(A4 가로) · Word(DOCX, 편집 가능한 표) · CSV(엑셀) · 백업 JSON. 네이티브 저장 창으로 저장.

## 2. 동작

- 일정 모델: `CalendarEntry`에 `dept?`(부서 코드 `^[A-Z0-9_-]{1,24}$`)와 `milestone?: true`를 더했다. 저장 위치·병합 규칙은 50번 그대로. 동점 병합(`richness`)에 두 필드를 넣어, 이 필드를 모르는 옛 앱 사본이 같은 수정에서 이기지 못하게 했다.
- 보드 설정(plan): `d = "team-sprint:<릴레이>"` 한 문서, 멤버마다 사본, **가장 최근 수정 하나가 통째로 이긴다**(`updatedAt`, 같으면 `updatedBy`). 내용 `{ v:1, plan:{ title, start, weeks(1~26), phases[{label,weeks,tone}], depts[{key,label,color?}], note?, keyDates[{label,date}], updatedAt, updatedBy } }`. 저장된 설정이 없으면 "이번 주 월요일부터 8주" 기본값을 보여 준다(저장하지 않음).
- 팀원 일정: `d = "team-availability:<릴레이>"` 한 문서, 사람 단위 last-writer-wins, 삭제는 `deleted: true`. 규칙 `{ id, kind: busy|available|tentative, startDate, endDate, weekday(0~6, 없으면 매일), start/end(분, 0~1440), title, exclude[] }`. 빈 `exclude`와 `weekday:null`은 저장에서 뺀다(용량). 60KB를 넘으면 오래된 삭제 기록부터 빼고, 그래도 넘으면 저장을 거부한다(파라태권도 18명·284개 ≈ 40KB).
- 한 번에 여는 달: 보드 기간의 달 + 그 앞달 + 달력에 보이는 앞·현재·뒷달을 합쳐 최대 12개(`useTeamCalendarMonths`, 슬롯 고정 12개 + 반복 문서). 26주 보드여도 12개 안에 든다. 달을 옮겨도 이미 열린 달은 다시 읽지 않는다(`assignMonthSlots`).
- 스프린트 칸 배치(`sprintCells`): 일정이 걸친 **모든 주**에 보인다(12/20~12/22는 W14·W15 둘 다). 반복 일정은 보드 범위만큼 펼친다. 부서가 없거나 보드에 없는 부서면 "부서 미지정" 행(필요할 때만)에 넣어, 달력에 있는 일정이 보드에서 빠지지 않는다.
- 칸 글자(`sprintItemLabel`): 반복은 "월 14:30 기획", 하루짜리는 "10/4 키스탭 확정", 그 주를 꽉 채우지 않는 기간은 "편집 1차 (12/14–12/17)", 주 전체면 제목만 — 마스터 플랜 표기 그대로.
- 가져오기 후: 새 보드 설정 때문에 막 열린 달들이 저장 직전 상태를 읽었을 수 있어, 가져오기가 끝나면 모든 달·설정·팀원 일정을 한 번 다시 읽는다(라이브 구독은 릴레이 클라이언트가 초당 하나씩 열어서 늦을 수 있다).
- 내보내기: 파일은 웹뷰에서 만든다(외부 라이브러리 없음). PNG·PDF는 캔버스에 직접 그리고(항상 밝은 종이 테마, 캔버스 1,600만 픽셀 이하로 축소), PDF는 페이지마다 JPEG 한 장, DOCX는 압축 없는 ZIP + 표, 스프린트는 종이 형식에서 8주씩 나눈다. 달력 내보내기에서 여러 날 일정은 주마다 한 번만(시작일 또는 그 주 일요일에 "↳") 쓴다. 저장은 Rust `save_team_calendar_export`(종류별 매직 바이트 확인, 40MB 상한, 확장자 보정) → 네이티브 저장 창. e2e/웹 빌드에서는 브라우저 다운로드로 대신한다.
- 보기 선택(스프린트/달력)은 이 기기 localStorage에만 기억한다.

## 3. 의도 (패치가 안 맞을 때 다시 만드는 기준)

- 스프린트는 **별도 데이터가 아니라 캘린더 일정의 다른 보기**다. 이 원칙을 지키면 "서로 바뀐 대로 적용"이 자동으로 된다.
- 업스트림 접점은 Rust 명령 하나(`commands/mod.rs`, `lib.rs`의 `generate_handler!`에 `save_team_calendar_export`)뿐. 나머지는 `features/team-calendar/` 안.
- 50번 파일 중 바뀐 것: `teamCalendar.ts`(필드 2개), `useTeamCalendar.ts`(빈 슬롯·여러 달 훅·일괄 저장·다시 읽기), `EntryForm.tsx`(부서·◆ 입력), `TeamCalendarDialog.tsx`(다시 짬; 달력 격자와 날짜 패널은 `CalendarGrid.tsx`·`DayPanel.tsx`로 뺐다).
- 화면 문구 한국어 고정, `data-no-translate` 유지.

## 4. 파일

- 추가(lib): `teamSprint.ts`(보드 설정·주 계산·칸 배치·라벨), `teamAvailability.ts`(팀원 일정 모델·병합·하루 요약), `useSharedTeamDoc.ts`(공유 문서 하나 읽기/쓰기 훅), `useTeamSprint.ts`(보드 설정·팀원 일정 훅), `monthSlots.ts`, `calendarImport.ts`(가져오기/백업 형식), `exportModel.ts`(보기 → 페이지), `exportFormats.ts`(ZIP·DOCX·PDF·CRC32), `exportCanvas.ts`(PNG/PDF 그리기), `saveExport.ts`.
- 추가(ui): `SprintBoard.tsx`, `SprintPlanForm.tsx`, `CalendarGrid.tsx`, `DayPanel.tsx`, `AvailabilityPanel.tsx`, `AvailabilityRuleForm.tsx`, `ImportPanel.tsx`, `ExportPanel.tsx`.
- 추가(Rust): `src-tauri/src/commands/team_calendar_export.rs`(+ 단위 테스트).
- 테스트: `teamSprint.test.mjs`, `teamAvailability.test.mjs`, `calendarExport.test.mjs`(35개). 기존 캘린더 테스트 42개 그대로 통과.

## 5. 알려진 한계

- 이 패치가 없는 옛 팀 앱이 스프린트 일정을 **수정해서 저장**하면 부서·◆ 표시가 사라진다(달력에는 남고, 스프린트에서는 "부서 미지정"으로 간다). 팀 전체가 같은 빌드로 업데이트해야 한다.
- 옛 앱에는 스프린트 보기·팀원 일정·배포가 없다. 보드 설정과 팀원 일정은 옛 앱이 건드리지 않는다.
- 팀원 일정은 평문이라 커뮤니티 멤버 누구나 읽을 수 있다(빈칸 페이지는 관리자 링크가 있었다). 개인 시간표를 올리기 전에 팀에 알린다.
- 일정 하나는 여전히 최대 28일(50번). 보드는 최대 26주.
- PDF는 이미지 PDF라 글자를 선택·검색할 수 없다(편집이 필요하면 DOCX).
- DOCX 글꼴은 "맑은 고딕"으로 지정한다. 없는 기기에서는 Word가 비슷한 글꼴로 바꿔 보여 준다.
- 팀원 일정의 "함께 가능한 시간 찾기"(빈칸의 추천 시간)는 아직 없다. 날짜별 불가/조율 목록과 "종일불가 N" 표시까지만 있다.
