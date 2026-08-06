#!/usr/bin/env bash
# Onchain Bridges - required pre-merge secret scan (Code-Provenance-Audit).
# Blocks a merge if a real secret appears in tracked files. High-PRECISION rules
# (few false positives) so the gate stays trusted and is not bypassed.
#
# Fail-closed: a built-in self-test must detect a canary secret; if the regex
# engine is broken, the scan FAILS rather than passing silently.
#
# Usage: bash scripts/secret-scan-ci.sh [root_dir]
set -uo pipefail
ROOT="${1:-.}"
cd "$ROOT" || { echo "::error::cannot cd to $ROOT"; exit 2; }

# Files that legitimately contain pattern *text* (this scanner, its config, the
# workflow) - exclude so the gate does not flag itself. Lockfiles too (noise).
EXCLUDE_RE='(^|/)(secret-scan-ci\.sh|\.gitleaks\.toml|secret-scan\.yml|package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock)$'

# label|regex   (EVM private keys are KEY-CONTEXT scoped so on-chain tx/block
# hashes, storage slots, event topics and bytecode - all bare 0x+64hex - do NOT
# trip the gate; only a 64-hex next to key/priv/deployer/mnemonic/pk does.)
PATTERNS=(
  'anthropic-key|sk-ant-[A-Za-z0-9_-]{20,}'
  'openai-key|sk-[A-Za-z0-9]{40,}'
  'aws-akia|AKIA[0-9A-Z]{16}'
  'google-key|AIza[0-9A-Za-z_-]{35}'
  'github-token|gh[pousr]_[A-Za-z0-9]{36}'
  'slack-token|xox[baprs]-[A-Za-z0-9-]{10,}'
  'pem-private-key|-----BEGIN[ A-Z]*PRIVATE KEY-----'
  'alchemy-key|(g\.)?alchemy\.com/v2/[A-Za-z0-9_-]{20,}'
  'infura-key|infura\.io/v3/[A-Za-z0-9]{20,}'
  'evm-private-key-in-context|(private[_-]?key|privkey|deployer[_-]?key|signer[_-]?key|mnemonic|[^a-zA-Z]pk)["'\'' ]{0,4}[:=][ "'\'']{0,4}0x[a-fA-F0-9]{64}'
  'anthropic-key-assignment|ANTHROPIC_API_KEY[ ]{0,4}[:=][ ]{0,4}["'\'']?(sk-|[A-Za-z0-9_-]{20})'
  'signer-token-assignment|SIGNER_TOKEN[ ]{0,4}[:=][ ]{0,4}["'\'']?[A-Za-z0-9_-]{16}'
  'quoted-generic-secret|(api[_-]?key|apikey|secret|access[_-]?token|auth[_-]?token|password|passwd|passphrase)["'\'' ]{0,4}[:=][ ]{0,4}["'\''][A-Za-z0-9_/+.\-]{16,}["'\'']'
)

# ---- fail-closed self-test: the engine MUST catch a known canary ----
CANARY='sk-ant-api03-SELFTESTselftestSELFTESTselftest1234'
if ! printf '%s\n' "$CANARY" | grep -aEq 'sk-ant-[A-Za-z0-9_-]{20,}'; then
  echo "::error::secret-scan self-test FAILED (regex engine broken) - blocking merge fail-closed"
  exit 2
fi

FILES="$(git ls-files 2>/dev/null | grep -avE "$EXCLUDE_RE")"
[ -z "$FILES" ] && { echo "no tracked files to scan"; exit 0; }

HITS=0
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # skip binary files
  if grep -aIq . "$f" 2>/dev/null; then :; else continue; fi
  for p in "${PATTERNS[@]}"; do
    label="${p%%|*}"; rx="${p#*|}"
    m="$(grep -aEnI "$rx" "$f" 2>/dev/null)"
    if [ -n "$m" ]; then
      echo "::error file=$f::possible secret [$label]"
      # print location, redacting the middle of the match so the log does not re-leak it
      echo "$m" | sed -E 's/([A-Za-z0-9_+/.-]{6})[A-Za-z0-9_+/.-]{6,}([A-Za-z0-9_+/.-]{4})/\1_REDACTED_\2/g' | sed 's/^/    /'
      HITS=$((HITS+1))
    fi
  done
done <<< "$FILES"

if [ "$HITS" -gt 0 ]; then
  echo "::error::secret-scan BLOCKED this merge - $HITS possible secret(s) found."
  echo "Remove the secret from ALL commits (a plain revert does NOT purge git history), rotate it"
  echo "immediately (it is compromised the instant it is public), and move it to an untracked .env,"
  echo "a secret store, or a CRE Vault referenced by \${VAR}/getSecret(). See SESSION-COORDINATION/README.md."
  exit 1
fi
echo "secret-scan: clean ($(printf '%s\n' "$FILES" | wc -l | tr -d ' ') files, ${#PATTERNS[@]} patterns, self-test OK)"
exit 0
