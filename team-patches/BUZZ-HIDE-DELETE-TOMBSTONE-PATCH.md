# 93-hide-delete-tombstone.patch — 지운 메시지 흔적 없애기

구윤 요청(10/13): 메시지를 지우면 "OOO removed a message" 줄이 남아 공지 채널이 지저분해진다. 깔끔하게 사라지게.

- 기준: `desktop-v0.5.28` + `10`~`92` 패치 위에 적용(업스트림 `timelineItems.ts` 한 곳만 수정).

## 1. 범위

- 멤버가 **자기 메시지를 지운** 흔적(kind 40099 `message_deleted`, `public_reason` 없음)은 타임라인에 표시하지 않는다.
- **관리자가 신고로 지운** 메시지(릴레이가 `public_reason`을 붙임)는 "Removed by community moderators"로 그대로 보인다(투명성 유지).
- 메시지 자체는 원래대로 사라진다. 이 패치는 남는 안내 줄만 숨긴다.

## 2. 의도 (패치가 안 맞을 때 다시 만드는 기준)

`buildTimelineItems` 입구에서 `isSelfDeleteTombstone`인 항목을 걸러 낸다. 렌더러(`SystemMessageRow`)가 아니라 목록 단계에서 빼야 날짜 구분선·입장 묶기·안 읽음 구분선 계산이 빈 줄 없이 맞는다.

## 3. 파일

- 수정: `desktop/src/features/messages/lib/timelineItems.ts` (`isSelfDeleteTombstone` 추가 + 입구 필터)
- 추가: `desktop/src/features/messages/lib/hideDeleteTombstone.test.mjs`

## 4. 한계

- 이 패치가 없는 앱(공식 앱·폰 앱)에서는 여전히 흔적이 보인다.
