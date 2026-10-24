# Pocket Linux Display

An X11 display server for Android. It is a fork of [Termux:X11](https://github.com/termux/termux-x11)
that the [Pocket Linux](https://github.com/Aransok) app uses to show a Linux desktop (XFCE,
Cinnamon) that runs under proot on an unrooted phone.

* Application id: `app.pocketlinux.x11`
* License: GPLv3 (`LICENSE`). Credits and the list of changes: `NOTICE.md`.
* Not affiliated with the Termux project.

## How it fits together

```
Pocket Linux app (closed source)              Pocket Linux Display (this repo, GPLv3)
  runs proot + Debian/Ubuntu guest              Android app: draws the screen, takes touch input
        |                                                   ^
        |  pl-x11 :0  (shell script, in the guest)          | broadcast with the X server's Binder
        v                                                   |
  app_process -> CmdEntryPoint  (the X server, libXlorie.so, loaded from this APK)
        ^
        | X11 protocol over /tmp/.X11-unix/X0
  XFCE / Cinnamon / any X client in the guest
```

1. The Pocket Linux app starts this app's `MainActivity` with an explicit intent.
2. Inside the guest, `pl-x11 :0 -xstartup start-desktop` runs `com.termux.x11.CmdEntryPoint` with
   this APK on the class path. That process is the X server. It listens on `$TMPDIR/.X11-unix/X0`
   (`TMPDIR=/tmp` in the guest, which the app maps to a folder in its own storage).
3. The X server broadcasts `app.pocketlinux.x11.CmdEntryPoint.ACTION_START` with its Binder to this
   app. The receiver requires the permission `app.pocketlinux.x11.permission.CONNECT`, which only
   apps that declare it in their manifest can hold (the Pocket Linux app does).
4. This app gets the surface and the input events through that Binder.

The Pocket Linux app never links or loads any code from this repo. It only starts an activity,
sends broadcasts and runs a separate process, which keeps its own license unaffected.

## Relationship to Termux:X11

Everything that matters comes from Termux:X11. This fork exists because the Pocket Linux guest is
a normal glibc Linux, not Termux, and it must be installable next to Termux:X11 without
clashing (different application id, different intent actions). The Java packages
(`com.termux.x11`) are unchanged on purpose, to keep merging upstream easy. See `NOTICE.md` for
every difference.

## Build

CI builds it: `.github/workflows/build.yml` uploads `pocketlinux-x11-debug.apk` as an artifact on
every push and attaches it to a GitHub release when you push a tag such as `v0.1.0`.

Locally you need JDK 17, the Android SDK with platform 34, NDK `29.0.14206865` and CMake
`3.22.1`, plus `bison`, `patch` and `python3`:

```
bash scripts/fetch-sources.sh        # X server sources at the pinned commits
./gradlew :lorie-app:assembleDebug
```

The APK is `lorie-app/build/outputs/apk/debug/pocketlinux-x11-debug.apk`. For adb testing use
`-PplOpenReceiver=true` (see `NOTICE.md`, change 4), and never publish that build.

## The `pl-x11` script

`scripts/pl-x11` is installed into the Pocket Linux images as `/usr/local/bin/pl-x11`. It finds the
APK (`$PL_X11_APK`, then `pm path app.pocketlinux.x11`) and runs
`app_process ... com.termux.x11.CmdEntryPoint "$@"`. All options of Termux:X11 work, for example:

```
pl-x11 :0 -xstartup "start-desktop"
pl-x11 :0 -legacy-drawing -xstartup "start-desktop"     # black screen on some devices
pl-x11 :0 -force-bgra -xstartup "start-desktop"         # wrong colors on some devices
```

The guest must see the Android system folders: the Pocket Linux app binds `/system`, `/apex`,
`/vendor`, `/data/app` and `/linkerconfig` and forwards the Android runtime environment
(`BOOTCLASSPATH`, `ANDROID_ROOT`, ...) into the guest.

## Closing it from outside

```
am broadcast -a app.pocketlinux.x11.ACTION_STOP -p app.pocketlinux.x11
```

## License

GPLv3. See `LICENSE` and `NOTICE.md`.
