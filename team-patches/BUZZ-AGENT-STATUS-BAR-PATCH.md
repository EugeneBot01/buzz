# 96-agent-status-bar.patch — 입력칸 위 "에이전트 지금 답할 수 있나" 한 줄

구윤 요청(10/13): 에이전트는 만든 사람 맥이 켜져 있어야 답하는데, 팀원은 프로필 소개·채널 설명을 안 본다. 질문하는 순간 보이는 곳에 상태가 있어야 한다.

- 기준: `10`~`95` 위. 업스트림 `MessageComposer.tsx`에 한 줄 + 새 컴포넌트.

## 범위
- 채널에 에이전트 멤버가 있으면 입력칸 바로 위에 한 줄: `● 버즈 도우미 지금 답할 수 있어요` / `● Fizz, Pollen 쉬는 중 (만든 사람 맥이 꺼져 있으면 답하지 않아요)`. 3개 넘으면 "외 N".
- 상태는 릴레이 presence(TTL 180초, buzz-acp가 60초마다 갱신)를 기존 `useAgentAvailabilityLookup`으로 읽는다. 맥이 꺼지면 3분 안에 "쉬는 중"으로 바뀐다. 알림 없음.
- 에이전트가 없는 채널·DM이면 아무것도 안 그린다. 상태를 모를 때(연결 끊김)도 안 그린다.

## 파일
- 추가: `desktop/src/features/messages/ui/ChannelAgentStatusBar.tsx`
- 수정: `desktop/src/features/messages/ui/MessageComposer.tsx` (import 1줄 + 렌더 1줄)

## 확인
- `tsc` 통과, e2e 목업(`?e2e=mock`, #agents)에서 표시 확인.
