#!/bin/bash

# Imports
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. "$script_dir/scripts/env_utils.sh"
. "$script_dir/scripts/sbv2_utils.sh"

verify_cli

