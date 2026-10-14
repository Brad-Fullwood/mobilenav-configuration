namespace BradFullwood.MobileNAV.Configuration;

/// <summary>The result of one configuration import requested through the configImports API.</summary>
table 77708 "BJF MN Config Import"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Import';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; Id; Guid)
        {
            Caption = 'Id';
        }
        field(2; "Backup Snapshot Code"; Code[20])
        {
            Caption = 'Backup Snapshot Code';
        }
        field(3; "Imported Snapshot Code"; Code[20])
        {
            Caption = 'Imported Snapshot Code';
        }
        field(4; "Config Kind"; Text[20])
        {
            Caption = 'Configuration Kind';
        }
        field(5; "Config Description"; Text[250])
        {
            Caption = 'Configuration Description';
        }
        field(6; "Base Config Version"; Text[30])
        {
            Caption = 'Base Configuration Version';
        }
        field(7; "Imported At"; DateTime)
        {
            Caption = 'Imported At';
        }
        field(8; "Imported By"; Code[50])
        {
            Caption = 'Imported By';
            DataClassification = EndUserIdentifiableInformation;
        }
    }

    keys
    {
        key(PK; Id)
        {
            Clustered = true;
        }
    }
}
