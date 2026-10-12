# 66-team-zip-audio.patch — zip으로 올라간 음원을 앱에서 바로 재생·원본 저장

요청: 파라파라 강은서(10/7) — m4a 음원 업로드가 안 됨, 음원팀은 계속 이 형식을 씀.

## 1. 범위
- 65번은 릴레이가 거부하는 음원을 `노래.m4a.zip`(파일 하나짜리 zip)으로 포장해 올린다. 받는 사람은 지금까지 내려받아 직접 압축을 풀어야 했다.
- 이 패치는 메시지 안의 `*.m4a.zip / .mp3.zip / .wav.zip / .aac.zip / .flac.zip / .ogg.zip / .opus.zip` 첨부를 알아보고, 일반 파일 카드 대신 **음원 카드**를 보여 준다:
  - [재생] → 앱 안에서 압축을 풀어 바로 재생(누를 때만 내려받음)
  - [원본 저장] → 압축을 푼 원래 파일(`노래.m4a`)로 저장
- 그 밖의 zip, 파일이 여러 개인 zip, 음원이 아닌 zip은 예전처럼 파일 카드.

## 2. 파일
- `src-tauri/src/commands/team_zip_audio.rs` — `unzip_team_audio(url)`(풀린 음원 바이트를 그대로 반환), `save_team_audio(url)`(저장 창). 내려받기는 기존 `fetch_blob_bytes_with_cap`·`validate_download_url`(릴레이 주소만 허용) 재사용, zip은 기존 `zip` 크레이트. 테스트 2개.
- `src/features/messages/ui/TeamZipAudioAttachment.tsx` — 음원 카드.
- 연결: `commands/mod.rs`, `lib.rs`(명령 등록), `shared/ui/markdown.tsx`(파일 카드 직전에 분기 한 곳).

## 3. 의도 (충돌 시 재구현 기준)
- **릴레이 쪽은 못 바꾼다**: 호스팅 릴레이(Block)의 `crates/buzz-media/src/validation.rs`가 파일 내용을 보고 `audio/*`와 ISO-BMFF(`ftyp`, m4a)를 코드로 거부한다. 커뮤니티 설정이 없어서 업스트림 변경 없이는 원본 업로드가 불가능하다.
- 그래서 보내는 쪽(65)은 그대로 두고 받는 쪽만 고친다. 압축 해제는 Rust에서 하고, 항목 1개·이름에 경로 없음·음원 확장자·200MB 이하일 때만 연다.

## 4. 알려진 한계
- 이 패치가 없는 앱(옛 팀 앱·공식 앱·모바일)은 여전히 zip 파일로 보인다.
- 파형 표시·재생 속도 같은 음성 메모 전용 기능은 없다(기본 오디오 플레이어).
