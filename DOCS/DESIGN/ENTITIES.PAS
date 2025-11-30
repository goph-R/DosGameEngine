unit Entities;

interface

uses VGA, Sprite, LinkList;

const Align_Left = 0;
const Align_Right = -2;
const Align_Top = 0;
const Align_Bottom = -2;
const Align_Center = -1;

type
  PEntity = ^TEntity;  
  TEntity = object
    Disabled: Boolean;
    Parent: PEntity;

    { Only position is precise: pixel position multiplied and divided by 1024 (shl 10, shr 10) }
    X: LongInt;
    Y: LongInt;

    { Width and Height is in simple pixel, can not be negative }
    Width: Word;
    Height: Word;

    { Align can be only 0, -1, -2 because Left/Top is the default }
    AlignH: ShortInt;
    AlignV: ShortInt;

    { Sprite + drawing offset }
    SpriteInstance: PSpriteInstance;
    SpriteOffsetX: ShortInt;
    SpriteOffsetY: ShortInt;

    Physics: PPhysics;

    procedure Init;

    { Global position (includes parent offset) }
    function GetGlobalX: LongInt;
    function GetGlobalY: LongInt;

    { These will be only used for collision detection }
    function GetTop: Integer;
    function GetRight: Integer;
    function GetBottom: Integer;
    function GetLeft: Integer;

    procedure PreUpdate(DeltaTime: Real);
    procedure Update(DeltaTime: Real);
    procedure Draw(FrameBuffer: PFrameBuffer);
  end;

type
  PPhysics = ^TPhysics;
  TPhysics = object

    { Every value is precise here because position related }

    { Initial position }
    InitialX: LongInt; 
    InitialY: LongInt;

    { Initial velocity }
    InitialVelocityX: LongInt;
    InitialVelocityY: LongInt;

    { Current velocity }
    VelocityX: LongInt; 
    VelocityY: LongInt; 

    { Velocity modifiers }
    Acceleration: LongInt;
    Gravity: LongInt;

  	procedure Update(var Entity: TEntity; DeltaTime: Real);
  end;

type
  TEntityManager = object
    EntityList: TLinkedList;
    RemoveEntityList: TLinkedList;
    procedure Init;
    procedure Add(Entity: PEntity);
    procedure Remove(Entity: PEntity);
    procedure UpdateAll(DeltaTime: Real);
    procedure Done;
  end;

implementation

procedure TEntityManager.Init;
begin
  ListInit(EntityList);
  ListInit(RemoveEntityList);
end;

procedure TEntityManager.Done;
begin
  ListFree(EntityList);
  ListFree(RemoveEntityList);
end;

procedure TEntityManager.Add(Entity: PEntity);
begin
  ListAdd(EntityList, Entity);
end;

procedure TEntityManager.Remove(Entity: PEntity);
begin
  ListAdd(RemoveEntityList, Entity);
end;

procedure TEntityManager.UpdateAll(DeltaTime: Real);
var
  Entry, NextEntry, SearchEntry: PListEntry;
  Entity: PEntity;
begin
  { PreUpdate entities }
  Entry := EntityList.First;
  while Entry <> nil do
  begin
    Entity := Entry^.Value;
    Entity^.PreUpdate(DeltaTime);
    Entry := Entry^.Next;
  end;

  { Update entities }
  Entry := EntityList.First;
  while Entry <> nil do
  begin
    Entity := Entry^.Value;
    Entity^.Update(DeltaTime);
    Entry := Entry^.Next;
  end;

  { Process entities marked for removal }
  Entry := RemoveEntityList.First;
  while Entry <> nil do
  begin
    NextEntry := Entry^.Next;
    Entity := PEntity(Entry^.Value);

    { Remove from entity list }
    ListRemoveByValue(EntityList, Entity);

    { Free entity memory }
    Dispose(Entity);

    { Remove from removal list }
    ListRemove(RemoveEntityList, Entry);
    Entry := NextEntry;
  end;
end;

procedure TPhysics.Update(var EntityManager: TEntityManager; var Entity: TEntity; DeltaTime: Real);
begin
  { TODO: Set X, Y via Velocity and DeltaTime }
  { TODO: Check collision with blocks }
  { TODO: Check collision with near entities with Physics.Collider }
  { TODO: Set IntialX/Y, InitialVelocityX/Y and VelocityX/Y if collision happened }
end;

procedure TEntity.Init;
begin
  X := 160 shl 10;
  Y := 100 shl 10;
  Width := 16;
  Height := 16;
  AlignH := Align_Center;
  AlignV := Align_Bottom;
  SpriteInstance := nil;
  Physics := nil;
end;

function TEntity.GetGlobalX: LongInt;
begin
  if Parent <> nil then
    GetGlobalX := X + Parent^.GetGlobalX;
  else
    GetGlobalX := X;
end;

function TEntity.GetGlobalY: LongInt;
begin
  if Parent <> nil then
    GetGlobalY := Y + Parent^.GetGlobalY;
  else
    GetGlobalY := Y;
end;

function TEntity.GetTop: Integer;
begin
  GetTop := GetGlobalY shr 10 + AlignV * Height;
end;

function TEntity.GetRight: Integer;
begin
  GetRight := GetGlobalX shr 10 - (AlignH + 2) * Width;
end;

function TEntity.GetBottom: Integer;
begin
  GetBottom := GetGlobalY shr 10 - (AlignV + 2) * Height;
end;

function TEntity.GetLeft: Integer;
begin
  GetLeft := GetGlobalX shr 10 + AlignH * Width;
end;

procedure TEntity.PreUpdate(DeltaTime: Real);
begin
  { Override in derived types if needed }
end;

procedure TEntity.Update(DeltaTime: Real);
begin
  if Disabled then
	  Exit;
  if Physics <> nil then
  	Physics^.Update(Self, DeltaTime);
  if SpriteInstance <> nil then
  	UpdateSprite(SpriteInstance^, DeltaTime);
end;

procedure TEntity.Draw(FrameBuffer: PFrameBuffer);
begin
  if (SpriteInstance = nil) or (SpriteInstance.Hidden) then
  	Exit;
  SpriteInstance.X := GetGlobalX shr 10 + AlignV * SpriteInstance.Sprite^.Width + SpriteOffsetX;
  SpriteInstance.Y := GetGlobalY shr 10 + AlignH * SpriteInstance.Sprite^.Height + SpriteOffsetY;
  DrawSprite(SpriteInstance, FrameBuffer);
end;

end.