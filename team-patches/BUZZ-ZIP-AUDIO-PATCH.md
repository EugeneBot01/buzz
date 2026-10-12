# 92-zip-audio.patch — zip으로 포장된 음원 바로 듣기·원본으로 저장

65 패치가 m4a·mp3 같은 음원을 `이름.m4a.zip`으로 포장해 올리게 한 뒤, 받는 사람이 압축을 풀어야 했다(강은서 10/7 요청: 음원팀은 계속 m4a로 올림).

- 기준: `desktop-v0.5.28` + `10`~`85` 패치(특히 65) 위에 적용.

## 1. 범위

- 채팅에서 `<이름>.<음원 확장자>.zip` 첨부는 원래 이름(`이름.m4a`)으로 보이고, 옆의 **바로 듣기** 버튼으로 앱 안에서 재생된다.
- 첨부를 눌러 저장하거나(파일 카드), 채널 파일 모아보기(60)에서 저장하면 **zip이 아니라 원본 음원**이 저장된다.
- 새로 올리는 포장 zip은 압축하지 않고(Stored) 담는다. 음원은 이미 압축돼 있어 크기 차이가 거의 없고, 읽기가 단순해진다. 예전에 올린 deflate zip도 재생·저장된다.

## 2. 왜 릴레이를 안 고치나

릴레이(`buzz-media/src/validation.rs`)는 음원을 일부러 거부한다 — 음원 컨테이너의 위치 메타데이터 검사기가 아직 없어서. 서버 정책이라 팀 빌드에서 바꾸지 않고, 클라이언트에서 풀어 쓴다.

## 3. 의도

- 저장: `media_team_zip::unpack_team_zip(bytes, filename, max)` — 이름이 `<이름>.<확장자>.zip`이고, 항목이 하나이고, 그 항목이 릴레이가 거부하는 종류(음원·비표준 이미지)로 판별될 때만 푼다. 크기는 다운로드 한도(512 MiB)로 막는다(`take`로 선언 크기도 믿지 않음). 손으로 만든 zip은 그대로 저장.
- 재생: `features/messages/lib/teamZipAudio.ts` — imeta `m = application/zip` + 이름 패턴으로 알아보고, 중앙 디렉터리로 항목 하나를 꺼낸다(Stored는 자르기, Deflate는 `DecompressionStream("deflate-raw")`). 200 MiB 넘으면 재생 안 함(저장은 가능).

## 4. 파일

- `src-tauri/src/commands/media_team_zip.rs` — Stored로 포장, `unpack_team_zip` + 테스트.
- `src-tauri/src/commands/media_download.rs` — `download_file`, `download_files_to_folder`에서 풀어서 저장.
- `src/features/messages/lib/teamZipAudio.ts` + 테스트, `src/shared/ui/markdown/TeamZipAudioCard.tsx`, 연결 `src/shared/ui/markdown.tsx`.

## 5. 한계

- 이 패치가 없는 옛 앱은 여전히 zip으로 받는다.
- Rust 쪽은 리눅스 컨테이너에서 모듈 단위 테스트만 돌렸다(전체 Tauri 빌드는 맥/CI에서 확인).
