function fail() {
    echo "$1"
    exit 1
}

function assertFileExists() {
    if [[ ! -f "$1" ]]; then
        fail "Expected $1 to exist but it was not found."
    fi
}

function assertFileDoesntExist() {
    if [[ -e "$1" ]]; then
        fail "Expected $1 not to exist but it does."
    fi
}

function assertFileIsExecutable() {
    if [[ ! -x "$1" ]]; then
        fail "Expected $1 to be executable but it was not."
    fi
}

function assertEmacsParse() {
    assertFileExists "$1"
    assertFileIsExecutable "$hp/bin/emacs"
    if ! "$hp/bin/emacs" --batch --eval "(with-temp-buffer (insert-file-contents \"$1\") (goto-char (point-min)) (read (current-buffer)))"; then
        fail "Expected $1 to be parseable by emacs but it was not."
    fi
}

function assertFileContains() {
    if ! grep -qF "$2" "$1"; then
        fail "Expected $1 to contain $2 but it did not."
    fi
}

function assertFileDoesntContain() {
    if grep -qF "$2" "$1"; then
        fail "Expected $1 not to contain $2 but it did."
    fi
}
