#!/bin/zsh
# Runs the unit tests. With only the Command Line Tools installed, swift-testing lives
# outside the default search paths, so point the compiler and linker at it.
set -euo pipefail
cd "$(dirname "$0")/.."
DEV=$(xcode-select -p)
FRAMEWORKS="$DEV/Library/Developer/Frameworks"
LIBS="$DEV/Library/Developer/usr/lib"
if [[ -d "$FRAMEWORKS/Testing.framework" ]]; then
  exec swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$LIBS" "$@"
else
  exec swift test "$@"
fi
