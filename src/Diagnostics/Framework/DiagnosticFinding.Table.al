namespace BradFullwood.MobileNAV.Configuration;

table 77761 "BJF Diagnostic Finding"
{
    Access = Public;
    Caption = 'Diagnostic Finding';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(2; "Check Type"; Enum "BJF Diagnostic Check Type")
        {
            Caption = 'Check';
            Editable = false;
        }
        field(3; Severity; Enum "BJF Diagnostic Severity")
        {
            Caption = 'Severity';
            Editable = false;
        }
        field(4; Message; Text[2048])
        {
            Caption = 'Message';
            Editable = false;
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
        }
        field(7; "Fix Description"; Text[250])
        {
            Caption = 'Fix Description';
            Editable = false;
        }
        field(8; "Fix Context"; Text[250])
        {
            Caption = 'Fix Context';
            Editable = false;
        }
        field(9; "User ID"; Code[50])
        {
            Caption = 'User ID';
            Editable = false;
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

    procedure Add(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text)
    var
        BlankRecordId: RecordId;
    begin
        Add(CheckType, FindingSeverity, MsgText, BlankRecordId);
    end;

    procedure Add(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId)
    begin
        Rec.Init();
        Rec."Entry No." := 0; // AutoIncrement
        Rec."Check Type" := CheckType;
        Rec.Severity := FindingSeverity;
        Rec.Message := CopyStr(MsgText, 1, MaxStrLen(Rec.Message));
        Rec."Related Record ID" := RelatedRecordId;
        Rec."User ID" := CopyStr(UserId(), 1, MaxStrLen(Rec."User ID"));
        Rec.Insert();
    end;

    /// <summary>
    /// Adds a finding that the contributing check can repair: the findings list offers
    /// "Apply Fix" on the line and dispatches back to the check's ApplyFix implementation.
    /// </summary>
    procedure AddWithFix(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId; FixDescriptionText: Text)
    begin
        AddWithFix(CheckType, FindingSeverity, MsgText, RelatedRecordId, FixDescriptionText, '');
    end;

    /// <summary>
    /// As AddWithFix, additionally carrying an opaque context value (for example a key) that
    /// the check's ApplyFix reads back. Use when the fix target has no record to anchor the
    /// Related Record ID to, or the related record may vanish before the fix runs.
    /// </summary>
    procedure AddWithFix(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId; FixDescriptionText: Text; FixContext: Text)
    begin
        Add(CheckType, FindingSeverity, MsgText, RelatedRecordId);
        Rec.Fixable := true;
        Rec."Fix Description" := CopyStr(FixDescriptionText, 1, MaxStrLen(Rec."Fix Description"));
        Rec."Fix Context" := CopyStr(FixContext, 1, MaxStrLen(Rec."Fix Context"));
        Rec.Modify();
    end;
}
