namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Registers the configuration checks with the diagnostics runner. Values 0–3 are the general MobileNAV checks; 100–199 are reserved for satellite apps.</summary>
enumextension 77783 "BJF MN Config Doctor Checks" extends "BJF Diagnostic Check Type"
{
    value(200; "Config Services")
    {
        Caption = 'Config: Services & Web Services';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Services";
    }
    value(201; "Config Fields")
    {
        Caption = 'Config: Fields & Importance';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Fields";
    }
    value(202; "Config Profiles")
    {
        Caption = 'Config: Profiles';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Profiles";
    }
    value(203; "Config Page Rules")
    {
        Caption = 'Config: Relations & Page Rules';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Page Rules";
    }
    value(204; "Config Apply State")
    {
        Caption = 'Config: Apply State';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Apply State";
    }
}
