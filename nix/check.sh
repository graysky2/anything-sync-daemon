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
    setup|before|after|crash)
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
