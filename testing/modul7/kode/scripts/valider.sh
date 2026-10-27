#!/usr/bin/env bash
# =============================================================================
#  scripts/valider.sh  –  de fire offline-kontrollene, i rekkefølge
# -----------------------------------------------------------------------------
#  Kjøres på to steder, og det er hele poenget:
#    - lokalt, før du pusher:   bash scripts/valider.sh
#    - i porten, i ci.yml:      bash scripts/valider.sh
#
#  Reglene står ikke her. De står i .tflint.hcl og .checkov.yaml. Skriptet
#  sørger bare for at de kjøres likt, med de riktige flaggene, hver gang.
#
#  Skriptet kjører ALLE kontrollene selv om en tidlig feiler, slik at du ser
#  alle funnene på én gang. Feiler noe, avslutter det med feilkode til slutt.
# =============================================================================

# Mappene som skal kjøre `terraform validate`. Legg til nye stacker her.
TERRAFORM_MAPPER="stacks/nettverk backend-bootstrap"

# Stå i repo-rota uansett hvor skriptet startes fra. Da slipper du å tenke på
# hvilken mappe du står i – lokalt eller på runneren.
cd "$(git rev-parse --show-toplevel)" || exit 1

feilet=""

kontroll() {
  echo
  echo "=== $1 ==="
}

# --- 1. Formatering ----------------------------------------------------------
kontroll "1/4 terraform fmt"
if ! terraform fmt -check -recursive; then
  echo "→ Rett med: terraform fmt -recursive"
  feilet="$feilet fmt"
fi

# --- 2. Validering -----------------------------------------------------------
kontroll "2/4 terraform validate"
for mappe in $TERRAFORM_MAPPER; do
  echo "--- $mappe"
  # -backend=false: hent providerne, men ikke koble til state i Azure.
  if ! (cd "$mappe" &&
        terraform init -backend=false -input=false > /dev/null &&
        terraform validate -no-color); then
    feilet="$feilet validate($mappe)"
  fi
done

# --- 3. TFLint ---------------------------------------------------------------
kontroll "3/4 TFLint"
tflint --init > /dev/null
# --config med full sti: ellers brukes ikke regelsettet i undermappene.
if ! tflint --recursive --config "$(pwd)/.tflint.hcl"; then
  feilet="$feilet tflint"
fi

# --- 4. Checkov --------------------------------------------------------------
kontroll "4/4 Checkov"
# Leser .checkov.yaml i repo-rota automatisk.
if ! checkov -d .; then
  feilet="$feilet checkov"
fi

# --- Oppsummering ------------------------------------------------------------
echo
if [ -z "$feilet" ]; then
  echo "✅ Alle kontrollene er grønne."
  exit 0
else
  echo "❌ Feilet:$feilet"
  exit 1
fi
