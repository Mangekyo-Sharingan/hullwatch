#!/bin/sh
set -eu
LC_ALL=C
export LC_ALL
fail() { printf 'Hullwatch update: %s\n' "$*" >&2; exit 1; }
recover=0 launch=1
if [ "${1-}" = --recover ]; then
    [ "$#" -eq 2 ] || fail 'expected --recover TARGET'
    recover=1 target=$2 wait_pid=0
    shift 2
else
    [ "$#" -ge 5 ] || fail 'expected TARGET PAYLOAD SHA256 SIZE WAIT_PID'
    target=$1 payload=$2 sha=$3 size=$4 wait_pid=$5
    shift 5
    case ${1-} in
        --no-launch) [ "$#" -eq 1 ] || fail 'unexpected no-launch arguments'; launch=0; shift ;;
        --) shift ;;
        '') [ "$#" -eq 0 ] || fail 'expected -- before restart arguments' ;;
        *) fail 'expected -- or --no-launch' ;;
    esac
    case $sha in *[!0-9a-f]*) fail 'invalid SHA256' ;; esac
    [ "${#sha}" -eq 64 ] || fail 'invalid SHA256'
    case $size in ''|0*|*[!0-9]*) fail 'invalid size' ;; esac
    [ "${#size}" -le 19 ] && [ "$size" -le 9223372036854775807 ] || fail 'size exceeds int64'
fi
case $wait_pid in ''|*[!0-9]*) fail 'invalid PID' ;; esac
[ "${#wait_pid}" -le 10 ] && [ "$wait_pid" -le 2147483647 ] || fail 'invalid PID'

# Linux coreutils + util-linux flock ship on Steam Deck. Hostile same-user races
# require an fd-based native installer; receipt hashes are local crash evidence.
check_path() {
    case $1 in /*) ;; *) fail 'paths must be absolute' ;; esac
    case $1 in *//*|*/./*|*/../*|*/.|*/..|*/) fail 'non-canonical path' ;; esac
    check_component=$1
    while [ "$check_component" != / ]; do
        [ ! -L "$check_component" ] || fail "symlink refused: $check_component"
        check_component=${check_component%/*}
        [ -n "$check_component" ] || check_component=/
    done
}
check_path "$target"
target_dir=${target%/*}
[ -n "$target_dir" ] || target_dir=/
stage=${target_dir%/}/.hullwatch-update
previous=$stage/previous
backup=$previous/${target##*/}
old_receipt=$backup.sha256
new_receipt=$stage/expected-new.sha256
current_receipt=$stage/expected-old.sha256
handoff=$stage/handoff
pending=$stage/pending
lock=$stage/apply.lock
guard=$stage/apply.guard
download=$stage/download.lock
fixed_payload=$stage/payload

