import { app, BrowserWindow, globalShortcut, ipcMain, screen } from 'electron';
import * as path from 'path';
import { Output } from 'easymidi';

let mainWindow: BrowserWindow | null = null;
let midiOutput: Output | null = null;

const WIN_WIDTH = 920;
const WIN_HEIGHT = 230;

function activeDisplay() {
  return screen.getDisplayNearestPoint(screen.getCursorScreenPoint());
}

function positionOnActiveDisplay() {
  if (!mainWindow) return;
  const d = activeDisplay();
  const { x: dx, y: dy, width: dw, height: dh } = d.workArea;
  mainWindow.setBounds({
    x: dx + Math.round((dw - WIN_WIDTH) / 2),
    y: dy + dh - WIN_HEIGHT - 60,
    width: WIN_WIDTH,
    height: WIN_HEIGHT,
  });
}

function createWindow() {
  const d = activeDisplay();
  const { x: dx, y: dy, width: dw, height: dh } = d.workArea;

  mainWindow = new BrowserWindow({
    width: WIN_WIDTH,
    height: WIN_HEIGHT,
    x: dx + Math.round((dw - WIN_WIDTH) / 2),
    y: dy + dh - WIN_HEIGHT - 60,
    frame: false,
    transparent: true,
    hasShadow: false,
    alwaysOnTop: true,
    resizable: false,
    movable: true,
    skipTaskbar: true,
    show: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.setAlwaysOnTop(true, 'floating');
  mainWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  mainWindow.loadFile(path.join(__dirname, 'renderer/index.html'));

  mainWindow.on('blur', () => {
    if (mainWindow?.isVisible()) {
      mainWindow.webContents.send('release-all');
      mainWindow.hide();
    }
  });
}

function toggleWindow() {
  if (!mainWindow) return;
  if (mainWindow.isVisible()) {
    mainWindow.webContents.send('release-all');
    mainWindow.hide();
  } else {
    positionOnActiveDisplay();
    mainWindow.show();
    mainWindow.focus();
  }
}

app.whenReady().then(() => {
  try {
    midiOutput = new Output('OnScreen Keyboard', true);
    console.log('Virtual MIDI port created: "OnScreen Keyboard"');
  } catch (e) {
    console.error('Failed to create virtual MIDI port:', e);
  }

  createWindow();

  const ok = globalShortcut.register('CommandOrControl+K', toggleWindow);
  if (!ok) console.error('Failed to register Cmd+K shortcut');

  if (process.platform === 'darwin') {
    app.dock?.hide();
  }
});

ipcMain.on('midi-note-on', (_e, { note, velocity }: { note: number; velocity: number }) => {
  midiOutput?.send('noteon', { note, velocity, channel: 0 });
});

ipcMain.on('midi-note-off', (_e, { note }: { note: number }) => {
  midiOutput?.send('noteoff', { note, velocity: 0, channel: 0 });
});

ipcMain.on('midi-cc', (_e, { controller, value }: { controller: number; value: number }) => {
  midiOutput?.send('cc', { controller, value, channel: 0 });
});

ipcMain.on('hide-window', () => {
  if (mainWindow?.isVisible()) {
    mainWindow.webContents.send('release-all');
    mainWindow.hide();
  }
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
  midiOutput?.close();
});

app.on('window-all-closed', (e: Electron.Event) => {
  e.preventDefault();
});
