#!/usr/bin/env bats
# Copyright 2026 Copyright (c) 2026 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

export DPM_SDK_VERSION=${VERSION}
bats_require_minimum_version 1.5.0

@test "dpm version | works correctly" {
  run -0 dpm version
  run -0 dpm version --active

  [ "$output" = "${VERSION}" ]
}

platform_pwd() {
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]];
  then
    pwd -W | sed 's/\//\\/g'
  else
    pwd -P
  fi
}

decolour() {
  sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"
}

setup() {
  working_dir="$RUNNER_TEMP/working-dir"
  mkdir -p "$working_dir"
}

teardown() {
  rm -rf $working_dir
}

kill_and_wait() {
  local name=$1
  local process_id=$2

  if [[ -z "$process_id" ]]; then return 0; fi

  echo "OSTYPE is "$OSTYPE""

  case "$OSTYPE" in
    msys*|cygwin*|win32*)
      echo "Killing $name (Windows)" >&3

      if [[ -f "/proc/$process_id/winpid" ]]; then
        winpid=$(cat "/proc/$process_id/winpid")
      else
        winpid=$process_id
      fi

      # Use correct taskkill syntax
      taskkill //F //T //PID "$winpid" 2>/dev/null || \
      taskkill //F //PID "$winpid" 2>/dev/null
      ;;
    *)
      echo "Killing $name (Non-Windows)" >&3
      kill -INT "$process_id" 2>/dev/null || kill -TERM "$process_id"
      ;;
  esac

  while ps -p $process_id > /dev/null
  do
    sleep 1
    echo "Waiting for $name to die..." >&3
  done
  sleep 1
}

wait_for_output() {
  local handle=$1
  local expectation=$2
  echo "Waiting for \"$expectation\"" >&3
  until [[ "$output" == *"$expectation"* ]]
  do
    read -t 180 -r output <&"$handle"
    echo -e "$output" >&3
    output=$(echo $output | decolour)
  done
  echo "Found expectated output" >&3
}

write_to_input() {
  local handle=$1
  local message=$2
  echo "Writing $2 to output" >&3
  echo -e "$2" >&"$1"
}

@test "dpm sandbox | can be started" {
  coproc SANDBOX (dpm sandbox --debug)
  bats::on_failure() {
    kill_and_wait "Sandbox" $SANDBOX_PID
  }

  wait_for_output ${SANDBOX[0]} "Canton sandbox is ready."
  kill_and_wait "Sandbox" $SANDBOX_PID
}

@test "dpm canton-console | can connect to sandbox" {
  coproc SANDBOX (dpm sandbox --debug)
  bats::on_failure() {
    kill_and_wait "Sandbox" $SANDBOX_PID
  }

  wait_for_output ${SANDBOX[0]} "Canton sandbox is ready."

  coproc CONSOLE (dpm canton-console --no-tty)
  bats::on_failure() {
    write_to_input ${CONSOLE[1]} "exit\n"
    kill_and_wait "Canton Console" $CONSOLE_PID
  }

  wait_for_output ${CONSOLE[0]} "Type \`help\` to get started. \`exit\` to leave."
  write_to_input ${CONSOLE[1]} "sandbox.health.active\n"
  wait_for_output ${CONSOLE[0]} "res0: Boolean = true"

  write_to_input ${CONSOLE[1]} "exit\n"
  kill_and_wait "Canton Console" $CONSOLE_PID
  kill_and_wait "Sandbox" $SANDBOX_PID
}

setup_project() {
  local tmpdir=$(mktemp -d -p $working_dir)
  cd $tmpdir
  dpm new myproject --template multi-package-example
  cd myproject
  echo $tmpdir
}

@test "dpm new | can create and build skeleton" {
  setup_project
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    cmd //c tree
  fi
  run dpm build --all
  echo $status
  echo -e "$output"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    cmd //c tree
  fi

}

@test "dpm test | can run tests on default template" {
  setup_project
  cd main
  # Explicitly do not build test, as `dpm test` should not need it

  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    cmd //c tree
  fi
  run dpm build
  echo $status
  echo -e "$output"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    cmd //c tree
  fi

  cd ../test

  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    cmd //c tree
  fi
  run dpm test
  echo $status
  echo -e "$output"
  if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    cmd //c tree
  fi

  dpm test
}

