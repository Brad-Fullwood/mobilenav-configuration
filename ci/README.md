# Configuration CI

A pull request that changes a MobileNAV configuration app fails when the app has a cop diagnostic,
when the provider's apply would stop with an error, or when the Doctor reports a finding at Warning
or above. `check.py` runs the steps, `.github/workflows/configuration-ci.yml` and
`azure-pipelines.yml` call it.

## What runs

| Step | Command | Fails when |
|---|---|---|
| setup | `check.py setup` | the AL compiler or the ALCops analyzers cannot be installed, or the .NET runtime it needs is missing |
| build | `check.py build` | any diagnostic (error, warning or info) with CodeCop, UICop, PerTenantExtensionCop and the five ALCops cops, a missing analyzer, an analyzer crash |
| deploy | `check.py deploy` | the Automation API upload does not end as `Completed`. Skipped with `--no-deploy` |
| preview | `check.py preview` | a provider the app declares is not listed by the environment, or `mnconfig.py preview` prints `The apply would stop with:` |
| apply | `check.py apply` | the provider is not `Applied` afterwards. Skipped with `--no-apply` |
| device | `check.py device` | a declared field is missing, hidden or read-only on the device, a button's function is missing from the page's SOAP service, or a tile is missing. Runs only with `--device` (`--device-id`, `--device-profile` optional): it signs in as the harness device, which writes a login log row and takes a device licence, so sandbox only |
| doctor | `check.py doctor` | a finding at `--fail-on` severity or above (default Warning, so Blocker and Warning) |
| all | `check.py all` | any of the above. Prints one table and exits 1 on any failure |

A failed step makes the steps that depend on it show `skipped` in the table (a failed build skips the
rest, a failed deploy skips preview, apply and doctor).

`check.py` calls each tool with `--json` and reads the last line of its output that starts with `{`. A tools checkout that does not accept the flag fails the step at once, so update the checkout with the tools.

