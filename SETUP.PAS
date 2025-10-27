program Setup;

{$G+}  { Enable 286 instructions }

uses Dos;

const
  { Box drawing characters (IBM ASCII) }
  CH_TL = #218;  { Top-left corner }
  CH_TR = #191;  { Top-right corner }
  CH_BL = #192;  { Bottom-left corner }
  CH_BR = #217;  { Bottom-right corner }
  CH_H  = #196;  { Horizontal line }
  CH_V  = #179;  { Vertical line }
  CH_VR = #195;  { Vertical-right }
  CH_VL = #180;  { Vertical-left }
  CH_HU = #193;  { Horizontal-up }
  CH_HD = #194;  { Horizontal-down }
  CH_X  = #197;  { Cross }

  { Colors }
  CLR_NORMAL   = 7;   { Light gray }
  CLR_HIGHLIGHT = 15; { White }
  CLR_SELECTED = 14;  { Yellow }
  CLR_TITLE = 11;     { Cyan }
  CLR_BOX = 3;        { Cyan }

  { Sound card types }
  SND_NONE = 0;
  SND_ADLIB = 1;
  SND_SOUNDBLASTER = 2;

  CONFIG_FILE = 'SOUND.CFG';

type
  TSoundConfig = record
    CardType: Byte;      { 0=None, 1=Adlib, 2=SoundBlaster }
    SBPort: Word;        { SoundBlaster port (e.g., $220) }
    SBIRQ: Byte;         { SoundBlaster IRQ (e.g., 5) }
    SBDMA: Byte;         { SoundBlaster DMA (e.g., 1) }
  end;

var
  Config: TSoundConfig;
  Modified: Boolean;

{ Keyboard functions }
function KeyPressed: Boolean; assembler;
asm
  mov ah, 01h
  int 16h
  jz @NoKey
  mov al, 1
  jmp @Done
@NoKey:
  xor al, al
@Done:
end;

function ReadKey: Char; assembler;
asm
  xor ah, ah     { Function 00h: Read key }
  int 16h        { Returns: AL=ASCII, AH=scan code }
  { AL is automatically the function result (Char) }
end;

{ Screen functions }
procedure GotoXY(X, Y: Byte); assembler;
asm
  mov ah, 02h
  mov bh, 0
  mov dh, Y
  dec dh
  mov dl, X
  dec dl
  int 10h
end;

procedure TextColor(Color: Byte); assembler;
asm
  mov ah, 09h
  mov al, ' '
  mov bh, 0
  mov bl, Color
  mov cx, 1
  int 10h
end;

procedure ClrScr; assembler;
asm
  mov ax, 0003h
  int 10h
end;

procedure WriteChar(C: Char; Color: Byte);
begin
  asm
    mov ah, 09h
    mov al, C
    mov bh, 0
    mov bl, Color
    mov cx, 1
    int 10h
  end;
  { Move cursor forward }
  asm
    mov ah, 03h
    mov bh, 0
    int 10h
    inc dl
    mov ah, 02h
    int 10h
  end;
end;

procedure WriteStr(const S: string; Color: Byte);
var
  i: Integer;
begin
  for i := 1 to Length(S) do
    WriteChar(S[i], Color);
end;

{ Draw box }
procedure DrawBox(X, Y, W, H: Byte; Color: Byte);
var
  i: Integer;
begin
  { Top line }
  GotoXY(X, Y);
  WriteChar(CH_TL, Color);
  for i := 1 to W - 2 do
    WriteChar(CH_H, Color);
  WriteChar(CH_TR, Color);

  { Sides }
  for i := 1 to H - 2 do
  begin
    GotoXY(X, Y + i);
    WriteChar(CH_V, Color);
    GotoXY(X + W - 1, Y + i);
    WriteChar(CH_V, Color);
  end;

  { Bottom line }
  GotoXY(X, Y + H - 1);
  WriteChar(CH_BL, Color);
  for i := 1 to W - 2 do
    WriteChar(CH_H, Color);
  WriteChar(CH_BR, Color);
end;

{ Clear inside box }
procedure ClearBox(X, Y, W, H: Byte);
var
  i, j: Integer;