check_stage() {
    for checked in "$target" "$fixed_payload" "$backup" "$old_receipt" "$current_receipt" "$new_receipt" "$handoff" "$pending" "$lock" "$guard" "$download/owner_pid"; do
        check_path "$checked"
    done
    [ -d "$stage" ] || fail 'missing staging directory'
    for directory in "$previous" "$download" "$lock"; do
        [ ! -e "$directory" ] || [ -d "$directory" ] || fail 'invalid staging directory'
    done
    for regular in "$target" "$fixed_payload" "$backup" "$old_receipt" "$current_receipt" "$new_receipt" "$handoff" "$pending" "$guard" "$download/owner_pid"; do
        [ ! -e "$regular" ] || [ -f "$regular" ] || fail 'regular file required'
    done
    device=$(stat -c %d -- "$target_dir") || fail 'cannot stat target directory'
    for same_device in "$stage" "$previous" "$target" "$fixed_payload" "$backup"; do
        [ ! -e "$same_device" ] || [ "$(stat -c %d -- "$same_device")" = "$device" ] || fail 'staging must be on target filesystem'
    done
}
is_running() { [ "$1" -gt 0 ] && { kill -0 "$1" 2>/dev/null || [ -d "/proc/$1" ]; }; }
read_pid() {
    [ -f "$1" ] || fail 'missing lock owner'
    owner=$(cat -- "$1") || fail 'cannot read lock owner'
    case $owner in ''|0*|*[!0-9]*) fail 'invalid lock owner' ;; esac
    [ "${#owner}" -le 10 ] && [ "$owner" -le 2147483647 ] || fail 'invalid lock owner'
}
hash_file() { hash_result=$(sha256sum < "$1") || fail 'cannot hash executable'; hash_result=${hash_result%% *}; }
read_hash() {
    receipt_hash=
    [ -f "$1" ] || return 0
    receipt_hash=$(cat -- "$1") || fail 'cannot read hash receipt'
    case $receipt_hash in *[!0-9a-f]*) fail 'invalid hash receipt' ;; esac
    [ "${#receipt_hash}" -eq 64 ] || fail 'invalid hash receipt'
}
receipt_temp= backup_temp= owns_download=0 swap_attempted=0 download_owner=
write_receipt() {
    receipt_temp=$(mktemp "$stage/.receipt.XXXXXX") || fail 'cannot create receipt'
    printf '%s\n' "$2" > "$receipt_temp"
    sync -f -- "$receipt_temp" || fail 'cannot flush receipt'
    mv -fT -- "$receipt_temp" "$1" || fail 'cannot publish receipt'
    receipt_temp=
}
download_owned() {
    check_path "$download/owner_pid"
    [ -d "$download" ] || return 1
    read_pid "$download/owner_pid"
    [ "$owner" = "$download_owner" ] || return 1
    if { [ "$wait_pid" -gt 0 ] && [ "$owner" -eq "$wait_pid" ]; } || { [ "$wait_pid" -eq 0 ] && ! is_running "$owner"; }; then
        return 0
    fi
    return 1
}
release_download() {
    download_owned || return 0
    rm -f -- "$download/owner_pid"
    rmdir -- "$download" || :
}
cleanup() {
    [ -z "$backup_temp" ] || rm -f -- "$backup_temp"
    [ -z "$receipt_temp" ] || rm -f -- "$receipt_temp"
    if [ "$owns_download" -eq 1 ]; then
        if [ "$recover" -eq 0 ] && [ "$swap_attempted" -eq 0 ] && download_owned; then
            rm -f -- "$handoff" "$pending"
        fi
        release_download
    fi
    rm -f -- "$lock/owner_pid"
    rmdir -- "$lock" || :
    flock -u 9
    exec 9>&-
}
check_path "$stage"
[ -d "$stage" ] || { [ "$recover" -eq 1 ] && [ ! -e "$stage" ] && exit 0; fail 'missing staging directory'; }
check_stage
# The OS lock dies with the helper; it serializes safe reclamation of a stale mkdir.
exec 9>>"$guard"
flock -n 9 || fail 'another installer is active'
if [ -e "$lock" ]; then
    [ -d "$lock" ] || fail 'invalid apply lock'
    check_path "$lock/owner_pid"
    if [ -e "$lock/owner_pid" ]; then
        read_pid "$lock/owner_pid"
        ! is_running "$owner" || fail 'another installer is active'
        rm -- "$lock/owner_pid"
    fi
    rmdir -- "$lock" || fail 'cannot reclaim apply lock'
