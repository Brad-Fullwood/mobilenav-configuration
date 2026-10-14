namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Where a Doctor run came from. The run log shows it next to the run.</summary>
enum 77810 "BJF Doctor Run Source"
{
    Access = Public;
    Caption = 'Doctor Run Source';
    Extensible = false;

    value(1; "Page Open")
    {
        Caption = 'Page open';
    }
    value(2; Manual)
    {
        Caption = 'Manual';
    }
    value(3; "Job Queue")
    {
        Caption = 'Job queue';
    }
}
