# MobileNAV Configuration

Two Business Central apps in one repository — open `MobileNAV Configuration.code-workspace` in VS Code to work on both.

| Folder | App | What it is |
|---|---|---|
| [`MobileNAV Configuration/`](MobileNAV%20Configuration/README.md) | MobileNAV Configuration | The framework: declare what a MobileNAV device shows in fluent AL, apply it correctly, route device buttons to one event, and diagnose and repair MobileNAV from the MobileNAV Doctor page. |
| [`MobileNAV Configuration WMS/`](MobileNAV%20Configuration%20WMS/README.md) | MobileNAV Configuration WMS | Satellite: the doctor checks that need WMS MobileNAV installed. |

Build either app from its own folder (see its README); the WMS app compiles against the framework's `.app` in its `.alpackages`.
