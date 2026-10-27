# Oppgave 7 – kort løkke lokalt, alle reglene i porten

Dette repoet er Oppgave 6 (enkel) med to nye spørsmål i porten: **TFLint** (er
koden skrevet etter reglene?) og **Checkov** (er det koden lager, trygt?).
Begge kjøres av ett skript, `scripts/valider.sh`, som du kjører lokalt og som
porten kjører på pull requesten.

## Filene

```text
.tflint.hcl                    NY      Regelsettet for TFLint
.checkov.yaml                  NY      Oppsettet for Checkov
.gitattributes                 NY      *.sh lagres med Linux-linjeskift
scripts/valider.sh             NY      fmt → validate → TFLint → Checkov
.github/workflows/ci.yml       ENDRET  kontroll-jobben heter nå «kodekontroll» og kaller skriptet
modules/network/main.tf        ENDRET  required_version lagt til (TFLint)
backend-bootstrap/main.tf      ENDRET  prevent_destroy + begrunnede unntak
backend-bootstrap/pipeline.tf  ENDRET  begrunnede unntak
backend-bootstrap/.terraform.lock.hcl  NY  låsefil for fire plattformer
stacks/nettverk/               uendret fra Oppgave 6
.github/workflows/cd-*.yml     uendret fra Oppgave 6
riv-ned-nettverk.yml           uendret fra Oppgave 6
```

## Hvem trenger Azure?

| Jobb | Trenger Azure? |
|---|---|
| `ci.yml` → `kodekontroll` | **Nei.** Alle fire kontrollene er offline |
| `ci.yml` → `plan mot dev` | Ja – innlogging, Key Vault, state |
| `cd-dev.yml`, `cd-test.yml`, `cd-prod.yml`, `riv-ned-nettverk.yml` | Ja |

Det betyr at **porten kan testes i et helt tomt repo**, uten backend, OIDC
eller Key Vault. Spor A under gjør nettopp det. Spor B er for den som bygger
videre på sitt eget repo fra Oppgave 6.

---

## Felles: verktøyene på din maskin

Gjøres én gang. Detaljer og feilsøking: modul 7 side 3.

**macOS**

```bash
brew install terraform-linters/tap/tflint
python3 -m venv ~/.checkov
~/.checkov/bin/pip install checkov==3.3.21
echo 'export PATH="$HOME/.checkov/bin:$PATH"' >> ~/.zshrc
# åpne en ny terminal
```

Ikke `brew install checkov` – den pakken mangler alle `CKV2_*`-sjekkene.

**Windows** (PowerShell for installasjon, **Git Bash** for alt etterpå)

```powershell
winget install -e --id Git.Git
winget install -e --id TerraformLinters.tflint
winget install -e --id Python.Python.3.12
# lukk og åpne VS Code
pip install checkov==3.3.21
```

**Sjekk** (Git Bash på Windows):

```bash
terraform version    # 1.16.x
tflint --version     # 0.64.0
checkov --version    # 3.3.21
```

---

## Spor A – testrepo fra null, uten Azure (ca. 45 min)

Målet er å se porten virke slik studentene ser den: først Oppgave 6s
`fmt og validate`, så bytte til `kodekontroll`.

### A1. Lag repoet

Repoet må være **public** – branch protection er bare gratis på public repoer.

```bash
gh repo create <org-eller-bruker>/m07-porttest --public --clone
cd m07-porttest
```

### A2. Legg inn utgangspunktet (Oppgave 6) på `main`

Kopier løsningsforslaget til Oppgave 6 (enkel) fra kursrepoet. Workflowene som
krever Azure, tar du ikke med – de ville bare feilet:

```bash
KURS=<sti-til>/dcst3005-ntnu-canvas
cp -R "$KURS/modules/06-building-and-delivery/arbeidskrav/losningsforslag-enkel/kode/." .
rm .github/workflows/cd-*.yml .github/workflows/riv-ned-nettverk.yml

git add -A
git commit -m "Utgangspunkt: Oppgave 6 (enkel)"
git push -u origin main
```

