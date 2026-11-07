#!/bin/sh
# Example external clipboard helper for pass (requires wl-clipboard).
# Copy this file, make it executable, and customize the backend below:
#   pass --clip-command /path/to/copy-password entry
#
# Contract:
# - Read the password from stdin, without expecting a trailing newline.
# - No positional arguments or additional metadata are supplied.
# - Exit zero once copying succeeds; exit nonzero on failure.
# - stdout is discarded by pass; send diagnostics to stderr.
# - Own the clipboard lifecycle, including any background ownership, delayed
#   clearing, or restoration. pass waits for this script to exit and does not
#   apply PASSWORD_STORE_CLIP_TIME to it.
#
# Customize this invocation for your clipboard tool. Forward stdin directly:
# do not put the password in command-line arguments or diagnostic output.
# wl-copy backgrounds its clipboard owner by default. This example does NOT
# schedule automatic clearing; implement that policy here if desired.
exec wl-copy --type text/plain --sensitive