begin
  for j := 1 to H - 2 do
  begin
    GotoXY(X + 1, Y + j);
    for i := 1 to W - 2 do
      WriteChar(' ', CLR_NORMAL);
  end;
end;

{ Load config from file }
procedure LoadConfig;
var
  F: File;
begin
  { Defaults }
  Config.CardType := SND_NONE;
  Config.SBPort := $220;
  Config.SBIRQ := 5;
  Config.SBDMA := 1;

  { Try to load existing config }
  Assign(F, CONFIG_FILE);
  {$I-}
  Reset(F, 1);
  {$I+}
  if IOResult = 0 then
  begin
    BlockRead(F, Config, SizeOf(Config));
    Close(F);
  end;

  Modified := False;
end;

{ Save config to file }
procedure SaveConfig;
var
  F: File;
begin
  Assign(F, CONFIG_FILE);
  {$I-}
  Rewrite(F, 1);
  {$I+}
  if IOResult = 0 then
  begin
    BlockWrite(F, Config, SizeOf(Config));
    Close(F);
    Modified := False;
  end;
end;

{ Get card name }
function GetCardName(CardType: Byte): string;
begin
  case CardType of
    SND_NONE: GetCardName := 'None';
    SND_ADLIB: GetCardName := 'Adlib';
    SND_SOUNDBLASTER: GetCardName := 'Sound Blaster';
  else
    GetCardName := 'Unknown';
  end;
end;

{ Draw title }
procedure DrawTitle;
begin
  GotoXY(1, 1);
  WriteStr('              DOS GAME ENGINE - SOUND SETUP              ', CLR_TITLE);
  GotoXY(1, 2);
  WriteStr('=========================================================', CLR_TITLE);
end;

{ Card selection menu }
function SelectCardMenu: Byte;
var
  Selection: Byte;
  Key: Char;
  ExtKey: Char;
  Done: Boolean;
begin
  Selection := Config.CardType;
  Done := False;

  repeat
    { Draw selection box }
    DrawBox(25, 8, 30, 10, CLR_BOX);
    ClearBox(25, 8, 30, 10);
    GotoXY(28, 9);
    WriteStr('SELECT SOUND CARD', CLR_TITLE);

    { Draw options }
    GotoXY(27, 11);
    if Selection = SND_NONE then
      WriteStr('> None           ', CLR_SELECTED)
    else
      WriteStr('  None           ', CLR_NORMAL);

    GotoXY(27, 12);
    if Selection = SND_ADLIB then
      WriteStr('> Adlib          ', CLR_SELECTED)
    else
      WriteStr('  Adlib          ', CLR_NORMAL);

    GotoXY(27, 13);
    if Selection = SND_SOUNDBLASTER then
      WriteStr('> Sound Blaster  ', CLR_SELECTED)
    else
      WriteStr('  Sound Blaster  ', CLR_NORMAL);

    { Instructions }
    GotoXY(27, 15);
    WriteStr('W/S - Select', CLR_NORMAL);
    GotoXY(27, 16);
    WriteStr('ENTER - Choose', CLR_NORMAL);

    { Wait for key }
    Key := ReadKey;

    case Key of
      'w', 'W': begin  { Up }
                  if Selection > SND_NONE then Dec(Selection);
                end;
      's', 'S': begin  { Down }
                  if Selection < SND_SOUNDBLASTER then Inc(Selection);
                end;
      #13: Done := True;  { Enter }
      #27: begin  { ESC }
             Selection := Config.CardType;  { Cancel }
             Done := True;
           end;
    end;

  until Done;

  SelectCardMenu := Selection;
end;

