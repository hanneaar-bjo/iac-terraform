# =============================================================================
#  backend-bootstrap/  –  lagringsplassen for alle andre stacks
# -----------------------------------------------------------------------------
#  Kjøres ÉN gang, før noe annet. Den oppretter:
#
#    ressursgruppe -> storage account -> container "tfstate" -> rolletildeling
#
#  og skriver ut en ferdig backend-konfigurasjon i outputs.tf.
#
#  Denne stacken har lokal state. Se kommentaren i versions.tf om hvorfor.
# =============================================================================

provider "azurerm" {
  features {}

  # storage_use_azuread: provideren må selv snakke Entra ID mot dataplanet,
  # ikke bruke kontonøkler. Uten den klarer den ikke å opprette containeren på
  # en konto der nøklene er slått av (se shared_access_key_enabled nedenfor).
  storage_use_azuread = true

  # Lar du denne stå null, plukkes verdien fra ARM_SUBSCRIPTION_ID eller fra
  # den aktive subscriptionen i `az account show`.
  subscription_id = var.subscription_id
}

# Hvem er jeg logget inn som? Brukes til å gi MEG tilgang til containeren,
# uten at noen må lime inn sin egen object-ID.
data "azurerm_client_config" "current" {}

# Storage account-navn må være GLOBALT unike. Vi kombinerer kortnavnet ditt med
# en tilfeldig hale: kortnavnet gjør at du finner igjen din egen konto i
# portalen, halen sikrer at navnet er ledig.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

locals {
  # sttf + kortnavn + 6 tegn. Maks 24 tegn totalt, bare små bokstaver og tall.
  sa_name = substr(lower("sttf${var.shortname}${random_string.suffix.result}"), 0, 24)

  tags = {
    # Den nattlige oppryddingsjobben på den delte tenanten sletter alle
    # ressursgrupper som ikke er merket. Dette er det eneste som holder
    # state-backend-en i live fra dag til dag.
    keep      = "true"
    purpose   = "terraform-backend"
    owner     = var.shortname
    managedby = "terraform"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = format("rg-tfstate-%s", var.shortname)
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "sa" {
  #checkov:skip=CKV2_AZURE_33:Private endpoint krever privat nettverk, som er utenfor faget
  #checkov:skip=CKV2_AZURE_1:Microsoft-administrerte nøkler holder for et studentoppsett
  #checkov:skip=CKV_AZURE_59:Runneren leser state over internett
  #checkov:skip=CKV_AZURE_206:LRS holder; state er beskyttet av versjonering og soft delete
  #checkov:skip=CKV_AZURE_33:Queue-tjenesten brukes ikke
  name                = local.sa_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"

  # ---------------------------------------------------------------------------
  #  K2 – nøklene er slått av.
  #
  #  Med shared_access_key_enabled = false finnes det ingen kontonøkkel å
  #  hente. Backend-ens standardmetode (access key lookup) blir dermed
  #  UMULIG, ikke bare frarådet – og da MÅ backend-konfigurasjonen ha
  #  use_azuread_auth = true. Det er nettopp poenget: vi gjør den utrygge
  #  varianten uvalgbar i stedet for å be folk la være.
  # ---------------------------------------------------------------------------
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"

  # ---------------------------------------------------------------------------
  #  K3 – sikkerhetsnettet under state-fila.
  #
  #  versioning_enabled tar vare på hver versjon, så en apply som gikk galt
  #  kan rulles tilbake. delete_retention_policy gir sju dagers angrefrist på
  #  en slettet blob. Begge koster praktisk talt ingenting, og de er
  #  forskjellen på et uhell og en katastrofe.
  # ---------------------------------------------------------------------------
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  tags = local.tags

  # Vil du beskytte backend-en mot en `terraform destroy` i feil mappe, slår du
  # på denne. Den er kommentert ut her fordi oppgaven ber deg rydde opp til
  # slutt – men i et ekte oppsett hører den hjemme:
  #
  # lifecycle {
  #   prevent_destroy = true
  # }

  lifecycle {
    prevent_destroy = true
  }
}

# K4: containeren er privat. Det er standardverdien, men den skrives eksplisitt
# fordi konsekvensen av å ta feil er en offentlig liste over infrastrukturen din.
# tflint-ignore: azurerm_resources_missing_prevent_destroy # Slettede containere kan gjenopprettes i 7 dager (container_delete_retention_policy)
resource "azurerm_storage_container" "tfstate" {
  #checkov:skip=CKV2_AZURE_21:Lese-logging for state koster mer enn den gir i et studentoppsett
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.sa.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
#  K4 – tilgang til INNHOLDET, ikke bare til kontoen.
#
#  Å eie ressursgruppa gir deg kontrollplanet: du kan opprette og slette
#  kontoen. Å lese og skrive blobene er dataplanet, og krever sin egen rolle.
#  Det er den forskjellen som gir «men jeg ER jo Owner»-forvirringen i Azure.
#
#  Contributor, ikke Reader: Terraform skal SKRIVE state hit. Med Reader får du
#  lest state, men init feiler når den skal skrive.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "blob_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"

  # Avhengigheten til containeren finnes ikke som en referanse i blokka, så den
  # må skrives. RBAC-tildelinger feiler gjerne hvis de kjøres for tidlig.
  depends_on = [
    azurerm_storage_account.sa,
    azurerm_storage_container.tfstate
  ]
}
