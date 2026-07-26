import assert from "node:assert/strict";
import { mkdtemp, readFile, stat } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import { SecretFileExistsError, saveSecretDocument } from "./secret-store.mjs";

test("writes a secret document inside the fixed .secrets drawer", async () => {
  const homeDir = await mkdtemp(join(tmpdir(), "secret-drawer-"));
  const result = await saveSecretDocument({
    homeDir,
    fileName: "gemini.env",
    document: "GEMINI_API_KEY='test-value'\n"
  });

  assert.equal(result.fileName, "gemini.env");
  assert.equal(await readFile(result.filePath, "utf8"), "GEMINI_API_KEY='test-value'\n");

  if (process.platform !== "win32") {
    assert.equal((await stat(result.filePath)).mode & 0o077, 0);
  }
});

test("requires explicit replacement when a secret file already exists", async () => {
  const homeDir = await mkdtemp(join(tmpdir(), "secret-drawer-"));
  await saveSecretDocument({
    homeDir,
    fileName: "gemini.env",
    document: "GEMINI_API_KEY='first-value'\n"
  });

  await assert.rejects(
    saveSecretDocument({
      homeDir,
      fileName: "gemini.env",
      document: "GEMINI_API_KEY='replacement-value'\n"
    }),
    SecretFileExistsError
  );
});
