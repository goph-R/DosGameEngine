unit XIRender;

interface

uses VGA, XITypes, DRect, VGAPrint, StrUtil, VGAFont;

{ Initialize renderer with required resources }
procedure InitRenderer(BgBuf, BackBuf: PFrameBuffer; const GemImg: TImage);

{ Low-level gem drawing }
procedure DrawGem(GemColor: TGemColor; X, Y: Integer);
procedure DrawGemFlash(GemColor: TGemColor; X, Y: Integer; FlashOn: Boolean);

{ High-level rendering }
procedure RenderPlayfield(var Field: TPlayfield; FlashActive: Boolean; FlashTimer: Real;
                          const FlashTiles: array of Boolean);
procedure RenderStack(const Stack: TGemStack; var LastX: Integer; var LastY: Real);
procedure RenderNextStack(const NextGems: array of TGemColor);
procedure RenderHUD(FPS: Integer; ShowFPS: Boolean; ShowMem: Boolean; Score: LongInt; Level, Blocks: Integer;
                    var LastScore: LongInt; var LastLevel, LastBlocks: Integer;
                    var FontLarge, FontSmall: TFont);

{ Dialog rendering }
procedure RenderDialogBackground(FrameBuffer: PFrameBuffer);

implementation

var
  BackgroundBuffer: PFrameBuffer;
  BackBuffer: PFrameBuffer;
  GemsImage: TImage;

procedure InitRenderer(BgBuf, BackBuf: PFrameBuffer; const GemImg: TImage);
begin
  BackgroundBuffer := BgBuf;
  BackBuffer := BackBuf;
  GemsImage := GemImg;
end;

