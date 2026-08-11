#!/usr/bin/env bash

command="${1:-}"
if [ "$#" -gt 0 ]; then shift; fi

case "$command" in
bootstrap-secrets) bootstrap_secrets_cmd "$@" ;;
render) render_cmd "$@" ;;
watch) watch_cmd "$@" ;;
-h | --help | "") usage ;;
*)
    echo "unknown command: $command" >&2
    usage >&2
    exit 2
    ;;
esac
