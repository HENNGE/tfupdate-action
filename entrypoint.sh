#!/bin/sh
#
# Copyright (c) 2019 Masayuki Morita
# Released under the MIT license
# https://github.com/minamijoyo/tfupdate/blob/master/LICENSE

set -e

function run_tfupdate {
  case ${INPUT_RESOURCE} in
    terraform)
      VERSION=$(tfupdate release latest hashicorp/terraform)
      PULL_REQUEST_BODY="For details see: https://github.com/hashicorp/terraform/releases"
      # Changing UPDATE_MESSAGE variable will cause issue in matching existing pull requests
      # Do not change unless absolutely necessary
      # ref. https://github.com/HENNGE/tfupdate-action/issues/25
      UPDATE_MESSAGE="[tfupdate] Bump Terraform to v${VERSION}"
      ;;

    provider)
      if [ ! ${INPUT_PROVIDER_NAME} ]; then
        echo 'ERROR: "provier_name" needs to be set for "provider" resource'
        exit 1
      fi
      REPOSITORY="hashicorp/terraform-provider-${INPUT_PROVIDER_NAME}"
      if [ -n "${INPUT_PROVIDER_REPO}" ]; then
        REPOSITORY=${INPUT_PROVIDER_REPO}
      fi
      VERSION=$(tfupdate release latest "$REPOSITORY")
      PULL_REQUEST_BODY="For details see: https://github.com/$REPOSITORY/releases"
      # Changing UPDATE_MESSAGE variable will cause issue in matching existing pull requests
      # Do not change unless absolutely necessary
      # ref. https://github.com/HENNGE/tfupdate-action/issues/25
      UPDATE_MESSAGE="[tfupdate] Bump Terraform Provider ${INPUT_PROVIDER_NAME} to v${VERSION}"
      ;;
    module)
      if ! [ ${INPUT_MODULE_NAME} ] || ! [ ${INPUT_SOURCE_TYPE} ]; then
        echo 'ERROR: both "module_name" and "source_type" need to be set for "module" resource'
        exit 1
      fi
      VERSION=$(tfupdate release latest --source-type=${INPUT_SOURCE_TYPE} ${INPUT_MODULE_NAME})
      # Changing UPDATE_MESSAGE variable will cause issue in matching existing pull requests
      # Do not change unless absolutely necessary
      # ref. https://github.com/HENNGE/tfupdate-action/issues/25
      UPDATE_MESSAGE="[tfupdate] Bump Terraform Module ${INPUT_MODULE_NAME} to v${VERSION}"
      case ${INPUT_SOURCE_TYPE} in
        github)
          PULL_REQUEST_BODY="For details see: https://github.com/${INPUT_MODULE_NAME}/releases"
          ;;
        gitlab)
          PULL_REQUEST_BODY="For details see: https://gitlab.com/${INPUT_MODULE_NAME}/releases"
          ;;
        tfregistryModule)
          PULL_REQUEST_BODY="For details see: https://registry.terraform.io/modules/${INPUT_MODULE_NAME}/${VERSION}"
          ;;
        *)
          echo "ERROR: unknown source type"
          exit 1
      esac
      ;;
    *)
      echo "ERROR: unknown resource"
      exit 1
      ;;
  esac

  # Set optional arguments
  ARGS="--version=${VERSION}"
  if [ ${INPUT_RECURSIVE} ]; then
    ARGS="${ARGS} --recursive=${INPUT_RECURSIVE}"
  fi
  if [ ${INPUT_IGNORE_PATH} ]; then
    ARGS="${ARGS} --ignore-path=${INPUT_IGNORE_PATH}"
  fi
  if [ ${INPUT_PROVIDER_NAME} ]; then
    ARGS="${ARGS} ${INPUT_PROVIDER_NAME}"
  fi
  if [ ${INPUT_MODULE_NAME} ]; then
    ARGS="${ARGS} ${INPUT_MODULE_NAME}"
  fi

  # Fix for https://github.com/HENNGE/tfupdate-action/issues/43
  git config --global --add safe.directory "$GITHUB_WORKSPACE"

  # Set github config
  git config --local user.email "${USER_EMAIL}"
  git config --local user.name "${USER_NAME}"

  # Checkout a branch if a PR does not exist.
  BRANCH_NAME="update-${INPUT_RESOURCE}-to-v${VERSION}"
  if [ -n "${INPUT_BRANCH_NAME_SUFFIX}" ]; then
    BRANCH_NAME="${BRANCH_NAME}_${INPUT_BRANCH_NAME_SUFFIX}"
  fi
  if [[ $(hub pr list -s "open" -h "${BRANCH_NAME}") ]]; then
    echo "A pull request already exists"
    exit 0
  elif [[ $(hub pr list -s "merged" -h "${BRANCH_NAME}") ]]; then
    echo "A pull request is already merged"
    exit 0
  elif [[ $(hub pr list -s "closed" -h "${BRANCH_NAME}") ]]; then
    echo "A pull request is already closed"
    exit 0
  else
    echo "Checking out to ${BRANCH_NAME} branch"
    git fetch --all
    git checkout -b "${BRANCH_NAME}" "origin/${INPUT_BASE_BRANCH}"
  fi

  # Execute tfupdate command
  COMMAND="${INPUT_RESOURCE} ${ARGS} ${INPUT_FILE_PATH}"
  echo "Running tfupdate ${COMMAND}"
  tfupdate ${COMMAND}

  # Send a pull reuqest agaist the base branch
  if git add . && git diff --cached --exit-code --quiet; then
    echo "No changes"
  else
    echo "Creating a pull request: ${UPDATE_MESSAGE}"
    git commit -m "${UPDATE_MESSAGE}"
    if [ ${INPUT_REVIEWER} ]; then
      hub pull-request -m "${UPDATE_MESSAGE}" -m "${PULL_REQUEST_BODY}" -b "${INPUT_BASE_BRANCH}" -l "${INPUT_LABEL}" -r "${INPUT_REVIEWER}" -p
    else
      hub pull-request -m "${UPDATE_MESSAGE}" -m "${PULL_REQUEST_BODY}" -b "${INPUT_BASE_BRANCH}" -l "${INPUT_LABEL}" -p
    fi
  fi
}

run_tfupdate
