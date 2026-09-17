#!/usr/bin/env bash
# Usage: apply-talos.sh controlplane|worker [--apply]
set -euo pipefail
cd "$(dirname "$0")/../talos"

case "${1:-}" in
    controlplane) name=cloudrack ;;
    worker) name=homerack ;;
    *) echo "usage: $0 controlplane|worker [--apply]" >&2; exit 2 ;;
esac

dec() { sops -d --input-type yaml --output-type yaml "$1"; }
# ponytail: node IP comes from the Kubernetes API; if it is down, run talosctl -n <ip> by hand.
node=$(kubectl --kubeconfig <(dec ../kubernetes/kubeconfig.enc) get node "$name" \
    -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' | cut -d' ' -f1)
tc() { talosctl --talosconfig <(dec talosconfig.enc) -n "$node" "$@"; }

# The dry-run diff contains secret values, so only its verdict is printed.
out=$(tc apply-config --dry-run -f <(dec "$1.enc.yaml") 2>&1) || { echo "$name: dry-run failed" >&2; exit 1; }
if grep -q 'No changes' <<<"$out"; then echo "$name: no changes"; exit 0; fi
echo "$name: config differs"
if [ "${2:-}" = --apply ]; then tc apply-config --mode=no-reboot -f <(dec "$1.enc.yaml"); fi
