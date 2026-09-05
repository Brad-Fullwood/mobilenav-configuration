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
        this.Add(CheckType, FindingSeverity, MsgText, BlankRecordId);
    end;

    procedure Add(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId)
    begin
        Rec.Init();
        Rec.Validate("Check Type", CheckType);
        Rec.Validate(Severity, FindingSeverity);
        Rec.Validate(Message, CopyStr(MsgText, 1, MaxStrLen(Rec.Message)));
        Rec.Validate("Related Record ID", RelatedRecordId);
        Rec.Validate("User ID", CopyStr(UserId(), 1, MaxStrLen(Rec."User ID")));
        Rec.Insert(false);
    end;

    /// <summary>Adds a finding the check can repair; the findings list offers Apply Fix on it.</summary>
    procedure AddWithFix(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId; FixDescriptionText: Text)
    begin
        this.AddWithFix(CheckType, FindingSeverity, MsgText, RelatedRecordId, FixDescriptionText, '');
    end;

    /// <summary>As AddWithFix, with an opaque context the check's ApplyFix reads back when no record anchors the fix.</summary>
    procedure AddWithFix(CheckType: Enum "BJF Diagnostic Check Type"; FindingSeverity: Enum "BJF Diagnostic Severity"; MsgText: Text; RelatedRecordId: RecordId; FixDescriptionText: Text; FixContext: Text)
    begin
        this.Add(CheckType, FindingSeverity, MsgText, RelatedRecordId);
        Rec.Validate(Fixable, true);
        Rec.Validate("Fix Description", CopyStr(FixDescriptionText, 1, MaxStrLen(Rec."Fix Description")));
        Rec.Validate("Fix Context", CopyStr(FixContext, 1, MaxStrLen(Rec."Fix Context")));
        Rec.Modify(false);
    end;
}
