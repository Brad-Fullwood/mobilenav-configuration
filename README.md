# MobileNAV Configuration

A declarative Business Central framework for defining, applying, and tracking custom MobileNAV configuration in AL.

It extracts the reusable mechanism first implemented in Translift's `Setup.Codeunit.al`: publish page web services, register drill-target pages, refresh host-page metadata, configure extension fields, and bind fields that open filtered MobileNAV pages. Customer-specific page IDs and control names remain in small provider codeunits owned by the consuming extension.

## Contract

A provider implements `interface "BJF MN Config Provider"` and must supply:

- a stable, non-localized provider ID;
- a display name and description;
- a positive configuration version;
- a declarative definition built with `codeunit "BJF MN Config Builder"`.

The builder supports only these operations:

- `AddPublishedPage`;
- `AddField` / `AddVisibleField`;
- `AddLinkedField`.

There is deliberately no `ApplySetup()` method. Providers describe desired state; the framework validates and applies it. Empty definitions, incomplete operations, duplicate targets, duplicate provider IDs, empty metadata, and non-positive versions are rejected.

AL interfaces cannot enforce purity: a deliberately hostile implementation can still perform side effects inside any interface method. The framework contract does ensure that no provider receives an arbitrary execution callback, and no framework-owned MobileNAV mutation starts until the complete declared plan has passed validation.

## Responsibilities

- **Provider contract and builder** collect a constrained intermediate configuration plan.
- **Provider catalog** discovers enum-registered providers and validates required metadata and unique IDs.
- **Validator** validates the complete plan before persistent MobileNAV changes begin.
- **Executor** orders dependencies: published pages, referenced-page metadata, fields, then links.
- **Web service, page, and field managers** each own one MobileNAV persistence concern.
- **Status manager** records successful provider/version applications and manual invalidation.
- **Apply custom MobileNAV config** is the single administration page for selecting, applying, and marking providers outdated.

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

The app targets Business Central 27 (`runtime 16.0`) and MobileNAV 12. Put the matching Microsoft and `MULTISOFT KFT_MobileNAV` symbol packages in `.alpackages`, then compile with the AL extension or `alc`:

```sh
alc /project:. /packagecachepath:.alpackages /out:MobileNAV-Configuration.app
```

The repository does not include proprietary MobileNAV or Microsoft symbol packages.
