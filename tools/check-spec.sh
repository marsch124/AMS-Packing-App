#!/bin/bash
# The specification moves with What's new — his rule (4 Oct 2026): "every nit and
# nitty-bitty documented", so the app can be rewritten and hardened from docs/spec.
# The last commit that changed What's new (Releases.swift) must also change docs/spec/.
# Run by the TestFlight workflow before anything is built, and by the local ship script.
set -e
cd "$(dirname "$0")/.."
last=$(git log -1 --format=%H -- App/Sources/Guide/Releases.swift)
if [ -z "$last" ]; then echo "spec: no What's new change in reach — nothing to check"; exit 0; fi
if git show --name-only --format= "$last" | grep -q '^docs/spec/'; then
  echo "spec: moved with What's new (${last:0:7})"; exit 0
fi
echo "::error::What's new changed in ${last:0:7} without docs/spec — update the specification in the same commit"
exit 1
