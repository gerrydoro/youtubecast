// The Docker image, the NixOS module and start.sh set these explicitly.
// Falling back to the working directory keeps `bun run start` working from a
// source checkout, where ./config, ./content and ./static live in the repo.
const CONFIG_BASE = process.env['CONFIG_BASE'] ?? process.cwd();
const APP_DIR = process.env['APP_DIR'] ?? process.cwd();

const CONFIG_FOLDER_PATH = `${CONFIG_BASE}/config`;
const CONTENT_FOLDER_PATH = `${CONFIG_BASE}/content`;
const COOKIES_TXT_FILE_PATH = `${CONFIG_BASE}/config/cookies.txt`;
const UI_FOLDER_PATH = `${APP_DIR}/static`;

export default {
  CONFIG_FOLDER_PATH,
  CONTENT_FOLDER_PATH,
  COOKIES_TXT_FILE_PATH,
  UI_FOLDER_PATH,
};
