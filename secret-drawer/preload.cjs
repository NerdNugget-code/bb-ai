const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("secretDrawer", {
  getProfiles: () => ipcRenderer.invoke("profiles"),
  save: (payload) => ipcRenderer.invoke("save-secret", payload),
  openSecretFolder: () => ipcRenderer.invoke("open-secret-folder")
});
