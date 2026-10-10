# 90-render-when-covered.patch — 가려진 창도 계속 그리기 (맥별 선택)

## 문제
macOS 웹킷은 다른 창에 가려진 웹뷰의 그리기를 멈춘다. 그래서 Buzz가 뒤에 있을 때 창을 캡처하면(스크린샷, Claude의 자동 화면 확인 등) **옛 화면이나 빈 화면**이 찍힌다. 시험·검수를 할 때마다 Buzz를 앞으로 꺼내야 해서 하던 작업이 끊긴다.

## 수정
- 맥 설정값 하나로 켜는 선택 기능. 켠 맥에서만 모든 Buzz 웹뷰의 "가려지면 그리기 멈춤"(WKWebView `_setWindowOcclusionDetectionEnabled:`)을 끈다.
  ```
  defaults write xyz.block.buzz.app BuzzRenderWhenCovered -bool YES   # 켜기 (Buzz 재시작 후 적용)
  defaults delete xyz.block.buzz.app BuzzRenderWhenCovered            # 끄기
  ```
- 기본은 꺼짐 → 팀원 맥에는 아무 변화 없음. 켜면 가려진 동안에도 그려서 전력을 조금 더 쓴다.
- 비공개 API라 `respondsToSelector:`로 먼저 확인 → 나중 macOS에서 없어지면 그냥 아무 일도 안 함.

## 검증
- 별도 시험 앱(WKWebView 2개를 다른 앱 창 뒤에 깔고 50ms 시계 실행)으로 확인: 기본 웹뷰는 캡처가 빈 화면, 이 설정을 끈 웹뷰는 현재 시계 값(4776)이 그대로 찍힘.
- `cargo check` 통과, `desktop-v0.5.28` + 기존 패치 11개 위에 `git apply --3way` 적용 확인.

## 의도 (충돌 시 재구현 기준)
- `on_webview_ready`에서 모든 웹뷰에 적용(메인·허들 창 포함), 설정값이 켜졌을 때만.
