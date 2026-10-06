#!/usr/bin/env bash
# =============================================================================
#  scripts/config.sh  –  felles verdier for alle sjekk- og oppsettskriptene
# -----------------------------------------------------------------------------
#  Leses inn (source) av de andre skriptene. Kjøres ikke alene.
#
#  Det står INGEN personlige verdier her, så fila kan committes til et public
#  repo. Verdiene hentes fra stedene der de allerede står:
#
#    backend       shared/backend.hcl
#    Key Vault     outputen fra backend-bootstrap (lokal state på din maskin)
#    GitHub-repo   repoet du står i
#    client-ID     må eksporteres, den står bare i GitHub og i Azure:
#
#      export AZURE_CLIENT_ID=<client-id til App Registration-en>
#
#  Alle verdiene kan overstyres på samme måte, f.eks.
#  export KEYVAULT_NAME=kv-tf-...
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# terraform-projects/ – mappa over scripts/, ikke nødvendigvis repo-rota.
PROSJEKT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# .tfvars-filene ligger lokalt i terraform-projects/ (dev.tfvars, prod.tfvars …).
# .gitignore stopper dem fra å havne i Git.
TFVARS_DIR="$PROSJEKT_DIR"

# Backend: leses fra shared/backend.hcl, så verdiene bare står ett sted.
backend_verdi() {
  sed -n 's/^[[:space:]]*'"$1"'[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$PROSJEKT_DIR/shared/backend.hcl" 2>/dev/null || true
}
TFSTATE_RG="${TFSTATE_RG:-$(backend_verdi resource_group_name)}"
TFSTATE_SA="${TFSTATE_SA:-$(backend_verdi storage_account_name)}"
TFSTATE_CONTAINER="${TFSTATE_CONTAINER:-$(backend_verdi container_name)}"

# Key Vault: navnet backend-bootstrap skrev ut (output "keyvault_name").
KEYVAULT_NAME="${KEYVAULT_NAME:-$(terraform -chdir="$PROSJEKT_DIR/backend-bootstrap" \
  output -raw keyvault_name 2>/dev/null || true)}"

# Miljøene. Hvert av dem har sin egen tfvars-<miljø> i Key Vault og sitt eget
# environment i GitHub.
MILJOER=(dev test prod)

# GitHub-repoet som <org>/<repo>. Tom = repoet du står i (se krev_gh).
GITHUB_REPO="${GITHUB_REPO:-}"

# App Registration-ens client-ID (= AZURE_CLIENT_ID-secreten i GitHub).
# GitHub lar deg ikke lese secrets tilbake, derfor må du eksportere den.
AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"

# Service principal-ens OBJECT-ID (ikke client-ID). Brukes til å sjekke
# rolletildelingene. Tom = slås opp med az ad sp show.
AZURE_SP_OBJECT_ID="${AZURE_SP_OBJECT_ID:-}"

# -----------------------------------------------------------------------------
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
feil() { printf '  \033[31m✘\033[0m %s\n' "$*"; FEIL=$((${FEIL:-0} + 1)); }
info() { printf '\n\033[1m%s\033[0m\n' "$*"; }

krev_az() {
  command -v az >/dev/null || { echo "Fant ikke az (Azure CLI)." >&2; exit 1; }
  az account show >/dev/null 2>&1 || { echo "Ikke innlogget. Kjør: az login" >&2; exit 1; }
}

krev_gh() {
  command -v gh >/dev/null || { echo "Fant ikke gh (GitHub CLI)." >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Ikke innlogget. Kjør: gh auth login" >&2; exit 1; }
  if [[ -z "$GITHUB_REPO" ]]; then
    GITHUB_REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  fi
  [[ -n "$GITHUB_REPO" ]] || {
    echo "Vet ikke hvilket repo. Kjør fra klonen, eller: export GITHUB_REPO=<org>/<repo>" >&2
    exit 1
  }
}

krev_backend() {
  [[ -n "$TFSTATE_RG" && -n "$TFSTATE_SA" && -n "$TFSTATE_CONTAINER" ]] || {
    echo "Fant ikke backend-verdiene i shared/backend.hcl." >&2
    exit 1
  }
}

krev_kv() {
  [[ -n "$KEYVAULT_NAME" ]] || {
    echo "Fant ikke Key Vault-navnet. Kjør: export KEYVAULT_NAME=<kv-navn>" >&2
    echo "(Det står i portalen, eller: terraform -chdir=backend-bootstrap output keyvault_name)" >&2
    exit 1
  }
}

krev_client_id() {
  [[ -n "$AZURE_CLIENT_ID" ]] || {
    echo "AZURE_CLIENT_ID mangler. Kjør: export AZURE_CLIENT_ID=<client-id til App Registration-en>" >&2
    exit 1
  }
}