fi
mkdir -- "$lock" || fail 'cannot acquire apply lock'
printf '%s\n' "$$" > "$lock/owner_pid"
trap cleanup EXIT
trap 'exit 1' HUP INT TERM
if [ "$recover" -eq 1 ]; then
    [ -f "$handoff" ] || exit 0
    if [ -d "$download" ]; then
        read_pid "$download/owner_pid"
        download_owner=$owner
        ! is_running "$owner" || fail 'handoff owner is still running'
    fi
    owns_download=1
    read_hash "$old_receipt"; old_hash=$receipt_hash
    read_hash "$current_receipt"; current_hash=$receipt_hash
    read_hash "$new_receipt"; new_hash=$receipt_hash
    valid_current=0
    if [ -f "$target" ]; then
        hash_file "$target"
        [ "$hash_result" != "$old_hash" ] && [ "$hash_result" != "$current_hash" ] && [ "$hash_result" != "$new_hash" ] || valid_current=1
    fi
    if [ "$valid_current" -eq 0 ]; then
        { [ -n "$old_hash" ] || [ -n "$current_hash" ]; } && [ -f "$backup" ] || fail 'no verified prior executable; recovery left untouched'
        hash_file "$backup"
        [ "$hash_result" = "$old_hash" ] || [ "$hash_result" = "$current_hash" ] || fail 'prior executable hash mismatch; recovery left untouched'
        old_hash=$hash_result
        backup_temp=$(mktemp "$previous/.restore.XXXXXX")
        cp -p -- "$backup" "$backup_temp" || fail 'cannot copy recovery executable'
        hash_file "$backup_temp"
        [ "$hash_result" = "$old_hash" ] || fail 'recovery copy hash mismatch'
        chmod u+x -- "$backup_temp"
        sync -f -- "$backup_temp"
        mv -fT -- "$backup_temp" "$target" || fail 'cannot restore prior executable'
        backup_temp=
        sync -f -- "$target_dir"
    fi
    rm -f -- "$fixed_payload" "$handoff"
    # A valid new build still needs the parent's GUI boot acknowledgment.
    [ "$hash_result" = "$new_hash" ] || rm -f -- "$pending"
    sync -f -- "$stage"
    exit 0
fi
[ "$payload" = "$fixed_payload" ] || fail 'payload must use the fixed staging path'
check_path "$payload"
[ -f "$handoff" ] || fail 'missing download handoff'
[ -d "$download" ] || fail 'missing download lock'
read_pid "$download/owner_pid"
download_owner=$owner
if [ "$wait_pid" -gt 0 ]; then
    [ "$owner" -eq "$wait_pid" ] || fail 'unrelated download owner'
else
    ! is_running "$owner" || fail 'download owner is still running'
fi
owns_download=1
validate_payload() {
    check_stage
    [ -f "$target" ] && [ -f "$payload" ] || fail 'missing regular executable or payload'
    [ "$(stat -c %s -- "$payload")" = "$size" ] || fail 'payload size mismatch'
    hash_file "$payload"
    [ "$hash_result" = "$sha" ] || fail 'payload SHA256 mismatch'
}
validate_payload
# PID reuse and zombies count as running; never signal the game on timeout.
deadline=$(($(date +%s) + 30))
while is_running "$wait_pid"; do
    [ "$(date +%s)" -lt "$deadline" ] || fail 'wait timeout; running game left untouched'
    sleep 1
done
validate_payload
mkdir -p -- "$previous"
check_stage
hash_file "$target"
old_hash=$hash_result
write_receipt "$current_receipt" "$old_hash"
backup_temp=$(mktemp "$previous/.previous.XXXXXX")
cp -p -- "$target" "$backup_temp" || fail 'cannot copy rollback executable; target retained'
hash_file "$backup_temp"
[ "$hash_result" = "$old_hash" ] || fail 'rollback copy hash mismatch; target retained'
sync -f -- "$backup_temp"
mv -fT -- "$backup_temp" "$backup" || fail 'cannot publish rollback executable; target retained'
backup_temp=
write_receipt "$old_receipt" "$old_hash"
write_receipt "$new_receipt" "$sha"
write_receipt "$pending" "$sha"
chmod u+x -- "$payload" || fail 'cannot make payload executable; target retained'
sync -f -- "$stage"
swap_attempted=1
mv -fT -- "$payload" "$target" || fail 'cannot install payload; prior executable retained'
sync -f -- "$target_dir"
cleanup
trap - EXIT HUP INT TERM
[ "$launch" -eq 1 ] || exit 0
cd -- "$target_dir"
# exec preserves literal argv. Later nonzero game exits do not invalidate the build.
exec "$target" "$@"
