# MobileNAV Configuration

A reusable Business Central extension for defining MobileNAV setup in AL instead of maintaining it manually per tenant.

It extracts the general configuration mechanism first implemented in an internal `Setup.Codeunit.al`: publish page web services, register drill-target pages, refresh host-page metadata, expose extension fields, and bind fields that open filtered MobileNAV pages. Consumer-specific page ids, control names, and filters stay in the consuming extension.

## Architecture

- `codeunit "BJF MobileNAV Configurator"` is the public, idempotent API over MobileNAV's configuration tables and metadata codeunits.
- `interface "BJF MobileNAV Setup Module"` defines one independent unit of app-specific setup.
- `enum "BJF MobileNAV Setup Module"` is an extensible registry. A consuming app contributes a module through an `enumextension`.
- `codeunit "BJF MobileNAV Setup Runner"` applies one module during install/upgrade or all registered modules on demand.
- `report "BJF Apply MN Configuration"` provides the **Apply MobileNAV Configuration** Tell Me action for manual and development-publish scenarios.

The library has no customer-specific setup and does not run configuration from its own install trigger. A dependency is installed before its consumer, so the consuming app's setup module is not available when this library is first installed. Each consumer calls `ApplyModule` from its own install and upgrade codeunits.

## Public API

| Procedure | Behaviour |
|---|---|
| `PublishPageWebService(PageId, ServiceName)` | Creates or repairs a published tenant page web service. |
| `EnsurePage(PageId, PreferredServiceName, var ServiceName)` | Creates the MobileNAV Main row if needed, refreshes metadata, and returns the actual service name. Existing names are preserved. |
| `EnsurePublishedPage(PageId, PreferredServiceName, var ServiceName)` | Ensures the MobileNAV page and publishes its web service using the actual retained service name. |
| `RefreshConfiguredPage(PageId, var ServiceName)` | Refreshes an existing MobileNAV host page; returns `false` if it is not configured. |
| `ShowField(ServiceName, ControlName, Editable)` | Makes a refreshed field visible and sets its editability; returns `false` if metadata did not contain it. |
| `ConfigureField(...)` | Explicitly sets visible, editable, and display-in-menu values. |
| `ShowLinkedField(...)` | Makes a field visible and upserts its relation plus FIELD filter to a registered target service. |
| `ConvertFieldName(OriginalName)` | Exposes MobileNAV's control/field-name normalization. |

`ShowLinkedField` converges existing relation/filter rows to the requested values on repeat runs. This fixes a limitation of the original implementation, which treated any existing relation as complete even when its target or filter had changed.

## Using it from another extension

1. Add **MobileNAV Configuration** to the consumer's `app.json` dependencies.
2. Implement `"BJF MobileNAV Setup Module"` in a small codeunit containing that app's setup only.
3. Register the codeunit with an `enumextension` of `"BJF MobileNAV Setup Module"`.
4. Call `SetupRunner.ApplyModule(...)` from the consumer's install and upgrade codeunits.
5. Add the consumer module codeunit to the consumer's permission set so administrators can use the manual apply report.

See [examples/ConsumerExtension.md](examples/ConsumerExtension.md) for a complete skeleton.

## Build

The app currently targets Business Central 27 (`runtime 16.0`) and MobileNAV 12. Put the matching Microsoft and `MULTISOFT KFT_MobileNAV` symbol packages in `.alpackages`, then compile with the AL extension or `alc`:

```sh
alc /project:. /packagecachepath:.alpackages /out:MobileNAV-Configuration.app
```

The repository does not include proprietary MobileNAV or Microsoft symbol packages.
