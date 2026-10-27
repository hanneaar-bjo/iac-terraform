#!/usr/bin/env bash
# =============================================================================
#  scripts/02-last-opp-tfvars.sh  –  tfvars-<miljø> inn i Key Vault
# -----------------------------------------------------------------------------
#  Laster opp <miljø>.tfvars fra terraform-projects/ som secret tfvars-<miljø>.
#  Trygt å kjøre flere ganger: hver kjøring lager en ny versjon av secreten.
#
#      bash scripts/02-last-opp-tfvars.sh prod     # bare prod – det Oppgave 6 trenger
#      bash scripts/02-last-opp-tfvars.sh          # dev, test og prod
#
#  Fila må finnes lokalt først: cp prod.tfvars.eksempel prod.tfvars
# =============================================================================
set -euo pipefail
source "$(dirname "$0")/config.sh"
krev_az
krev_kv

if (( $# > 0 )); then MILJOER=("$@"); fi

for MILJO in "${MILJOER[@]}"; do
  FIL="$TFVARS_DIR/$MILJO.tfvars"
  info "tfvars-$MILJO  ←  $MILJO.tfvars"
  bash "$SCRIPT_DIR/set-tfvars-secret.sh" "$KEYVAULT_NAME" "tfvars-$MILJO" "$FIL" >/dev/null
  ok "lastet opp"
done

info "Secrets i $KEYVAULT_NAME nå"
az keyvault secret list --vault-name "$KEYVAULT_NAME" \
  --query "[?starts_with(name, 'tfvars-')].{navn:name, oppdatert:attributes.updated}" -o table
