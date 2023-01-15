#!/bin/bash

# -- get the info files
RUNNER_TOKEN=./data/RUNNER_TOKEN
RUNNER_SHA=./data/RUNNER_SHA
RUNNER_NAME=./data/RUNNER_NAME
RUNNER_DOWNLOAD_URL=./data/RUNNER_DOWNLOAD_URL
RUNNER_REPO=./data/RUNNER_REPO
RUNNER_LABELS=./data/RUNNER_LABELS
RUNNER_GROUP=./data/RUNNER_GROUP

# set up internal labels
INTERNAL_LABELS="self-hosted,macOS,ARM64"

# -- check if necessary files exist
# -- check if the contents are not empty
# -- if all pass, assign to variable
if [ -f "$RUNNER_TOKEN" ] && [ -s "$RUNNER_TOKEN" ]; then
    RUNNER_TOKEN=$(cat "$RUNNER_TOKEN")
else
    echo "RUNNER_TOKEN file is missing or empty. Exiting script."
    exit 1
fi

if [ -f "$RUNNER_SHA" ] && [ -s "$RUNNER_SHA" ]; then
    RUNNER_SHA=$(cat "$RUNNER_SHA")
else
    echo "RUNNER_SHA file is missing or empty. Exiting script."
    exit 1
fi

if [ -f "$RUNNER_NAME" ] && [ -s "$RUNNER_NAME" ]; then
    RUNNER_NAME=$(cat "$RUNNER_NAME")
else
    echo "RUNNER_NAME file is missing or empty. Exiting script."
    exit 1
fi

if [ -f "$RUNNER_DOWNLOAD_URL" ] && [ -s "$RUNNER_DOWNLOAD_URL" ]; then
    RUNNER_DOWNLOAD_URL=$(cat "$RUNNER_DOWNLOAD_URL")
else
    echo "RUNNER_DOWNLOAD_URL file is missing or empty. Exiting script."
    exit 1
fi

if [ -f "$RUNNER_REPO" ] && [ -s "$RUNNER_REPO" ]; then
    RUNNER_REPO=$(cat "$RUNNER_REPO")
else
    echo "RUNNER_REPO file is missing or empty. Exiting script."
    exit 1
fi

# -- only check if the labels exist, then use it if it is available
if [ -f "$RUNNER_LABELS" ]; then
    IFS=',' read -ra RUNNER_LABELS_ARRAY <<< "$(< "$RUNNER_LABELS")"
    IFS=',' read -ra INTERNAL_LABELS_ARRAY <<< "$INTERNAL_LABELS"
	UNIQUE_LABELS=$(echo "${INTERNAL_LABELS_ARRAY[@]} ${RUNNER_LABELS_ARRAY[@]}" | tr ' ' '\n' | sort | uniq | tr '\n' ',' | sed 's/,$//')
else
    UNIQUE_LABELS="$INTERNAL_LABELS"
fi

# -- only check if the group exist, then use it if it is available
if [ -f "$RUNNER_GROUP" ]; then
    RUNNER_GROUP="$(< "$RUNNER_GROUP")"
else
    RUNNER_GROUP="default"
fi


# -- download the GitHub action runner
curl -o actions-runner.tar.gz -L $RUNNER_DOWNLOAD_URL

# -- check the checksum
if [ "$(shasum -a 256 actions-runner.tar.gz | awk '{print $1}')" != "$RUNNER_SHA" ]; then
	echo "SHA checksum does not match, exiting script"
	exit 1
fi

# -- create the runner directory
mkdir -p ~/actions-runner

# -- extract the installer
tar xzf ./actions-runner.tar.gz --directory ~/actions-runner

# -- copy over the pre- and -post commands
cp pre-run.sh  ~/actions-runner
cp post-run.sh ~/actions-runner

# -- go to the runner directory
cd ~/actions-runner

# -- add the commands to the runner hooks
export ACTIONS_RUNNER_HOOK_JOB_STARTED=~/actions-runner/pre-run.sh
export ACTIONS_RUNNER_HOOK_JOB_COMPLETED=~/actions-runner/post-run.sh

./config.sh --url "$RUNNER_REPO" --ephemeral --replace --labels $UNIQUE_LABELS --name $RUNNER_NAME --runnergroup "$RUNNER_GROUP" --work _work --token $RUNNER_TOKEN

# Last step, run it!
./run.sh
