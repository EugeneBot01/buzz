# 98-artcraft.patch — ArtCraft 앱으로 열기 · 에이전트가 ArtCraft 쓰기

ArtCraft(github.com/storytold)는 Word·Excel·PowerPoint·PDF 등을 새로 만든 오픈소스(Apache-2.0) 맥 앱 모음이다. 앱마다 명령줄 도구(`<앱>-cli`)와 MCP 서버(`<앱>-cli mcp`)가 들어 있어 에이전트가 조종할 수 있다. 맥용은 애플 공증(notarized)을 받은 universal 빌드다. 2026-10 기준 알파 단계(WordCraft 스스로 "실무의 약 60%")라 원본은 보관하고 쓴다.

- 기준: `desktop-v0.5.28` + `10`~`97` 위.
- 설치: 저장소 루트의 `install-artcraft.sh`(한 줄 설치). 기본 WordCraft·GridCraft, `ARTCRAFT_APPS="wordcraft gridcraft deckcraft pdfcraft"`로 더. 앱은 `~/Applications`(관리자 암호 불필요), 도구는 `~/Library/Application Support/ArtCraft/bin`, 작업 폴더 `~/BuzzArtCraft`. 내려받은 파일은 릴리스의 `SHA256SUMS.txt`로, 앱은 `spctl`(애플 공증)로 확인한 뒤에만 설치한다.

## 1. 파일 카드 "열기"
- 첨부 파일 카드 옆 "열기" 버튼. 파일을 임시 폴더(`$TMPDIR/buzz-opened/<uuid>/`)에 받고 `open -a`로 연다: docx·doc·odt·rtf → WordCraft, xlsx·xls·xlsm·ods·csv·tsv → GridCraft, pptx·ppt·odp → DeckCraft, pdf → PdfCraft. 그 앱이 `/Applications`나 `~/Applications`에 없으면 맥 기본 앱으로 연다.
- 네이티브 명령 `open_file_in_app`(`media_download.rs`): `download_file`과 같은 주소(지금 커뮤니티 서버의 `/media/`만)·크기(512MB)·형식 검사, `92`의 zip 풀기 적용. **문서·그림 확장자 목록(`TEAM_OPENABLE_EXTENSIONS`)만** 연다. 스크립트·앱·설치 파일은 시스템이 실행해 버리므로 거부한다(화면 쪽 목록 `shared/lib/openInApp.ts`와 같음).

## 2. 에이전트 도구
- "바로가기 버튼 → 고급: 에이전트가 쓰는 도구"에 "워드 문서 (WordCraft)", "엑셀 (GridCraft)" 항목(`70`의 `MCP_PRESETS`).
- 실행: `/bin/sh -c 'mkdir -p "$HOME/BuzzArtCraft" && cd … && exec "$HOME/Library/Application Support/ArtCraft/bin/<앱>-cli" mcp …'`. 에이전트가 도는 맥의 `$HOME`을 쓰기 위해 셸을 거친다. WordCraft는 `--automation-read-root/--automation-write-root`로 `~/BuzzArtCraft` 안만 읽고 쓰게 가둔다. GridCraft의 MCP에는 그런 옵션이 없어 작업 폴더에서 시작만 한다.
- 확인한 것: 이 맥에서 두 명령 모두 빈 환경(`env -i HOME=… PATH=/usr/bin:/bin`)으로 MCP 초기화·도구 목록(WordCraft 16개, GridCraft 21개)까지 응답. 한글 문서 생성·PDF/PNG 내보내기 정상.

## 3. 알려진 한계
- 알파 단계 앱이라 복잡한 서식·차트가 있는 실제 파일은 깨질 수 있다.
- 에이전트 도구와 "열기"는 그 맥에 `install-artcraft.sh`로 설치돼 있어야 동작한다(없으면 "열기"는 기본 앱으로).
- 에이전트가 만든 파일은 `~/BuzzArtCraft`에 생긴다. Buzz에 올리는 것은 에이전트가 따로 해야 한다.