{ Edit SoundBlaster settings }
procedure EditSBSettings;
var
  Field: Byte;  { 0=Port, 1=IRQ, 2=DMA, 3=Save & Back }
  Key: Char;
  ExtKey: Char;
  Done: Boolean;
  TempPort: Word;
  TempIRQ, TempDMA: Byte;
  PortStr, IRQStr, DMAStr: string;
  i: Integer;

  procedure UpdateDisplay;
  begin
    { Draw settings box }
    DrawBox(20, 8, 40, 16, CLR_BOX);
    ClearBox(20, 8, 40, 16);
    GotoXY(23, 9);
    WriteStr('SOUND BLASTER SETTINGS', CLR_TITLE);

    { Port }
    GotoXY(22, 11);
    if Field = 0 then
      WriteStr('> Port (hex): $' + PortStr + '   ', CLR_SELECTED)
    else
      WriteStr('  Port (hex): $' + PortStr + '   ', CLR_NORMAL);

    { IRQ }
    GotoXY(22, 13);
    if Field = 1 then
      WriteStr('> IRQ: ' + IRQStr + '   ', CLR_SELECTED)
    else
      WriteStr('  IRQ: ' + IRQStr + '   ', CLR_NORMAL);

    { DMA }
    GotoXY(22, 15);
    if Field = 2 then
      WriteStr('> DMA: ' + DMAStr + '   ', CLR_SELECTED)
    else
      WriteStr('  DMA: ' + DMAStr + '   ', CLR_NORMAL);

    { Save & Back button }
    GotoXY(22, 18);
    if Field = 3 then
      WriteStr('> [ Save & Back ]       ', CLR_SELECTED)
    else
      WriteStr('  [ Save & Back ]       ', CLR_NORMAL);

    { Instructions }
    GotoXY(22, 20);
    WriteStr('W/S        - Select field', CLR_NORMAL);
    GotoXY(22, 21);
    WriteStr('0-9/A-F    - Edit value', CLR_NORMAL);
    GotoXY(22, 22);
    WriteStr('BACKSPACE  - Delete', CLR_NORMAL);
  end;

begin
  Field := 0;
  Done := False;
  TempPort := Config.SBPort;
  TempIRQ := Config.SBIRQ;
  TempDMA := Config.SBDMA;

  { Convert to strings }
  Str(TempPort, PortStr);
  { Convert port to hex string }
  PortStr := '';
  for i := 3 downto 0 do
    PortStr := PortStr + Chr(48 + ((TempPort shr (i * 4)) and $F) +
               (Ord(((TempPort shr (i * 4)) and $F) > 9) * 7));

  Str(TempIRQ, IRQStr);
  Str(TempDMA, DMAStr);

  repeat
    UpdateDisplay;

    Key := ReadKey;

    case Key of
      'w', 'W': begin  { Up }
                  if Field > 0 then Dec(Field);
                end;
      's', 'S': begin  { Down }
                  if Field < 3 then Inc(Field);
                end;
      #13: begin  { Enter }
             if Field = 3 then
             begin
               { Parse values }
               TempPort := 0;
               for i := 1 to Length(PortStr) do
               begin
                 TempPort := TempPort * 16;
                 if (PortStr[i] >= '0') and (PortStr[i] <= '9') then
                   TempPort := TempPort + Ord(PortStr[i]) - 48
                 else if (PortStr[i] >= 'A') and (PortStr[i] <= 'F') then
                   TempPort := TempPort + Ord(PortStr[i]) - 55;
               end;

               TempIRQ := 0;
               for i := 1 to Length(IRQStr) do
                 TempIRQ := TempIRQ * 10 + Ord(IRQStr[i]) - 48;

               TempDMA := 0;
               for i := 1 to Length(DMAStr) do
                 TempDMA := TempDMA * 10 + Ord(DMAStr[i]) - 48;

               { Save }
               Config.SBPort := TempPort;
               Config.SBIRQ := TempIRQ;
               Config.SBDMA := TempDMA;
               Modified := True;
               Done := True;
             end;
           end;
      #27: Done := True;  { ESC - cancel }
      #8: begin  { Backspace }
            case Field of
              0: if Length(PortStr) > 0 then Delete(PortStr, Length(PortStr), 1);
              1: if Length(IRQStr) > 0 then Delete(IRQStr, Length(IRQStr), 1);
              2: if Length(DMAStr) > 0 then Delete(DMAStr, Length(DMAStr), 1);
            end;
          end;
      '0'..'9', 'A'..'F', 'a'..'f':
        begin
          { Convert lowercase to uppercase }
          if (Key >= 'a') and (Key <= 'f') then
            Key := Chr(Ord(Key) - 32);

          case Field of
            0: if Length(PortStr) < 4 then PortStr := PortStr + Key;
            1: if (Length(IRQStr) < 2) and (Key >= '0') and (Key <= '9') then
                 IRQStr := IRQStr + Key;
            2: if (Length(DMAStr) < 2) and (Key >= '0') and (Key <= '9') then
                 DMAStr := DMAStr + Key;
          end;
        end;
    end;

  until Done;
