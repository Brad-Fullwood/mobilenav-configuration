namespace BradFullwood.MobileNAV.Configuration;

using System.Text;

/// <summary>
/// Captions per language and menu pictures. MobileNAV keeps captions in its CaptionML table,
/// one row per page, control and language (control 0 is the page itself), and a page's tile
/// picture on the Main row with a version counter devices use to know when to refetch it.
/// </summary>
codeunit 77760 "BJF MN Appearance Mgt."
{
    Access = Internal;
    Permissions = tabledata "MobileNAV CaptionML Admin." = rim,
        tabledata "MobileNAV Service Setup" = rm;

    /// <summary>Writes the caption. Errors when the control has no row.</summary>
    procedure SetCaption(ServiceName: Text[100]; ControlName: Text[100]; LanguageCode: Code[10]; CaptionText: Text[250])
    var
        CaptionML: Record "MobileNAV CaptionML Admin.";
        PageId: Integer;
        ControlId: Integer;
    begin
        this.GetCaptionKey(ServiceName, ControlName, PageId, ControlId);
        if CaptionML.Get(PageId, ControlId, LanguageCode) then begin
            if CaptionML."Caption ML" = CaptionText then
                exit;
            CaptionML.Validate("Caption ML", CaptionText);
            CaptionML.Modify(true);
            exit;
        end;
        CaptionML.Init();
        CaptionML.Validate("Page ID", PageId);
        CaptionML.Validate("Control ID", ControlId);
        CaptionML.Validate("Language Code", LanguageCode);
        CaptionML.Validate("Caption ML", CaptionText);
        CaptionML.Insert(true);
    end;

    /// <summary>The live caption; false when the control or the caption row does not exist.</summary>
    procedure GetCaption(ServiceName: Text[100]; ControlName: Text[100]; LanguageCode: Code[10]; var CaptionText: Text): Boolean
    var
        CaptionML: Record "MobileNAV CaptionML Admin.";
        PageId: Integer;
        ControlId: Integer;
    begin
        if not this.TryGetCaptionKey(ServiceName, ControlName, PageId, ControlId) then
            exit(false);
        if not CaptionML.Get(PageId, ControlId, LanguageCode) then
            exit(false);
        CaptionText := CaptionML."Caption ML";
        exit(true);
    end;

    /// <summary>Writes the picture when it differs from the live one, bumping the version devices watch.</summary>
    procedure SetMenuPicture(ServiceName: Text[100]; var PictureLine: Record "BJF MN Config Line" temporary)
    var
        MainRow: Record "MobileNAV Service Setup";
        PictureIn: InStream;
        PictureOut: OutStream;
    begin
        if not this.Lookup.FindMainRow(ServiceName, MainRow) then
            Error(this.ServiceMissingErr, ServiceName);
        if this.MenuPictureMatches(MainRow, PictureLine) then
            exit;
        PictureLine.CalcFields(Picture);
        PictureLine.Picture.CreateInStream(PictureIn);
        Clear(MainRow."Menu Picture");
        MainRow."Menu Picture".CreateOutStream(PictureOut);
        CopyStream(PictureOut, PictureIn);
#pragma warning disable PC0037
        MainRow."Menu Picture Extension" := PictureLine."Picture Extension";
        MainRow."Menu Picture Version" += 1;
#pragma warning restore PC0037
        MainRow.Modify(true);
    end;

    procedure MenuPictureMatches(var MainRow: Record "MobileNAV Service Setup"; var PictureLine: Record "BJF MN Config Line" temporary): Boolean
    var
        Base64Convert: Codeunit "Base64 Convert";
        MainIn: InStream;
        LineIn: InStream;
        MainBase64: Text;
        LineBase64: Text;
    begin
        if MainRow."Menu Picture Extension" <> PictureLine."Picture Extension" then
            exit(false);
        MainRow.CalcFields("Menu Picture");
        if MainRow."Menu Picture".HasValue() then begin
            MainRow."Menu Picture".CreateInStream(MainIn);
            MainBase64 := Base64Convert.ToBase64(MainIn);
        end;
        PictureLine.CalcFields(Picture);
        if PictureLine.Picture.HasValue() then begin
            PictureLine.Picture.CreateInStream(LineIn);
            LineBase64 := Base64Convert.ToBase64(LineIn);
        end;
        exit(MainBase64 = LineBase64);
    end;

    local procedure GetCaptionKey(ServiceName: Text[100]; ControlName: Text[100]; var PageId: Integer; var ControlId: Integer)
    begin
        if not this.TryGetCaptionKey(ServiceName, ControlName, PageId, ControlId) then
            Error(this.ControlMissingErr, ControlName, ServiceName);
    end;

    local procedure TryGetCaptionKey(ServiceName: Text[100]; ControlName: Text[100]; var PageId: Integer; var ControlId: Integer): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        if not this.Lookup.FindMainRow(ServiceName, ServiceSetup) then
            exit(false);
        PageId := ServiceSetup."Object ID";
        ControlId := 0;
        if ControlName = '' then
            exit(true);
        if not this.Lookup.FindFieldRow(ServiceName, ControlName, ServiceSetup) then
            exit(false);
        ControlId := ServiceSetup.ControlID;
        exit(true);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        ServiceMissingErr: Label 'MobileNAV service %1 is not registered.', Comment = '%1 = service name';
        ControlMissingErr: Label 'Control %1 was not found on MobileNAV service %2.', Comment = '%1 = control name (empty for the page), %2 = service name';
}
