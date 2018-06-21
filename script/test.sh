#!/usr/bin/env bash

set -e

if [ -z "$QUIET" ]; then
	set -x
fi

git config --global credential.helper store
echo "https://${GITHUB_USERNAME}:${GITHUB_PASSWORD}@github.com" > ~/.git-credentials

if [ -n "$QUIET" ]; then
	bundle install > /dev/null
else
	bundle install
fi

TEST_FLAGS=""
if [ -z "$VERBOSE" ]; then
	TEST_FLAGS="-v"
fi

if [ -z "$RUN_TEST" ]; then
	echo "Running all tests"
	bundle exec rake clean compile:netlify_redirector test $TEST_FLAGS
else
	echo "Running tests in $RUN_TEST"
	bundle exec rake clean compile:netlify_redirector test $TEST_FLAGS "$RUN_TEST"
fi
