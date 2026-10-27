# =============================================================================
#  backend-bootstrap/pipeline.tf  –  DET ENESTE SOM ER NYTT I BOOTSTRAP-EN
# -----------------------------------------------------------------------------
#  Resten av backend-bootstrap/ er uendret fra Oppgave 4: ressursgruppe,
#  storage account uten nøkler, container, og en rolletildeling til DEG.
#
#  Denne fila legger til de to tingene Oppgave 5 trenger:
#
#    1. Key Vault-et parameterfilene skal bo i (K5)
#    2. Rettigheter til SERVICE PRINCIPAL-EN, ikke bare til deg (K4)
#
#  K4 er kravet som stopper flest. Grunnen er at alt SER riktig ut: azure/login
#  går grønt, og så feiler `terraform init` med 403
#  AuthorizationPermissionMismatch. Innloggingen virket. Det er tilgangen til
#  blobben som mangler – autentisering og autorisasjon er ikke det samme.
#
#  I Oppgave 4 ga du deg selv tilgang. Service principal-en fantes ikke da, og
#  den arver ingenting av deg.
# =============================================================================

# Object-ID-en må komme utenfra, og det er ikke inkonsekvent selv om din egen
# hentes med azurerm_client_config. Data source-en svarer på «hvem kjører denne
# koden NÅ», og det er aldri service principal-en – du kjører bootstrap-en fra
# din egen maskin.
#
#   az ad sp show --id <din-client-id> --query id -o tsv
#
# MERK: object-ID, ikke client-ID. De ser like ut, begge er GUID-er, og limer
# du inn feil får du enten PrincipalNotFound eller en tildeling som peker på
# ingenting. Verdien er ikke en hemmelighet – en object-ID identifiserer en
# konto, den gir ingen tilgang.
variable "pipeline_principal_id" {
  type        = string
  description = "Object-ID til service principal-en workflowen logger inn som."

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.pipeline_principal_id))
    error_message = "Skal være en GUID. Husk: object-ID fra `az ad sp show`, ikke client-ID."
  }
}

# ---------------------------------------------------------------------------
#  K4 – state-containeren
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "pipeline_blob_contributor" {
  scope                = azurerm_storage_account.sa.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.pipeline_principal_id

  # principal_type er valgfritt, men ta det med. Står det der, slipper Azure å
  # slå opp hva slags konto ID-en tilhører. Det oppslaget er det som feiler med
  # PrincipalNotFound når en identitet nettopp er opprettet – en feil som ser
  # ut som en skrivefeil, men ikke er det.
  principal_type = "ServicePrincipal"

  depends_on = [
    azurerm_storage_account.sa,
    azurerm_storage_container.tfstate
  ]
}

# ---------------------------------------------------------------------------
#  Key Vault – kilden til parameterfilene
# ---------------------------------------------------------------------------
# tflint-ignore: azurerm_resources_missing_prevent_destroy # Key Vault-et har soft delete og kan gjenopprettes
resource "azurerm_key_vault" "kv" {
  #checkov:skip=CKV_AZURE_110:Purge protection hindrer opprydding i et studentoppsett
  #checkov:skip=CKV2_AZURE_32:Private endpoint krever privat nettverk, som er utenfor faget
  #checkov:skip=CKV_AZURE_42:Krever purge protection, se CKV_AZURE_110
  #checkov:skip=CKV_AZURE_189:Runneren henter parameterfila over internett
  #checkov:skip=CKV_AZURE_109:Runneren henter parameterfila over internett
  # Navnet må være globalt unikt, maks 24 tegn, og kan ikke inneholde
  # understrek. Vi gjenbruker den tilfeldige halen fra storage account-navnet,
  # slik at de to hører synlig sammen i portalen.
  #
  # MERK: `random_string.suffix` er navnet DENNE løsningen brukte i Oppgave 4.
  # Oppgave 4 krevde den ikke – den ba bare om at navnet var globalt unikt og
  # inneholdt kortnavnet ditt. Skrev du navnet for hånd, finnes ressursen ikke
  # i stacken din, og linja under feiler med «Reference to undeclared
  # resource». Bytt da ut ${random_string.suffix.result} med den samme
  # strengen du valgte den gangen.
  name                = substr(lower("kv-tf-${var.shortname}${random_string.suffix.result}"), 0, 24)
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Avgjørende for rolletildelingene under: med RBAC er det Azures vanlige
  # rollemodell som styrer tilgang. Uten den må du bruke access policies i
  # stedet, og `az keyvault set-policy` er da riktig kommando. De to systemene
  # kan ikke blandes – velg ett, og her er det RBAC.
  rbac_authorization_enabled = true

  # Soft delete kan ikke slås av. 7 dager er minimum, og vi velger minimum med
  # vilje: på en delt tenant vil et navn du «slettet» ellers være opptatt i tre
  # måneder når du skal prøve på nytt.
  soft_delete_retention_days = 7

  # purge_protection_enabled = true ville vært riktigere i produksjon – da kan
  # ingen fjerne vaultet før soft delete-perioden er over, heller ikke ved et
  # uhell. I dette faget er det feil vei: du ville ikke fått ryddet opp etter
  # deg. Det er et bevisst avvik, ikke en forglemmelse.
  purge_protection_enabled = false

  tags = local.tags
}

# DU skal kunne SKRIVE secrets – det er du som laster opp .tfvars-filene.
# Officer, ikke User.
resource "azurerm_role_assignment" "kv_officer_meg" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
}

# Workflowen skal bare LESE. Secrets User, ikke Officer.
#
# Minste privilegium er ikke pedanteri her: en workflow som kan skrive til Key
# Vault, kan også overskrive parameterfila for prod. Den trenger det aldri.
resource "azurerm_role_assignment" "kv_user_pipeline" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.pipeline_principal_id
  principal_type       = "ServicePrincipal"
}

# Verdien som skal inn som ENVIRONMENT secret i GitHub – én gang per miljø,
# under Settings -> Environments -> <miljø> -> Environment secrets.
#
# Den er ikke hemmelig. Den ligger som environment secret fordi den er
# MILJØSPESIFIKK: i et modent oppsett har dev, test og prod hvert sitt vault,
# og da er det denne verdien som skiller dem.
output "keyvault_name" {
  value       = azurerm_key_vault.kv.name
  description = "Legges inn som environment secret KEYVAULT_NAME i GitHub."
}
