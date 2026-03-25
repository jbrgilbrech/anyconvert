# AnyConvert for macOS

`AnyConvert` is a native macOS file converter with:

- a terminal app: `anyconvert`
- a basic GUI app: `AnyConvert.app`
- a GitHub Pages site in `docs/`

It uses built-in macOS converters instead of third-party dependencies:

- `sips` for images
- `textutil` for text and office-style documents
- `afconvert` for audio

## What it can convert

This version supports broad native coverage for:

- images: `png`, `jpg`, `tiff`, `gif`, `bmp`, `heic`, `jp2`, `pdf`, `ico`, `icns`, `tga`, `psd`, `avif`, `pbm`
- documents: `txt`, `rtf`, `rtfd`, `html`, `doc`, `docx`, `odt`, `wordml`, `webarchive`
- audio: `wav`, `aiff`, `aifc`, `caf`, `m4a`, `mp3`, `aac`, `flac`, `opus`

It does not claim universal conversion for every possible file type. The structure is set up so more converters can be added cleanly.

## Public website

The static site for GitHub Pages lives in `docs/`.

- expected URL: `https://jbrgilbrech.github.io/anyconvert/`
- deploys through `.github/workflows/pages.yml`

## Build

```bash
swift build
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