procedure DrawGem(GemColor: TGemColor; X, Y: Integer);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  { Step 1: ALWAYS restore the background first }
  { This wipes whatever 'ghost' data (exploded gems, etc) is in this spot }
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  CopyFrameBufferRect(BackgroundBuffer, GemRect, BackBuffer, X, GemRect.Y);

  { Step 2: If it's empty, we are done (background is already restored) }
  if GemColor = Gem_Empty then Exit;

  { Calculate gem sprite index }
  GemIndex := Ord(GemColor);

  { Setup source rectangle in gem sprite sheet }
  GemRect.X := GemIndex * TileSize;
  GemRect.Y := 0;

  { Step 3: Draw gem sprite over the clean background }
  PutImageRect(GemsImage, GemRect, X, Y, True, BackBuffer);
end;

procedure DrawGemFlash(GemColor: TGemColor; X, Y: Integer; FlashOn: Boolean);
var
  GemRect: TRectangle;
  GemIndex: Integer;
begin
  GemRect.X := X;
  GemRect.Y := Y;
  GemRect.Width := TileSize;
  GemRect.Height := TileSize;

  if FlashOn then
  begin
    { Show the gem when flash is on }
    GemIndex := Ord(GemColor);
    GemRect.X := GemIndex * TileSize;
    GemRect.Y := 0;
    GemRect.Width := TileSize;
    GemRect.Height := TileSize;
    PutImageRect(GemsImage, GemRect, X, Y, True, BackBuffer);
  end
  else
  begin
    { Show background when flash is off (gem disappears) }
    GemRect.X := X;
    GemRect.Y := Y;
    CopyFrameBufferRect(BackgroundBuffer, GemRect, BackBuffer, X, Y);
  end;
end;

procedure RenderPlayfield(var Field: TPlayfield; FlashActive: Boolean; FlashTimer: Real;
                          const FlashTiles: array of Boolean);
var
  X, Y: Integer;
  PixelX, PixelY: Integer;
  R: TRectangle;
  FlashOn: Boolean;
  TileIndex: Integer;  
begin
  { Calculate flash state (blink every 100ms) }
  FlashOn := FlashActive and (Trunc(FlashTimer * 10) mod 2 = 0);

  { Render gems on playfield }
  for Y := 0 to PlayfieldRows - 1 do
  begin
    for X := 0 to PlayfieldCols - 1 do
    begin
      TileIndex := Y * PlayfieldCols + X;

      { Only redraw changed tiles or flashing tiles }
      if Field.TileChanged[X, Y] or (FlashActive and FlashTiles[TileIndex]) then
      begin
        PixelX := PlayfieldX + X * TileSize;
        PixelY := PlayfieldY + Y * TileSize;

        { If this tile is flashing, draw flash effect }
        if FlashActive and FlashTiles[TileIndex] then
        begin
          DrawGemFlash(Field.Tiles[X, Y], PixelX, PixelY, FlashOn);
        end
        else
        begin
          { Draw the gem at this position }
          DrawGem(Field.Tiles[X, Y], PixelX, PixelY);
        end;

        { Mark this tile as dirty }
        R.X := PixelX;
        R.Y := PixelY;
        R.Width := TileSize;
        R.Height := TileSize;
        AddDirtyRect(R);

        { Clear changed flag }
        Field.TileChanged[X, Y] := False;
      end;
    end;
  end;
end;

procedure RenderStack(const Stack: TGemStack; var LastX: Integer; var LastY: Real);
var
  I: Integer;
  GemY: Integer;
  R: TRectangle;
begin
  if not Stack.Active then Exit;

  { Set clipping to playfield bounds only }
  R.X := PlayfieldX;
  R.Y := PlayfieldY;
  R.Width := PlayfieldCols * TileSize;
  R.Height := PlayfieldRows * TileSize;
  SetClipRectangle(R);

  { --- STEP 1: CLEAR OLD POSITION --- }

  R.X := LastX;
  R.Y := Trunc(LastY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Clip playfield top }
  if R.Y < PlayfieldY then
  begin
    Dec(R.Height, Abs(R.Y - PlayfieldY));
    R.Y := PlayfieldY;
  end;

  CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
  AddDirtyRect(R);

  { --- STEP 2: DRAW NEW POSITION --- }

  for I := 0 to 2 do
  begin
    { Calculate Y relative to the stack top }
    GemY := Trunc(Stack.PixelY) + (I * TileSize);
    DrawGem(Stack.Gems[I], Stack.PixelX, GemY + PlayfieldY);
  end;

  { --- STEP 3: MARK DIRTY RECT FOR NEW POSITION --- }

  R.X := Stack.PixelX;
  R.Y := Trunc(Stack.PixelY) + PlayfieldY;
  R.Width := TileSize;
  R.Height := TileSize * 3;

  { Clip playfield top }
  if R.Y < PlayfieldY then
  begin
    Dec(R.Height, Abs(R.Y - PlayfieldY));
    R.Y := PlayfieldY;
  end;

  AddDirtyRect(R);

  { Save current position for next frame }
  LastX := Stack.PixelX;
  LastY := Stack.PixelY;

  { Reset clipping to full screen }
  R.X := 0;
  R.Y := 0;
  R.Width := 320;
  R.Height := 200;
  SetClipRectangle(R);
end;

procedure RenderNextStack(const NextGems: array of TGemColor);
var
  i: Integer;
  R: TRectangle;
begin
  for i := 0 to 2 do
  begin
    DrawGem(NextGems[i], NextStackX, NextStackY + i * TileSize);
  end;

  R.X := NextStackX;
  R.Y := NextStackY;
  R.Width := TileSize;
  R.Height := TileSize * 3;
  AddDirtyRect(R);
end;

{ Helper function to zero-pad numbers }
function PadZero(Value: LongInt; Length: Integer): string;
var
  S: string;
begin
  S := IntToStr(Value);
  while System.Length(S) < Length do
    S := '0' + S;
  PadZero := S;
end;

procedure RenderHUD(FPS: Integer; ShowFPS: Boolean; ShowMem: Boolean; Score: LongInt; Level, Blocks: Integer;
                    var LastScore: LongInt; var LastLevel, LastBlocks: Integer;
                    var FontLarge, FontSmall: TFont);
var
  R: TRectangle;
  ScoreText, LevelText, BlocksText: string;
  TextWidth: Integer;
  NextY: Integer;
  FreeMem: LongInt;
  S: string;
const
  ScoreY = 25;   { 17 + 8 }
  LevelY = 66;   { 58 + 8 }
  BlocksY = 107; { 99 + 8 }
begin  
  NextY := 10;

  if (ShowFPS) then
  begin
    { Render FPS counter (top-left, unchanged) }
    R.X := NextY;
    R.Y := 10;
    R.Width := 80;
    R.Height := 8;
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
    PrintText(10, 10, 'FPS: ' + IntToStr(FPS), 15, BackBuffer);
    AddDirtyRect(R);
    Inc(NextY, R.Height + 2);
  end;

  if (ShowMem) then
  begin
    { Render free memory }
    R.X := NextY;
    R.Y := 10;
    R.Width := 160;
    R.Height := 8;
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);
    FreeMem := MemAvail;
    Str(FreeMem, S);
    PrintText(10, NextY, 'Free: ' + S + ' bytes', 15, BackBuffer);
    AddDirtyRect(R);
    Inc(NextY, R.Height + 2);
  end;  

  { Render Score number (only if changed) }
  if Score <> LastScore then
  begin
    ScoreText := PadZero(Score, 7);
    TextWidth := GetTextWidth(ScoreText, FontLarge);

    { Clear area and redraw }
    R.X := 0;
    R.Y := ScoreY;
    R.Width := StatLabelsX;
    R.Height := FontLarge.Height;
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);

    { Draw right-aligned }
    PrintFontTextRight(StatLabelsX, ScoreY, ScoreText, FontLarge, BackBuffer);
    AddDirtyRect(R);

    LastScore := Score;
  end;

  { Render Level number (only if changed) }
  if Level <> LastLevel then
  begin
    LevelText := PadZero(Level, 2);
    TextWidth := GetTextWidth(LevelText, FontLarge);

    { Clear area and redraw }
    R.X := 0;
    R.Y := LevelY;
    R.Width := StatLabelsX;
    R.Height := FontLarge.Height;
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);

    { Draw right-aligned }
    PrintFontTextRight(StatLabelsX, LevelY, LevelText, FontLarge, BackBuffer);
    AddDirtyRect(R);

    LastLevel := Level;
  end;

  { Render Blocks number (only if changed) }
  if Blocks <> LastBlocks then
  begin
    BlocksText := PadZero(Blocks, 3);
    TextWidth := GetTextWidth(BlocksText, FontLarge);

    { Clear area and redraw }
    R.X := 0;
    R.Y := BlocksY;
    R.Width := StatLabelsX;
    R.Height := FontLarge.Height;
    CopyFrameBufferRect(BackgroundBuffer, R, BackBuffer, R.X, R.Y);

    { Draw right-aligned }
    PrintFontTextRight(StatLabelsX, BlocksY, BlocksText, FontLarge, BackBuffer);
    AddDirtyRect(R);

    LastBlocks := Blocks;
  end;
