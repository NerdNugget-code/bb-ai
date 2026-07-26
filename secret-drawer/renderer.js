const profileSelect = document.querySelector("#profile");
const fields = document.querySelector("#fields");
const form = document.querySelector("#secret-form");
const saveButton = document.querySelector("#save");
const status = document.querySelector("#status");
const openFolderButton = document.querySelector("#open-folder");

let profiles = {};
let replacePending = false;

function setStatus(message, type = "") {
  status.textContent = message;
  status.className = `status ${type}`;
}

function inputField({ name, label, hint = "", required = true }) {
  return `
    <label class="field" for="${name}">
      <span>${label}</span>
      <input id="${name}" name="${name}" type="password" autocomplete="off" ${required ? "required" : ""} />
      ${hint ? `<small>${hint}</small>` : ""}
    </label>`;
}

function renderFields() {
  const profileId = profileSelect.value;
  replacePending = false;
  setStatus("");

  if (profileId === "custom") {
    fields.innerHTML = `
      <label class="field" for="fileName">
        <span>파일 이름</span>
        <input id="fileName" name="fileName" value="my-service.env" autocomplete="off" required />
        <small>영문·숫자·하이픈만 쓰고, 꼭 <code>.env</code>로 끝내세요.</small>
      </label>
      <label class="field" for="variableName">
        <span>환경변수 이름</span>
        <input id="variableName" name="variableName" value="MY_API_KEY" autocomplete="off" required />
        <small>대문자와 밑줄만 사용하세요. 예: <code>GEMINI_API_KEY</code></small>
      </label>
      ${inputField({ name: "value", label: "API 키 또는 토큰" })}`;
    return;
  }

  const profile = profiles[profileId];
  fields.innerHTML = profile.fields.map((name) => inputField({
    name,
    label: name,
    hint: profileId === "threads" && name === "THREADS_USER_ID" ? "토큰 연결 확인 뒤에 자동으로 채워도 됩니다." : "",
    required: !(profileId === "threads" && name === "THREADS_USER_ID")
  })).join("");
}

function collectValues() {
  const data = new FormData(form);
  return Object.fromEntries(Array.from(data.entries(), ([name, value]) => [name, value.trim()]));
}

function clearSecretInputs() {
  for (const input of fields.querySelectorAll('input[type="password"]')) {
    input.value = "";
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const values = collectValues();
  const required = Object.values(values).some((value) => value.length === 0);

  if (required && profileSelect.value !== "threads") {
    setStatus("빈칸 없이 입력해 주세요.", "error");
    return;
  }

  saveButton.disabled = true;
  setStatus("내 컴퓨터의 비밀 폴더에 저장하는 중입니다.");

  const result = await window.secretDrawer.save({
    profileId: profileSelect.value,
    values,
    replace: replacePending
  });

  saveButton.disabled = false;
  if (result.ok) {
    clearSecretInputs();
    replacePending = false;
    setStatus(`${result.fileName}에 저장했습니다. 키 값은 다시 표시하지 않습니다.`, "success");
    return;
  }

  if (result.type === "exists") {
    replacePending = true;
    setStatus("같은 파일이 이미 있습니다. 다시 ‘내 비밀 폴더에 저장’을 누르면 기존 값을 바꿉니다.", "error");
    return;
  }

  setStatus(result.message, "error");
});

openFolderButton.addEventListener("click", async () => {
  const result = await window.secretDrawer.openSecretFolder();

  if (!result.ok) {
    setStatus(`비밀 폴더를 열지 못했습니다: ${result.message}`, "error");
    return;
  }

  if (result.created) {
    setStatus("비밀 폴더를 열었습니다. 아직 저장한 키가 없어서 비어 있어요.");
  }
});

profiles = await window.secretDrawer.getProfiles();
renderFields();
profileSelect.addEventListener("change", renderFields);
