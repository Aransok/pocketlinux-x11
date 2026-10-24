#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Fetches the third party sources the native X server is built from, at the exact commits that
# upstream Termux:X11 pins as git submodules (see .gitmodules).
#
# This repository was created by copying files, not by `git clone --recurse-submodules`, so the
# submodule commits are not recorded in git. This script replaces `git submodule update --init`.
# If you turn these folders into real submodules later, the script skips every folder that is
# already filled in.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# path url commit
PINS='
lorie/src/main/cpp/bzip2 https://gitlab.com/bzip2/bzip2.git 6a8690fc8d26c815e798c588f796eabe9d684cf0
lorie/src/main/cpp/libepoxy https://github.com/anholt/libepoxy c84bc9459357a40e46e2fec0408d04fbdde2c973
lorie/src/main/cpp/libfontenc https://gitlab.freedesktop.org/xorg/lib/libfontenc.git 780d1f6f192a331de7b298a96e23ebc44d2a884b
lorie/src/main/cpp/libtirpc https://github.com/alisw/libtirpc 5ca4ca92f629d9d83e83544b9239abaaacf0a527
lorie/src/main/cpp/libx11 https://gitlab.freedesktop.org/xorg/lib/libx11.git 6c75545a1deb51f5903992c52af6bc35cc9bc103
lorie/src/main/cpp/libxau https://gitlab.freedesktop.org/xorg/lib/libxau.git a9c65683e68b3a4349afee5d7673b393fb924d2e
lorie/src/main/cpp/libxcvt https://gitlab.freedesktop.org/xorg/lib/libxcvt.git dd8631c61465cc0de5e476c7a98e56528d62b163
lorie/src/main/cpp/libxdmcp https://gitlab.freedesktop.org/xorg/lib/libxdmcp.git 1192d3bc407348ff316bd3bffc791b3ac73f591b
lorie/src/main/cpp/libxfont https://gitlab.freedesktop.org/xorg/lib/libxfont.git 975cc6526e892c6fad8fa49d0fef58565fbaa003
lorie/src/main/cpp/libxkbfile https://gitlab.freedesktop.org/xorg/lib/libxkbfile.git 42e5dedd7fd3c7c73f3870a8751893c03c1afc69
lorie/src/main/cpp/libxshmfence https://gitlab.freedesktop.org/xorg/lib/libxshmfence.git 89f064748554e11832a3ec783945e1f4c7fe846e
lorie/src/main/cpp/libxtrans https://gitlab.freedesktop.org/xorg/lib/libxtrans.git cf05ba4a10c90da2c63805a5375e983b174e28b0
lorie/src/main/cpp/pixman https://gitlab.freedesktop.org/pixman/pixman.git 9cc163c9da0fb4da430641715313d95a6ec466d9
lorie/src/main/cpp/xkbcomp https://gitlab.freedesktop.org/xorg/app/xkbcomp.git 2c7789785981ad1fce3858c726615b49293f7de0
lorie/src/main/cpp/xorgproto https://gitlab.freedesktop.org/xorg/proto/xorgproto.git 6d3907b6d5dc4aa7d7ee6ee5d7d8714e7466630b
lorie/src/main/cpp/xserver https://gitlab.freedesktop.org/xorg/xserver.git 65d790bd208ec380b196eb98f144abb0b32e334d
'

fetch_one() {
  local path="$1" url="$2" sha="$3"
  if [ -n "$(ls -A "$path" 2>/dev/null)" ]; then
    echo "skip $path (already present)"
    return 0
  fi
  echo "fetch $path @ ${sha:0:12}"
  mkdir -p "$path"
  git -C "$path" init -q
  git -C "$path" remote add origin "$url"
  local try
  for try in 1 2 3; do
    if git -C "$path" fetch -q --depth 1 origin "$sha"; then
      git -C "$path" checkout -q FETCH_HEAD
      return 0
    fi
    echo "  fetch failed (try $try), retrying" >&2
    sleep $((try * 5))
  done
  echo "could not fetch $url @ $sha" >&2
  return 1
}

pids=()
while read -r path url sha; do
  [ -n "$path" ] || continue
  fetch_one "$path" "$url" "$sha" &
  pids+=("$!")
  # Keep at most 6 downloads running.
  while [ "$(jobs -rp | wc -l)" -ge 6 ]; do sleep 1; done
done <<< "$PINS"

rc=0
for p in "${pids[@]}"; do wait "$p" || rc=1; done
exit "$rc"
