import { chmod, mkdir, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";

export class SecretFileExistsError extends Error {
  constructor(fileName) {
    super(`${fileName} already exists`);
    this.name = "SecretFileExistsError";
  }
}

export async function saveSecretDocument({ homeDir, fileName, document, replace = false }) {
  const secretDirectory = join(homeDir, ".secrets");
  const filePath = join(secretDirectory, fileName);

  await mkdir(secretDirectory, { recursive: true, mode: 0o700 });
  await chmod(secretDirectory, 0o700);

  if (!replace && existsSync(filePath)) {
    throw new SecretFileExistsError(fileName);
  }

  await writeFile(filePath, document, { encoding: "utf8", mode: 0o600 });
  await chmod(filePath, 0o600);

  return { fileName, filePath };
}
