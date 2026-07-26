const { app, BrowserWindow, ipcMain, screen, shell } = require("electron");
const { existsSync } = require("node:fs");
const { mkdir } = require("node:fs/promises");
const path = require("node:path");

let secretModel;
let secretStore;

async function loadSecretModules() {
  secretModel = await import("./secret-model.mjs");
  secretStore = await import("./secret-store.mjs");
}

function createWindow() {
  const window = new BrowserWindow({
    width: 560,
    height: Math.min(880, screen.getPrimaryDisplay().workArea.height),
    minWidth: 560,
    minHeight: 600,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      preload: path.join(__dirname, "preload.cjs")
    }
  });

  window.removeMenu();
  window.loadFile("index.html");
}

function publicProfiles() {
  return Object.fromEntries(
    Object.entries(secretModel.SECRET_PROFILES).map(([id, profile]) => [id, {
      label: profile.label,
      fields: profile.fields
    }])
  );
}

app.whenReady().then(async () => {
  await loadSecretModules();

  ipcMain.handle("profiles", () => publicProfiles());

  ipcMain.handle("save-secret", async (_event, payload) => {
    try {
      const { fileName, document } = secretModel.createProfileDocument(payload.profileId, payload.values);
      const result = await secretStore.saveSecretDocument({
        homeDir: app.getPath("home"),
        fileName,
        document,
        replace: payload.replace === true
      });

      return { ok: true, fileName: result.fileName };
    } catch (error) {
      if (error instanceof secretStore.SecretFileExistsError) {
        return { ok: false, type: "exists", fileName: payload.profileId === "custom" ? payload.values.fileName : undefined };
      }

      return { ok: false, type: "validation", message: error.message };
    }
  });

  ipcMain.handle("open-secret-folder", async () => {
    const secretDirectory = path.join(app.getPath("home"), ".secrets");
    const created = !existsSync(secretDirectory);
    await mkdir(secretDirectory, { recursive: true, mode: 0o700 });
    const failure = await shell.openPath(secretDirectory);

    if (failure) {
      return { ok: false, message: failure };
    }

    return { ok: true, created };
  });

  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
