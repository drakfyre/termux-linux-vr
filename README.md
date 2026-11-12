# termux-linux-setup

A unified script to easily set up native Linux desktop environments (XFCE4, LXQt, MATE, KDE) on Android via Termux. Includes GPU acceleration, audio, Windows app support (Box64/Wine), the Chromium browser, and a comprehensive set of default tools.

## GPU acceleration

* **Meta Quest (Horizon OS):** uses VirGL, which forwards OpenGL to the headset's own Adreno driver (OpenGL ES 3.2, desktop OpenGL 2.1). Turnip/Zink can't work on Quest because Horizon OS blocks the GPU memory allocation Turnip needs. The VirGL server starts automatically with the desktop. Apps that can use OpenGL ES (Chromium, Godot's Compatibility renderer) get the most out of it.
* **Other Adreno phones:** Turnip + Zink (Vulkan).

Check it from a desktop terminal with `glxinfo -B | grep renderer`. On Quest it should say `virgl (Adreno ...)`.

Chromium needs no extra flags: it uses ANGLE on top of the GPU driver, so WebGL and WebGPU run on the GPU. Video decoding is software-only (no hardware decode is available).

## Bigger Termux:X11 window on Quest

Horizon OS opens Termux:X11 in a small 1024x640 panel. On a Quest, the setup script offers to patch the app so it opens at 1440x1000 instead. It rebuilds your installed Termux:X11 on the headset (with apktool) and re-signs it with a key made just for you (`~/.android-patch-key.jks`). Near the end you'll be asked to uninstall the official app and install the patched one.

* After a Termux:X11 update, run `patch-termux-x11` again (or `patch-termux-x11 WIDTH HEIGHT` for a different size) and install the APK it makes. It installs over the old one.
* Keep `~/.android-patch-key.jks`. If you lose it, you'll have to uninstall Termux:X11 before installing a newly patched build.
* `~/start-linux.sh` starts X with `~/bin/termux-x11-patched`, because the stock `termux-x11` command rejects the re-signed app.

## Prerequisites

Before running this script, you must install the correct versions of the required applications on your Android device.

1. **Termux Base App**: Do not download Termux from the Google Play Store, as that version is broken and no longer receives updates. You must download the official, updated version from F-Droid:
   * [Download Termux (F-Droid)](https://f-droid.org/en/packages/com.termux/)

2. **Termux-X11 App**: This application acts as the display server (your monitor) to show the Linux desktop. **Note:** Termux-X11 is no longer available on F-Droid. You must download the official Companion APK (`app-arm64-v8a-debug.apk`) directly from their GitHub releases page:
   * [Download Termux-X11 Nightly (GitHub)](https://github.com/termux/termux-x11/releases/tag/nightly)

## How to Install

Once you have both applications installed on your phone, open the primary **Termux** app and paste the following command to automatically download and run the setup script:

```bash
curl -O https://raw.githubusercontent.com/drakfyre/termux-linux-vr/main/termux-linux-vr-setup.sh && chmod +x termux-linux-vr-setup.sh && ./termux-linux-vr-setup.sh
```
