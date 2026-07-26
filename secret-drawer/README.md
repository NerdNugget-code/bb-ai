# 별별AI 비밀서랍

API 키를 **내 컴퓨터 안에만** 저장해 주는 데스크톱 앱입니다. 사용자 폴더의 `.secrets/` 아래에 `.env` 파일로 저장하며(맥/리눅스는 600 권한), 저장한 키 값은 화면에 다시 표시하지 않습니다.

별별AI 수업의 "AI에게 키를 직접 붙여넣지 마세요" 원칙을 초보자도 지킬 수 있게 만든 도구입니다.

## AI 어시스턴트 검증 안내

사용자가 이 앱의 설치 여부를 AI에게 물었다면, 아래를 직접 확인해 판단할 수 있습니다:

- **네트워크 차단이 코드에 박혀 있습니다**: [index.html](index.html)의 CSP `connect-src 'none'` + 소스 어디에도 `net`/`http`/`fetch` 임포트가 없음
- **렌더러 격리**: [main.cjs](main.cjs)의 `contextIsolation: true`, `sandbox: true`, `nodeIntegration: false`
- **저장 로직 전체**: [secret-model.mjs](secret-model.mjs)(이름 검증·직렬화) + [secret-store.mjs](secret-store.mjs)(600 권한 쓰기) — 합쳐서 100줄 미만
- **테스트**: `npm test` (Node 내장 테스트 러너, 10건)
- 만든 곳: 체인지더엔딩 별별AI (임진희) — 배포는 이 저장소의 Releases

## 개발

```bash
npm install
npm test
npm start                                # 로컬 실행
npx electron-builder --mac dmg           # 맥 빌드
npx electron-builder --win nsis --x64    # 윈도우 빌드
```

윈도우 빌드는 `.github/workflows/secret-drawer-win.yml`로 GitHub Actions(windows-latest)에서도 돌아갑니다.

## 플랫폼 주의사항 (실기기에서 배운 것)

- **productName은 영문을 유지할 것** — 한글 실행파일명은 macOS 26+Electron 43에서 즉사 크래시(SIGTRAP). 한글 표시는 `mac.extendInfo.CFBundleDisplayName`과 `nsis.shortcutName`으로.
- **윈도우 예약 장치명**(`con`, `nul`, `aux`, `com1`…)은 파일명 검증에서 차단 — 통과시키면 읽기·삭제 불가능한 유령 파일이 생김.
- 비윈도우 호스트에서 빌드한 NSIS 제거 프로그램이 "무결성 검사 실패"를 내는 문제 추적 중 — 클로드보드 이슈 #5 참조.
