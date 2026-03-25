import { FFmpeg } from "./vendor/ffmpeg/index.js";
import { fetchFile } from "./vendor/ffmpeg-util/index.js";

const ffmpeg = new FFmpeg();
const ffmpegBaseURL = new URL("./vendor/ffmpeg/", import.meta.url);
const ffmpegURLs = {
  classWorkerURL: new URL("./worker.js", ffmpegBaseURL).href,
  coreURL: new URL("./ffmpeg-core.js", ffmpegBaseURL).href,
  wasmURL: new URL("./ffmpeg-core.wasm", ffmpegBaseURL).href,
};

const MIME_TYPES = {
  png: "image/png",
  jpg: "image/jpeg",
  webp: "image/webp",
  gif: "image/gif",
  bmp: "image/bmp",
  tiff: "image/tiff",
  ico: "image/x-icon",
  mp3: "audio/mpeg",
  wav: "audio/wav",
  flac: "audio/flac",
  ogg: "audio/ogg",
  aac: "audio/aac",
  m4a: "audio/mp4",
  mp4: "video/mp4",
  webm: "video/webm",
  srt: "text/plain",
  vtt: "text/vtt",
  ass: "text/plain",
};

const CATEGORY_MAP = {
  image: {
    inputs: ["jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff", "svg", "ico"],
    outputs: [
      { value: "png", label: "PNG" },
      { value: "jpg", label: "JPG" },
      { value: "webp", label: "WebP" },
      { value: "gif", label: "GIF" },
      { value: "bmp", label: "BMP" },
      { value: "tiff", label: "TIFF" },
      { value: "ico", label: "ICO" },
    ],
    presets: [
      { value: "default", label: "Default" },
      { value: "small", label: "Smaller file" },
      { value: "quality", label: "Higher quality" },
      { value: "icon", label: "Icon 256x256" },
    ],
  },
  audio: {
    inputs: ["mp3", "wav", "flac", "ogg", "oga", "aac", "m4a", "opus", "aiff"],
    outputs: [
      { value: "mp3", label: "MP3" },
      { value: "wav", label: "WAV" },
      { value: "flac", label: "FLAC" },
      { value: "ogg", label: "OGG" },
      { value: "aac", label: "AAC" },
      { value: "m4a", label: "M4A" },
    ],
    presets: [
      { value: "default", label: "Default" },
      { value: "small", label: "Smaller file" },
      { value: "quality", label: "Higher quality" },
    ],
  },
  video: {
    inputs: ["mp4", "mov", "webm", "mkv", "avi", "m4v", "gif"],
    outputs: [
      { value: "mp4", label: "MP4" },
      { value: "webm", label: "WebM" },
      { value: "gif", label: "GIF" },
      { value: "mp3", label: "MP3 audio only" },
      { value: "wav", label: "WAV audio only" },
    ],
    presets: [
      { value: "default", label: "Default" },
      { value: "small", label: "Smaller file" },
      { value: "quality", label: "Higher quality" },
    ],
  },
  subtitle: {
    inputs: ["srt", "vtt", "ass"],
    outputs: [
      { value: "srt", label: "SRT" },
      { value: "vtt", label: "WebVTT" },
      { value: "ass", label: "ASS" },
    ],
    presets: [
      { value: "default", label: "Default" },
    ],
  },
};

const state = {
  file: null,
  category: null,
  isLoaded: false,
  outputURL: null,
};

const ui = {
  engineState: document.querySelector("#engine-state"),
  dropzone: document.querySelector("#dropzone"),
  fileInput: document.querySelector("#file-input"),
  fileSummary: document.querySelector("#file-summary"),
  fileName: document.querySelector("#file-name"),
  fileType: document.querySelector("#file-type"),
  fileSize: document.querySelector("#file-size"),
  formatSelect: document.querySelector("#format-select"),
  presetSelect: document.querySelector("#preset-select"),
  convertButton: document.querySelector("#convert-button"),
  downloadLink: document.querySelector("#download-link"),
  statusLine: document.querySelector("#status-line"),
  logOutput: document.querySelector("#log-output"),
  progressBar: document.querySelector("#progress-bar"),
  dot: document.querySelector(".dot"),
};

function log(message, mode = "append") {
  if (mode === "replace") {
    ui.logOutput.textContent = message;
  } else {
    ui.logOutput.textContent += `${ui.logOutput.textContent ? "\n" : ""}${message}`;
  }
  ui.logOutput.scrollTop = ui.logOutput.scrollHeight;
}

