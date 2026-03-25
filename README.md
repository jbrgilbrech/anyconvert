# AnyConvert

AnyConvert now has two separate execution models:

- native macOS tools in Swift
- a browser app served as static assets

The browser app is the part that should be containerized. Its conversion engine is still `ffmpeg.wasm`, so the actual transcoding runs inside the end user's browser tab, not inside the container. Docker is responsible for packaging and serving the web app consistently.

## Architecture

### Native macOS path

The Swift targets are local macOS executables:

- `anyconvert`: CLI
- `AnyConvertGUI`: AppKit GUI

These use Apple-native tools:

- `sips` for images
- `textutil` for rich text and document conversion
- `afconvert` for audio

That path is macOS-specific and is not what the Docker image serves.

### Browser path

The browser app lives in `docs/` and is composed of:

- `docs/index.html`: UI shell
- `docs/styles.css`: layout and visual system
- `docs/app.js`: client-side conversion logic
- `docs/vendor/ffmpeg/*`: vendored `ffmpeg.wasm` runtime files
- `docs/vendor/ffmpeg-util/*`: vendored browser helpers

Execution model:

1. Nginx serves static files from the container.
2. The browser downloads `app.js`, `ffmpeg-core.js`, and `ffmpeg-core.wasm`.
3. `app.js` spins up the FFmpeg worker and loads the WebAssembly runtime.
4. The selected file is copied into FFmpeg's in-memory virtual filesystem.
5. FFmpeg runs in the browser worker thread.
6. The output file is read back into browser memory and exposed as a download.

Implications:

- no backend upload API exists
- the container does not transcode files server-side
- CPU and memory pressure happen in the client browser process
- very large files can hit browser memory limits even if the container itself is fine

## Supported browser conversion scope

The browser app is media-focused. It is a realistic browser converter for:

- images: `jpg`, `jpeg`, `png`, `webp`, `gif`, `bmp`, `tif`, `tiff`, `svg`, `ico`
- audio: `mp3`, `wav`, `flac`, `ogg`, `oga`, `aac`, `m4a`, `opus`, `aiff`
- video: `mp4`, `mov`, `webm`, `mkv`, `avi`, `m4v`, `gif`
- subtitles: `srt`, `vtt`, `ass`

It is not a universal browser converter for arbitrary office formats or every proprietary binary format.

## Local development

### Native Swift build

```bash
swift build
```

### Browser dependencies

The browser app vendors the FFmpeg runtime into `docs/vendor/`. That sync step is reproducible and should be rerun when the FFmpeg dependency version changes.

```bash
npm ci
npm run sync:web-vendor
```

### Local static preview

```bash
npm run serve:web
```

This serves the browser app at `http://localhost:8042`.

## Dockerized browser deployment

### Files involved

- `Dockerfile`
- `docker/nginx.conf`
- `docker-compose.yml`
- `.dockerignore`

### Build pipeline

The container image is multi-stage.

#### Stage 1: `web-assets`

Base image:

- `node:24-bookworm-slim`

Responsibilities:

1. install npm dependencies with `npm ci`
2. copy `docs/` and `scripts/`
3. run `npm run sync:web-vendor`

This guarantees the served static bundle contains the exact FFmpeg runtime files expected by `docs/app.js`.

#### Stage 2: `web-runtime`

Base image:

- `nginx:1.27-alpine`

Responsibilities:

1. copy the prepared `docs/` directory to `/usr/share/nginx/html`
2. install an explicit Nginx site config
3. expose port `8080`

The Nginx config does two important things:

- sets `application/wasm` for `.wasm`
- serves JS/WASM/CSS with long-lived immutable caching

### Build the image

```bash
docker build -t anyconvert-web:local .
```

Equivalent npm wrapper:

```bash
npm run docker:build
```

### Run the container

```bash
docker run --rm -p 8080:8080 anyconvert-web:local
```

Equivalent npm wrapper:

```bash
npm run docker:run
```

The app will then be available at:

```text
http://localhost:8080
```

### Run with Docker Compose

```bash
docker compose up --build
```

This uses `docker-compose.yml` and exposes the same service on port `8080`.

## Technical notes for production

### 1. Browser memory profile

`ffmpeg.wasm` is large. The vendored `ffmpeg-core.wasm` is roughly tens of megabytes before the user even starts a conversion. During conversion, memory usage can spike because there are multiple resident copies:

- source file blob in browser memory
- FFmpeg virtual filesystem copy
- intermediate transcoding buffers
- output blob

For large video inputs, this can exceed browser tab memory limits.

### 2. Why Docker still matters

Even though conversion is client-side, Docker gives you:

- immutable static asset packaging
- reproducible dependency install and vendor sync
- a predictable HTTP server with correct MIME and cache headers
- an easy deployment unit for Kubernetes, ECS, Nomad, Fly.io, Render, Railway, or a plain VPS

### 3. Reverse proxy requirements

If you put another proxy in front of this container:

- preserve `Content-Type: application/wasm` for `.wasm`
- do not gzip or rewrite the wasm path incorrectly
- allow worker/module asset loading from the same origin

### 4. HTTPS

For production, terminate TLS outside the container or with a front proxy. The app itself is fully static and does not require origin state.

### 5. Caching strategy

The Nginx config marks:

- `index.html` as effectively non-cacheable
- `.js`, `.mjs`, `.css`, and `.wasm` as immutable cacheable assets

That is the correct split for a static app shell plus versioned artifact deployment. If you later fingerprint asset names, this becomes even safer.

### 6. Operational reality

This architecture is only correct if you want:

- no backend conversion service
- no user uploads to your infrastructure
- lower hosting complexity

It is not the right architecture if you need:

- huge file support
- long-running jobs
- guaranteed codec availability beyond what `ffmpeg.wasm` can realistically handle in-browser
- proprietary document conversion
- multi-file pipelines on the server

If you want those, the correct next step is a real backend conversion service, probably FFmpeg in a server-side worker queue, not browser-only WebAssembly.

## Native macOS usage

### CLI

List output formats:

```bash
swift run anyconvert formats /path/to/input.jpg
```

Convert:

```bash
swift run anyconvert convert --input /path/to/input.jpg --to png
swift run anyconvert convert --input /path/to/input.mp3 --to wav --output /path/to/output.wav
```

### GUI app

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/AnyConvert.app
```
