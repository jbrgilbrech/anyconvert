# AnyConvert for macOS

`AnyConvert` now has two tracks:

- a Swift macOS CLI: `anyconvert`
- a Swift macOS GUI app: `AnyConvert.app`
- a browser app in `docs/` for GitHub Pages

The native macOS apps use built-in macOS converters instead of third-party dependencies:

- `sips` for images
- `textutil` for text and office-style documents
- `afconvert` for audio

The browser app uses `ffmpeg.wasm` and runs entirely client-side.

## What it can convert

This version supports broad native coverage for:

- images: `png`, `jpg`, `tiff`, `gif`, `bmp`, `heic`, `jp2`, `pdf`, `ico`, `icns`, `tga`, `psd`, `avif`, `pbm`
- documents: `txt`, `rtf`, `rtfd`, `html`, `doc`, `docx`, `odt`, `wordml`, `webarchive`
- audio: `wav`, `aiff`, `aifc`, `caf`, `m4a`, `mp3`, `aac`, `flac`, `opus`

The browser app is media-focused rather than universal. It is a real browser converter for common image, audio, video, and subtitle formats, but it does not claim support for every proprietary document format.

## Public website

The GitHub Pages web app lives in `docs/`.

- expected URL: `https://jbrgilbrech.github.io/anyconvert/`
- deploys through `.github/workflows/pages.yml`
- browser assets are synced with `npm run sync:web-vendor`

## Build

```bash
swift build
```

## Browser app

Install browser dependencies and sync the local vendor assets:

```bash
npm install
npm run sync:web-vendor
```

Preview the GitHub Pages app locally:

```bash
npm run serve:web
```

## CLI usage

List output formats supported for a specific input file:

```bash
swift run anyconvert formats /path/to/input.jpg
```

Convert a file:

```bash
swift run anyconvert convert --input /path/to/input.jpg --to png
swift run anyconvert convert --input /path/to/input.mp3 --to wav --output /path/to/output.wav
```

## Build the GUI app bundle

```bash
chmod +x scripts/build-app.sh
./scripts/build-app.sh
open dist/AnyConvert.app
```
