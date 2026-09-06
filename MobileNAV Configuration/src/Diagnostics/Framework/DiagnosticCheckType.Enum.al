namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Every check the doctor can run. Values below 100 are general MobileNAV checks, 100 to 199
/// are reserved for satellite apps, and 200 upwards compare providers' declarations with
/// MobileNAV's live configuration.
/// </summary>
enum 77762 "BJF Diagnostic Check Type" implements "BJF Diagnostic Check"
{
    Access = Public;
    Caption = 'Diagnostic Check';
    Extensible = true;

    value(0; "Movement Journals")
    {
        Caption = 'Movement Journals';
        Implementation = "BJF Diagnostic Check" = "BJF Check Movement Journals";
    }
    value(1; "Item Tracking Codes")
    {
        Caption = 'Item Tracking Codes';
        Implementation = "BJF Diagnostic Check" = "BJF Check Item Tracking Codes";
    }
    value(2; "Leftover Journal Lines")
    {
        Caption = 'Leftover Journal Lines';
        Implementation = "BJF Diagnostic Check" = "BJF Check Leftover Jnl. Lines";
    }
    value(3; "Page Relations")
    {
        Caption = 'Page Relations';
        Implementation = "BJF Diagnostic Check" = "BJF Check Page Relations";
    }
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
    value(205; "Config Properties")
    {
        Caption = 'Config: Page & Control Settings';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Properties";
    }
    value(206; "Config Staging")
    {
        Caption = 'Config: Wizards';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Staging";
    }
    value(207; "Config Relations")
    {
        Caption = 'Config: Links & Lookups';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Relations";
    }
    value(208; "Config Page Rows")
    {
        Caption = 'Config: Filters & Operations';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Page Rows";
    }
    value(209; "Config Groups")
    {
        Caption = 'Config: Groups & Order';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Groups";
    }
    value(210; "Config Layouts")
    {
        Caption = 'Config: Dynamic Layouts';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Layouts";
    }
    value(211; "Config Master Data")
    {
        Caption = 'Config: Categories & Profiles';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Master Data";
    }
    value(212; "Config Appearance")
    {
        Caption = 'Config: Captions & Pictures';
        Implementation = "BJF Diagnostic Check" = "BJF Check Config Appearance";
    }
}
