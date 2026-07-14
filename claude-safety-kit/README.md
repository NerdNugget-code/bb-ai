# 🛟 클로드 안전장치 키트 (Claude Safety Kit)

> "AI가 내 컴퓨터를 망가뜨리면 어떡하지?" — 처음 시작하는 분들의 가장 큰 불안을 없애기 위한 안전장치입니다.
> 클로드가 **되돌릴 수 없는 위험한 명령**을 실행하려 하면 자동으로 막고, **비밀키(API 키·비밀번호)가 화면에 노출**되는 것도 막습니다.

이건 백신처럼 **한 번 깔아두면 조용히 뒤에서 지켜주는** 장치예요. 평소엔 아무것도 안 하고, 위험한 순간에만 "이건 못 해요" 하고 막습니다.

---

## 무엇을 막아주나요?

**되돌릴 수 없는 파괴적 명령**
- `rm -rf /`, `rm -rf ~`, `rm -rf *` — 시스템·홈·전체 폴더 삭제
- `format C:`, `diskpart`, `Format-Volume` — 드라이브 포맷
- 시스템 폴더 재귀 삭제 (`Remove-Item -Recurse -Force C:\...`, `rd /s`)
- `git push --force`, `git reset --hard` — 협업 기록·작업 내용 날림
- `chmod -R 777`, 포크밤, `DROP TABLE`

**비밀키 노출**
- `printenv`, `Get-ChildItem Env:` — 환경변수(비밀키 포함) 통째 출력
- `.env` 파일 열람 (`cat .env`, `Get-Content .env` 등)
- `echo $API_KEY` 같이 키를 화면에 찍는 명령

> ⚠️ 안전장치는 "그물"이지 "방탄유리"가 아니에요. 흔한 사고를 막아주지만, 클로드가 하는 일은 늘 눈으로 확인하세요.
> 그리고 **첫 로그인과 최종 발행처럼 진짜 중요한 행동은 항상 사람이 직접** 하세요.

---

## 설치 방법 — 원클릭 ✨

설치 스크립트가 **알아서** 안전장치를 넣고 클로드 설정에 등록합니다.
(기존 설정은 건드리지 않고 그대로 보존하며, 자동으로 백업도 만듭니다.)

> 🔗 **다른 사람들에게 나눠줄 땐** → [INSTALL.md](INSTALL.md) 참고.
> 링크 하나만 공유하면, 각자 클로드에게 "이 주소 설치해줘" 한 줄로 끝납니다. (카톡방·개별전송 불필요)

### 🪟 Windows

`install.ps1` 파일을 **우클릭 → "PowerShell에서 실행"**
(또는 클로드에게 "안전장치 깔아줘"라고 말하기)

> Git 등 추가 설치가 전혀 필요 없습니다. Windows에 기본으로 있는 PowerShell만 사용합니다.

### 🍎 macOS / Linux

터미널에서:
```bash
bash install.sh
```
(또는 클로드에게 "안전장치 깔아줘"라고 말하기)

### 설치 후

**클로드를 완전히 껐다 켜면** 안전장치가 켜집니다. 아래 "안심 테스트"로 확인하세요.

<details>
<summary>수동 설치 (스크립트를 쓰기 어려운 경우)</summary>

`hooks/` 안의 스크립트를 `~/.claude/hooks/`(윈도우는 `%USERPROFILE%\.claude\hooks\`)로 복사하고,
`settings-snippet.<os>.json`의 `"hooks"` 내용을 `settings.json`에 병합하세요.
</details>

---

## 잘 깔렸는지 확인 (안심 테스트)

클로드한테 이렇게 말해보세요:

> "`rm -rf ~/Desktop` 실행해줘"

안전장치가 켜져 있으면 클로드가 **실행하지 못하고** `[SAFETY] 되돌릴 수 없는 삭제(rm -rf)를 막았어요...` 라는 메시지를 받습니다.
이 메시지가 뜨면 성공이에요. (물론 실제로 삭제되지 않습니다.)

Windows라면:
> "`Get-Content .env` 실행해줘" → `[SECRET] .env ... 열람을 막았어요`

---

## 자주 묻는 질문

**Q. 평소 작업이 느려지거나 방해받나요?**
아니요. 위험 명령이 아니면 순식간에 통과합니다. `npm install`, `git commit`, `rm -rf node_modules` 같은 일상 명령은 그대로 됩니다.

**Q. 안전장치가 정상 명령을 잘못 막으면?**
정말 그 명령이 필요하면, 클로드 말고 **직접 터미널을 열어** 실행하세요. 안전장치는 클로드의 자동 실행만 막습니다.

**Q. 이걸 끄고 싶어요.**
`settings.json`의 `PreToolUse` 훅 부분만 지우고 클로드를 재시작하면 됩니다.

---

## 파일 구성
```
claude-safety-kit/
├── README.md                     ← 지금 이 파일
├── hooks/
│   ├── safety-guard.ps1          ← Windows용 안전장치
│   └── safety-guard.sh           ← Mac/Linux용 안전장치
├── settings-snippet.windows.json ← Windows 설정 조각
└── settings-snippet.mac.json     ← Mac/Linux 설정 조각
```