function setStatus(message) {
  ui.statusLine.textContent = message;
}

function revokeDownload() {
  if (state.outputURL) {
    URL.revokeObjectURL(state.outputURL);
    state.outputURL = null;
  }
  ui.downloadLink.hidden = true;
  ui.downloadLink.removeAttribute("href");
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB"];
  let value = bytes / 1024;
  let unit = units[0];
  for (let index = 1; index < units.length && value >= 1024; index += 1) {
    value /= 1024;
    unit = units[index];
  }
  return `${value.toFixed(value >= 100 ? 0 : 1)} ${unit}`;
}

function getExtension(filename) {
  const parts = filename.toLowerCase().split(".");
  return parts.length > 1 ? parts.pop() : "";
}

function getBaseName(filename) {
  const lastDot = filename.lastIndexOf(".");
  return lastDot > 0 ? filename.slice(0, lastDot) : filename;
}

function detectCategory(file) {
  const ext = getExtension(file.name);
  const fromExtension = Object.entries(CATEGORY_MAP).find(([, config]) => config.inputs.includes(ext))?.[0];
  if (fromExtension) return fromExtension;
  if (file.type.startsWith("image/")) return "image";
  if (file.type.startsWith("audio/")) return "audio";
  if (file.type.startsWith("video/")) return "video";
  return null;
}

function setSelectOptions(select, options, placeholder) {
  select.innerHTML = "";
  if (!options.length) {
    const option = document.createElement("option");
    option.value = "";
    option.textContent = placeholder;
    select.append(option);
    return;
  }

  for (const item of options) {
    const option = document.createElement("option");
    option.value = item.value;
    option.textContent = item.label;
    select.append(option);
  }
}

function refreshUIForFile(file, category) {
  state.file = file;
  state.category = category;
  revokeDownload();
  ui.progressBar.style.width = "0%";

  ui.fileSummary.hidden = false;
  ui.fileName.textContent = file.name;
  ui.fileType.textContent = category ?? "Unsupported";
  ui.fileSize.textContent = formatBytes(file.size);

  if (!category) {
    setSelectOptions(ui.formatSelect, [], "Unsupported file type");
    setSelectOptions(ui.presetSelect, [{ value: "default", label: "Default" }], "Default");
    ui.formatSelect.disabled = true;
    ui.presetSelect.disabled = true;
    ui.convertButton.disabled = true;
    setStatus("This browser app currently focuses on image, audio, video, and subtitle formats.");
    log(`Unsupported input: ${file.name}`, "replace");
    return;
  }

  const outputOptions = CATEGORY_MAP[category].outputs.filter((option) => option.value !== getExtension(file.name));
  setSelectOptions(ui.formatSelect, outputOptions, "No output formats");
  setSelectOptions(ui.presetSelect, CATEGORY_MAP[category].presets, "Default");
  ui.formatSelect.disabled = false;
  ui.presetSelect.disabled = false;
  ui.convertButton.disabled = !outputOptions.length;
  setStatus(`Ready to convert ${file.name}.`);
  log(`Loaded ${file.name} (${category}, ${formatBytes(file.size)})`, "replace");
}

function buildArgs(inputName, outputName, category, preset, targetExt) {
  const args = ["-i", inputName];

  if (category === "image") {
    if (preset === "small") args.push("-q:v", "8");
    if (preset === "quality") args.push("-q:v", "2");
    if (preset === "icon" || targetExt === "ico") args.push("-vf", "scale=256:256:force_original_aspect_ratio=decrease");
    if (targetExt === "jpg") args.push("-q:v", preset === "small" ? "10" : "2");
    if (targetExt === "gif") args.push("-loop", "0");
  }

  if (category === "audio") {
    if (targetExt === "mp3") {
      args.push("-b:a", preset === "small" ? "128k" : preset === "quality" ? "320k" : "192k");
    }
    if (targetExt === "aac") {
      args.push("-b:a", preset === "small" ? "128k" : preset === "quality" ? "256k" : "192k");
    }
    if (targetExt === "ogg") {
      args.push("-c:a", "libvorbis", "-q:a", preset === "small" ? "3" : preset === "quality" ? "8" : "5");
    }
    if (targetExt === "m4a") {
      args.push("-c:a", "aac", "-b:a", preset === "small" ? "128k" : preset === "quality" ? "256k" : "192k");
    }
  }

  if (category === "video") {
    if (targetExt === "gif") {
      args.push("-vf", preset === "small" ? "fps=10,scale=480:-1:flags=lanczos" : "fps=12,scale=720:-1:flags=lanczos");
    } else if (targetExt === "mp3" || targetExt === "wav") {
      args.push("-vn");
      if (targetExt === "mp3") args.push("-b:a", preset === "small" ? "128k" : "192k");
    } else if (targetExt === "mp4") {
      args.push("-c:v", "libx264", "-preset", "veryfast", "-crf", preset === "small" ? "31" : preset === "quality" ? "20" : "25");
    } else if (targetExt === "webm") {
      args.push("-c:v", "libvpx-vp9", "-crf", preset === "small" ? "38" : preset === "quality" ? "28" : "32", "-b:v", "0");
    }
  }

  args.push("-y", outputName);
  return args;
}

