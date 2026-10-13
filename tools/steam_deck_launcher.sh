#!/bin/sh
set -eu
package_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$package_dir"
exec "$package_dir/Hullwatch.x86_64" --resolution 1280x800 --fullscreen --rendering-method mobile --max-fps 30 "$@"
