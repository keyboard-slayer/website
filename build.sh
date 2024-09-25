#!/usr/bin/env bash

set -e

if [ -z "$CUTEKIT_PYTHON" ]; then
    export CUTEKIT_PYTHON="python3"
fi

if [ -z "$CUTEKIT_VERSION" ]; then
    export CUTEKIT_VERSION="stable"
fi

$CUTEKIT_PYTHON -m cutekit > /dev/null 2>/dev/null || {
    if [ ! -d "./.env" ]; then
        $CUTEKIT_PYTHON -m venv ./.env
        source ./.env/bin/activate
        $CUTEKIT_PYTHON -m pip install git+https://github.com/cute-engineering/cutekit.git@${CUTEKIT_VERSION} markdown
    else
        source ./.env/bin/activate
    fi
}

$CUTEKIT_PYTHON -m cutekit $@