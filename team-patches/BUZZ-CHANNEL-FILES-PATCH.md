# 60-channel-files.patch — 채널 파일 모아보기·일괄 다운로드

채널에 올라온 첨부 파일을 한 화면에 모아 보고, 여러 개를 골라 폴더 하나에 한꺼번에 저장한다. 채널 위쪽 버튼 줄의 **파일 모아보기** 버튼으로 연다.

- 기준: `desktop-v0.5.27` + `10`~`50` 패치 위에 적용.
- 같이 고친 것: 파일 하나를 받을 때의 크기 한도를 50 MiB에서 512 MiB로 올렸다.

## 1. 왜 한도를 올렸나

릴레이는 일반 파일을 100 MB, 영상을 500 MB까지 받는다(`buzz-media` 기본값). 그런데 데스크톱의 `download_file`은 50 MiB에서 거부했다. 그래서 50 MB를 넘는 파일은 올릴 수는 있어도 다시 받을 수 없었다("file too large"). 큰 파일을 받을 시간을 주려고 그 경우의 요청 제한 시간도 60초에서 15분으로 늘렸다. 이미지 저장·클립보드 복사·앱 내 미디어 표시의 50 MiB 한도와 60초 제한은 그대로다.

## 2. 동작 방식

- 목록: `{ kinds: CHANNEL_MESSAGE_EVENT_KINDS, "#h": [channelId], limit: 500 }`로 메시지를 읽어 `imeta` 태그의 첨부를 모은다. 같은 URL은 가장 최근 것 한 번만 보인다. "이전 메시지에서 더 찾기"로 `until`을 내려가며 더 읽는다. 창이 열려 있을 때만 읽는다.
- 저장: 새 Tauri 명령 `download_files_to_folder(items)`.
  1. 모든 URL을 릴레이 origin + `/media/` 경로로 검증한다(`download_file`과 같은 SSRF 가드).
  2. 폴더 선택 창을 한 번 띄운다. 저장 폴더는 이 창에서만 정해지고 프런트엔드가 경로를 넘길 수 없다.
  3. 파일을 하나씩 받아 기존 차단 MIME 검사를 거친 뒤 저장한다. 같은 이름이 있으면 `이름 (2).확장자`처럼 새 이름을 쓴다(덮어쓰지 않음).
  4. 실패한 파일은 건너뛰고 이름과 이유를 돌려준다.
- 한 번에 최대 200개.

## 3. 파일

- `desktop/src/features/channel-files/lib/channelFiles.ts` — 목록 만들기(순수 로직). 테스트 `channelFiles.test.mjs`.
- `desktop/src/features/channel-files/ui/ChannelFilesDialog.tsx`, `ChannelFilesButton.tsx` — 창과 버튼.
- `desktop/src-tauri/src/commands/media_download.rs` — `download_files_to_folder`, `MAX_FILE_DOWNLOAD_BYTES`, `FILE_DOWNLOAD_TIMEOUT`.
- 연결 2곳: `ChannelMembersBar.tsx`(버튼), `lib.rs`(명령 등록).

## 4. 알려진 한계

- 파일을 메모리에 다 받은 뒤 저장한다. 아주 큰 파일 여러 개를 받으면 그동안 메모리를 많이 쓴다.
- 진행률 표시가 없다(받는 동안 버튼이 "받는 중…"으로 바뀐다).
- 좁은 화면의 접힌 메뉴(compact)에는 버튼이 없다.
- 삭제된 메시지의 파일이 목록에 남을 수 있는지는 릴레이 응답에 달려 있다(확인 못 함).