@test "dpm script | can run tests on default template against ide-ledger" {
  setup_project
  dpm build --all
  cd test
  dpm script --dar .daml/dist/myproject-test-1.0.0.dar --ide-ledger --all
}

@test "dpm script | can run tests on default template against canton" {
  setup_project
  dpm build --all
  cd test
  coproc SANDBOX (dpm sandbox --debug)
  bats::on_failure() {
    kill_and_wait "Sandbox" $SANDBOX_PID
  }

  wait_for_output ${SANDBOX[0]} "Canton sandbox is ready."
  # If any tests fail, dpm script gives non-zero exit, so test will fail
  echo "Running script" >&3
  dpm script --dar .daml/dist/myproject-test-1.0.0.dar --ledger-host localhost --ledger-port 6865 --all --upload-dar=yes >&3
  echo "ran script, killing sandbox" >&3
  kill_and_wait "Sandbox" $SANDBOX_PID
}

# bats test_tags=no-3_4
@test "dpm codegen | generate java codegen and use it to connect to canton" {
  setup_project
  dpm build --all
  cd main
  dpm codegen-java -d com.daml.skeleton.test.TemplateDecoder -o target/generated-sources ./.daml/dist/myproject-main-1.0.0.dar=com.daml.skeleton.model
  cp -r $BATS_TEST_DIRNAME/java-codegen/* .
  # Find out the canton & daml version by reading `dpm resolve` and using the canton/damlc path
  canton_version=$(
    dpm resolve --output json | \
    DIR=$(platform_pwd) jq -r \
      '.Packages[env.DIR].Components
      | if has("canton-enterprise") then .["canton-enterprise"] else .["canton-open-source"] end
      | split("[\\\\/]";"")
      | .[-1]'
    )
  daml_version=$(dpm resolve --output json | DIR=$(platform_pwd) jq -r '.Packages[env.DIR].Components["damlc"] | split("[\\\\/]";"") | .[-1]')
  # Replace __BINDINGS_VERSION__ in `pom.xml`, so the correct bindings-java is pulled.
  if echo "$VERSION" | grep -q "^3\.4"; then
    # In 3.4, bindings was published from daml, afterwards it was published from canton
    bindings_version="$daml_version"
  else
    bindings_version="$canton_version"
  fi
  find . -name pom.xml -exec sed -i -e 's/__BINDINGS_VERSION__/'$bindings_version'/g' {} \;
  # Replace __DAML_VERSION__ in `pom.xml`, so the correct codegen-java is pulled.
  find . -name pom.xml -exec sed -i -e 's/__DAML_VERSION__/'$daml_version'/g' {} \;

  # Start up canton
  coproc SANDBOX (dpm sandbox --debug)
  bats::on_failure() {
    kill_and_wait "Sandbox" $SANDBOX_PID
  }
  wait_for_output ${SANDBOX[0]} "Canton sandbox is ready."

  # Upload the package
  curl --data-binary @.daml/dist/myproject-main-1.0.0.dar http://localhost:6864/v2/packages

  party=$(curl -d '{"partyIdHint":"Alice"}' http://localhost:6864/v2/parties | jq -r '.partyDetails.party')

  # Run the codegen
  mvn compile exec:java@run-skeleton-java -Dparty=$party >&3
  echo "Finished mvn" >&3

  kill_and_wait "Sandbox" $SANDBOX_PID
}

@test "dpm codegen | generate js codegen and use it to connect to canton" {
  setup_project
  dpm build --all
  cd main
  cp -r $BATS_TEST_DIRNAME/js-codegen/* .
  # Find out the daml version by reading `dpm resolve` and using the damlc path
  daml_version=$(dpm resolve --output json | DIR=$(platform_pwd) jq -r '.Packages[env.DIR].Components["damlc"] | split("[\\\\/]";"") | .[-1]')

  # Replace __DAML_VERSION__ in `package.json`, so the correct daml-types is pulled.
  find . -name *.json -exec sed -i -e 's/__DAML_VERSION__/'$daml_version'/g' {} \;
  dpm codegen-js -o js/js-generated ./.daml/dist/myproject-main-1.0.0.dar

  # Start up canton
  coproc SANDBOX (dpm sandbox --debug)
  bats::on_failure() {
    kill_and_wait "Sandbox" $SANDBOX_PID
  }
  wait_for_output ${SANDBOX[0]} "Canton sandbox is ready."

  # Upload the package
  curl --data-binary @.daml/dist/myproject-main-1.0.0.dar http://localhost:6864/v2/packages

  # Run the codegen
  cd js
  npm install >&3
  # Grab the openapi definition
  curl -o openapi.yaml http://localhost:6864/docs/openapi >&3
  npm run generate_api >&3
  npm run build >&3
  npm run test >&3

  echo "Finished npm" >&3

  kill_and_wait "Sandbox" $SANDBOX_PID
}

@test "dpm upgrade-check | Works with DAR from damlc" {
  setup_project
  dpm build --all
  cd main
  cp ./.daml/dist/myproject-main-1.0.0.dar ./v1.dar
  sed -i 's/name/renamed/g' daml/Main.daml
  sed -i 's/version: 1.0.0/version: 1.0.1/g' daml.yaml
  dpm build
  cp ./.daml/dist/myproject-main-1.0.1.dar ./v2.dar
  run -1 dpm upgrade-check --both ./v1.dar ./v2.dar
  # Participant failure
  echo -e "$output" | grep -q "NOT_VALID_UPGRADE_PACKAGE"
  # Compiler failure
  echo -e "$output" | grep -q "UpgradeCheckMain -- Error while checking two DARs"
}

@test "dpm pqs & shell | Can be queried for contract from skeleton" {
  skip "Failing because postgres is non-cooperative"
  setup_project
  dpm build --all
  cd main

  # Start up canton
  coproc SANDBOX (dpm sandbox --debug)
  bats::on_failure() {
    kill_and_wait "Sandbox" $SANDBOX_PID
  }
  wait_for_output ${SANDBOX[0]} "Canton sandbox is ready."

  # Upload the package
  curl --data-binary @.daml/dist/myproject-main-1.0.0.dar http://localhost:6864/v2/packages
  
  # Set up postgres
  initdb -D .pg >&3
  pg_ctl -D .pg -o "--unix_socket_directories=$PWD" -o "-F -p 5435" start >&3
  bats::on_failure() {
    pg_ctl -D .pg stop --mode=fast
    echo "failed!" >&3
  }
  createuser postgres -s -h localhost -p 5435 >&3

  # Run PQS
  coproc PQS (dpm pqs pipeline ledger postgres-document \
    --pipeline-ledger-start Oldest \
    --source-ledger-host localhost \
    --source-ledger-port 6865 \
    --target-postgres-host localhost \
    --target-postgres-port 5435 \
    --target-postgres-database postgres
  )
  bats::on_failure() {
    kill_and_wait "PQS" $PQS_PID
  }

  # Create a contract on the ledger, also gives time for PQS to boot up properly
  dpm script --dar ../test/.daml/dist/myproject-test-1.0.0.dar --ledger-host localhost --ledger-port 6865 --all >&3

  # Connect via shell, on -no-tty mode, as interacting with tty in bash is very difficult across all platforms
  coproc DAML_SHELL (dpm daml-shell --no-tty --postgres-host localhost --postgres-port 5435 --postgres-password postgres)
  bats::on_failure() {
    write_to_input ${DAML_SHELL[1]} "quit\n"
    kill_and_wait "Daml Shell" $DAML_SHELL_PID
  }

  # Query contract story
  write_to_input ${DAML_SHELL[1]} "active\n"
  wait_for_output ${DAML_SHELL[0]} "myproject-main:Main:Asset"

  # Shutdown everything
  write_to_input ${DAML_SHELL[1]} "quit\n"
  kill_and_wait "Daml Shell" $DAML_SHELL_PID
  kill_and_wait "PQS" $PQS_PID >&3
  kill_and_wait "Sandbox" $SANDBOX_PID >&3
  echo "Killing postgres" >&3
  pg_ctl -D .pg stop --mode=fast >&3 2>&1
  echo "Done" >&3
}
