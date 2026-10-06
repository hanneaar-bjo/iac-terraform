# Oppgave 6 (enkel) – fra pull request til prod, ett miljø om gangen

Dette repoet er Oppgave 5 med noe satt **mellom** pushen og produksjonen. Hvert
miljø har sin egen workflow-fil, og du flytter selv en commit fra miljø til
miljø.

## Filene

```text
.github/workflows/
  ci.yml                 NY      Steg 1 og 3 – fmt, validate og plan på pull requesten
  cd-dev.yml             ENDRET  Steg 4 – deploy-nettverk.yml fra Oppgave 5, nytt navn
  cd-test.yml            NY      Steg 5 – promoter en SHA til test
  cd-prod.yml            NY      Steg 6 – promoter en SHA til prod, med godkjenning
  riv-ned-nettverk.yml   ENDRET  Steg 8 – prod lagt til i lista
stacks/nettverk/         uendret fra Oppgave 5 (+ låsefila, se under)
modules/network/         uendret
shared/backend.hcl       uendret
backend-bootstrap/       uendret fra Oppgave 5
scripts/
  set-tfvars-secret.sh   uendret – legger en .tfvars inn i Key Vault
  config.sh              NY   felles verdier, hentet fra backend.hcl og bootstrap
  01-sjekk-azure.sh      NY   finnes backend og Key Vault? (endrer ingenting)
  02-last-opp-tfvars.sh  NY   tfvars-<miljø> inn i Key Vault
  03-github-environments.sh  NY   environments + KEYVAULT_NAME
  05-sjekk-oppsett.sh    NY   er ALT klart? (endrer ingenting)
dev.tfvars.eksempel      mal for dev og test
prod.tfvars.eksempel     NY  mal for prod
```

## Hele flyten på én skjerm

```text
  din gren ──▶ pull request ──▶ CI: fmt og validate ──▶ CI: plan mot dev ──▶ merge
                                                                              │
                                                                              ▼
                                                 cd-dev.yml    starter av seg selv
                                                     │         «dev ← 3f9a…»
                                         du kopierer SHA-en
                                                     ▼
                                                 cd-test.yml   du trykker Run workflow
                                                     │         «test ← 3f9a…»
                                         samme SHA
                                                     ▼
                                                 cd-prod.yml   du trykker Run workflow,
                                                               så venter den på godkjenning
                                                               «prod ← 3f9a…»
```

| Fil | Starter når | Azure-tilgang | Miljø |
|---|---|---|---|
| `ci.yml` → `fmt og validate` | pull request | **ingen** | – |
| `ci.yml` → `plan mot dev` | pull request | leser dev | dev |
| `cd-dev.yml` | merge til `main` | endrer dev | dev |
| `cd-test.yml` | du trykker *Run workflow* | endrer test | test |
| `cd-prod.yml` | du trykker *Run workflow* + godkjenner | endrer prod | prod |

Det som flyttes fra miljø til miljø, er **commit-SHA-en**. Ingenting annet.

## Fra start til mål

### 0. Utgangspunktet – Oppgave 5

Backend-stacken og Key Vault står. `tfvars-dev` og `tfvars-test` ligger i
vaultet. Environmentene `dev`, `test` og `prod` har hver sin federated
credential og hver sin `KEYVAULT_NAME`.

### 1. Før du begynner

Sjekk at alt fra Oppgave 4 og 5 står der det skal, og legg parameterfila for
prod i vaultet:

```bash
az login
export AZURE_CLIENT_ID=<client-id til App Registration-en>

bash scripts/01-sjekk-azure.sh            # backend og Key Vault (endrer ingenting)
cp prod.tfvars.eksempel prod.tfvars       # rett shortname
bash scripts/02-last-opp-tfvars.sh prod   # eller: ./scripts/set-tfvars-secret.sh <kv-navn> tfvars-prod ./prod.tfvars
bash scripts/03-github-environments.sh    # dev, test, prod + KEYVAULT_NAME (rører ikke reglene)
bash scripts/05-sjekk-oppsett.sh          # skal ende med «Alt workflowene trenger, er på plass.»
```

