# 🛟 이 컴퓨터에는 "클로드 안전장치"가 설치되어 있습니다 (v1.1.0)

> 이 파일은 안전장치가 설치될 때 함께 들어온 **설명서**입니다.
> 클로드가 어떤 명령을 거부하면서 `[안전장치 v...]`라는 메시지를 보여줬다면, 바로 이 장치가 막은 것입니다.
> 궁금하면 클로드에게 이렇게 물어보세요: **"~/.claude/hooks/SAFETY-KIT.md 읽고 설명해줘"**

## 설치된 파일 (전부 `~/.claude/hooks/` 안에만 있습니다)

| 파일 | 역할 |
|---|---|
| `safety-guard.sh` (맥/리눅스) 또는 `safety-guard.ps1` (윈도우) | 위험 명령 차단기 본체 |
| `SAFETY-KIT.md` | 지금 이 설명서 |
| `uninstall.sh` 또는 `uninstall.ps1` | 완전 제거 스크립트 |

그리고 `~/.claude/settings.json`의 `hooks` 항목에 이 차단기가 등록되어 있습니다.
(설치 시 기존 설정은 `settings.json.bak`으로 백업됩니다.)

## 무엇을 막나요?

- **되돌릴 수 없는 삭제**: 홈 폴더·바탕화면·문서·시스템 폴더·드라이브 전체를 지우는 명령 (`rm -rf ~`, `Remove-Item -Recurse C:\Users\...` 등). `rm -rf node_modules` 같은 프로젝트 안 정리는 그대로 됩니다.
- **작업 기록 파괴**: `git push --force`, `git reset --hard`, `git clean -f`
- **디스크·DB 파괴**: `format C:`, `diskpart`, `DROP TABLE` 등
- **비밀키 노출**: `.env` 파일 열람, `printenv` 같은 환경변수 통째 출력, `echo $API_KEY`

> ⚠️ 안전장치는 "그물"이지 "방탄유리"가 아닙니다. 흔한 사고를 막아줄 뿐이니, 클로드가 하는 일은 늘 눈으로 확인하세요.

## 잘 작동하는지 확인 (아무것도 실행하지 않는 검사)

- 맥/리눅스: `bash ~/.claude/hooks/safety-guard.sh --self-test`
- 윈도우: `powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\safety-guard.ps1" -SelfTest`
- 또는 클로드에게: **"안전장치 자가진단 실행해줘"**

## 끄고 싶을 때 / 지우고 싶을 때

- **완전 제거(권장)**: 맥은 `bash ~/.claude/hooks/uninstall.sh`, 윈도우는 `powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\uninstall.ps1"` — 훅 등록과 파일이 모두 깨끗이 제거됩니다. 제거 후 클로드를 재시작하세요.
- 클로드에게 부탁해도 됩니다: **"안전장치 제거해줘 (uninstall 스크립트 실행)"**

## 출처

- 전체 코드 공개: https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit
- 이 장치는 수업(클로드 코드 기초)에서 배포된 것으로, 여러분 컴퓨터의 `~/.claude` 폴더 밖은 아무것도 건드리지 않습니다.
