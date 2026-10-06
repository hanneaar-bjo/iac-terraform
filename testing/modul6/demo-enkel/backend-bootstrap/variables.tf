variable "shortname" {
  type        = string
  description = <<-TEKST
    Ditt eget kortnavn. Går inn i både ressursgruppe- og storage account-navnet.
    Uten det finner du ikke igjen din egen konto når hele kullet oppretter
    samtidig – en ren random_string gir navn ingen kan kjenne igjen.
  TEKST
}

variable "location" {
  type        = string
  default     = "norwayeast"
  description = "Azure-regionen backend-en opprettes i."
}

variable "subscription_id" {
  type        = string
  default     = null
  description = <<-TEKST
    Settes bare hvis du har flere subscriptions. Står den som null, brukes
    ARM_SUBSCRIPTION_ID eller den aktive subscriptionen fra `az account show`.
  TEKST
}
