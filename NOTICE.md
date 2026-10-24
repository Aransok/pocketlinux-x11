# Notice

Pocket Linux Display is a fork of [Termux:X11](https://github.com/termux/termux-x11), an X server
for Android written by the Termux:X11 authors. Their work is the whole point of this project and
all credit for the X server, the renderer, the input handling and the Android app goes to them.

* Upstream: https://github.com/termux/termux-x11
* Forked from commit `7e5f5c5c9226e2cdab392b2efba91bc4bd86463e` (master)
* License: GNU General Public License version 3, see `LICENSE`. This fork keeps that license.
  Every copyright header in the source files is kept as it was.
* The native code builds on X.Org (xserver, libx11, xkbcomp and friends), pixman, libepoxy,
  libtirpc and bzip2. They are fetched at the commits upstream pins, by `scripts/fetch-sources.sh`,
  and keep their own licenses (MIT/X11 style, LGPL, BSD).

Pocket Linux Display is not affiliated with or endorsed by the Termux project.

## What is different from upstream

The Java packages (`com.termux.x11...`) and the native code were deliberately left alone, so the
fork stays easy to merge with upstream. The changes are:

1. **Application id and name.** `applicationId` is `app.pocketlinux.x11` (`lorie-app/build.gradle`),
   the app label is "Pocket Linux Display" (`lorie/src/main/res/values/strings.xml`), the
   notification title uses the same string, and the launcher icon background is a new color
   (`lorie_ic_launcher_background.xml`, referenced by both adaptive icon files).
2. **Intent actions.** Every action string that embedded the old id now embeds the new one:
   `app.pocketlinux.x11.CmdEntryPoint.ACTION_START`, `app.pocketlinux.x11.ACTION_STOP`,
   `app.pocketlinux.x11.ACTION_CUSTOM`, `app.pocketlinux.x11.ACTION_PREFERENCES_CHANGED`,
   `app.pocketlinux.x11.CHANGE_PREFERENCE` and `app.pocketlinux.x11.start_preferences_activity`
   (`CmdEntryPoint.java`, `MainActivity.java`, `LoriePreferences.java`, `TermuxX11ExtraKeys.java`,
   `lorie/src/main/AndroidManifest.xml`). This keeps the app from reacting to broadcasts meant for
   an installed Termux:X11, and the other way round. The `adb shell pm grant` hint shows the new id.
3. **Native process name check.** `lorie/src/main/cpp/lorie/activity.cpp` compared the process name
   with `com.termux.x11` to decide whether to redirect stderr to logcat. It now compares with
   `app.pocketlinux.x11`. Nothing else in the native code changed.
4. **Who may connect (replaces the Termux specific checks).** The audit found no list of Termux
   signatures in the app itself. The only trust check upstream is the signature comparison in
   `shell-loader/.../Loader.java`, which guards the Termux companion package. What the app does
   have is two exported broadcast receivers that accept the X server's Binder, open to every app.
   They are now protected by a permission:
   * `app.pocketlinux.x11.permission.CONNECT`, protection level `normal`, declared in
     `lorie/src/main/AndroidManifest.xml`. An app joins the allowlist by declaring
     `<uses-permission android:name="app.pocketlinux.x11.permission.CONNECT"/>`. The Pocket Linux
     app does. The X server process started from its proot guest runs under its uid, so it holds
     the permission.
   * The permission name is injected through the manifest placeholder `plReceiverPermission`
     (`lorie-app/build.gradle`). Building with `-PplOpenReceiver=true` swaps it for
     `android.permission.INTERNET`, which the adb shell user also holds. That is the debug switch:
     it allows `adb shell am broadcast` testing. Never publish such a build.
   * Android has no API to read the package of a plain broadcast sender, so a package name
     allowlist is not possible for this path. `queries` lists `app.pocketlinux` instead of
     `com.termux`.
5. **Loader.** The `termux-x11` command, which started `com.termux.x11.Loader` from a separate
   loader APK inside Termux, is replaced by `scripts/pl-x11`, a POSIX shell script for a glibc
   proot guest. It starts `com.termux.x11.CmdEntryPoint` straight from the Pocket Linux Display
   APK, as the upstream README describes for chroot. The `shell-loader` module is still built but
   unused; its constants point at the new id. Its Termux companion packaging
   (`companion-package.gradle`, the `termux-x11` and `termux-x11-preference` templates) was removed.
6. **Build.** ABIs are limited to `arm64-v8a` and `x86_64` (native build and APK). The `sharedUid`
   flavor was removed because it only makes sense inside the Termux app. APKs are named
   `pocketlinux-x11-<buildType>.apk`. The workflow is `.github/workflows/build.yml`. Because this
   repo was created by copying files, `scripts/fetch-sources.sh` replaces
   `git submodule update --init`.
7. **Docs.** `README.md` and `SECURITY.md` were rewritten; upstream issue templates, funding
   file and workflows were dropped.

The debug signing key `lorie-app/testkey_untrusted.jks` is upstream's public test key. Replace it
before publishing a build anywhere that expects a private key (Google Play).
