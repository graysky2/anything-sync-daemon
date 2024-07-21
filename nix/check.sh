#!/bin/sh

set -eu

# shellcheck disable=SC2317
setup() {
    mkdir -p "$b"

    for f in "$@"; do
        p="${b}/${f}"
        mkdir -p "$(dirname "$p")"
        touch "$p"
    done
}

# shellcheck disable=SC2317
block() {
    [ -e "$b" ]
}

# shellcheck disable=SC2317
before() {
    rc=0

    for f in "$@"; do
        for d in "$x" "$v"; do
            p="${d}/${1?}"
            if ! [ -e "$p" ]; then
                printf 1>&2 -- 'expected "%s" to exist but it does not...\n' "$p"
                rc=1
            fi
        done
    done

    return "$rc"
}

# shellcheck disable=SC2317
after() {
    rc=0

    for f in "$@"; do
        p="${b}/${f}"

        if ! [ -e "$p" ]; then
            printf 1>&2 -- 'expected "%s" to exist but it does not...\n' "$p"
            rc=1
        fi

        p="${v}/${1?}"

        if [ -e "$p" ]; then
            printf 1>&2 -- 'expected "%s" *not* to exist but it does...\n' "$p"
            rc=1
        fi
    done

    return "$rc"
}

# shellcheck disable=SC2317
crash() {
    i=0

    for cr in "$x"-crashrecovery-*.tar.zstd; do
        if [ -f "$cr" ]; then
            i="$(( i + 1 ))"
        fi
    done

    if [ "$i" -eq "${BACKUP_LIMIT:-2}" ]; then
        return 0
    else
        printf 1>&2 -- 'Expected %s crash recovery files but found %d...\n' "${BACKUP_LIMIT:-2}" "$i"
        return 1
    fi
}

# shellcheck disable=SC2317
flag() {
    install -D /dev/null "${v}/.flagged"
}

# shellcheck disable=SC2317
flagged() {
    [ -e "${v}/.flagged" ]
}

# shellcheck disable=SC2317
unflag() {
    unlink "${v}/.flagged"
}

# shellcheck disable=SC2317
run_mount_helper() {
    mountpoint="${1?}"
    shift

    # If `SUDO_USER` is defined, this command is being run with `sudo` as an
    # unprivileged user, and we need to use `sudo` to run the mount helper.
    # Also check the effective user ID directly, in case this script is being
    # run without `sudo`.
    # shellcheck disable=SC3028
    if [ -n "${SUDO_USER:-}" ] || [ "${EUID:-$(id -u 2>/dev/null)}" != 0 ]; then
        do_sudo=yes
    fi

    # Don't bother unmounting if the target path is not a mountpoint.
    # Likewise, don't fail if the umount operation fails but the target path is
    # no longer a mountpoint -- this helps address potential race conditions
    # where something else (e.g. `asd` itself) has unmounted the target path.
    ! mountpoint -q "$mountpoint" ||  ${do_sudo:+sudo} asd-mount-helper -d "$mountpoint" "$@" || ! mountpoint -q "$mountpoint"
}

# shellcheck disable=SC2317
umountb() {
    run_mount_helper "$b" mountdownall
}

# shellcheck disable=SC2317
umountv() {
    run_mount_helper "$v" mountdownall
}

# shellcheck disable=SC2317
umountx() {
    run_mount_helper "$x" mountdownall
}

# shellcheck disable=SC3028
euid="${EUID:-$(id -u 2>/dev/null)}"
euid="${euid:-0}"

# shellcheck disable=SC3028
user="${USER:-$(id -un 2>/dev/null)}"
user="${user:-root}"

if [ "$euid" = 0 ]; then
    b=/var/lib/what-to-sync
    v="/run/asd/asd-${user}/${b}"
else
    b=~/what-to-sync
    v="${XDG_RUNTIME_DIR:-"/run/user/${euid}"}/asd/asd-${user}/${b}"
fi

x="${b%/*}/.${b##*/}-backup_asd"

case "$1" in
    setup|block|before|after|crash|flag|flagged|unflag|umountb|umountv|umountx)
        "$@"
        exit
        ;;
    '')
        printf 1>&2 -- 'No operation provided :(\n'
        ;;
    *)
        printf 1>&2 -- 'Unrecognized operation "%s" :(\n' "$1"
        ;;
esac

exit 1
