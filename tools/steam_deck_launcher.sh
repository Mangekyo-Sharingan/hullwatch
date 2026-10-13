#!/bin/sh
set -eu
package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$package_dir"
export HULLWATCH_LAUNCHER_ACTIVE=1
stage=$package_dir/.hullwatch-update
child=
stop_game() { [ -z "$child" ] || kill -TERM "$child" 2>/dev/null || :; }
trap stop_game HUP INT TERM
while :; do
    if [ -f "$stage/handoff" ]; then
        /bin/sh "$package_dir/Hullwatch-Updater.sh" --recover "$package_dir/Hullwatch.x86_64"
    fi
    "$package_dir/Hullwatch.x86_64" --resolution 1280x800 --fullscreen --rendering-method mobile --max-fps 30 "$@" &
    child=$!
    result=0
    wait "$child" || result=$?
    child=
    [ "$result" -eq 42 ] || exit "$result"
    [ -f "$stage/launcher-request" ] && [ ! -L "$stage/launcher-request" ] && [ -f "$stage/handoff" ] || exit 1
    update_sha= update_size=
    { IFS= read -r update_sha; IFS= read -r update_size; } < "$stage/launcher-request"
    rm -f -- "$stage/launcher-request"
    if /bin/sh "$package_dir/Hullwatch-Updater.sh" "$package_dir/Hullwatch.x86_64" "$stage/payload" "$update_sha" "$update_size" 0 --no-launch; then
        continue
    fi
    printf '%s\n' 'Update failed; retaining or recovering the previous build.' >&2
    /bin/sh "$package_dir/Hullwatch-Updater.sh" --recover "$package_dir/Hullwatch.x86_64"
done
