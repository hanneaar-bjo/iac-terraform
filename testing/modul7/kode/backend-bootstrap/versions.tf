# =============================================================================
#  backend-bootstrap/versions.tf  –  ERSTATTER FILA FRA OPPGAVE 4
# -----------------------------------------------------------------------------
#  Dette er den ENESTE fila i backend-bootstrap/ som er endret siden Oppgave 4,
#  utover at pipeline.tf er ny. Grunnen er versjonene: Oppgave 4s løsning står
#  på azurerm ~> 4.0, mens sidene i modul 4 og 5 sier ~> 5.4.
#
#  Det er ikke kosmetikk her. Argumentet som slår på RBAC i pipeline.tf heter
#  `rbac_authorization_enabled`, og det navnet finnes først fra azurerm 4.42.
#  Har du en .terraform.lock.hcl fra Oppgave 4 som låser noe eldre, feiler
#  `plan` med «Unsupported argument» på en linje som er riktig. Da er det
#  versjonen som er feil, ikke koden:
#
#      terraform init -upgrade
# =============================================================================

terraform {
  required_version = ">= 1.16.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # K1 FRA OPPGAVE 4, UENDRET: HER STÅR DET INGEN backend-BLOKK, OG DET ER
  # MED VILJE.
  #
  # Denne stacken oppretter stedet alle de andre stackene lagrer state. Den
  # kan ikke selv lagre state i en container som ikke finnes ennå – det er
  # hønen og egget. Derfor beholder den local-backenden.
  #
  # Det er akseptabelt nettopp for denne ene stacken, fordi den er så liten:
  # mister du state her, importerer du ressursene tilbake med
  # `terraform import` og er ferdig på et kvarter. Mister du state for et
  # miljø, har du mistet oversikten over alt som står der.
}

# -----------------------------------------------------------------------------
#  Én ting til om spranget fra 4.x til 5.x, siden det overrasker folk:
#
#  I azurerm 5.0 ble standardverdien for `resource_provider_registrations`
#  endret fra "legacy" til "none". Provideren registrerer altså ikke lenger
#  resource providers for deg. Det FEILER ikke her – Microsoft.Storage og
#  Microsoft.KeyVault er for lengst registrert på den delte tenanten – men vil
#  du følge konvensjonen fra modul 4, sier du det du faktisk bruker, i
#  provider-blokka i main.tf:
#
#    provider "azurerm" {
#      features {}
#      storage_use_azuread = true
#      subscription_id     = var.subscription_id
#
#      resource_providers_to_register = ["Microsoft.Storage", "Microsoft.KeyVault"]
#    }
#
#  Resten av main.tf fra Oppgave 4 er allerede 5.x-klar: containeren bruker
#  `storage_account_id`, `min_tls_version` er TLS1_2, og
#  `allow_nested_items_to_be_public` står eksplisitt.
# -----------------------------------------------------------------------------
