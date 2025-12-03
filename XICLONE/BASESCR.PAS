unit BaseScr;

interface

uses
  VGA, VGAFont, VGAUI, GameUnit, XiStyle;

type
  PBaseScreen = ^TBaseScreen;
  TBaseScreen = object(TScreen)

    { UI related }
    DialogBackgroundBuffer: PFrameBuffer;  
    DialogImage: PImage;
    UI: TUIManager;
    CustomStyle: TXiStyle;

    { Fonts }
    FontLarge: PFont;
    FontSmall: PFont;

    { Palette }
    Palette: PPalette;    

    constructor Init(G: PGame);
    destructor Done; virtual;
    procedure Update(DT: Real); virtual;
  end;

implementation


constructor TBaseScreen.Init(G: PGame);
begin
  inherited Init(G);
  FontLarge   := G^.ResMan.GetFont('large');
  FontSmall   := G^.ResMan.GetFont('small');
  DialogImage := G^.ResMan.GetImage('dialog');
end;

destructor TBaseScreen.Done;
begin
end;

procedure TBaseScreen.Update(DT: Real);
begin
end;

end.