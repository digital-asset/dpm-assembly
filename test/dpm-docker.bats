#!/usr/bin/env bats
# Copyright 2026 Copyright (c) 2026 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

version="${VERSION:-"3.5.2"}"
image_name="europe-docker.pkg.dev/da-images/public-all/docker/sdk:${version}"
cmd="docker run --read-only --rm $image_name"
cmd_with_mount="docker run --read-only --mount type=tmpfs,destination=/tmp,tmpfs-size=10M --rm $image_name"

setup() {
#    bats_load_library bats-support
#    bats_load_library bats-assert
    # Optional setup function runs before each test.
    # We can ensure a basic image exists before all tests run.
    docker pull "${image_name}" > /dev/null 2>&1
}

@test "$cmd help | works correctly" {
    run $cmd help

    [ "$status" -eq 0 ]
}

@test "$cmd versions | produces expected output" {
    run $cmd versions

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"${version}"* ]]
}

@test "$cmd versions --active | produces expected output" {
    run $cmd versions --active

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"${version}"* ]]
}

@test "$cmd versions --help | produces expected output" {
    run $cmd versions --help

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "show sdk versions" ]
}

@test "$cmd versions --all | produces expected output" {
    run $cmd versions --all

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"${version}"* ]]
}

@test "$cmd versions --output json | produces expected output" {
    run $cmd versions --output json

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"\"version\": \"${version}\""* ]]
}

@test "$cmd versions --output table | produces expected output" {
    run $cmd versions --output table

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"${version}"* ]]
}

@test "$cmd version | produces expected output" {
    run $cmd version

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "$output" == *"${version}"* ]]
}

@test "$cmd_with_mount --version | produces expected output" {
    run $cmd_with_mount --version

    # Assertions about the command's execution
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"version:"* ]]
    [[ "${lines[1]}" == *"build:"* ]]
    [[ "${lines[2]}" == *"buildDate:"* ]]
}


@test "$cmd_with_mount non_existent_command | returns specific exit status" {
    run $cmd_with_mount non_existent_command

    # The container command fails, so the 'docker run' command should return a non-zero status
    [ "$status" -ne 0 ]
    # The error message should appear in the output
    [ "${lines[0]}" = "Error: unknown command \"non_existent_command\" for \"dpm\"" ]
}


@test "$cmd_with_mount install <version> | fails in read-only container" {
    run $cmd_with_mount install "${version}"

    [ "$status" -ne 0 ]
}

@test "$cmd_with_mount install | fails with missing version argument" {
    run $cmd_with_mount install

    [ "$status" -ne 0 ]
}

@test "$cmd_with_mount uninstall | fails with missing version argument" {
    run $cmd_with_mount uninstall

    [ "$status" -ne 0 ]
}

