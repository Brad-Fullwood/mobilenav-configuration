# MobileNAV Configuration WMS

Satellite app for [MobileNAV Configuration](../MobileNAV%20Configuration/README.md). It contributes the doctor checks that need **WMS MobileNAV** (MULTISOFT) installed, through an `enumextension` of `"BJF Diagnostic Check Type"`:

| Check | Catches |
|---|---|
| **Inventory Setup** | Package number series, package tracking and the undefined package number not set; the Move-posts-own-lines workaround active. |
| **Package Consistency** | Package No. Information records without a matching MUL WMS Package record, which the WMS integrity check hard-gets after every package posting. |
| **Split Packages** | Packages whose stock is spread over more than one bin, which fails every posting that touches them. The fix posts a reclassification consolidating the package into the bin holding most of it, carrying lot, serial and package tracking. |

It is a separate app only so the framework installs in environments without WMS MobileNAV. Depends on MobileNAV Configuration 4.0.0.0 and WMS MobileNAV 1.2.0.0. Object ids 77740 to 77759. Run the checks from **MobileNAV Doctor**, **Run all diagnostics**.