end;

{ Main menu }
procedure MainMenu;
var
  Selection: Byte;
  Key: Char;
  ExtKey: Char;
  Done: Boolean;
  NewCard: Byte;
begin
  Selection := 0;
  Done := False;

  repeat
    ClrScr;
    DrawTitle;

    { Main box }
    DrawBox(15, 5, 50, 14, CLR_BOX);
    GotoXY(25, 6);
    WriteStr('SOUND CONFIGURATION', CLR_TITLE);

    { Menu items }
    GotoXY(17, 9);
    if Selection = 0 then
      WriteStr('> Sound Card: ' + GetCardName(Config.CardType) + '          ', CLR_SELECTED)
    else
      WriteStr('  Sound Card: ' + GetCardName(Config.CardType) + '          ', CLR_NORMAL);

    { Show SB settings if selected }
    if Config.CardType = SND_SOUNDBLASTER then
    begin
      GotoXY(19, 10);
      WriteStr('Port: $', CLR_NORMAL);
      { Show port in hex }
      WriteChar(Chr(48 + ((Config.SBPort shr 8) shr 4) +
                (Ord(((Config.SBPort shr 8) shr 4) > 9) * 7)), CLR_NORMAL);
      WriteChar(Chr(48 + ((Config.SBPort shr 8) and $F) +
                (Ord(((Config.SBPort shr 8) and $F) > 9) * 7)), CLR_NORMAL);
      WriteChar(Chr(48 + ((Config.SBPort and $FF) shr 4) +
                (Ord(((Config.SBPort and $FF) shr 4) > 9) * 7)), CLR_NORMAL);
      WriteChar(Chr(48 + ((Config.SBPort and $FF) and $F) +
                (Ord(((Config.SBPort and $FF) and $F) > 9) * 7)), CLR_NORMAL);
      WriteStr('  IRQ: ', CLR_NORMAL);
      WriteChar(Chr(48 + Config.SBIRQ div 10), CLR_NORMAL);
      WriteChar(Chr(48 + Config.SBIRQ mod 10), CLR_NORMAL);
      WriteStr('  DMA: ', CLR_NORMAL);
      WriteChar(Chr(48 + Config.SBDMA), CLR_NORMAL);
    end;

    GotoXY(17, 13);
    if Selection = 1 then
      WriteStr('> Save & Exit                       ', CLR_SELECTED)
    else
      WriteStr('  Save & Exit                       ', CLR_NORMAL);

    GotoXY(17, 15);
    if Selection = 2 then
      WriteStr('> Exit Without Saving               ', CLR_SELECTED)
    else
      WriteStr('  Exit Without Saving               ', CLR_NORMAL);

    { Instructions }
    GotoXY(17, 18);
    WriteStr('W/S - Select    ENTER - Choose    ESC - Exit', CLR_NORMAL);

    { Wait for key }
    Key := ReadKey;

    case Key of
      'w', 'W': begin  { Up }
                  if Selection > 0 then Dec(Selection);
                end;
      's', 'S': begin  { Down }
                  if Selection < 2 then Inc(Selection);
                end;
      #13: begin  { Enter }
             case Selection of
               0: begin
                    NewCard := SelectCardMenu;
                    if NewCard <> Config.CardType then
                    begin
                      Config.CardType := NewCard;
                      Modified := True;

                      { If SoundBlaster selected, configure it }
                      if NewCard = SND_SOUNDBLASTER then
                        EditSBSettings;
                    end;
                  end;
               1: begin
                    SaveConfig;
                    Done := True;
                  end;
               2: Done := True;
             end;
           end;
      #27: Done := True;  { ESC }
    end;

  until Done;
end;

begin
  ClrScr;
  LoadConfig;
  MainMenu;

  { Final message }
  ClrScr;
  if Modified then
    WriteLn('Configuration saved to ', CONFIG_FILE)
  else
    WriteLn('Configuration not changed.');
end.
