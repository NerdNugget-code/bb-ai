import assert from "node:assert/strict";
import test from "node:test";

import { createProfileDocument, serializeSecrets } from "./secret-model.mjs";

test("serializes one API key as a shell-safe env entry", () => {
  const document = serializeSecrets([
    { name: "GEMINI_API_KEY", value: "AIza-test-value" }
  ]);

  assert.equal(document, "GEMINI_API_KEY='AIza-test-value'\n");
});

test("omits optional blank values without leaving an empty secret entry", () => {
  const document = serializeSecrets([
    { name: "THREADS_ACCESS_TOKEN", value: "test-token" },
    { name: "THREADS_USER_ID", value: "" }
  ]);

  assert.equal(document, "THREADS_ACCESS_TOKEN='test-token'\n");
});

test("rejects names that cannot be environment variables", () => {
  assert.throws(
    () => serializeSecrets([{ name: "gemini-key", value: "test-value" }]),
    /환경변수 이름/
  );
});

test("rejects values containing a line break", () => {
  assert.throws(
    () => serializeSecrets([{ name: "GEMINI_API_KEY", value: "first\nsecond" }]),
    /줄바꿈/
  );
});

test("rejects Windows reserved device names as custom file names", () => {
  for (const fileName of ["con.env", "CON.env", "prn.env", "aux.env", "nul.env", "com1.env", "lpt9.env"]) {
    assert.throws(
      () => createProfileDocument("custom", { fileName, variableName: "MY_KEY", value: "test-value" }),
      /예약어/,
      `${fileName} should be rejected`
    );
  }
});

test("allows names that merely start with a reserved word", () => {
  for (const fileName of ["console.env", "con-fig.env", "auxiliary.env"]) {
    const result = createProfileDocument("custom", { fileName, variableName: "MY_KEY", value: "test-value" });
    assert.equal(result.fileName, fileName);
  }
});

test("builds the fixed Gemini secret file without exposing optional fields", () => {
  const result = createProfileDocument("gemini", {
    GEMINI_API_KEY: "AIza-test-value"
  });

  assert.equal(result.fileName, "gemini.env");
  assert.equal(result.document, "GEMINI_API_KEY='AIza-test-value'\n");
});

test("builds a custom secret file from the user-provided variable name", () => {
  const result = createProfileDocument("custom", {
    fileName: "my-service.env",
    variableName: "MY_SERVICE_TOKEN",
    value: "test-value"
  });

  assert.equal(result.fileName, "my-service.env");
  assert.equal(result.document, "MY_SERVICE_TOKEN='test-value'\n");
});
