namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A part of a list row or card a dynamic layout can color. The names are MobileNAV's own action types without the Color suffix.</summary>
enum 77767 "BJF MN Layout Area"
{
    Access = Public;
    Extensible = false;

    value(0; FirstLine) { Caption = 'First Line'; }
    value(1; SecondLine) { Caption = 'Second Line'; }
    value(2; TopLeft) { Caption = 'Top Left'; }
    value(3; MiddleLeft) { Caption = 'Middle Left'; }
    value(4; BottomLeft) { Caption = 'Bottom Left'; }
    value(5; TopRight) { Caption = 'Top Right'; }
    value(6; MiddleRight) { Caption = 'Middle Right'; }
    value(7; BottomRight) { Caption = 'Bottom Right'; }
    value(8; Background) { Caption = 'Background'; }
}
