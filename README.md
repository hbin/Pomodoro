<h1 align="center">
  <a href="https://github.com/hbin/Pomodoro"><img src="docs/images/icon.png" alt="Pomodoro app icon" width="128" height="128"></a><br>
  Pomodoro
</h1>

<p align="center">
  <strong>Free.</strong> A quiet focus timer for the macOS menu bar.<br>
  Choose focus or a break, then press Start. When an interval ends, the next
  step is ready; nothing starts without you.
</p>

<p align="center">
  <a href="#install"><strong>Install</strong></a> ·
  <a href="https://github.com/hbin/Pomodoro/releases/latest"><strong>Download</strong></a>
</p>

<p align="center">
  <img alt="macOS 15 or later" src="https://img.shields.io/badge/macOS-15%2B-2B2520?style=flat-square&logo=apple&logoColor=FFFFFF">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=FFFFFF">
  <img alt="Free" src="https://img.shields.io/badge/price-free-3E8E5A?style=flat-square">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-3E8E5A?style=flat-square"></a>
</p>

<p align="center">
  <img src="docs/screenshots/light-theme.png" width="320" alt="Pomodoro in Light theme">
  <img src="docs/screenshots/black-theme.png" width="320" alt="Pomodoro in Black theme">
</p>

## Install

Download the latest `Pomodoro.dmg` from
[Releases](https://github.com/hbin/Pomodoro/releases/latest), open it, and drag
**Pomodoro** into **Applications**.

If macOS blocks the first launch, open Pomodoro once, then go to
**System Settings → Privacy & Security** and choose **Open Anyway**.
Alternatively, clear the quarantine flag in Terminal:

```sh
xattr -dr com.apple.quarantine /Applications/Pomodoro.app
open /Applications/Pomodoro.app
```

## License

Pomodoro is free to use, modify, and distribute, including for commercial
purposes, under the [MIT License](LICENSE).