Skriptene henter backend-verdiene fra `shared/backend.hcl` og Key Vault-navnet
fra `terraform output` i `backend-bootstrap/`. Det står ingen personlige verdier
i `scripts/config.sh`, så den kan committes. Kjør `05-sjekk-oppsett.sh` igjen
hver gang en workflow feiler på tilgang.

Låsefila må virke på Linux, siden CI kjører der:

```bash
cd stacks/nettverk
terraform providers lock \
  -platform=linux_amd64 -platform=darwin_arm64 \
  -platform=darwin_amd64 -platform=windows_amd64
```

### 2. Arbeidsløkka du bruker hele oppgaven

```bash
git switch main && git pull          # start alltid fra oppdatert main
git switch -c <navn-på-grenen>       # ny gren
# ... gjør endringen ...
git add <filer>
git commit -m "<hva og hvorfor>"
git push -u origin <navn-på-grenen>
gh pr create --base main --fill      # eller «Compare & pull request» i GitHub
```

Når kontrollene er grønne: *Merge pull request*. Deretter `git switch main && git pull`.

### 3. Rekkefølgen

1. **Steg 1:** `ci.yml` med bare `kontroll`-jobben, via gren og PR. Merge.
2. **Steg 2:** Branch protection på `main` (se under). Kontrollen må ha kjørt
   minst én gang før du kan velge den.
3. **Steg 3:** Legg `plan-dev`-jobben til i `ci.yml`, via PR. Når den har kjørt,
   legger du `plan mot dev` til som required status check også.
4. **Steg 4:** `git mv .github/workflows/deploy-nettverk.yml .github/workflows/cd-dev.yml`,
   gjør endringene, via PR. Merge → *CD dev* starter.
5. **Steg 5:** `cd-test.yml` via PR. Merge. Knappen *Run workflow* finnes først
   når fila ligger på `main`. Kjør med SHA-en fra *CD dev*.
6. **Steg 6:** Porten på `prod` (se under). Deretter `cd-prod.yml` via PR.
   Merge. Kjør med samme SHA. Godkjenn.
7. **Steg 8:** `riv-ned-nettverk.yml` for dev, test og prod. Disable `cd-dev.yml`.

## Innstillingene som ikke er kode

**Branch protection på `main`** (*Settings → Branches → Add branch ruleset*, eller *Add classic branch protection rule*):

- Require a pull request before merging
- Required approvals: **0** – du kan ikke godkjenne din egen PR
- Require status checks to pass: `fmt og validate` og `plan mot dev`
- **Do not allow bypassing the above settings**

**Environment `prod`** (*Settings → Environments → prod*):

- Required reviewers: deg selv
- Prevent self-review: **av** – ellers kan ingen godkjenne mens du er alene
- Deployment branches and tags: *Selected branches and tags* → `main`

`dev` og `test` har ingen protection rules. Repoet må fortsatt være public.

## Kjente feller

- **PR-en venter på «Expected – Waiting for status to be reported».** Navnet i
  branch protection matcher ikke `name:` på jobben, eller workflowen har et
  `paths:`-filter som gjorde at den ikke startet. `ci.yml` har med vilje ikke
  noe filter.
- **Ingen *Run workflow*-knapp på *CD test*.** Fila ligger ikke på `main` ennå.
  `workflow_dispatch` vises bare for filer på standardgrenen.
- **`ligger ikke på main`.** Du limte inn SHA-en fra grenen din, ikke
  merge-commiten. Ta SHA-en fra oppsummeringen i *CD dev*-kjøringen.
- **`couldn't find remote ref`.** SHA-en er forkortet. Lim inn alle 40 tegnene.
- ***CD prod* feiler straks med «not allowed to deploy to prod».** Du valgte en
  annen gren enn `main` under *Use workflow from*.
- **To workflows ruller ut dev på samme merge.** `deploy-nettverk.yml` ligger der
  fortsatt. Bruk `git mv`, ikke kopi.

## Det dette oppsettet IKKE garanterer

- Ingenting sjekker at SHA-en du gir til *CD prod*, faktisk har vært i test.
  Det er en konvensjon du følger, ikke en regel GitHub håndhever.
- Planen for prod lages etter godkjenningen. Du godkjenner commiten, ikke planen.
- Ingenting sjekker at infrastrukturen *virker*, bare at `apply` ble grønn.
