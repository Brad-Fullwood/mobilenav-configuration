namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Validated intermediate representation produced by a configuration provider.</summary>
table 77780 "BJF MN Config Line"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Line';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; Operation; Enum "BJF MN Config Operation")
        {
            Caption = 'Operation';
        }
        field(3; "Page ID"; Integer)
        {
            Caption = 'Page ID';
        }
        field(4; "Service Name"; Text[100])
        {
            Caption = 'Service Name';
        }
        field(5; "Control Name"; Text[100])
        {
            Caption = 'Control Name';
        }
        field(6; Visible; Boolean)
        {
            Caption = 'Visible';
        }
        field(7; Editable; Boolean)
        {
            Caption = 'Editable';
        }
        field(8; "Display In Menu"; Boolean)
        {
            Caption = 'Display In Menu';
        }
        field(9; "Target Page ID"; Integer)
        {
            Caption = 'Target Page ID';
        }
        field(10; "Target Filter Field"; Text[100])
        {
            Caption = 'Target Filter Field';
        }
        field(11; "Source Field"; Text[100])
        {
            Caption = 'Source Field';
        }
        field(12; "Mobile Type"; Text[30])
        {
            Caption = 'Mobile Type';
        }
        field(13; "Function Name"; Text[50])
        {
            Caption = 'Function Name';
        }
        field(14; "Function Type"; Text[30])
        {
            Caption = 'Function Type';
        }
        field(15; "Validation Behavior"; Text[50])
        {
            Caption = 'Validation Behavior';
        }
        field(16; "Main Menu Action"; Text[30])
        {
            Caption = 'Main Menu Action';
        }
        field(17; "Auto Next Stage"; Boolean)
        {
            Caption = 'Auto Next Stage';
        }
        field(18; "Back-Next Visible"; Boolean)
        {
            Caption = 'Back-Next Visible';
        }
        field(19; "Stage Id"; Code[100])
        {
            Caption = 'Stage Id';
        }
        field(20; "Stage Enabled"; Boolean)
        {
            Caption = 'Stage Enabled';
        }
        field(21; "Stage Description"; Text[250])
        {
            Caption = 'Stage Description';
        }
        field(22; Importance; Text[30])
        {
            Caption = 'Importance';
        }
        field(23; Filterable; Boolean)
        {
            Caption = 'Filterable';
        }
        field(24; "Staging Behavior"; Text[30])
        {
            Caption = 'Staging Behavior';
        }
        field(25; "Stage Restart From"; Boolean)
        {
            Caption = 'Stage Restart From';
        }
        field(26; Profile; Code[30])
        {
            Caption = 'Profile';
            // Empty means every defined profile.
        }
        field(27; "Page Type"; Text[30])
        {
            Caption = 'Page Type';
            // Empty keeps MobileNAV's default for the page object.
        }
        field(28; "Function Codeunit ID"; Integer)
        {
            Caption = 'Function Codeunit ID';
            // The codeunit whose procedures the page's buttons run. For a dialog, Report Service
            // Name identifies its published endpoint. For an ordinary page, an empty Report
            // Service Name registers this codeunit as the unpublished same-name companion.
        }
        field(29; "Report Service Name"; Text[100])
        {
            Caption = 'Report Service Name';
            // Dialog function-service name. Empty for an ordinary page's same-name companion.
        }
        field(30; "Group Code"; Code[20])
        {
            Caption = 'Group Code';
            // Controls: the field group (a MobileNAV category) the control sits in.
        }
        field(31; "Filter Type"; Text[30])
        {
            Caption = 'Filter Type';
            // MobileNAV FilterType member: FIELD, CONST or FILTER.
        }
        field(32; Comparison; Text[30])
        {
            Caption = 'Comparison';
            // MobileNAV Filter Comparsion Type member: Equal, NotEqual, Less, ..., Own, NotOwn.
        }
        field(33; "Filter Value"; Text[250])
        {
            Caption = 'Filter Value';
        }
        field(34; "Filter Scope"; Text[30])
        {
            Caption = 'Filter Scope';
            // MobileNAV Filter Scope member: Online, Offline or Both.
        }
        field(35; "Multi Select"; Boolean)
        {
            Caption = 'Multi Select';
        }
        field(36; "Auto Refresh On Open"; Boolean)
        {
            Caption = 'Auto Refresh On Open';
        }
        field(37; "Propagation Type"; Text[30])
        {
            Caption = 'Propagation Type';
        }
        field(38; "Action Type"; Text[30])
        {
            Caption = 'Action Type';
            // MobileNAV D. L. Action Type member.
        }
        field(39; Color; Text[30])
        {
            Caption = 'Color';
            // MobileNAV color area member.
        }
        field(40; Icon; Code[20])
        {
            Caption = 'Icon';
        }
        field(41; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
        }
        field(42; Disabled; Boolean)
        {
            Caption = 'Disabled';
        }
        field(43; "Search Type"; Text[30])
        {
            Caption = 'Search Type';
            // MobileNAV Search Type member: BeginMatch, Equal or AnyMatch.
        }
        field(44; "Own Filter Set"; Boolean)
        {
            Caption = 'Own Filter Set';
        }
        field(45; "View Type"; Text[30])
        {
            Caption = 'View Type';
            // MobileNAV View Type member: List or Map.
        }
        field(46; "Operation Type"; Text[30])
        {
            Caption = 'Operation Type';
        }
        field(47; "Related Code Field"; Text[100])
        {
            Caption = 'Related Code Field';
        }
        field(48; "Related Description Field"; Text[100])
        {
            Caption = 'Related Description Field';
        }
        field(49; Description; Text[250])
        {
            Caption = 'Description';
        }
        field(50; Picture; Blob)
        {
            Caption = 'Picture';
        }
        field(53; "Menu Category"; Code[20])
        {
            Caption = 'Menu Category';
            // Profile Page only: the category the page's tile sits under in that profile.
        }
        field(52; "Show In Menu"; Boolean)
        {
            Caption = 'Show In Menu';
            // Published page only: give the page a tile on the device home menu. Pages reached
            // through a Link from another page leave this off.
        }
        field(51; "Picture Extension"; Text[10])
        {
            Caption = 'Picture Extension';
        }
        field(54; "Line Format No."; Integer)
        {
            Caption = 'Line Format No.';
            // Line Format only: MobileNAV's Setup Line No. 1 and 2 are the first and second line,
            // 3 to 8 the list cells.
        }
        field(55; "Line Format Position"; Integer)
        {
            Caption = 'Line Format Position';
            // Line Format only: the element's place in its line. The fingerprint sorts lines by
            // control name, so element order has to be a value of its own.
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    /// <summary>Filters to the control lines: Field, Function Field, Linked Field, Scan Field and Lookup Field.</summary>
    procedure SetControlFilter()
    begin
        this.SetFilter(Operation, '%1|%2|%3|%4|%5',
            Enum::"BJF MN Config Operation"::Field, Enum::"BJF MN Config Operation"::"Function Field",
            Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Scan Field",
            Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    /// <summary>Filters to the controls that open another page: Linked Field and Lookup Field.</summary>
    procedure SetRelationFilter()
    begin
        this.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    /// <summary>The distinct pages that have a line of the operation, in entry order. Clears the filters on the record.</summary>
    /// <param name="LineOperation">The operation to look for.</param>
    /// <returns>The page ids.</returns>
    procedure PageIdsWith(LineOperation: Enum "BJF MN Config Operation"): List of [Integer]
    begin
        this.Reset();
        this.SetRange(Operation, LineOperation);
        exit(this.CollectPageIds());
    end;

    /// <summary>The distinct pages that have a line of either operation, in entry order. Clears the filters on the record.</summary>
    /// <param name="FirstOperation">One operation to look for.</param>
    /// <param name="SecondOperation">The other operation to look for.</param>
    /// <returns>The page ids.</returns>
    procedure PageIdsWith(FirstOperation: Enum "BJF MN Config Operation"; SecondOperation: Enum "BJF MN Config Operation"): List of [Integer]
    begin
        this.Reset();
        this.SetFilter(Operation, '%1|%2', FirstOperation, SecondOperation);
        exit(this.CollectPageIds());
    end;

    /// <summary>The distinct pages that have a line of any operation, in entry order, without page 0. Clears the filters on the record.</summary>
    /// <returns>The page ids.</returns>
    procedure DeclaredPageIds(): List of [Integer]
    begin
        this.Reset();
        this.SetFilter("Page ID", '<>0');
        exit(this.CollectPageIds());
    end;

    local procedure CollectPageIds() PageIds: List of [Integer]
    begin
        if this.FindSet() then
            repeat
                if not PageIds.Contains(this."Page ID") then
                    PageIds.Add(this."Page ID");
            until this.Next() = 0;
        this.Reset();
        exit(PageIds);
    end;
}
