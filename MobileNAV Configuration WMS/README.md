# MobileNAV Configuration WMS

Satellite app for [MobileNAV Configuration](../MobileNAV%20Configuration/README.md). It contributes the doctor checks that need **WMS MobileNAV** (MULTISOFT) installed — inventory setup for package tracking, package record consistency, and split packages with an automatic consolidation fix — through an `enumextension` of `"BJF Diagnostic Check Type"`. It is a separate app only so the framework itself installs in environments without WMS MobileNAV.

Depends on MobileNAV Configuration 3.0.0.0+ and WMS MobileNAV 1.2.0.0+. Object ids 77740–77759. Run the checks from **MobileNAV Doctor → Run all diagnostics**.