end;

procedure RenderDialogBackground(FrameBuffer: PFrameBuffer); assembler;
{ Optimized assembly checkerboard dither for 286 }
{ Odd rows (1,3,5...): black at even X positions (0,2,4...) }
{ Even rows (0,2,4...): black at odd X positions (1,3,5...) }
asm
  push ds
  les di, FrameBuffer    { ES:DI = framebuffer base }
  xor bx, bx             { BX = row counter (0-199) }
  cld                    { Clear direction flag }

@RowLoop:
  { Calculate row start address: FrameBuffer + (row * 320) }
  les di, FrameBuffer
  mov ax, bx             { AX = row number }
  mov cx, 320
  mul cx                 { DX:AX = row * 320 }
  add di, ax             { ES:DI = framebuffer + row offset }

  { Check if row is odd or even }
  test bl, 1             { Test bit 0 of row number }
  jnz @OddRow

@EvenRow:
  { Even rows: write black at odd positions (1,3,5,...) }
  inc di                 { Start at offset 1 }
  mov cx, 160            { 320/2 = 160 pixels to write }
  xor al, al             { AL = 0 (black color) }
@EvenLoop:
  stosb                  { Write black to [ES:DI], DI++ }
  inc di                 { Skip next pixel (DI++) }
  loop @EvenLoop
  jmp @NextRow

@OddRow:
  { Odd rows: write black at even positions (0,2,4,...) }
  mov cx, 160            { 320/2 = 160 pixels to write }
  xor al, al             { AL = 0 (black color) }
@OddLoop:
  stosb                  { Write black to [ES:DI], DI++ }
  inc di                 { Skip next pixel (DI++) }
  loop @OddLoop

@NextRow:
  inc bx                 { Next row }
  cmp bx, 200
  jl @RowLoop

  pop ds
end;

end.
