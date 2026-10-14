namespace BradFullwood.MobileNAV.Configuration;

using System.Text;

/// <summary>
/// Reads the pictures that MobileNAV keeps for the menu tiles and the buttons, and encodes them for
/// the device emulator. A menu tile takes the picture of the Main row of its service, a button the
/// picture of its Field row, both in MobileNAV Service Setup. The picture goes out as base64 with its
/// file type. A picture above the size limit or of another file type is left out, so the emulator
/// draws its neutral glyph instead. Nothing is written.
/// </summary>
codeunit 77775 "BJF MN Emulator Pictures"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    /// <summary>Adds the picture of a menu tile to the tile object.</summary>
    /// <param name="ServiceName">The service of the tile.</param>
    /// <param name="Target">The tile object. Receives picture and pictureType when the service has a picture.</param>
    procedure AddTilePicture(ServiceName: Text; var Target: JsonObject)
    begin
        this.AddPicture(ServiceName, '', true, Target);
    end;

    /// <summary>Adds the picture of a button to the action object.</summary>
    /// <param name="ServiceName">The service of the card.</param>
    /// <param name="FieldName">The field of the button.</param>
    /// <param name="Target">The action object. Receives picture and pictureType when the field has a picture.</param>
    procedure AddButtonPicture(ServiceName: Text; FieldName: Text; var Target: JsonObject)
    begin
        this.AddPicture(ServiceName, FieldName, false, Target);
    end;

    /// <summary>
    /// Finds the Service Setup row of a picture, the Main row for a tile or the Field row for a button, and
    /// adds its picture when it is a picture type the device shows and is not above the size limit.
    /// </summary>
    /// <param name="ServiceName">The service of the picture.</param>
    /// <param name="FieldName">The field of a button. Not used for a tile.</param>
    /// <param name="IsMain">True for the picture of a tile, false for the picture of a button.</param>
    /// <param name="Target">The object that receives picture and pictureType.</param>
    local procedure AddPicture(ServiceName: Text; FieldName: Text; IsMain: Boolean; var Target: JsonObject)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        Base64Convert: Codeunit "Base64 Convert";
        PictureStream: InStream;
        Extension: Text;
    begin
        if ServiceName = '' then
            exit;
        ServiceSetup.SetLoadFields("Menu Picture Extension");
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", CopyStr(ServiceName, 1, MaxStrLen(ServiceSetup."Service Name")));
        if IsMain then begin
            ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
            ServiceSetup.SetRange(FieldName);
        end else begin
            ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Field);
            ServiceSetup.SetRange(FieldName, CopyStr(FieldName, 1, MaxStrLen(ServiceSetup.FieldName)));
        end;
        if not ServiceSetup.FindFirst() then
            exit;
        ServiceSetup.CalcFields("Menu Picture");
        if not ServiceSetup."Menu Picture".HasValue() then
            exit;
        if ServiceSetup."Menu Picture".Length() > this.MaxPictureBytes() then
            exit;
        Extension := LowerCase(ServiceSetup."Menu Picture Extension");
        if not this.IsShownType(Extension) then
            exit;
        ServiceSetup."Menu Picture".CreateInStream(PictureStream);
        Target.Add('picture', Base64Convert.ToBase64(PictureStream));
        Target.Add('pictureType', Extension);
    end;

    /// <summary>Tells whether the device emulator shows a picture of this file type.</summary>
    /// <param name="Extension">The file extension in lower case, without the dot.</param>
    /// <returns>True for png, jpg, jpeg, gif and svg.</returns>
    local procedure IsShownType(Extension: Text): Boolean
    begin
        exit(Extension in ['png', 'jpg', 'jpeg', 'gif', 'svg']);
    end;

    /// <summary>The largest picture that goes into a response, in bytes. A larger picture is left out.</summary>
    /// <returns>The size limit: 256 KB.</returns>
    local procedure MaxPictureBytes(): Integer
    begin
        exit(262144);
    end;
}