Apply runs between preview and doctor because the Doctor reports a Warning ("The provider's definition
has changed since it was last applied") as soon as a pull request changes the declaration. Without the
apply every such pull request would fail. Use `--no-apply` where the sandbox must keep its earlier
configuration.

The providers come from the app's source: each codeunit that implements `"BJF MN Config Provider"`,
read from its `GetId` procedure (a Label or a literal). `--provider ID` overrides that.

`build` downloads symbols for the app from the environment's developer endpoint
(`/dev/packages`): the Microsoft apps, MobileNAV and any other dependency in `app.json`. Apps given with
`--with` are built first and used as symbols instead, so a pull request that changes the framework and
an app that depends on it is checked together.

## Secrets and variables

Four values, set as repository secrets (GitHub) or variables in a variable group (Azure Pipelines):

| Name | Value |
|---|---|
| `BC_TENANT` | Microsoft Entra tenant id of the Business Central environment |
| `BC_ENVIRONMENT` | environment name of the sandbox, for example `Development` |
| `BC_CLIENT_ID` | application (client) id of the Entra app registration |
| `BC_CLIENT_SECRET` | a client secret of that app registration |

Optional: `BC_COMPANY` when the sandbox has more than one company (the name, as in the company list),
`BC_AL_VERSION` to pin the marketplace version of the AL extension (default: latest), `BC_ALCOPS_VERSION`
to change the ALCops release (default: the one pinned in `check.py`).

The tools repo (`bcbd.py`, `mnconfig.py`) is private. The GitHub workflow reads it with a fifth secret,
`TOOLS_TOKEN`, a token with read access to `Brad-Fullwood/tools`. The Azure template reads it through a
GitHub service connection. `check.py` finds the tools through `BC_TOOLS` or `--tools`, the path of the
checkout.

`check.py` signs in with `bcbd.py login --as ci --app --client-id ... --secret-env BC_CLIENT_SECRET`.
The secret stays in the environment, `bcbd.py` keeps only the variable name.

## The Entra application

1. Register an application in the customer's Microsoft Entra tenant and create a client secret.
2. Add the application permissions of the Dynamics 365 Business Central API that the Automation and
   custom API pages need (`Automation.ReadWrite.All` and `API.ReadWrite.All`) and grant admin consent.
3. In the sandbox open the page "Microsoft Entra Applications", add the application with its client id,
   set it to Enabled, and give it these permission sets: `D365 AUTOMATION`, `EXTEN. MGT. - ADMIN`,
   the MobileNAV permission sets and `BJF MN Configuration`.
4. Check it with `bcbd.py token`: it prints the application id.

An application sign-in is not a delegated administrator, so MobileNAV's device handover during apply
needs no confirmation. It also needs no user and no MFA.

## Sandbox requirements

- Use a sandbox only for CI. Every run uploads the app and applies its providers, which changes the
  MobileNAV configuration of the company it uses. Do not point it at a sandbox someone configures
  by hand.
- MobileNAV is installed, and MobileNAV Configuration 4.4.0.0 or later (the API pages, and `preview`).
  The check needs the framework in the sandbox before the first run unless the pull request also
  carries it with `--with`.
- Only one run at a time. The GitHub workflow serialises runs with `concurrency`. In Azure Pipelines
  set the pipeline's parallelism to one.
- The per-tenant upload needs each run's version to be higher than the installed one. `--stamp-revision N`
  replaces the fourth part of the version in each built app (the workflows pass the run number) and puts
  `app.json` back afterwards. The revision in the sandbox must stay below it. After a manual
  upload with a higher revision, raise the run numbers or uninstall the app.
- The first run fails if the app is currently published as Dev. Uninstall it once (`bcbd.py uninstall`).
- Pull requests from forks get no secrets, so the GitHub job is skipped for them.

## Adopt it in a customer app

1. Copy two files into the app's repository: `ci/check.py` and `.github/workflows/configuration-ci.yml`
   (or `ci/azure-pipelines.yml` for Azure Pipelines).
2. Set the four values above.

In the workflow change the last step to the customer app's folder. For an app at the repository root:

```yaml
      - name: Check the app
        run: python ci/check.py all --stamp-revision ${{ github.run_number }}
```

`--app <folder>` selects another folder and `--with <folder>` adds an app of the same repository that it
depends on. In the Azure template set `app` and `withArguments`. The workflow's unit test step
(`python -m unittest discover -s ci/tests`) belongs to this repository, delete it from a customer copy.

## Run it locally

```
export BC_TOOLS=~/Projects/tools/business-central
export BC_TENANT=<tenant id> BC_ENVIRONMENT=Development BC_COMPANY="CRONUS UK Ltd."
python3 ci/check.py build --app "MobileNAV Configuration Example" --with "MobileNAV Configuration"
python3 ci/check.py all --no-deploy --no-apply --app "MobileNAV Configuration Example" --with "MobileNAV Configuration"
```

Without `BC_CLIENT_ID` the tools use their own sign-in (`al authenticate login`) and the app's
`.vscode/launch.json`, so tenant and environment can stay unset. `--no-deploy` reads what is installed.
Options: `--out-dir`, `--provider`, `--no-symbols`, `--refresh-symbols`, `--fail-on`, `--stamp-revision`.

Tests: `python3 -m unittest discover -s ci/tests`. They check the parsers against recorded tool output
and run `check.py` against fake `bcbd.py` and `mnconfig.py` scripts, with no network.

## Not verified

- The GitHub workflow and the Azure template have not run on a runner. Every command in them was run
  on a Linux machine, except the actions (`checkout`, `setup-python`, `setup-dotnet`, `UseDotNet`) and
  the Azure variable and checkout paths.
- The deploy and apply steps have not run against a live sandbox, only against fake tools.
- Whether the Entra application may call the developer endpoint for symbol downloads is not confirmed.
  Symbol downloads were tested with a user sign-in. If it is refused, put the symbols in `.alpackages`
  (a cache step) and pass `--no-symbols`.
