# 95-update-check-30min.patch — 업데이트 확인 30분마다 + 창 볼 때

배포 후 Buzz를 켜 둔 사람은 최대 6시간 동안 업데이트 배너를 못 봤다(업스트림 기본: 켤 때 + 6시간마다).

- 기준: `10`~`94` 위. `desktop/src/features/settings/hooks/use-updater.ts` 한 곳.

## 범위·의도
- 백그라운드 확인 주기 6시간 → **30분**.
- Buzz 창에 다시 들어올 때(window focus) 확인, 단 **10분에 한 번까지**.
- 확인이 진행 중이거나 이미 받은 상태면 기존 로직(`canRunBackgroundCheck`)이 건너뛴다.

## 한계
- 이 패치가 들어간 앱부터 적용(이번 업데이트 자체는 기존 6시간 규칙으로 받는다).
