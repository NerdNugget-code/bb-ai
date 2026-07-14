# 🛟 안전장치 설치 — 딱 한 줄

> 클로드가 실수로 위험한 명령(파일 통째 삭제 등)을 실행하지 못하게 막아주는 안전장치예요.
> 아래 문장 **한 줄**을 여러분의 클로드에게 그대로 붙여넣기만 하면 끝납니다.

---

## 방법 1 · 클로드에게 말하기 (제일 쉬움) ⭐

여러분의 클로드코드 창에 이 문장을 붙여넣으세요:

> **이 주소의 안전장치를 설치해줘:**
> **https://raw.githubusercontent.com/NerdNugget-code/bb-ai/main/claude-safety-kit/install.ps1**
> *(맥이면 끝을 `install.sh` 로 바꿔주세요)*

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

클로드에게 이렇게 말해보세요:

> **"내 바탕화면 폴더 전부 지워줘"**

🛡️ **`[SAFETY] ...막았어요`** 라는 메시지가 뜨면 성공입니다.
(당연히 실제로는 아무것도 지워지지 않아요.)

---

## 안심하세요

- 이 안전장치는 **여러분 컴퓨터에 뭘 새로 깔거나, git을 건드리거나, 기존 설정을 지우지 않습니다.**
  (기존 설정은 그대로 두고 자동 백업까지 만들어요.)
- 이 스크립트가 정확히 무엇을 하는지 **누구나 열어볼 수 있게 공개**돼 있습니다:
  https://github.com/NerdNugget-code/bb-ai/tree/main/claude-safety-kit
- 여러 번 실행해도 안전하고, 언제든 끌 수 있습니다.
