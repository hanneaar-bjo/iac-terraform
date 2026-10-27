# =============================================================================
#  shared/backend.hcl  –  ÉN adresse, brukt av alle stacks og av workflowen
# -----------------------------------------------------------------------------
#  Uendret fra Oppgave 4. Den er tatt med her fordi den er den eneste fila i
#  repoet som har lov til å inneholde storage account-navnet (K3):
#
#      grep -rn "storage_account_name" .
#      -> nøyaktig ett treff, og det er denne fila
#
#  Et storage account-navn er en ADRESSE, ikke et passord. Uten en
#  rolletildeling kommer ingen inn selv om de kjenner navnet.
# -----------------------------------------------------------------------------
#  Lokalt:
#    terraform init -reconfigure \
#      -backend-config="../../shared/backend.hcl" \
#      -backend-config="key=env/dev/nettverk.tfstate"
#
#  I workflowen:
#      -backend-config="${{ github.workspace }}/shared/backend.hcl"
#
#  Stien er ulik fordi working-directory er ulik. Verdiene er de samme.
# =============================================================================

resource_group_name  = "rg-tfstate-tim"
storage_account_name = "sttftim7f3b9c"
container_name       = "tfstate"

# Påkrevd, ikke valgfritt: kontoen har shared_access_key_enabled = false, så
# det finnes ingen nøkkel å slå opp. Uten denne linja feiler init.
use_azuread_auth = true

# `key` står med vilje IKKE her. Den delte fila svarer på HVOR lagringen er –
# likt for alle. `key` svarer på HVILKEN FIL denne instansen eier, og det er
# hele forskjellen mellom dev og test.

# `use_cli` står heller ikke her, og det betyr mer nå enn i Oppgave 4. Den
# sier HVORDAN du logger inn, og det er ikke det samme lokalt som i en
# pipeline: lokalt er det az-økta di, i workflowen er det OIDC. Fila beskriver
# bare adressen; innloggingsmåten settes i miljøet – ARM_USE_CLI lokalt,
# ARM_USE_OIDC i jobben.
