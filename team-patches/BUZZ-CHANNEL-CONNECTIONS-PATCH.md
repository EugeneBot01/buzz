# 70-channel-connections.patch — 채널 연결 (바로가기 · 에이전트 MCP)

채널 위쪽의 **연결**(플러그 아이콘) 버튼. 두 가지를 다룬다.

- 기준: `desktop-v0.5.27` + `10`~`60` 패치 위에 적용.

## 1. 바로가기 (사람이 누르면 바로 열림)

- 구글 미트 방, 피그마 파일, 그 밖의 링크를 채널에 붙여 둔다. 채널 위쪽에 아이콘 버튼으로 최대 3개가 보이고(나머지는 연결 창 안), 누르면 기본 브라우저에서 열린다.
- 바로가기는 그 채널에만, 또는 "모든 채널에 보이기"로 커뮤니티 전체에 둘 수 있다.
- 저장: 팀 캘린더와 같은 공유 모델. 멤버마다 `(pubkey, kind 30078, d = "team-links:<정규화한 릴레이 주소>")`에 합쳐진 사본을 평문 JSON으로 올리고 읽는 쪽이 합친다(바로가기 단위 last-writer-wins, 삭제는 `deleted: true`).
- 주소는 `https:`만 받는다. 저장할 때와 읽을 때 모두 검사한다(`normalizeLinkUrl`): 팀원 누구나 한 번 눌러 여는 링크이기 때문이다.
- 미트 방을 자동으로 만들어 주지는 않는다(구글 로그인 연동 없음). "새 구글 미트 방 만들러 가기"로 `meet.google.com/new`를 열어 주소를 받아 붙여 넣는다.

## 2. 에이전트 MCP

- 그 채널에 있는 **내가 이 컴퓨터에서 돌리는 에이전트**마다 MCP 서버를 고른다: 미리 넣어 둔 목록(피그마, 노션, 지라·컨플루언스, 리니어)에서 체크하거나, 이름 + `https://` 주소 또는 실행 명령으로 직접 추가.
- 저장하면 에이전트의 환경 변수 `BUZZ_TEAM_MCP_SERVERS`에 JSON 배열(`[{ name, command, args, env }]`)로 들어간다(에이전트의 다른 환경 변수는 그대로 둔다). 실행 중이면 "에이전트 다시 시작"을 눌러야 적용된다.
- 하니스 쪽: `crates/buzz-acp/src/lib.rs`의 `build_mcp_servers`가 이 환경 변수를 읽어, 원래 넘기던 서버(`BUZZ_ACP_MCP_COMMAND`) 뒤에 덧붙여 ACP `session/new`의 `mcpServers`로 넘긴다. Claude·Codex 등 런타임과 상관없이 같은 통로다. 잘못된 값은 무시한다(에이전트가 죽지 않게).
- 원격(https) MCP는 `npx -y mcp-remote <주소>`로 감싼 stdio 서버로 넘긴다(ACP 스키마가 stdio만 받는다). 처음 쓸 때 에이전트가 도는 컴퓨터에서 브라우저 로그인 창이 뜬다. 그 컴퓨터에 Node(`npx`)가 있어야 한다.

## 3. 파일

- `desktop/src/features/team-links/lib/teamLinks.ts`, `useTeamLinks.ts` — 바로가기 로직·훅. `lib/mcpCatalog.ts` — MCP 목록과 환경 변수 직렬화. 테스트 `lib/teamLinks.test.mjs`.
- `desktop/src/features/team-links/ui/ChannelConnections.tsx` — 채널 헤더 버튼과 연결 창. `ui/AgentMcpSection.tsx` — 에이전트 MCP 설정.
- 연결 2곳: `features/channels/ui/ChannelMembersBar.tsx`(버튼 하나), `crates/buzz-acp/src/lib.rs`(`build_mcp_servers`).

## 4. 알려진 한계

- 팀 버전 맥 앱에서만 보인다.
- 사람이 AI 없이 MCP 도구를 직접 실행하는 기능은 없다. MCP는 에이전트를 통해서만 쓴다.
- 에이전트 MCP는 에이전트 주인의 컴퓨터에서만 설정·실행된다. 다른 사람의 에이전트는 목록에 나오지 않는다.
- 미리 넣어 둔 MCP 주소는 각 서비스가 바꾸면 고쳐야 한다(직접 추가로 대신할 수 있다).
