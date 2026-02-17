const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('api', {
  // Window controls
  minimize: () => ipcRenderer.send('window:minimize'),
  maximize: () => ipcRenderer.send('window:maximize'),
  close: () => ipcRenderer.send('window:close'),

  // State management
  checkResume: () => ipcRenderer.invoke('state:check-resume'),
  saveState: (state) => ipcRenderer.invoke('state:save', state),
  setAutoStart: (enable) => ipcRenderer.invoke('state:set-autostart', enable),

  // Shell execution
  exec: (command, options) => ipcRenderer.invoke('shell:exec', command, options),
  wsl: (command, options) => ipcRenderer.invoke('shell:wsl', command, options),
  stream: (command, options) => ipcRenderer.invoke('shell:stream', command, options),
  ssh: (host, command, options) => ipcRenderer.invoke('shell:ssh', host, command, options),

  // Streaming output listener
  onOutput: (callback) => {
    ipcRenderer.on('shell:output', (_, data) => callback(data));
  },
  removeOutputListener: () => {
    ipcRenderer.removeAllListeners('shell:output');
  },

  // File system
  writeFile: (filePath, content) => ipcRenderer.invoke('fs:write', filePath, content),
  readFile: (filePath) => ipcRenderer.invoke('fs:read', filePath),
  fileExists: (filePath) => ipcRenderer.invoke('fs:exists', filePath),

  // Dialog
  showMessage: (options) => ipcRenderer.invoke('dialog:message', options),

  // System info
  getNetworkIPs: () => ipcRenderer.invoke('system:get-ip')
});
