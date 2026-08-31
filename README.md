# MobileNAV Configuration

A declarative Business Central framework for defining, applying, and tracking custom MobileNAV configuration in AL.

It extracts the reusable mechanism first implemented in an internal `Setup.Codeunit.al`: publish page web services, register drill-target pages, refresh host-page metadata, configure extension fields, and bind fields that open filtered MobileNAV pages. Customer-specific page IDs and control names remain in small provider codeunits owned by the consuming extension.

## Contract

A provider implements `interface "BJF MN Config Provider"` and must supply:

- a stable, non-localized provider ID;
- a display name and description;
- a positive configuration version;
- a declarative definition built with `codeunit "BJF MN Config Builder"`.

The builder supports only these operations:

- `AddPublishedPage`;
- `AddField` / `AddVisibleField` / `AddFilterableField`;
- `AddLinkedField`;
- `AddToProfile`.

`AddField` and `AddVisibleField` place a field in MobileNAV's standard section and leave it out of the device filter pane. MobileNAV itself defaults a new field to *Additional* importance, which hides it behind the card's additional fields section, so the framework always writes importance explicitly. The `AddField` overload taking `Importance` and `Filterable` accepts MobileNAV's own importance vocabulary (`None`, `RequiredForInsert`, `Mandatory`, `Additional`) and offers the field in the filter pane; `AddFilterableField` is the visible, standard, filterable shorthand. Filter Scope is left at MobileNAV's default.

`AddFunctionField` and `AddScanField` place their control in the standard section for the same reason: a function control is a button, and a button left at MobileNAV's *Additional* default is one the device user never finds. `AddFunctionField` has an `Importance` overload for deliberate placement elsewhere.

Publishing a page with `AddPublishedPage` also makes it usable: MobileNAV collects a user's pages from the profile rows of type Page, so a published page with no such row is not collected — it has no tile, *and* any control whose only job is to open it is force-hidden, because a relation button is only drawn once its target page is reachable. The framework therefore creates the page row (and, from each `AddLinkedField`, the Parent Page row that makes the target reachable from the page the control sits on), using MobileNAV's own routines as the model.

`AddToProfile` declares a control for MobileNAV's *profiles*. MobileNAV resolves visibility in two layers: the service-level field configuration is the default, but a row for the control in the device user's profile overrides it outright. MobileNAV writes those profile rows itself when it rebuilds a profile's page hierarchy, and a control it has not been told about is not visible there — so a field can be configured correctly at service level and still be missing from the device screen. Calling `AddToProfile(PageId, ControlName)` covers every defined profile; the overloads take a named profile, and explicit `Visible`/`Editable`. Re-declaring is safe.

There is deliberately no `ApplySetup()` method. Providers describe desired state; the framework validates and applies it. Empty definitions, incomplete operations, duplicate targets, duplicate provider IDs, empty metadata, and non-positive versions are rejected.

AL interfaces cannot enforce purity: a deliberately hostile implementation can still perform side effects inside any interface method. The framework contract does ensure that no provider receives an arbitrary execution callback, and no framework-owned MobileNAV mutation starts until the complete declared plan has passed validation.

## Responsibilities

- **Provider contract and builder** collect a constrained intermediate configuration plan.
- **Provider catalog** discovers enum-registered providers and validates required metadata and unique IDs.
- **Validator** validates the complete plan before persistent MobileNAV changes begin.
- **Application service** validates a definition, orders its dependencies, applies it, and records success in one transaction.
- **Page and field managers** isolate MobileNAV persistence from provider and UI code.
- **Status table** owns provider/version application state and manual invalidation rules.
- **Apply custom MobileNAV config** uses standard row selection to apply or mark one or more providers outdated.

The status page shows every provider registered through an `enumextension`, whether it has ever been applied, its current and applied versions, last application details, and one of these states:

- **Not Applied** — no successful application is recorded;
- **Applied** — the applied version matches the provider version;
- **Outdated** — the provider version changed or an administrator marked it outdated.

Applying a provider clears its manual-outdated flag. Incrementing `GetVersion()` makes existing application state outdated automatically.

## Using it from another extension

1. Add **MobileNAV Configuration 2.0.0.0** to the consumer's `app.json` dependencies.
2. Implement `"BJF MN Config Provider"` in one codeunit.
3. Register it through an `enumextension` of `"BJF MN Config Provider"`.
4. Call `"BJF MN Config Application".ApplyProvider(...)` from the consumer's install or upgrade codeunit when automatic application is required.
5. Grant execute permission to the consumer provider codeunit and assign/include the library permission set for the administration page.

See [examples/ConsumerExtension.md](examples/ConsumerExtension.md) for a complete skeleton.

## Build

The app targets Business Central 25 (`runtime 14.3`) and MobileNAV 11 or later. Put compatible Microsoft and `MULTISOFT KFT_MobileNAV` symbol packages in `.alpackages`, then compile with the AL extension or `alc`:

```sh
alc /project:. /packagecachepath:.alpackages /out:MobileNAV-Configuration.app
```

The repository does not include proprietary MobileNAV or Microsoft symbol packages.

## Nested git submodules

All AL objects are guarded by the `BJF_MN_CONFIG_SOURCE` preprocessor symbol, which is defined only by this app's manifest. This lets a consuming AL project keep the repository as a nested git submodule without compiling the library objects into the consumer. The consumer still declares the app dependency and places a compiled `MobileNAV Configuration` package in its symbol cache.
