#!/usr/bin/env bash
# Run as your admin user (not the Terraform service account):
#   PREFIX=d-fyi-lz ./test_guardrails.sh
# Each "expect deny" test passes only if GCP refuses the action.

set -uo pipefail   # no -e: several commands are SUPPOSED to fail

PREFIX="${PREFIX:?set PREFIX, e.g. PREFIX=d-fyi-lz}"
REGION="${REGION:-europe-west2}"
ZONE="${ZONE:-europe-west2-a}"
PROD="${PREFIX}-prod-app"
HOST="${PREFIX}-net-host"
SEC="${PREFIX}-common-sec"
SUBNET="projects/${HOST}/regions/${REGION}/subnetworks/prod-subnet"
TEST_SA="test-sa@${PROD}.iam.gserviceaccount.com"
LOG="guardrail-results-$(date +%Y%m%d-%H%M%S).log"

PASS=0; FAIL=0
STEP_TIMEOUT="${STEP_TIMEOUT:-240}"   # seconds before any single step is abandoned
export CLOUDSDK_CORE_DISABLE_PROMPTS=1 # gcloud must never wait for a y/N answer
# macOS has no `timeout` unless coreutils is installed (gtimeout); fall back to none.
if ! command -v timeout >/dev/null; then
  if command -v gtimeout >/dev/null; then timeout() { gtimeout "$@"; }
  else timeout() { shift; "$@"; }; fi
fi
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red()   { printf '\033[31m%s\033[0m\n' "$*"; }
note()  { printf '\n\033[1m== %s\033[0m\n' "$*" | tee -a "$LOG"; }

# run cmd args... : no stdin (so nothing can sit on a hidden prompt) and a time limit.
run() {
  if declare -F "$1" >/dev/null; then "$@" </dev/null   # shell function: it sets its own timeouts
  else timeout "$STEP_TIMEOUT" "$@" </dev/null; fi
}

# step "description" cmd args... : shows progress, runs, logs. Sets OUT and RC.
step() {
  local desc="$1"; shift
  printf '      ... %s (%s)\n' "$desc" "$(date +%H:%M:%S)"
  OUT=$(run "$@" 2>&1); RC=$?
  printf '%s\n%s\n[exit %s]\n' "\$ $*" "$OUT" "$RC" >> "$LOG"
  [[ $RC -eq 124 ]] && OUT="TIMED OUT after ${STEP_TIMEOUT}s"$'\n'"$OUT"
}

# expect_deny "description" cmd args...  -> PASS if GCP refuses the command
expect_deny() {
  local desc="$1"; shift
  step "$desc" "$@"
  if [[ $RC -eq 0 ]]; then
    red "FAIL  $desc (command was allowed)"; FAIL=$((FAIL+1))
  elif [[ $RC -eq 124 ]]; then
    red "FAIL  $desc (timed out)"; FAIL=$((FAIL+1))
  else
    green "PASS  $desc (denied)"; PASS=$((PASS+1))
    echo "$OUT" | grep -m1 -iE 'constraint|policy|denied|prohibited' | sed 's/^/      /'
  fi
}

# expect_ok "description" cmd args...  -> PASS if the command succeeds
expect_ok() {
  local desc="$1"; shift
  step "$desc" "$@"
  if [[ $RC -eq 0 ]]; then
    green "PASS  $desc"; PASS=$((PASS+1))
  else
    red "FAIL  $desc"; FAIL=$((FAIL+1))
    echo "$OUT" | tail -n 4 | sed 's/^/      /'
  fi
}

# expect_output "description" cmd args... -> PASS if the command prints something
expect_output() {
  local desc="$1"; shift
  step "$desc" "$@"
  if [[ $RC -eq 0 && -n "$OUT" ]]; then
    green "PASS  $desc"; PASS=$((PASS+1))
  else
    red "FAIL  $desc (no entries yet; logs can lag a few minutes)"; FAIL=$((FAIL+1))
  fi
}

# Remove anything the tests created, even if the script is interrupted.
cleanup() {
  note "Cleanup"
  gcloud compute instances delete t1 --project="$PROD" --zone="$ZONE" --quiet >/dev/null 2>&1
  gcloud iam service-accounts delete "$TEST_SA" --project="$PROD" --quiet >/dev/null 2>&1
  gcloud storage rm "gs://${PREFIX}-us-test" --recursive >/dev/null 2>&1
  gcloud storage rm "gs://${PREFIX}-prod-data/hello.txt" >/dev/null 2>&1
  echo "done (full output in $LOG)"
}
trap cleanup EXIT

echo "Testing guardrails for prefix '$PREFIX' as $(gcloud config get-value account 2>/dev/null)"

note "1. No service account keys"
expect_ok   "create test service account" \
  gcloud iam service-accounts create test-sa --project="$PROD"
expect_deny "create service account key" \
  gcloud iam service-accounts keys create /tmp/key.json --iam-account="$TEST_SA"
rm -f /tmp/key.json

note "2. Data residency"
expect_deny "create bucket in us-central1" \
  gcloud storage buckets create "gs://${PREFIX}-us-test" --location=us-central1 --project="$PROD"

note "3. No public IPs"
expect_deny "create VM with external IP" \
  gcloud compute instances create t1 --project="$PROD" --zone="$ZONE" \
    --machine-type=e2-micro --subnet="$SUBNET"
expect_ok   "create VM without external IP" \
  gcloud compute instances create t1 --project="$PROD" --zone="$ZONE" \
    --machine-type=e2-micro --subnet="$SUBNET" --no-address
# Create gcloud's SSH key up front so ssh-keygen never waits on a hidden prompt.
[[ -f ~/.ssh/google_compute_engine ]] || ssh-keygen -t rsa -f ~/.ssh/google_compute_engine -N "" -q
echo "      waiting 45s for the VM to boot..."; sleep 45
# Retry: sshd may not be ready yet. timeout stops a hung tunnel from blocking the script.
ssh_iap() {
  local i
  for i in 1 2 3; do
    timeout 90 gcloud compute ssh t1 --project="$PROD" --zone="$ZONE" --tunnel-through-iap \
      --quiet --strict-host-key-checking=no \
      --ssh-flag="-o ConnectTimeout=20" --ssh-flag="-o BatchMode=yes" \
      --command="echo connected via IAP" && return 0
    echo "      SSH attempt $i failed, retrying in 20s..." >&2; sleep 20
  done
  return 1
}
expect_ok   "SSH through IAP" ssh_iap
expect_ok   "delete VM" \
  gcloud compute instances delete t1 --project="$PROD" --zone="$ZONE" --quiet

note "4. Central audit trail"
expect_output "audit entries in org-audit bucket" \
  gcloud logging read 'logName:"cloudaudit.googleapis.com"' --project="$SEC" \
    --bucket=org-audit --location="$REGION" --view=_AllLogs --limit=10 --freshness=1h

note "5. VPC Service Controls perimeter (dry run)"
expect_ok   "copy to prod bucket (allowed in dry run)" \
  bash -c "echo hello | gcloud storage cp - gs://${PREFIX}-prod-data/hello.txt"
echo "      waiting 60s for the dry-run violation to be logged..."; sleep 60
expect_output "dry-run violation logged" \
  gcloud logging read 'protoPayload.metadata.dryRun=true' --project="$PROD" --limit=5 --freshness=1h

note "Summary"
echo "Passed: $PASS   Failed: $FAIL" | tee -a "$LOG"
[[ $FAIL -eq 0 ]]
