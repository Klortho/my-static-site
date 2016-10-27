#!/bin/bash
# This is a smoke test of the current default branch on GitHub
#
# Usage:
#
#   ./functional-test.sh [clean]
#
# If you give the `clean` argument, it simply clean up processes and temp
# files, but does not run a new test.

REPO_TO_TEST='https://github.com/Klortho/try-gitbook.git'
STATIC_SERVER_PORT=9995
GITBOOK_SERVER_PORT=9996

set -o errexit
set -o pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# test_clean kills any running server created earlier, and erases the test
# directory
function test_clean() {
  # Kill the servers, if they are running
  GITBOOK_SERVER_PID=$( ps | grep 'gitbook' | grep -v grep | cut -d' ' -f1 )
  if [ x"$GITBOOK_SERVER_PID" != x ]; then
    echo "Killing old gitbook server at PID=$GITBOOK_SERVER_PID"
    kill -9 $GITBOOK_SERVER_PID
  else
    echo "Nothing to kill here"
  fi

  STATIC_SERVER_PID=$( ps | grep 'safe-http' | grep $STATIC_SERVER_PORT | \
    grep -v grep | cut -d' ' -f1 )
  if [ x"$STATIC_SERVER_PID" != x ]; then
    echo "Killing old static server at PID=$STATIC_SERVER_PID"
    kill -9 $STATIC_SERVER_PID
  else
    echo "Nothing to kill here"
  fi

  # Remove any old temp directories
  echo "Removing $DIR/.test.*"
  rm -rfv "$DIR/.test."*
}

# Clean up any old files. If `clean` was given, that's all we'll do
test_clean
if [ x"$1" == xclean ]; then
  exit 0
fi

TEST_DIR=`mktemp -d "$DIR/.test.XXXXX"` || exit 1
echo "Testing directory: $TEST_DIR"

# Starting from a fresh clone, build and test
git clone $REPO_TO_TEST $TEST_DIR
cd $TEST_DIR
  npm install
  npm link gitbook-plugin-theme-ncbi
  gitbook install
  gitbook build
  echo "Starting safe-http-server on port $STATIC_SERVER_PORT"
  nohup $(cd _book && safe-http-server -p $STATIC_SERVER_PORT) &
  echo "Starting gitbook server on port $GITBOOK_SERVER_PORT"
  nohup gitbook serve --port $GITBOOK_SERVER_PORT &
  echo "Wait for it ...."
  sleep 10
  echo "Verify the page looks good on both $STATIC_SERVER_PORT and " \
    "$GITBOOK_SERVER_PORT"
  open "http://localhost:$STATIC_SERVER_PORT/"
  open "http://localhost:$GITBOOK_SERVER_PORT/"
cd ..

