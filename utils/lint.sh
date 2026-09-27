#!/usr/bin/env bash

set -euo pipefail

base_ref=${1:?Usage: bash utils/lint.sh BASE_REF}
repo_root=$(git rev-parse --show-toplevel)
baseline_dir=$(mktemp -d)
trap 'rm -rf "$baseline_dir"' EXIT

# Keep existing violations in the base revision from blocking unrelated changes.
git archive "$base_ref" | tar -x -C "$baseline_dir"
(
    cd "$baseline_dir"
    swiftlint lint --strict --no-cache --write-baseline baseline.json > lint.log 2>&1 || {
        status=$?
        if [ "$status" -ne 2 ] || [ ! -s baseline.json ]; then
            cat lint.log
            exit "$status"
        fi
    }
)

python3 - "$baseline_dir" "$repo_root" <<'PY'
import json
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

baseline_dir = Path(sys.argv[1]).resolve()
repo_root = Path(sys.argv[2]).resolve()
baseline_path = baseline_dir / "baseline.json"
violations = json.loads(baseline_path.read_text())
for violation in violations:
    location = violation["violation"]["location"]
    file_path = Path(unquote(urlsplit(location["file"]).path)).resolve()
    location["file"] = (repo_root / file_path.relative_to(baseline_dir)).as_uri()
baseline_path.write_text(json.dumps(violations))
PY

cd "$repo_root"
swiftlint lint --strict --no-cache --baseline "$baseline_dir/baseline.json"
