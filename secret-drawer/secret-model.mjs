const ENVIRONMENT_NAME = /^[A-Z][A-Z0-9_]*$/;
const WINDOWS_RESERVED_NAME = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\.|$)/i;

export const SECRET_PROFILES = {
  gemini: {
    label: "Gemini API",
    fileName: "gemini.env",
    fields: ["GEMINI_API_KEY"]
  },
  openai: {
    label: "OpenAI API",
    fileName: "openai.env",
    fields: ["OPENAI_API_KEY"]
  },
  anthropic: {
    label: "Anthropic API",
    fileName: "anthropic.env",
    fields: ["ANTHROPIC_API_KEY"]
  },
  threads: {
    label: "Threads 자동화",
    fileName: "threads.env",
    fields: ["THREADS_ACCESS_TOKEN", "THREADS_APP_SECRET", "THREADS_USER_ID"]
  }
};

function quoteValue(value) {
  return "'" + value.replaceAll("'", "'\"'\"'") + "'";
}

export function serializeSecrets(entries) {
  const lines = [];

  for (const entry of entries) {
    if (!ENVIRONMENT_NAME.test(entry.name)) {
      throw new Error("환경변수 이름은 대문자·숫자·밑줄만 쓸 수 있어요. 예: MY_API_KEY");
    }

    if (entry.value.includes("\n") || entry.value.includes("\r")) {
      throw new Error("키 값에는 줄바꿈이 들어갈 수 없어요. 한 줄로 붙여넣어 주세요.");
    }

    if (entry.value.length > 0) {
      lines.push(`${entry.name}=${quoteValue(entry.value)}`);
    }
  }

  return lines.length === 0 ? "" : `${lines.join("\n")}\n`;
}

export function createProfileDocument(profileId, values) {
  if (profileId === "custom") {
    const fileName = values.fileName.trim();
    if (!/^[a-z0-9][a-z0-9-]*\.env$/i.test(fileName)) {
      throw new Error("파일 이름은 영문·숫자·하이픈만 쓰고 .env로 끝나야 해요. 예: my-service.env");
    }

    if (WINDOWS_RESERVED_NAME.test(fileName)) {
      throw new Error("윈도우에서 쓸 수 없는 예약어 이름이에요(con, nul 등). 다른 이름을 지어주세요.");
    }

    return {
      fileName,
      document: serializeSecrets([{ name: values.variableName, value: values.value }])
    };
  }

  const profile = SECRET_PROFILES[profileId];
  if (!profile) {
    throw new Error("Unknown secret profile");
  }

  return {
    fileName: profile.fileName,
    document: serializeSecrets(profile.fields.map((name) => ({ name, value: values[name] ?? "" })))
  };
}
