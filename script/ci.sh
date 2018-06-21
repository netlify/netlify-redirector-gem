#!/usr/bin/env bash

set -e

: ${RUBY_VERSION:="2.5.1"}
DOCKER_IMAGE="netlify/redirector:${RUBY_VERSION}"
GEM_CACHE="gem_cache_${RUBY_VERSION}"

while getopts dq FLAG; do
	case "$FLAG" in
		q)
			QUIET=1
			;;
		v)
			VERBOSE=1
			;;
		*)
			;;
	esac
done

shift $((OPTIND - 1))

if [ -z $QUIET ]; then
	set -x
fi

function init_gem_cache {
	docker volume inspect $GEM_CACHE &> /dev/null || docker volume create --name $GEM_CACHE
}

if [ "$QUIET" ]; then
	init_gem_cache > /dev/null
else
	init_gem_cache
fi

docker run \
	--workdir /redirector \
	--volume $(pwd):/redirector \
	--volume $GEM_CACHE:/usr/local/bundle \
	--env RUN_TEST="$RUN_TEST" \
	--env QUIET="$QUIET" \
	--env GITHUB_USERNAME \
	--env GITHUB_PASSWORD \
	--env VERBOSE \
	--env TESTOPTS \
	--rm \
	$DOCKER_IMAGE script/test.sh
