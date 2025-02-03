#!/bin/bash

function main() {
  make dependencies
}

main "${@:-}" > >(tee "/forticom/results/.signal_ios_docker.log") 2>&1
