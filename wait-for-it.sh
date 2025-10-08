#!/usr/bin/env bash
#   Use this script to test if a given TCP host/port are available

cmdname=$(basename "$0")
echoerr() { if [[ $QUIET -ne 1 ]]; then echo "$@" 1>&2; fi }

usage() {
    cat << USAGE >&2
Usage:
    $cmdname host:port [-s] [-t timeout] [-- command args]
    -h HOST | --host=HOST       Host or IP
    -p PORT | --port=PORT       TCP port
    -s | --strict               Only execute subcommand if test succeeds
    -q | --quiet                Suppress status messages
    -t SECONDS | --timeout=SECONDS
    -- COMMAND ARGS             Run command after success
USAGE
    exit 1
}

wait_for() {
    if [[ $TIMEOUT -gt 0 ]]; then
        echoerr "$cmdname: waiting $TIMEOUT seconds for $HOST:$PORT"
    else
        echoerr "$cmdname: waiting for $HOST:$PORT without a timeout"
    fi
    local start_ts
    start_ts=$(date +%s)
    while :; do
        (echo > /dev/tcp/$HOST/$PORT) >/dev/null 2>&1 && break
        sleep 1
    done
    local end_ts
    end_ts=$(date +%s)
    echoerr "$cmdname: $HOST:$PORT is available after $((end_ts - start_ts)) seconds"
    return 0
}

wait_for_wrapper() {
    if [[ $QUIET -eq 1 ]]; then
        timeout "$TIMEOUT" "$0" --quiet --child --host="$HOST" --port="$PORT" --timeout="$TIMEOUT" &
    else
        timeout "$TIMEOUT" "$0" --child --host="$HOST" --port="$PORT" --timeout="$TIMEOUT" &
    fi
    PID=$!
    trap "kill -INT -$PID" INT
    wait $PID
    RESULT=$?
    if [[ $RESULT -ne 0 ]]; then
        echoerr "$cmdname: timeout after $TIMEOUT seconds waiting for $HOST:$PORT"
    fi
    return $RESULT
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        *:*)
            hostport=(${1//:/ })
            HOST=${hostport[0]}
            PORT=${hostport[1]}
            shift
            ;;
        --child) CHILD=1; shift ;;
        -q|--quiet) QUIET=1; shift ;;
        -s|--strict) STRICT=1; shift ;;
        -h) HOST="$2"; shift 2 ;;
        --host=*) HOST="${1#*=}"; shift ;;
        -p) PORT="$2"; shift 2 ;;
        --port=*) PORT="${1#*=}"; shift ;;
        -t) TIMEOUT="$2"; shift 2 ;;
        --timeout=*) TIMEOUT="${1#*=}"; shift ;;
        --) shift; CLI="$*"; break ;;
        --help) usage ;;
        *) echoerr "Unknown argument: $1"; usage ;;
    esac
done

[[ -z "$HOST" || -z "$PORT" ]] && { echoerr "Error: host and port required."; usage; }

TIMEOUT=${TIMEOUT:-15}
STRICT=${STRICT:-0}
CHILD=${CHILD:-0}
QUIET=${QUIET:-0}

if [[ $CHILD -gt 0 ]]; then
    wait_for
    exit $?
else
    if [[ $TIMEOUT -gt 0 ]]; then
        wait_for_wrapper
        RESULT=$?
    else
        wait_for
        RESULT=$?
    fi
fi

if [[ -n "$CLI" ]]; then
    if [[ $RESULT -ne 0 && $STRICT -eq 1 ]]; then
        echoerr "$cmdname: strict mode, refusing to execute subprocess"
        exit $RESULT
    fi
    exec $CLI
else
    exit $RESULT
fi
