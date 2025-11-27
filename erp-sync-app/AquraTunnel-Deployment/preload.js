const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  login: (accessCode) => ipcRenderer.invoke('login', { accessCode }),

  loadBranches: () => ipcRenderer.invoke('load-branches'),
  saveConfig: (config) => ipcRenderer.invoke('save-config', config),
  testConnection: (config) => ipcRenderer.invoke('test-connection', config),
  syncHistoricalData: () => ipcRenderer.invoke('sync-historical-data'),
  startSync: () => ipcRenderer.invoke('start-sync'),
  stopSync: () => ipcRenderer.invoke('stop-sync'),
  getStatus: () => ipcRenderer.invoke('get-status'),
  onSyncLog: (callback) => ipcRenderer.on('sync-log', (event, data) => callback(data)),
  verifyLogout: (accessCode) => ipcRenderer.invoke('verify-logout', { accessCode }),
  forceClose: () => ipcRenderer.invoke('force-close'),
  onRequestLogoutVerification: (callback) => ipcRenderer.on('request-logout-verification', callback),
  getAutostartStatus: () => ipcRenderer.invoke('get-autostart-status'),
  setAutostart: (enabled) => ipcRenderer.invoke('set-autostart', { enabled })
});
