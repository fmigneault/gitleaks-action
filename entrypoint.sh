#!/bin/bash -l

set -e # Abort script at first error
set -u # nounset - Attempt to use undefined variable outputs error message, and forces an exit
# set -x # verbose (expands commands)

echo "GITHUB_EVENT_NAME: ${GITHUB_EVENT_NAME}"
echo "GITHUB_SHA:        ${GITHUB_SHA}"
echo "GITHUB_REF:        ${GITHUB_REF}"
echo "GITHUB_HEAD_REF:   ${GITHUB_HEAD_REF}"
echo "GITHUB_BASE_REF:   ${GITHUB_BASE_REF}"

cd "$GITHUB_WORKSPACE"
git fetch --quiet

if [[ "${GITHUB_EVENT_NAME}" == "pull_request" ]]
then
    # scan only new commits contained within the PR
    GITHUB_HEAD_SHA=$(git rev-parse "origin/${GITHUB_HEAD_REF}")
    GITHUB_BASE_SHA=$(git rev-parse "origin/${GITHUB_BASE_REF}")

    # when PR refers to a merge commit, we need to tweak values
    # scan github reference for final 'merge' in 'refs/pull/<pr-id>/merge'
    GITHUB_REF_NAME="$(echo ${GITHUB_REF} | cut -d '/' -f4)"
    (set -o xtrace;
    if [[ "${GITHUB_REF_NAME}" == "merge" ]]
    then
        # 'merge' PR trigger
        # commits between source and destination branches are inverted (flip commit-to/from)
        gitleaks -v --exclude-forks --redact --threads=1 \
            --commit-from=${GITHUB_HEAD_SHA} \
            --commit-to=${GITHUB_BASE_SHA} \
            --repo-path=/repo
    else
        # 'normal' PR trigger, such as when the job to test new commits is re-run
        gitleaks -v --exclude-forks --redact --threads=1 \
          --commit-to=${GITHUB_HEAD_SHA} \
          --commit-from=${GITHUB_BASE_SHA} \
          --repo-path=${GITHUB_WORKSPACE}
    fi
    )
else
    # branch/tag name in the form "refs/<ref-type>/<ref-id>[/<ref-subtype>]"
    # ref-type: heads|pull|tags
    GITHUB_REF_NAME="$(echo ${GITHUB_REF} | cut -d '/' -f3)"
    # run only from current to master instead of full history
    GITHUB_REF_MASTER=$(git rev-parse 'origin/master')

    (set -o xtrace;
    if [[ "${GITHUB_REF_NAME}" == "master" ]]
    then
        # push to master (eg: for tagged versioning), only scan the last commit
        gitleaks -v --exclude-forks --redact --threads=1 \
          --branch=${GITHUB_REF_NAME} \
          --depth=1 \
          --repo-path=${GITHUB_WORKSPACE}
    else
        gitleaks -v --exclude-forks --redact --threads=1 \
          --branch=${GITHUB_REF_NAME} \
          --commit-to=${GITHUB_REF_MASTER} \
          --repo-path=${GITHUB_WORKSPACE}
    fi
    )
fi