`ci.yml` har fortsatt jobben `plan mot dev`. Den kommer til å feile på hver
pull request i dette repoet, fordi det ikke finnes noen Azure-secrets. Det er
forventet – den skal ikke være påkrevd her. Se bare på `fmt og validate` og,
senere, `kodekontroll`.

### A3. Gjør `fmt og validate` påkrevd

Kontrollen må ha kjørt én gang før GitHub kan tilby den:

```bash
git switch -c forste-pr
echo "" >> README.md
git commit -am "Første PR – registrerer fmt og validate"
git push -u origin forste-pr
gh pr create --base main --fill
```

Vent til `fmt og validate` er grønn. Så **Settings → Branches → Add classic
branch protection rule** for `main`:

- ☑ Require a pull request before merging – *Required approvals:* **0**
- ☑ Require status checks to pass → velg `fmt og validate`
- ☑ Do not allow bypassing the above settings

Merge PR-en, og hent `main`:

```bash
gh pr merge --merge --delete-branch
git switch main && git pull
```

Nå står repoet der studentene står etter Oppgave 6. Gå videre til **Felles:
Oppgave 7-stegene** under.

---

## Spor B – studentens repo fra Oppgave 6

Utgangspunkt: Oppgave 6 (enkel) er levert. `main` er beskyttet med
`fmt og validate` som påkrevd kontroll.

```bash
git switch main && git pull
```

Gå videre til **Felles: Oppgave 7-stegene**.

---

## Felles: Oppgave 7-stegene

Alt fra S1 til S4 gjøres på **én gren** og blir **én pull request**.

```bash
git switch -c oppgave-7
```

### S1 og S2 – regelsettene, rettingene og unntakene

Kopier filene fra dette løsningsforslaget inn i repoet (eller skriv dem selv
etter side 4–6):

```bash
KURS=<sti-til>/dcst3005-ntnu-canvas      # samme som i A2
L="$KURS/modules/07-infrastructure-testing/arbeidskrav/losningsforslag/kode"
cp "$L/.tflint.hcl" "$L/.checkov.yaml" "$L/.gitattributes" .
mkdir -p scripts && cp "$L/scripts/valider.sh" scripts/
cp "$L/modules/network/main.tf"             modules/network/main.tf
cp "$L/backend-bootstrap/main.tf"           backend-bootstrap/main.tf
cp "$L/backend-bootstrap/pipeline.tf"       backend-bootstrap/pipeline.tf
cp "$L/backend-bootstrap/.terraform.lock.hcl" backend-bootstrap/.terraform.lock.hcl
```

I **spor B** har studenten sine egne versjoner av disse filene. Ikke kopier
`.tf`-filene over – kjør verktøyene og rett eller unnta funnene selv (side 4 og 5).

Hent Azure-pluginen til TFLint, og kjør hvert verktøy for seg:

```bash
tflint --init
tflint --recursive --config "$(pwd)/.tflint.hcl"   # ingen funn
checkov -d .                                       # Failed checks: 0, Skipped checks: 11
```

### S3 – skriptet

```bash
bash scripts/valider.sh
```

Slutten skal være `✅ Alle kontrollene er grønne.` Kjøringen lager ingen nye
filer i repoet (`git status` skal bare vise det du selv har endret).

### S4 – porten

Kopier den nye `ci.yml`:

```bash
cp "$L/.github/workflows/ci.yml" .github/workflows/ci.yml
```

Det eneste som er endret, er `kontroll`-jobben. Jobb-ID-en er fortsatt
`kontroll`, men `name:` er `kodekontroll`, og stegene installerer verktøyene og
kaller `bash scripts/valider.sh`. `plan-dev` er uendret.

Commit, push og åpne pull requesten:

```bash
git add -A
git commit -m "Oppgave 7: TFLint og Checkov i lokal løkke og i porten"
git push -u origin oppgave-7
gh pr create --base main --fill
```

