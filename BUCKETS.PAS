{ Chua Chee Wee
  U/96/0237638
  CIS205 Assignment 2
}
unit Buckets;
interface
 uses Objects;

const
    BucketSize = 100;
    UNUSED = 0;
    NOTFOUND = -1;
type
    TFarProc = function (P: Pointer; var NextBucket, NextPos: Integer): Boolean;
    TFPCompare = function (P1, P2: Pointer): Boolean;
    TProductCode = string[5];
    PSupplier = ^TSupplier;
    TSupplier = record { Current key is ProductCode with SupplierNo }
     ProductCode: TProductCode;
     SupplierNo,
     {v1.0}
     {Reserved1, Reserved2}
     {v1.1}
     BucketPos, Pos: Integer;
    end; { How to get the supplier no given the product code??? and }

    TBucketResult =
        (bktInserted, bktFound, bktNotFound, bktDeleted, bktUpdated, bktUnique);

    PLinkData = ^TLinkData;
    TLinkData = record
     BucketPos, ItemPos: Integer;
    end;
{
 A Bucket hashing object that works with any data size...
 To use the bucket, call CreateTable.

 CreateTable requires a filename, the number of buckets and the size
 of a single bucket.

 Any data should be declared as such...

 TDataRecord = record
  Fields...
 end

 Bucket = array [0..BucketSize-1] of TDataRecord
 One bucket contains many records...

 hence, when creating the bucket, you go...
 New(PSomethingBucket, CreateTable('FILENAME.DAT', NumberOfBucketsToCreate,
                                   SizeOf(Bucket));

}
    TBucketHashTable = object(TObject)
    private
     NumBuckets: Integer; { # of normal buckets }
     MaxOverflow: Integer; { Index of last overflow Bucket }
     Filename: string;
     DataFile: file;
     BucketSize: Integer;

     procedure NewOverflow(var BucketProbes, ItemProbes: Integer);


    public

     BucketPos, Pos: Integer;
     CurrentBucket: Pointer; { A single Bucket }

     procedure GetBucket(num: Longint);
     procedure PutBucket(num: Longint);

     destructor Done; virtual;

     { To override by descendants!!! }
     function GetBucketDataStatus(ABucket: Pointer;
                                  Index: Integer): Longint; virtual;

     { Gets the index for a record }
     function DecodeBucketDataIndex(ABucketData: Pointer): Longint; virtual;



     { Sets a record inside a bucket status to unused... }
     procedure ClearBucketData(ABucket: Pointer; Index: Integer); virtual;

     { Gets a record out of a bucket }
     procedure GetBucketData(ACurrentBucket: Pointer; Index: Integer;
                             DestinationData: Pointer); virtual;

     { Copies a record from elsewhere into a bucket }
     procedure SetBucketData(ABucket: Pointer; Index: Integer;
                             ABucketData: Pointer); virtual;


     {
     ABucketSize is the size in bytes, of each Bucket.
     A Bucket consists of many items of items...
     }
     constructor CreateTable(AFilename: string;
                             ANumBuckets, ABucketSize: Integer);

     constructor OpenTable(AFilename: string;
                           ANumBuckets, ABucketSize: Integer);

     function InsertItem(BucketData: Pointer;
                         var BucketProbes,
                             ItemProbes: Integer;
                         LinkData, TransferData: Pointer): TBucketResult;

     function FindItem(BucketData, TransferData: Pointer;
                       var BucketProbes,
                           ItemProbes: Integer): TBucketResult;

     function FindItemPos(BucketData: Pointer;
                          LinkData: PLinkData): TBucketResult;

     function DeleteItem(BucketData: Pointer;
                         var BucketProbes,
                             ItemProbes: Integer): TBucketResult;

     function UpdateItem(BucketData: Pointer;
                         var BucketProbes,
                             ItemProbes: Integer): TBucketResult;

     function Walk(BucketData: Pointer;
                   FarProc: TFarProc): Boolean; virtual;

     procedure DeleteItemLinks(P, OldData, CurrData, NewData: Pointer;
                                           fpCompare: TFPCompare);

     procedure ExtractLink(Source, Dest: Pointer); virtual;
     procedure MoveLink(Source, Dest: Pointer); virtual;
     procedure UpdateLink(LinkData: Pointer); virtual;
     procedure CopyZapItem(Source, Destination: Pointer); virtual;
     procedure CopyItem(Source, Destination: Pointer); virtual;
     function CheckDelete(P: Pointer): Boolean; virtual;
    end;

implementation

{ Close the file if it is open }
destructor TBucketHashTable.Done;
begin
    if (NumBuckets > 0) then Close(DataFile);
    FreeMem(CurrentBucket, BucketSize);
    inherited Done;
end;

constructor TBucketHashTable.OpenTable(AFilename: string;
                                       ANumBuckets, ABucketSize: Integer);
var
 I: Integer;
begin
 Filename := AFilename; BucketSize := ABucketSize;
 NumBuckets := ANumBuckets;
 Assign(DataFile, Filename);
 {$I-} Reset(DataFile, BucketSize); {$I+}
 if IOResult=2 then {file not found}
  Fail;
 GetMem(CurrentBucket, BucketSize);
{ Provided the Record Size given is correct, this is how the max overflow
  is calculated ... }
 MaxOverflow := FileSize(DataFile)-1;
end;

{ Create a new hash table }
constructor TBucketHashTable.CreateTable(AFilename: string;
                                         ANumBuckets, ABucketSize: Integer);
var
  I: Integer;
begin
    inherited Init;
    BucketSize := ABucketSize;
    NumBuckets := ANumBuckets;
    MaxOverflow := NumBuckets - 1;

    { Create the file }
    Filename := AFilename;
    Assign(DataFile, Filename);
    Rewrite(DataFile, BucketSize);

    GetMem(CurrentBucket, BucketSize);

{ For debugging purposes... The line below can be removed without harm... }
    FillChar(CurrentBucket^, BucketSize, $FF);

    { Clear CurrentBucket }
    for I := 0 to BucketSize - 1 do
     ClearBucketData(CurrentBucket, I);

    { Write the empty buckets into the file }
    for I := 0 to NumBuckets - 1 do
     BlockWrite(DataFile, CurrentBucket^, 1);
end;

{ Converts a record into it's corresponding index }
function TBucketHashTable.DecodeBucketDataIndex(ABucketData: Pointer): Longint;
begin
 { Override!!! }
 Abstract;
end;

{ Clears a record inside a bucket }
procedure TBucketHashTable.ClearBucketData(ABucket: Pointer; Index: Integer);
begin
 { Override!!! }
 Abstract;
end;

{
 Descendants actually do this...
 Returns
 DecodeBucketDataIndex(PSomeBucketDefinition(ABucket)^[Index]) as
 the result of this function...
}
function TBucketHashTable.GetBucketDataStatus(ABucket: Pointer;
                                              Index: Integer): Longint;
begin
 { Override!!! }
 Abstract;
end;

{ Copies a record into a bucket
  Index is the position of the record inside the bucket }
procedure TBucketHashTable.SetBucketData(ABucket: Pointer; Index: Integer;
                                         ABucketData: Pointer);
begin
 { Override!!! }
 Abstract;
end;

{
  Copies a record out of a bucket
  Index is the position of the record inside the bucket
}
procedure TBucketHashTable.GetBucketData(ACurrentBucket: Pointer;
                                         Index: Integer;
                                         DestinationData: Pointer);
begin
 { Override!!! }
 Abstract;
end;

{ Insert an item in a hash table. Return bktFound if the
  item is already in the table, bktInserted otherwise. }
function TBucketHashTable.InsertItem(BucketData: Pointer;
                                     var BucketProbes,
                                         ItemProbes: Integer;
                                     LinkData, TransferData: Pointer): TBucketResult;
var
    ABucketPos, APos: Integer;
    BucketFull: Boolean;
    BucketIndex: Longint;
    OldLinkData, NewLinkData: TLinkData;

    BucketProbes2, ItemProbes2: Integer;
    ThrowAway: TBucketResult;
begin
    BucketPos := NOTFOUND;

    BucketProbes := 0;
    ItemProbes := 0;

    { See if the item is already present. }
    if (FindItem(BucketData, nil, BucketProbes, ItemProbes) =
        bktFound) then
    begin
        InsertItem := bktFound;
        exit;
    end;

    { Get the Bucket where the item should be }
    BucketIndex := abs(DecodeBucketDataIndex(BucketData));
    ABucketPos := (BucketIndex mod NumBuckets);
    BucketProbes := BucketProbes + 1;
    GetBucket(ABucketPos);

    { See if the last position in the Bucket is used. }
    ItemProbes := ItemProbes + 1;
    BucketFull := GetBucketDataStatus(CurrentBucket, BucketSize - 1) <> UNUSED;

    { If the Bucket is full, use the last overflow Bucket. }
    if (BucketFull) then
    begin
        ABucketPos := MaxOverflow;
        if (ABucketPos < NumBuckets) then
        begin
            BucketFull := True
        end else
        begin
         BucketProbes := BucketProbes + 1;
         GetBucket(ABucketPos);
         BucketFull := GetBucketDataStatus(CurrentBucket, BucketSize - 1) <>
                       UNUSED;
        end;
    end;

    { If the overflow buckets are full, make a new one }
    if (BucketFull) then
    begin
        NewOverflow(BucketProbes, ItemProbes);
        ABucketPos := MaxOverflow;
    end;

    { At this point ABucketPos gives the index of a Bucket
      with at least one unused entry. Find the first
      unused entry and use it. }
    for APos := 0 to BucketSize - 1 do
    begin
        ItemProbes := ItemProbes + 1;
        if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then Break;
    end;

    { Insert the item. }
    SetBucketData(CurrentBucket, APos, BucketData);
    Pos := APos;

    { Update the data file. }
    BucketProbes := BucketProbes + 1;
    PutBucket(ABucketPos);
    BucketPos := ABucketPos;
    InsertItem := bktInserted;

    if LinkData<>nil then
     begin
      NewLinkData.BucketPos := ABucketPos;
      NewLinkData.ItemPos := APos;
      CopyZapItem(BucketData, TransferData);
      if FindItem(TransferData, TransferData,
                  BucketProbes2, ItemProbes2)=bktFound then
       begin
        ExtractLink(TransferData, LinkData);
         if (PLinkData(LinkData)^.BucketPos<>-1) and
            (PLinkData(LinkData)^.ItemPos<>-1) then
          begin
           repeat
            OldLinkData.BucketPos := PLinkData(LinkData)^.BucketPos;
            OldLinkData.ItemPos := PLinkData(LinkData)^.ItemPos;
            GetBucket(PLinkData(LinkData)^.BucketPos);
            GetBucketData(CurrentBucket, PLinkData(LinkData)^.ItemPos, TransferData);
            ExtractLink(TransferData, LinkData);
           until (PLinkData(LinkData)^.BucketPos = -1) and
                  (PLinkData(LinkData)^.ItemPos = -1);
           ABucketPos := BucketPos; APos := Pos;
           MoveLink(@NewLinkData, TransferData);
           ThrowAway := UpdateItem(TransferData, BucketProbes2, ItemProbes2);
          end;
       end else
       begin
        MoveLink(@NewLinkData, TransferData);
        ThrowAway := InsertItem(TransferData, BucketProbes2, ItemProbes2, nil, nil);
        InsertItem := bktUnique;
       end;
     end;
end;

{ Get a Bucket. }
procedure TBucketHashTable.GetBucket(num: Longint);
begin
    Seek(DataFile, num);
    BlockRead(DataFile, CurrentBucket^, 1);
end;

{ Save a Bucket to file. }
procedure TBucketHashTable.PutBucket(num: Longint);
begin
    Seek(DataFile, num);
    BlockWrite(DataFile, CurrentBucket^, 1);
end;

{ Create a new overflow Bucket. }
procedure TBucketHashTable.NewOverflow(var BucketProbes, ItemProbes: Integer);
var
    i: Integer;
begin
    { Clear CurrentBucket. }
    for i := 0 to BucketSize - 1 do
      ClearBucketData(CurrentBucket, i);
    ItemProbes := ItemProbes + BucketSize;

    { Write the new Bucket to disk. }
    MaxOverflow := MaxOverflow + 1;
    BucketProbes := BucketProbes + 1;
    PutBucket(MaxOverflow);
end;

{ Locates an item in a hash table.
  Optionally, copies the located item into another location, as indicated
  by TransferData }
function TBucketHashTable.FindItem(BucketData: Pointer;
                                   TransferData: Pointer;
                                   var BucketProbes,
                                       ItemProbes: Integer): TBucketResult;
var
    ABucketPos, APos: Integer;
    BucketIndex: Longint;
begin
    BucketPos := NOTFOUND;

    BucketProbes := 0;
    ItemProbes := 0;

    { Get the Bucket it belongs in. }
    BucketIndex := abs(DecodeBucketDataIndex(BucketData));
    ABucketPos := (BucketIndex mod NumBuckets);
    BucketProbes := BucketProbes + 1;
    GetBucket(ABucketPos);

    { Look for the item or an unused position. }
    for APos := 0 to BucketSize - 1 do
    begin
        ItemProbes := ItemProbes + 1;
        if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
        begin
            FindItem := bktNotFound;  { not here }
            exit;
        end;
        if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
        begin
            if TransferData<>nil then
             GetBucketData(CurrentBucket, APos, TransferData);
            FindItem := bktFound;    { found it. }
            BucketPos := ABucketPos;
            Pos := APos;
            exit;
        end;
    end;

    { If we haven't found it, check the overflow buckets. }
    for ABucketPos := NumBuckets to MaxOverflow do
    begin
        BucketProbes := BucketProbes + 1;
        GetBucket(ABucketPos);

        for APos := 0 to BucketSize - 1 do
        begin
            ItemProbes := ItemProbes + 1;
            if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
            begin
                FindItem := bktNotFound; { It's not here. }
                exit;
            end;
            if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
            begin
             if TransferData<>nil then
              GetBucketData(CurrentBucket, APos, TransferData);
             BucketPos := ABucketPos;
             FindItem := bktFound;    { We found it. }
             exit;
            end;
        end;
    end;

    { If we still haven't found it, it's not here. }
    FindItem := bktNotFound;
end;

function TBucketHashTable.FindItemPos(BucketData: Pointer;
                                      LinkData: PLinkData): TBucketResult;
var
    ABucketPos, APos: Integer;
    BucketIndex: Longint;

    BucketProbes,
    ItemProbes: Integer;
begin
    if LinkData<>nil then
     with LinkData^ do
      begin
       BucketPos := -1;
       ItemPos := -1;
      end;
    BucketPos := NOTFOUND;

    BucketProbes := 0;
    ItemProbes := 0;

    { Get the Bucket it belongs in. }
    BucketIndex := abs(DecodeBucketDataIndex(BucketData));
    ABucketPos := (BucketIndex mod NumBuckets);
    BucketProbes := BucketProbes + 1;
    GetBucket(ABucketPos);

    { Look for the item or an unused position. }
    for APos := 0 to BucketSize - 1 do
    begin
        ItemProbes := ItemProbes + 1;
        if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
        begin
            FindItemPos := bktNotFound;  { not here }
            exit;
        end;
        if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
        begin
            FindItemPos := bktFound;    { found it. }
            if LinkData<>nil then with LinkData^ do
             begin
              BucketPos := ABucketPos;
              ItemPos := APos;
             end;
            exit;
        end;
    end;

    { If we haven't found it, check the overflow buckets. }
    for ABucketPos := NumBuckets to MaxOverflow do
    begin
        BucketProbes := BucketProbes + 1;
        GetBucket(ABucketPos);

        for APos := 0 to BucketSize - 1 do
        begin
            ItemProbes := ItemProbes + 1;
            if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
            begin
                FindItemPos := bktNotFound; { It's not here. }
                exit;
            end;
            if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
            begin
            if LinkData<>nil then with LinkData^ do
             begin
              BucketPos := ABucketPos;
              ItemPos := APos;
             end;
             FindItemPos := bktFound;    { We found it. }
             exit;
            end;
        end;
    end;

    { If we still haven't found it, it's not here. }
    FindItemPos := bktNotFound;
end;


{
 Given a record, convert it into it's index, then based on that index,
 try and locate the record in the bucket file. If located, clears
 the record in the bucket file away... Doesn't actually delete the record in
 the bucket. Just marked it unused...
}
function TBucketHashTable.DeleteItem(BucketData: Pointer;
                                     var BucketProbes,
                                     ItemProbes: Integer): TBucketResult;
var
    ABucketPos, APos: Integer;
    BucketIndex: Longint;
begin
    BucketProbes := 0;
    ItemProbes := 0;

    { Get the Bucket it belongs in. }
    BucketIndex := abs(DecodeBucketDataIndex(BucketData));
    ABucketPos := (BucketIndex mod NumBuckets);
    BucketProbes := BucketProbes + 1;
    GetBucket(ABucketPos);

    { Look for the item or an unused position. }
    for APos := 0 to BucketSize - 1 do
    begin
        ItemProbes := ItemProbes + 1;
        if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
        begin
            DeleteItem := bktNotFound;  { not here }
            exit;
        end;
        if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
        begin
            ClearBucketData(CurrentBucket, APos);
            PutBucket(ABucketPos);
            DeleteItem := bktDeleted;    { Delete it! }
            exit;
        end;
    end;

    { If we haven't found it, check the overflow buckets. }
    for ABucketPos := NumBuckets to MaxOverflow do
    begin
        BucketProbes := BucketProbes + 1;
        GetBucket(ABucketPos);

        for APos := 0 to BucketSize - 1 do
        begin
            ItemProbes := ItemProbes + 1;
            if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
            begin
                DeleteItem := bktNotFound; { It's not here. }
                exit;
            end;
            if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
            begin
             ClearBucketData(CurrentBucket, APos);
             PutBucket(ABucketPos);
             DeleteItem := bktDeleted;    { Deleted it! }
             exit;
            end;
        end;
    end;

    { If we still haven't found it, it's not here. }
    DeleteItem := bktNotFound;
end;

{ Works by generating a BucketIndex from the data
  pointed to by BucketData. Then, using the data pointed
  to by BucketData, updates the item.

  Same implementation as InsertItem, except that returns
  different results...
}
function TBucketHashTable.UpdateItem(BucketData: Pointer;
                                     var BucketProbes,
                                     ItemProbes: Integer): TBucketResult;
var
    ABucketPos, APos: Integer;
    BucketIndex: Longint;
begin
    BucketPos := NOTFOUND;

    BucketProbes := 0;
    ItemProbes := 0;

    { Get the Bucket it belongs in. }
    BucketIndex := abs(DecodeBucketDataIndex(BucketData));
    ABucketPos := (BucketIndex mod NumBuckets);
    BucketProbes := BucketProbes + 1;
    GetBucket(ABucketPos);

    { Look for the item or an unused position. }
    for APos := 0 to BucketSize - 1 do
    begin
        ItemProbes := ItemProbes + 1;
        if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
        begin
            UpdateItem := bktNotFound;  { not here }
            exit;
        end;
        if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
        begin
            SetBucketData(CurrentBucket, APos, BucketData);
            PutBucket(ABucketPos);
            BucketPos := ABucketPos;
            Pos := APos;
            UpdateItem := bktUpdated;    { Updated it! }
            exit;
        end;
    end;

    { If we haven't found it, check the overflow buckets. }
    for ABucketPos := NumBuckets to MaxOverflow do
    begin
        BucketProbes := BucketProbes + 1;
        GetBucket(ABucketPos);

        for APos := 0 to BucketSize - 1 do
        begin
            ItemProbes := ItemProbes + 1;
            if GetBucketDataStatus(CurrentBucket, APos) = UNUSED then
            begin
                UpdateItem := bktNotFound; { It's not here. }
                exit;
            end;
            if GetBucketDataStatus(CurrentBucket, APos) = BucketIndex then
            begin
             SetBucketData(CurrentBucket, APos, BucketData);
             PutBucket(ABucketPos);
             BucketPos := ABucketPos;
             Pos := APos;
             UpdateItem := bktUpdated;    { Updated it! }
             exit;
            end;
        end;
    end;

    { If we still haven't found it, it's not here. }
    UpdateItem := bktNotFound;
end;

function TBucketHashTable.Walk(BucketData: Pointer;
                               FarProc: TFarProc): Boolean;
var
 ABucketPos, APos: Integer;
 BucketProbes, ItemProbes: Integer;
 Ret: Boolean;
begin
 Ret := False;
 if (FindItem(BucketData, BucketData, BucketProbes, ItemProbes) = bktFound) then
  begin
   Ret := FarProc(BucketData, ABucketPos, APos);
   while (ABucketPos<>-1) and (APos<>-1) do
    begin
     Ret := FarProc(BucketData, ABucketPos, APos) or Ret;
     if (ABucketPos<>-1) and (APos<>-1) then
      begin
       GetBucket(ABucketPos);
       GetBucketData(CurrentBucket, APos, BucketData);
      end;
   end;
   Walk := Ret;
  end else
  begin
   Walk := False;
  end;
end;

procedure TBucketHashTable.DeleteItemLinks(P, OldData, CurrData,
                                           NewData: Pointer;
                                           fpCompare: TFPCompare);
var
 Links: array[0..2] of TLinkData;
 BucketProbes, ItemProbes: Integer;
 ABucketPos, APos: Integer;
 LinkIndex: Integer;
begin
 LinkIndex := 0;
 CopyZapItem(P, OldData);
 if (FindItem(OldData, OldData, BucketProbes, ItemProbes) = bktFound) then
  begin
   CopyItem(OldData, CurrData);
   while not fpCompare(P, CurrData) do
    begin
     CopyItem(CurrData, OldData);
     CopyItem(OldData, CurrData);
     ExtractLink(CurrData, @Links);
     GetBucket(Links[LinkIndex].BucketPos);
     GetBucketData(CurrentBucket, Links[LinkIndex].ItemPos, CurrData);
    end;
   Links[1] := Links[0];
   if (Links[1].BucketPos<>-1) and (Links[1].ItemPos<>-1) then
    begin
     GetBucket(Links[1].BucketPos);
     GetBucketData(CurrentBucket, Links[1].ItemPos, NewData);
     ExtractLink(CurrData, @Links[1]);
    end;
   MoveLink(@Links[1], OldData);
   if not CheckDelete(OldData) then
    UpdateItem(OldData, BucketProbes, ItemProbes) else
    DeleteItem(OldData, BucketProbes, ItemProbes);
{   GetBucket(Links[LinkIndex].BucketPos);
   GetBucketData(CurrentBucket, Links[LinkIndex].ItemPos, OldData);
   MoveLink(@Links[, OldData);
   SetBucketData(CurrentBucket, Links[LinkIndex].ItemPos, OldData);
   PutBucket(Links[LinkIndex].BucketPos); }
  end else
  begin
  end;
end;

procedure TBucketHashTable.UpdateLink(LinkData: Pointer);
begin
end;

procedure TBucketHashTable.ExtractLink(Source, Dest: Pointer);
begin
end;

procedure TBucketHashTable.MoveLink(Source, Dest: Pointer);
begin
end;

procedure TBucketHashTable.CopyZapItem;
begin
end;

procedure TBucketHashTable.CopyItem;
begin
end;

function TBucketHashTable.CheckDelete(P: Pointer): Boolean;
begin
end;

end.
