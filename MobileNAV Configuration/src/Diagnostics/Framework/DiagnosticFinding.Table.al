namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A finding from a diagnostic check, listed on the Diagnostic Findings page.</summary>
table 77761 "BJF Diagnostic Finding"
{
    Access = Public;
    Caption = 'Diagnostic Finding';
    DataClassification = CustomerContent;
    Permissions = tabledata "BJF Diagnostic Finding" = im;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
            AllowInCustomizations = Never;
        }
        field(2; "Check Type"; Enum "BJF Diagnostic Check Type")
        {
            Caption = 'Check';
            Editable = false;
            ToolTip = 'Specifies which diagnostic check produced the finding.';
        }
        field(3; Severity; Enum "BJF Diagnostic Severity")
        {
            Caption = 'Severity';
            Editable = false;
            ToolTip = 'Specifies how serious the finding is. Blockers break a MobileNAV device flow.';
        }
        field(4; Message; Text[2048])
        {
            Caption = 'Message';
            Editable = false;
            ToolTip = 'Specifies the finding. Drill down on the list to read the full text.';
        }
        field(5; "Related Record ID"; RecordId)
        {
            Caption = 'Related Record ID';
            Editable = false;
        }
        field(6; Fixable; Boolean)
        {
            Caption = 'Fix Available';
            Editable = false;
            ToolTip = 'Specifies whether the check that produced this finding can repair it automatically with the Apply Fix action.';
        }
        field(7; "Fix Description"; Text[250])
        {
            Caption = 'Fix Description';
            Editable = false;
            ToolTip = 'Specifies what the Apply Fix action will do for this finding.';
        }
        field(8; "Fix Context"; Text[250])
        {
            Caption = 'Fix Context';
            Editable = false;
            AllowInCustomizations = Never;
        }
        field(9; "User ID"; Code[50])
        {
            Caption = 'User ID';
            Editable = false;
            AllowInCustomizations = Never;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Severity; Severity) { }
        key(UserId; "User ID") { }
    }

    /// <summary>Adds a finding with no related record and no fix.</summary>
    /// <param name="CheckType">The check that produced the finding.</param>
    /// <param name="FindingSeverity">How serious the finding is.</param>
    /// <param name="MsgText">The finding text, cut to the field length.</param>
    procedure Add(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text)
    var
        BlankRecordId: RecordId;
    begin
        this.Add(CheckType, FindingSeverity, MsgText, BlankRecordId);
    end;

    /// <summary>Adds a finding about a record, with no fix.</summary>
    /// <param name="CheckType">The check that produced the finding.</param>
    /// <param name="FindingSeverity">How serious the finding is.</param>
    /// <param name="MsgText">The finding text, cut to the field length.</param>
    /// <param name="RelatedRecordId">The record the finding is about.</param>
    procedure Add(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId)
    begin
        Rec.Init();
        Rec.Validate("Entry No.", 0); // Init keeps primary key fields; 0 lets AutoIncrement assign a new number
        Rec.Validate("Check Type", CheckType);
        Rec.Validate(Severity, FindingSeverity);
        Rec.Validate(Message, CopyStr(MsgText, 1, MaxStrLen(Rec.Message)));
        Rec.Validate("Related Record ID", RelatedRecordId);
        Rec.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(Rec."User ID")));
        Rec.Insert(false);
    end;

    /// <summary>Adds a finding the check can repair; the findings list offers Apply Fix on it.</summary>
    /// <param name="CheckType">The check that produced the finding.</param>
    /// <param name="FindingSeverity">How serious the finding is.</param>
    /// <param name="MsgText">The finding text, cut to the field length.</param>
    /// <param name="RelatedRecordId">The record the finding is about, or a blank RecordId.</param>
    /// <param name="FixDescriptionText">What the Apply Fix action will do.</param>
    procedure AddWithFix(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId; FixDescriptionText: Text)
    begin
        this.AddWithFix(CheckType, FindingSeverity, MsgText, RelatedRecordId, FixDescriptionText, '');
    end;

    /// <summary>As AddWithFix, with an opaque context the check's ApplyFix reads back when no record anchors the fix.</summary>
    /// <param name="CheckType">The check that produced the finding.</param>
    /// <param name="FindingSeverity">How serious the finding is.</param>
    /// <param name="MsgText">The finding text, cut to the field length.</param>
    /// <param name="RelatedRecordId">The record the finding is about, or a blank RecordId.</param>
    /// <param name="FixDescriptionText">What the Apply Fix action will do.</param>
    /// <param name="FixContext">Opaque text that the check's ApplyFix reads back.</param>
    procedure AddWithFix(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId; FixDescriptionText: Text; FixContext: Text)
    begin
        this.Add(CheckType, FindingSeverity, MsgText, RelatedRecordId);
        Rec.Validate(Fixable, true);
        Rec.Validate("Fix Description", CopyStr(FixDescriptionText, 1, MaxStrLen(Rec."Fix Description")));
        Rec.Validate("Fix Context", CopyStr(FixContext, 1, MaxStrLen(Rec."Fix Context")));
        Rec.Modify(false);
    end;
}
