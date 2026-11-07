#!/usr/bin/env bash

test_description='External clipboard commands'
cd "$(dirname "$0")" || exit 1
. ./setup.sh

export CLIP_CAPTURE="$PWD/copied" CLIP_STATUS=0
mkdir -p "$PWD/helpers with spaces"
helper="$PWD/helpers with spaces/copy-password"
cat > "$helper" <<'HELPER'
#!/bin/sh
[ "$#" -eq 0 ] || exit 99
cat > "$CLIP_CAPTURE"
echo helper-stdout
echo helper-stderr >&2
exit "${CLIP_STATUS:-0}"
HELPER
chmod +x "$helper"
export PATH="${helper%/*}:$PATH"

# Include shell metacharacters, leading/trailing whitespace, and backslashes.
printf '%s' '  -n $HOME `uname` ; "quotes" \\  ' > expected
printf '%s\n' "$(cat expected)" 'second line' > entry

test_expect_success 'Initialize multiline password' '
	"$PASS" init "$KEY1" &&
	"$PASS" insert -m entry < entry
'

test_expect_success 'Implicit show sends exact bytes and suppresses helper stdout' '
	"$PASS" --clip-command "$helper" entry > output 2> errors &&
	cmp expected "$CLIP_CAPTURE" &&
	grep -q "Copied entry to clipboard using external command." output &&
	! grep -q helper-stdout output &&
	! grep -q "Will clear" output &&
	grep -q helper-stderr errors
'

test_expect_success 'Explicit show resolves PATH and supports both option orders' '
	printf %s "second line" > second &&
	"$PASS" show --clip=2 --clip-command=copy-password entry &&
	cmp second "$CLIP_CAPTURE" &&
	"$PASS" show --clip-command copy-password -c2 entry &&
	cmp second "$CLIP_CAPTURE"
'

test_expect_success 'Generate copies the saved password without a newline' '
	"$PASS" generate --clip-command "$helper" generated 24 &&
	printf %s "$("$PASS" show generated)" > generated-expected &&
	test "$(wc -c < generated-expected)" -eq 24 &&
	cmp generated-expected "$CLIP_CAPTURE"
'

test_expect_success 'Invalid helpers fail before changing the store' '
	for invalid in "" missing-clipboard-command "$PWD/not-executable" "$PWD"; do
		: > "$PWD/not-executable" &&
		test_must_fail "$PASS" generate --clip-command "$invalid" invalid 20 || return 1
	done &&
	test ! -e "$PASSWORD_STORE_DIR/invalid.gpg" &&
	test_must_fail "$PASS" show --clip-command entry &&
	test_must_fail "$PASS" generate --clip-command
'

test_expect_success 'QR code conflicts fail before generation' '
	test_must_fail "$PASS" show -q --clip-command "$helper" entry &&
	test_must_fail "$PASS" generate -q --clip-command "$helper" conflict 20 &&
	test ! -e "$PASSWORD_STORE_DIR/conflict.gpg"
'

test_expect_success 'Helper failures do not report success or fall back' '
	test_must_fail env CLIP_STATUS=7 DISPLAY= WAYLAND_DISPLAY= "$PASS" show --clip-command "$helper" entry > output 2> errors &&
	! grep -q Copied output &&
	grep -q "External clipboard command failed" errors &&
	! grep -q "No X11" errors
'

test_expect_success 'Generated password survives clipboard failure' '
	test_must_fail env CLIP_STATUS=7 "$PASS" generate --clip-command "$helper" saved 20 &&
	printf %s "$("$PASS" show saved)" > saved-expected &&
	test "$(wc -c < saved-expected)" -eq 20 &&
	cmp saved-expected "$CLIP_CAPTURE"
'

test_expect_success 'Default dispatcher respects a platform clip override' '
	sed "/^PROGRAM=/,\$d" "$PASS" > functions.sh &&
	(
		. ./functions.sh
		clip() { printf "%s:%s" "$1" "$2"; }
		clip_command=""
		test "$(copy_to_clipboard secret entry)" = secret:entry
	)
'

cat > "${helper%/*}/wl-copy" <<'HELPER'
#!/bin/sh
printf '%s\n' "$@" > "$CLIP_CAPTURE.args"
cat > "$CLIP_CAPTURE"
exit "${CLIP_STATUS:-0}"
HELPER
chmod +x "${helper%/*}/wl-copy"
template="$TEST_HOME/../contrib/clipboard/pass-clip-template.sh"

test_expect_success 'Template forwards stdin, options, and exit status' '
	printf "%s\n" --type text/plain --sensitive > expected-args &&
	"$template" < expected &&
	cmp expected "$CLIP_CAPTURE" &&
	cmp expected-args "$CLIP_CAPTURE.args" &&
	(env CLIP_STATUS=7 "$template" < expected; test "$?" -eq 7)
'

test_expect_success 'Bash completion offers the option and helper paths' '
	(
		. "$TEST_HOME/../src/completion/pass.bash-completion"
		COMP_WORDS=(pass --clip-com); COMP_CWORD=1
		_pass &&
		[[ " ${COMPREPLY[*]} " == *" --clip-command "* ]] &&
		COMP_WORDS=(pass show --clip-command "${helper%/*}/copy-"); COMP_CWORD=3
		_pass &&
		[[ " ${COMPREPLY[*]} " == *" $helper "* ]] &&
		COMP_WORDS=(pass show --clip-command = "${helper%/*}/copy-"); COMP_CWORD=4
		_pass &&
		[[ " ${COMPREPLY[*]} " == *" $helper "* ]]
	)
'

test_done