async function ensureFFmpegLoaded() {
  if (state.isLoaded) return;

  setStatus("Loading browser conversion engine...");
  log("Loading ffmpeg.wasm runtime", "replace");
  await ffmpeg.load(ffmpegURLs);
  state.isLoaded = true;
  ui.engineState.textContent = "FFmpeg engine loaded";
  ui.dot.classList.add("ready");
  log("Engine ready");
}

async function handleConvert() {
  if (!state.file || !state.category) return;

  const targetExt = ui.formatSelect.value;
  if (!targetExt) return;

  revokeDownload();
  await ensureFFmpegLoaded();

  const inputExt = getExtension(state.file.name);
  const inputName = `input.${inputExt || "bin"}`;
  const outputName = `${getBaseName(state.file.name)}.${targetExt}`;
  const preset = ui.presetSelect.value;
  const args = buildArgs(inputName, outputName, state.category, preset, targetExt);

  setStatus(`Converting ${state.file.name} to ${targetExt.toUpperCase()}...`);
  log(`Writing ${state.file.name} into virtual filesystem`, "replace");
  ui.convertButton.disabled = true;
  ui.progressBar.style.width = "0%";

  try {
    await ffmpeg.writeFile(inputName, await fetchFile(state.file));
    log(`Running: ffmpeg ${args.join(" ")}`);
    const exitCode = await ffmpeg.exec(args);
    if (exitCode !== 0) {
      throw new Error(`ffmpeg exited with code ${exitCode}`);
    }
    const data = await ffmpeg.readFile(outputName);
    const blob = new Blob([data], { type: MIME_TYPES[targetExt] || "application/octet-stream" });
    state.outputURL = URL.createObjectURL(blob);

    ui.downloadLink.href = state.outputURL;
    ui.downloadLink.download = outputName;
    ui.downloadLink.hidden = false;
    setStatus(`Finished. ${outputName} is ready to download.`);
    log(`Created ${outputName} (${formatBytes(blob.size)})`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    setStatus("Conversion failed.");
    log(`Error: ${message}`);
  } finally {
    ui.convertButton.disabled = false;
    try {
      await ffmpeg.deleteFile(inputName);
    } catch {}
    try {
      await ffmpeg.deleteFile(outputName);
    } catch {}
  }
}

ffmpeg.on("log", ({ message }) => {
  if (message?.trim()) log(message);
});

ffmpeg.on("progress", ({ progress }) => {
  const ratio = Number.isFinite(progress) ? Math.max(0, Math.min(1, progress)) : 0;
  ui.progressBar.style.width = `${(ratio * 100).toFixed(1)}%`;
});

function onFileSelected(file) {
  if (!file) return;
  refreshUIForFile(file, detectCategory(file));
}

ui.fileInput.addEventListener("change", (event) => {
  const [file] = event.target.files ?? [];
  onFileSelected(file);
});

ui.dropzone.addEventListener("click", () => ui.fileInput.click());

for (const eventName of ["dragenter", "dragover"]) {
  ui.dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    ui.dropzone.classList.add("active");
  });
}

for (const eventName of ["dragleave", "drop"]) {
  ui.dropzone.addEventListener(eventName, (event) => {
    event.preventDefault();
    ui.dropzone.classList.remove("active");
  });
}

ui.dropzone.addEventListener("drop", (event) => {
  const [file] = event.dataTransfer?.files ?? [];
  onFileSelected(file);
});

ui.convertButton.addEventListener("click", () => {
  handleConvert();
});