**Det som skjer nå, er forventet:** PR-en venter på `fmt og validate`, som aldri
kommer – jobben har byttet navn. Vent til `kodekontroll` er ferdig, og gå til
**Settings → Branches** → rediger regelen for `main`:

- fjern `fmt og validate`
- legg til `kodekontroll`

PR-en venter nå på riktig kontroll. Er `kodekontroll` grønn, merge:

```bash
gh pr merge --merge --delete-branch
git switch main && git pull
```

### S5 – prøv å lure porten

**Rødt:** legg inn en SSH-regel uten å kjøre skriptet lokalt.

```bash
git switch -c lur-porten
```

Lim inn i `azurerm_network_security_group`-blokken i `modules/network/main.tf`:

```hcl
  security_rule {
    name                       = "ssh-feilsoking"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
```

```bash
git commit -am "SSH for feilsøking"
git push -u origin lur-porten
gh pr create --base main --fill
```

`kodekontroll` blir **rød** med `CKV_AZURE_10`, og merge-knappen er sperret.

**Grønt – med et dårlig unntak:** legg til `#checkov:skip=CKV_AZURE_10` (uten
begrunnelse) øverst i `azurerm_network_security_group`-blokken – rett under
`resource "azurerm_network_security_group" "nsg" {` – commit og push. `kodekontroll` blir
**grønn**. Porten ser *at* det finnes et unntak, ikke om det er et godt unntak.

Rydd opp – ikke merge:

```bash
gh pr close --delete-branch
git switch main
```

### S6 – refleksjon

Spørsmålene står i oppgaveteksten. De har ingen fasit.

---

## Innstillingene som ikke er kode

**Branch protection på `main`** etter Oppgave 7:

- Require a pull request before merging – *Required approvals:* **0**
- Require status checks to pass: **`kodekontroll`** (og `plan mot dev` i spor B)
- **Do not allow bypassing the above settings**

Ingen endringer i environments eller i Azure.

## Kjente feller

- **PR-en venter på «Expected – Waiting for status to be reported».** Regelen
  nevner fortsatt `fmt og validate`. Bytt til `kodekontroll` (S4).
- **`kodekontroll` finnes ikke i søket i branch protection.** Den har ikke kjørt
  ennå. Push grenen og vent på første kjøring.
- **Grønt lokalt, rødt i porten.** Ulik versjon av et verktøy, eller en fil du
  ikke har committet. Sjekk `checkov --version` – og på macOS: er Checkov
  installert med Homebrew?
- **`tflint` gir ingen funn selv om du har plantet et.** `--config
  "$(pwd)/.tflint.hcl"` mangler, eller du står ikke i repo-rota. Skriptet gjør
  dette riktig – kjør det i stedet.
- **`$'\r': command not found`.** Skriptet har Windows-linjeskift.
  `.gitattributes` mangler, eller fila ble laget før den kom på plass. Bytt til
  `LF` nederst til høyre i VS Code og lagre.
- **`init` feiler på sjekksummer for `backend-bootstrap`.** Låsefila der er
  laget bare for din plattform. Bruk den fra løsningsforslaget, eller kjør
  `terraform providers lock` med de fire plattformene (som for stacken i Oppgave 6).
- **`fmt` feiler på `modules/network/main.tf` uten at du har rørt den.** Modulen
  ble kopiert fra løsningsforslaget til Oppgave 6 før en formateringsfeil der ble
  rettet. Kjør `terraform fmt -recursive`.
- **`plan mot dev` er rød i spor A.** Forventet – testrepoet har ingen
  Azure-secrets.

## Det dette oppsettet IKKE garanterer

- At unntakene er **gode**. Checkov godtar et unntak uten begrunnelse (S5). Det
  er et menneske som må lese diff-en.
- At **versjonene** lokalt og i porten er like. Skriptet er det samme, men
  verktøyene installeres to steder. Workflowen låser versjonene; maskinen din
  gjør det bare hvis du installerte med versjonsnummer.
- At infrastrukturen **virker**. Alle fire kontrollene leser bare koden. Det de
  ikke ser, er tema på modul 7 side 7.
