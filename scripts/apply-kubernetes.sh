#!/usr/bin/env bash
# Usage: apply-kubernetes.sh [extra kubectl apply flags, e.g. --dry-run=server]
set -euo pipefail
cd "$(dirname "$0")/../kubernetes"

dec() { sops -d --input-type yaml --output-type yaml "$1"; }
kc() { kubectl --kubeconfig <(dec kubeconfig.enc) "$@"; }

dec secrets.enc.yaml | kc apply --server-side --force-conflicts "$@" -f -

# Only ${UPPER_CASE} placeholders are substituted (shell $VARS in manifests stay as-is); unset ones abort.
VARS=$(sops -d --output-type dotenv vars.enc.yaml) python3 -c '
import os, re, sys
v = dict(l.split("=", 1) for l in os.environ["VARS"].splitlines() if l)
def sub(m):
    if m[1] not in v: sys.exit(f"unset variable {m[1]}")
    return v[m[1]]
print("\n---\n".join(re.sub(r"\$\{([A-Z_]+)\}", sub, open(f).read()) for f in sys.argv[1:]))
' cloudrack/*.yaml homerack/*.yaml | kc apply --server-side --force-conflicts "$@" -f -
