#!/bin/bash

set -e -x -o pipefail

dub test
dub run --root=test
