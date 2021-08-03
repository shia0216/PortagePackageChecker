#!/bin/bash -ue

API='https://slack.com/api/chat.postMessage'
TOKEN="$(cat .token)"
CHANNEL="$(cat .channel)"
HEADER='Content-type: application/json'
AUTH="Authorization: Bearer ${TOKEN}"
OLD_FILE='old_result.txt'
NEW_FILE='new_result.txt'
DIFF_FILE='diff.txt'

SUMMARY=$(emerge -pv -uDN --with-bdeps=y @world 2>&1 \
	| grep -v -E "Calculating dependencies.*done!" \
	| tee "${NEW_FILE}" \
	| grep 'Total'
)

# Post a updatable package summary, and store the post message ts
THREAD=$(grep -q 'Total: 0 packages, Size of downloads: 0 KiB' "${NEW_FILE}" \
	|| diff -U 0 "${OLD_FILE}" "${NEW_FILE}" >${DIFF_FILE} \
	|| curl -sS -X POST -H "${HEADER}" -H "${AUTH}" "${API}" \
		--data "{'channel': '${CHANNEL}', 'text': 'Host: $(hostname -f)\n${SUMMARY}'}" \
	| grep -o -E '"ts":"[0-9.]+"' \
	| head -n 1 \
	| cut -d ':' -f 2 \
	| tr -d '"'
)

# Post a updatable package list as the thread
test -z ${THREAD} \
	|| curl -sS -o /dev/null -X POST -H "${HEADER}" -H "${AUTH}" "${API}" \
		--data "{'channel': '${CHANNEL}', 'thread_ts': '${THREAD}', 'text': '$(cat ${DIFF_FILE})'}"

mv "${NEW_FILE}" "${OLD_FILE}"
