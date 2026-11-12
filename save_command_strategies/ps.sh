#!/usr/bin/env bash

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PANE_PID="$1"

exit_safely_if_empty_ppid() {
	if [ -z "$PANE_PID" ]; then
		exit 0
	fi
}

# save.sh scans the process table once per save and passes the result in
# RESURRECT_PS_SNAPSHOT. Scanning it again for every pane is very slow with
# many panes (on macOS a scan can take seconds). Without the snapshot (script
# run on its own) fall back to a fresh scan.
process_list() {
	if [ -r "$RESURRECT_PS_SNAPSHOT" ]; then
		cat "$RESURRECT_PS_SNAPSHOT"
	else
		ps -ao "ppid,args"
	fi
}

# Exact match on the parent pid: a prefix match would also pick the children
# of any pid that merely starts with the same digits.
full_command() {
	process_list |
		sed "s/^ *//" |
		grep "^${PANE_PID} " |
		cut -d' ' -f2-
}

main() {
	exit_safely_if_empty_ppid
	full_command
}
main
