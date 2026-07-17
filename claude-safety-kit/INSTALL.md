# 🛟 안전장치 설치 — 딱 한 줄

> 클로드가 실수로 위험한 명령(파일 통째 삭제 등)을 실행하지 못하게 막아주는 안전장치예요.
> 아래 문장 **한 줄**을 여러분의 클로드에게 그대로 붙여넣기만 하면 끝납니다.

---

## 방법 1 · 클로드에게 말하기 (제일 쉬움) ⭐

**본인 컴퓨터에 맞는 문장 하나만** 골라서 클로드코드 창에 붙여넣으세요.

### 🪟 윈도우라면

> **이 주소의 안전장치를 설치해줘. 파워셸 설치 스크립트야:**
> **https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.ps1**

### 🍎 맥이라면

> **이 주소의 안전장치를 설치해줘. 받아서 bash로 실행하면 돼:**
> **https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.sh**

클로드가 알아서 받아서 깔아줍니다. **설치가 끝나면 클로드를 완전히 껐다 켜세요.**

---

## 방법 2 · 명령어 직접 붙여넣기

터미널(윈도우=PowerShell)에 붙여넣어도 됩니다.

**🪟 Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.ps1 | iex
```

**🍎 macOS / Linux**
```bash
curl -fsSL https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.sh | bash
```

---

## 잘 깔렸는지 확인 (안심 테스트)

클로드를 껐다 켠 뒤, 클로드에게 이렇게 말해보세요. 두 가지 모두 **아무것도 지우거나 바꾸지 않는** 테스트입니다.

**① "안전장치 자가진단 실행해줘"**
→ `🎉 전부 통과` 가 나오면 규칙이 정상입니다.

**② "`git push --force` 실행해봐"**
→ 🛡️ `[안전장치 v…] 강제 푸시...를 막았어요` 가 뜨면 성공입니다.
(git 저장소가 아닌 폴더에서는, 설령 안 막혀도 이 명령은 아무 일도 하지 않아요.)

---

## 안심하세요

- 이 안전장치는 **여러분 컴퓨터에 뭘 새로 깔거나, git을 건드리거나, 기존 설정을 지우지 않습니다.**
  (기존 설정은 그대로 두고 자동 백업까지 만들어요. 설정 파일이 깨져 있으면 덮어쓰지 않고 멈춥니다.)
- 설치되는 건 `~/.claude/hooks/` 안의 파일 3개가 전부이고, **설명서(`SAFETY-KIT.md`)가 함께 설치**되어 나중에 봐도 이게 뭔지 알 수 있습니다.
- 뭔가 차단되면 메시지가 항상 `[안전장치 v...]`로 시작해요. 왜 막혔는지 모른 채 헤맬 일이 없습니다.
- **지우고 싶으면 한 줄**: 맥 `bash ~/.claude/hooks/uninstall.sh` / 윈도우 `powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\uninstall.ps1"`
- 이 스크립트가 정확히 무엇을 하는지 **누구나 열어볼 수 있게 공개**돼 있습니다:
  https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit
