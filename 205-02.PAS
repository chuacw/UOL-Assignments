{ Chua Chee Wee
  CIS205 Assignment 2
  U/96/0237638
  Version  Date          By             Description
  ------------------------------------------------------------------------
  1.0      29 Nov 98     Chua Chee Wee
  1.1      14-15 Jan 98  Chua Chee Wee  Updated to support threading
                                        Marked v1.1 where changes are made
  Warehouse Monitor v1.1
  Needs TP/BP 7.0 or later version...

  WARNING! DO NOT RUN ON PENTIUM II 233 or later...
  CRT's Delay fails... when run on PII-233+
}
program Warehouse_Monitor;
uses Crt, Objects, Buckets;

const
    NumberOfBuckets = 50;
    MARKER = 'ZZZZZ';

type

    TProductCode = string[5];
    PProductData = ^TProductData;
    TProductData = record
     ProductCode: TProductCode; { key }
     QuantityOnHand,
     ReorderLevel,
     ReorderQuantity: Integer;
    end;

    PSupplier = ^TSupplier;
    TSupplier = record { Current key is ProductCode with SupplierNo }
     ProductCode: TProductCode;
     SupplierNo,
     {v1.0}
     {Reserved1, Reserved2}
     {v1.1}
     BucketPos, Pos: Integer;
    end; { How to get the supplier no given the product code??? and
           vice versa...}

    PSupplierAddress = ^TSupplierAddress;
    TSupplierAddress = record
     SupplierNo: Integer; { key }
     Address: string[30];
    end;

    PProductBucket = ^TProductBucket;
    TProductBucket = array [0..BucketSize - 1] of TProductData;

    PSupplierBucket = ^TSupplierBucket;
    TSupplierBucket = array [0..BucketSize - 1] of TSupplier;

    PSupplierAddressBucket = ^TSupplierAddressBucket;
    TSupplierAddressBucket = array [0..BucketSize - 1] of TSupplierAddress;

{ See BUCKET.PAS for these virtual/overide methods }
    PProductHashTable = ^TProductHashTable;
    TProductHashTable = object(TBucketHashTable)
     procedure ClearBucketData(ABucket: Pointer; Index: Integer); virtual;
     function GetBucketDataStatus(ABucket: Pointer; Index: Integer): Longint; virtual;
     function DecodeBucketDataIndex(ABucketData: Pointer): Longint; virtual;
     procedure SetBucketData(ABucket: Pointer; APos: Integer; ABucketData: Pointer); virtual;
     procedure GetBucketData(ACurrentBucket: Pointer; Index: Integer;
                             DestinationData: Pointer); virtual;
    end;

    PSupplierTable = ^TSupplierTable;
    TSupplierTable = object(TBucketHashTable)
     procedure ClearBucketData(ABucket: Pointer; Index: Integer); virtual;
     function GetBucketDataStatus(ABucket: Pointer; Index: Integer): Longint; virtual;
     function DecodeBucketDataIndex(ABucketData: Pointer): Longint; virtual;
     procedure SetBucketData(ABucket: Pointer; APos: Integer; ABucketData: Pointer); virtual;
     procedure GetBucketData(ACurrentBucket: Pointer; Index: Integer;
                             DestinationData: Pointer); virtual;
     {v1.1 }
     procedure UpdateLink(LinkData: Pointer); virtual;
     procedure ExtractLink(Source, Dest: Pointer); virtual;
     procedure MoveLink(Source, Dest: Pointer); virtual;
     procedure CopyZapItem(Source, Dest: Pointer); virtual;
     procedure CopyItem(Source, Dest: Pointer); virtual;
     function CheckDelete(P: Pointer): Boolean; virtual;
     {end v1.1}
    end;

    PSupplierAddressTable = ^TSupplierAddressTable;
    TSupplierAddressTable = object(TBucketHashTable)
     procedure ClearBucketData(ABucket: Pointer; Index: Integer); virtual;
     function GetBucketDataStatus(ABucket: Pointer; Index: Integer): Longint; virtual;
     function DecodeBucketDataIndex(ABucketData: Pointer): Longint; virtual;
     procedure SetBucketData(ABucket: Pointer; APos: Integer; ABucketData: Pointer); virtual;
     procedure GetBucketData(ACurrentBucket: Pointer; Index: Integer;
                             DestinationData: Pointer); virtual;
    end;

{
 Input:  string s
 Output: s is converted into all caps
}
procedure UpStr(var s: OpenString);
var
 I: Integer;
begin
   for I := 1 to Length(s) do s[I] := UpCase(s[I]);
end;

{
 Input:  TProductData Data
 Output: Displays various fields of Data on screen
}
procedure ShowProductData(var Data: TProductData);
begin
 with Data do
  begin
   WriteLn('The product code     : ', ProductCode);
   WriteLn('The quantity on hand : ', QuantityOnHand);
   WriteLn('The reorder level    : ', ReorderLevel);
   WriteLn('The reorder quantity : ', ReorderQuantity);
  end;
end;

{ Convert a product code into it's index }
function ProductCodeToIndex(ProductCode: TProductCode): Longint;
var
 I, J, K, L, M: Integer;
begin
   if ProductCode<>'' then
   begin
    I := Ord(ProductCode[1])-Ord('0');
    J := Ord(ProductCode[2])-Ord('0');
    K := Ord(ProductCode[3])-Ord('0');
    L := Ord(ProductCode[4])-Ord('A');
    M := Ord(ProductCode[5])-Ord('A');
    ProductCodeToIndex := Longint(I)*10000+J*1000+K*100+L*10+M;
   end else
    ProductCodeToIndex := UNUSED;
end;

{ Verify that a product code is in the format
  xYYAA
  where x is 1-9,
        YY is 00.99
        AA is AA..JJ
}
function VerifyProductCode(var ProductData: TProductData): Boolean;
begin
 with ProductData do
  VerifyProductCode := (ProductCode[1] in ['1'..'9']) and
                       (ProductCode[2] in ['0'..'9']) and
                       (ProductCode[3] in ['0'..'9']) and
                       (ProductCode[4] in ['A'..'J']) and
                       (ProductCode[5] in ['A'..'J']);

end;


procedure UpdateInteger(Fieldname: string; var UpdateInteger: Integer);
var
 sNewInteger: string[5];
 Error, NewInteger: Integer;
begin
 WriteLn('Please enter the new ', Fieldname, ' (ENTER=NO CHANGE)');
 Write('New ', Fieldname,': ');
 ReadLn(sNewInteger);
 Val(sNewInteger, NewInteger, Error);
 if Error=0 then
  UpdateInteger := NewInteger;
end;

procedure UpdateProductData(var ProductData: TProductData;
                            UpdateQuantityOnHand,
                            UpdateReorderLevel,
                            UpdateReorderQuantity: Boolean);
var
 sNewQuantity, sNewReorderLevel, sNewReorderQuantity: string[5];
 Error, NewQuantity, NewReorderLevel, NewReorderQuantity: Integer;
begin
 if UpdateQuantityOnHand then
  UpdateInteger('quantity on hand', ProductData.QuantityOnHand);
 if UpdateReorderLevel then
  UpdateInteger('reorder level', ProductData.ReorderLevel);
 if UpdateReorderQuantity then
  UpdateInteger('reorder quantity', ProductData.ReorderQuantity);
end;

function PromptYesNo(Prompt: string): Char;
var
 Ch: Char;
begin
 Write(Prompt, '? (Y/N):  ');
 repeat
  Ch := UpCase(ReadKey)
 until Ch in ['Y', 'N'];
 WriteLn(Ch);
 PromptYesNo := Ch;
end;

function ProductValuesChanged(var ProductData,
                              NewProductData: TProductData): Boolean;
begin
 ProductValuesChanged :=
     (ProductData.QuantityOnHand <> NewProductData.QuantityOnHand) or
     (ProductData.ReorderLevel <> NewProductData.ReorderLevel) or
     (ProductData.ReorderQuantity <> NewProductData.ReorderQuantity);

end;

procedure TProductHashTable.ClearBucketData(ABucket: Pointer; Index: Integer);
begin
 PProductBucket(ABucket)^[Index].ProductCode := '';
end;

function TProductHashTable.GetBucketDataStatus(ABucket: Pointer; Index: Integer): Longint;
begin
 GetBucketDataStatus := DecodeBucketDataIndex(@PProductBucket(ABucket)^[Index]);
end;

procedure TProductHashTable.SetBucketData(ABucket: Pointer; APos: Integer; ABucketData: Pointer);
begin
 PProductBucket(ABucket)^[APos] := PProductData(ABucketData)^;
end;

function TProductHashTable.DecodeBucketDataIndex(ABucketData: Pointer): Longint;
var
 I, J, K, L, M: Integer;
begin
 with PProductData(ABucketData)^ do
  DecodeBucketDataIndex := ProductCodeToIndex(ProductCode);
end;

procedure TProductHashTable.GetBucketData(ACurrentBucket: Pointer;
                                          Index: Integer;
                                          DestinationData: Pointer);
begin
 PProductData(DestinationData)^ := PProductBucket(ACurrentBucket)^[Index];
end;

{ New... }
procedure TSupplierTable.ClearBucketData(ABucket: Pointer; Index: Integer);
begin
 with PSupplierBucket(ABucket)^[Index] do
  begin
   SupplierNo:= UNUSED;
   ProductCode := '';
  end;
end;

function TSupplierTable.GetBucketDataStatus(ABucket: Pointer; Index: Integer): Longint;
begin
 GetBucketDataStatus := DecodeBucketDataIndex(@PSupplierBucket(ABucket)^[Index]);
end;

procedure TSupplierTable.SetBucketData(ABucket: Pointer; APos: Integer; ABucketData: Pointer);
begin
 PSupplierBucket(ABucket)^[APos] := PSupplier(ABucketData)^;
end;

function TSupplierTable.DecodeBucketDataIndex(ABucketData: Pointer): Longint;
var
 Index: Longint;
begin
 with PSupplier(ABucketData)^ do
  begin
   Index := ProductCodeToIndex(ProductCode);
   if Index=UNUSED then Index := SupplierNo;
   DecodeBucketDataIndex := Longint(SupplierNo)*10000+Index;
  end;
end;

{ Copy a record into the bucket }
procedure TSupplierTable.GetBucketData(ACurrentBucket: Pointer;
                                       Index: Integer;
                                       DestinationData: Pointer);
begin
 PSupplier(DestinationData)^ := PSupplierBucket(ACurrentBucket)^[Index];
end;


{ LinkData contains the old bucket position and item position }
procedure TSupplierTable.UpdateLink(LinkData: Pointer);
var
 NewBucketPos, NewItemPos: Integer;
begin
 NewBucketPos := BucketPos;
 NewItemPos := Pos;
 GetBucket(PLinkData(LinkData)^.BucketPos);
end;

procedure TSupplierTable.ExtractLink(Source, Dest: Pointer);
begin
 PLinkData(Dest)^.BucketPos := PSupplier(Source)^.BucketPos;
 PLinkData(Dest)^.ItemPos := PSupplier(Source)^.Pos;
end;

procedure TSupplierTable.MoveLink(Source, Dest: Pointer);
begin
 PSupplier(Dest)^.BucketPos := PLinkData(Source)^.BucketPos;
 PSupplier(Dest)^.Pos := PLinkData(Source)^.ItemPos;
end;

procedure TSupplierTable.CopyZapItem(Source, Dest: Pointer);
begin
 PSupplier(Dest)^.ProductCode := MARKER;
 PSupplier(Dest)^.SupplierNo := PSupplier(Source)^.SupplierNo;
end;

procedure TSupplierTable.CopyItem(Source, Dest: Pointer);
begin
 PSupplier(Dest)^ := PSupplier(Source)^;
end;

function TSupplierTable.CheckDelete(P: Pointer): Boolean;
begin
 CheckDelete := (PSupplier(P)^.ProductCode=MARKER) and
                (PSupplier(P)^.BucketPos=-1) and
                (PSupplier(P)^.Pos=-1);
end;

{ Set a record's status as UNUSED. This record is inside a bucket }
procedure TSupplierAddressTable.ClearBucketData(ABucket: Pointer; Index: Integer);
begin
 PSupplierAddressBucket(ABucket)^[Index].SupplierNo := UNUSED;
end;

{ Get a record's index or status }
function TSupplierAddressTable.GetBucketDataStatus(ABucket: Pointer; Index: Integer): Longint;
begin
 GetBucketDataStatus := DecodeBucketDataIndex(@PSupplierAddressBucket(ABucket)^[Index]);
end;

{ Copy a record into a bucket }
procedure TSupplierAddressTable.SetBucketData(ABucket: Pointer; APos: Integer; ABucketData: Pointer);
begin
 PSupplierAddressBucket(ABucket)^[APos] := PSupplierAddress(ABucketData)^;
end;

function TSupplierAddressTable.DecodeBucketDataIndex(ABucketData: Pointer): Longint;
var
 I, J, K, L, M: Integer;
begin
 with PSupplierAddress(ABucketData)^ do
  DecodeBucketDataIndex := SupplierNo;
end;

procedure TSupplierAddressTable.GetBucketData(ACurrentBucket: Pointer;
                                              Index: Integer;
                                              DestinationData: Pointer);
begin
  PSupplierAddress(DestinationData)^ :=
     PSupplierAddressBucket(ACurrentBucket)^[Index];
end;

function GenerateProductCode: TProductCode;
var
 I, J, K, A1, A2: Integer;
 s1, s2, s3, s4, s5: string[1];
begin
 I := Random(9)+1; { Guarantee greater than zero by +1}
 J := Random(10);  { Generate from 0 to 9}
 K := Random(10);
 A1 := Random(11); { Generate from 0 to 10 ie... A to J }
 A2 := Random(11);
 s1 := Chr(I+Ord('0'));
 s2 := Chr(J+Ord('0'));
 s3 := Chr(K+Ord('0'));
 s4 := Chr(Ord(A1)+Ord('A'));
 s5 := Chr(Ord(A2)+Ord('A'));
 GenerateProductCode := s1+s2+s3+s4+s5;
end;

procedure GenerateSupplierNo(var Supplier: TSupplier);
var
 I: Integer;
begin
 I := Random(32767)+1;
 Supplier.SupplierNo := I;
end;

procedure GenerateSupplierAddress(var SupplierAddress: TSupplierAddress);
var
 s: string[20];
 I: Longint;
begin
 I := Random(32767);
 Str(I, s);
 FillChar(SupplierAddress.Address, SizeOf(SupplierAddress.Address), 0);
 SupplierAddress.Address := 'ADDRESS '+s;
end;

procedure GenerateProductData(var ProductData: TProductData);
begin
 with ProductData do
  begin
   ProductCode := GenerateProductCode;
   ReorderLevel := 7+Random(3)+1;
   QuantityOnHand := 15+Random(5)+1;
   ReorderQuantity := 10+Random(5)+1;
  end;
end;

var
 ProductTable: PProductHashTable;
 SupplierTable: PSupplierTable;
 SupplierAddressTable: PSupplierAddressTable;

function ProductDisplay: Boolean; far;
const
 sVerifyData: array[Boolean] of string[6]=('Failed', 'Passed');
var
 FoundProductData, ProductData: TProductData;
 s: TProductCode;
 ProductTable: PProductHashTable;
 Quit: Boolean;
 BucketProbes, ItemProbes: Integer;
 I: Integer;
begin
 ProductDisplay := False;
 ProductTable := New(PProductHashTable, OpenTable('PRODUCT.DAT',
                     NumberOfBuckets, SizeOf(TProductBucket)));
 repeat
  Write('Enter a product code to display: ');
  ReadLn(s);
  UpStr(s);
  ProductData.ProductCode := s;
   if ProductTable^.FindItem(@ProductData, @FoundProductData, BucketProbes,
                               ItemProbes)=bktFound then
    begin
     WriteLn('Product found!');
     WriteLn('Data verification: ',
             sVerifyData[VerifyProductCode(ProductData)]);
     ShowProductData(FoundProductData);
    end else
    begin
     WriteLn('Product not found!');
    end;
  Quit := PromptYesNo('Look for more products')='N';
 until Quit;
 WriteLn('End product display...');
 Dispose(ProductTable, Done);
end;

function CompareSupplier(P1, P2: Pointer): Boolean; far;
var
 Ret: Boolean;
begin
 Ret := (PSupplier(P1)^.ProductCode=PSupplier(P2)^.ProductCode) and
        (PSupplier(P1)^.SupplierNo=PSupplier(P2)^.SupplierNo);
 CompareSupplier := Ret;
end;

function DisplayProducts(P: Pointer; var NextBucket, NextPos: Integer): Boolean; far;
var
 ProductData, FoundProductData: TProductData;
 BucketProbes, ItemProbes: Integer;
 OldSupplier, CurrSupplier, NewSupplier: TSupplier;
begin
 DisplayProducts := False;
 with PSupplier(P)^ do
 begin
  NextBucket := BucketPos;
  NextPos := Pos;
  if ProductCode=MARKER then exit;

{ Verify that the product code still exists in the product table.
  If it's not, then it has already been deleted, so we
  update the table for the supplier }
  ProductData.ProductCode := ProductCode;
  if ProductTable^.FindItem(@ProductData, @FoundProductData, BucketProbes,
                            ItemProbes)<>bktFound then
   begin
    SupplierTable^.DeleteItemLinks(P, @OldSupplier, @CurrSupplier,
                                   @NewSupplier, CompareSupplier);
    exit;
   end;
  WriteLn('Product Code: ', ProductCode);
  DisplayProducts := True;
{  if (NextPos=-1) and (NextBucket=-1) then exit; }
 end;
end;

function VerifyDelete(P1, P2: Pointer): Boolean; far;
begin
end;

function SupplierDisplay: Boolean; far;
var
 Supplier: TSupplier;
begin
 SupplierDisplay := False;
 Write('Enter supplier number to display: ');
 ReadLn(Supplier.SupplierNo);
 SupplierTable^.CopyZapItem(@Supplier, @Supplier);
 if not SupplierTable^.Walk(@Supplier, DisplayProducts) then
  WriteLn('No such supplier found!') else
 begin
  WriteLn('End display for supplier: ', Supplier.SupplierNo);
 end;
end;

function ProductAdd: Boolean; far;
var
    ProductData: TProductData;
    OldSupplier, Supplier: TSupplier;
    SupplierAddress: TSupplierAddress;
    IsNewSupplier: Char;

{v1.1 }
    LinkData, NewLinkData: TLinkData;


    BucketProbes, ItemProbes: Integer;
    SupplierResult: TBucketResult;
begin
 ProductAdd := False;
 WriteLn('Please supply the following information...');
 Write('New product code: '); ReadLn(ProductData.ProductCode);
 if ProductTable^.FindItem(@ProductData, @ProductData, BucketProbes,
                        ItemProbes)=bktFound then
  begin
   WriteLn('This product code already exists!');
   WriteLn('Try updating instead of adding...');
   exit;
  end else
  begin
   { Update all values on product data }
   UpdateProductData(ProductData, True, True, True);
   ProductTable^.InsertItem(@ProductData, BucketProbes, ItemProbes, nil, nil);
  end;
 Write('Supplier number: '); ReadLn(Supplier.SupplierNo);

 Supplier.BucketPos := -1; Supplier.Pos := -1;
 Supplier.ProductCode := ProductData.ProductCode;
 SupplierResult := SupplierTable^.InsertItem(@Supplier, BucketProbes,
                                             ItemProbes, @LinkData, @OldSupplier);
 if (SupplierResult<>bktInserted) and (SupplierResult<>bktUnique) then
  WriteLn('The supplier already supplies this product!!!') else
 if SupplierResult=bktUnique then
 begin
  Write('Enter supplier address: ');
  ReadLn(SupplierAddress.Address);
  SupplierAddress.SupplierNo := Supplier.SupplierNo;
  { The following should succeed, since the supplier doesn't exist... }
  SupplierAddressTable^.InsertItem(@SupplierAddress, BucketProbes,
                                   ItemProbes, nil, nil);
 end;
end;

function ProductDelete: Boolean; far;
var
 Supplier: TSupplier;
 ProductData: TProductData;
 s: string;
 BucketProbes, ItemProbes: Integer;
begin
 ProductDelete := False;
 Write('Enter product code: ');
 ReadLn(s); UpStr(s);
 ProductData.ProductCode := s;
 if ProductTable^.DeleteItem(@ProductData, BucketProbes,
                             ItemProbes)<>bktDeleted then
  WriteLn('The product doesn''t exist!') else
  WriteLn('The product is deleted.');
end;

function ProductUpdateQuantity: Boolean; far;
var
 ProductCode: TProductCode;
 ProductData, FoundProductData: TProductData;
 I: Integer;
 BucketProbes, ItemProbes: Integer;
begin
 ProductUpdateQuantity := False;
 Write('Enter product code: ');
 Readln(ProductCode); UpStr(ProductCode);
 ProductData.ProductCode := ProductCode;
 if ProductTable^.FindItem(@ProductData, @FoundProductData, BucketProbes,
                             ItemProbes)=bktFound then
  begin
   ShowProductData(FoundProductData);
   WriteLn;
   ProductData := FoundProductData;
   UpdateProductData(ProductData, True, False, False);
   if ProductValuesChanged(ProductData, FoundProductData) then
    ProductTable^.UpdateItem(@ProductData, BucketProbes, ItemProbes);
   WriteLn('Product updated...');
  end else
  begin
   WriteLn('Product not found!');
  end;
end;

function ProductUpdateReorder: Boolean; far;
var
 Password: string;
 ProductCode: TProductCode;
 ProductData, FoundProductData: TProductData;
 I: Integer;
 BucketProbes, ItemProbes: Integer;
 sNewReorderLevel: string[5];
begin
 ProductUpdateReorder := False;
 Write('Please enter password to proceed: ');
 ReadLn(Password);
 if Password='WAREHOUSE' then
  begin
   Write('Enter product code: ');
   Readln(ProductCode); UpStr(ProductCode);
   ProductData.ProductCode := ProductCode;
   if ProductTable^.FindItem(@ProductData, @FoundProductData, BucketProbes,
                               ItemProbes)=bktFound then
    begin
     ShowProductData(FoundProductData);
     ProductData := FoundProductData;
     UpdateProductData(ProductData, False, True, True);
     if ProductValuesChanged(ProductData, FoundProductData) then
      ProductTable^.UpdateItem(@ProductData, BucketProbes, ItemProbes);
     WriteLn('Product updated...');
    end else
    begin
     WriteLn('Product not found!');
    end;
  end else
  begin
   WriteLn('Password wrong!');
   WriteLn('Access denied...');
  end;
end;

function ProductOrderForm: Boolean; far;
var
 ProductCode: TProductCode;
 ProductData, FoundProductData: TProductData;
 I: Integer;
 BucketProbes, ItemProbes: Integer;
begin
 ProductOrderForm := False;
 Write('Enter product code: ');
 Readln(ProductCode); UpStr(ProductCode);
 ProductData.ProductCode := ProductCode;
 if ProductTable^.FindItem(@ProductData, @FoundProductData, BucketProbes,
                             ItemProbes)=bktFound then
  begin
   ShowProductData(FoundProductData);
   WriteLn;
   ProductData := FoundProductData;
{  UpdateProductData(ProductData, True, False, False); }
{  if ProductValuesChanged(ProductData, FoundProductData) then }
   ProductTable^.UpdateItem(@ProductData, BucketProbes, ItemProbes);
   WriteLn('Product updated...');
  end else
  begin
   WriteLn('Product not found!');
  end;
end;

function ProductGenerate: Boolean; far;
var
 ProductData: TProductData;
 OldSupplier, Supplier: TSupplier; LinkData: TLinkData;
 SupplierAddress: TSupplierAddress;
 ProductsGenerated, SuppliersGenerated: Integer;
 InsertResult: TBucketResult;
 AddressFile, CodeFile, SupplierNoFile: Text;
 BucketProbes, ItemProbes: Integer;
begin
 ProductGenerate := False; LinkData.BucketPos := -1;
 if SupplierAddressTable<>nil then Dispose(SupplierAddressTable, Done);
 if SupplierTable<>nil then Dispose(SupplierTable, Done);
 if ProductTable<>nil then Dispose(ProductTable, Done);
 ProductTable := New(PProductHashTable, CreateTable('PRODUCT.DAT',
                     NumberOfBuckets, SizeOf(TProductBucket)));
 SupplierTable:= New(PSupplierTable, CreateTable('SUPPLIER.DAT',
                     NumberOfBuckets, SizeOf(TSupplierBucket)));
 SupplierAddressTable:= New(PSupplierAddressTable, CreateTable('ADDRESS.DAT',
                            NumberOfBuckets, SizeOf(TSupplierAddressBucket)));
 SuppliersGenerated := 0; Supplier.SupplierNo := 0;
 Assign(CodeFile, 'CODES.TXT');
 Rewrite(CodeFile);
 Assign(SupplierNoFile, 'SUPPLIER.TXT');
 Rewrite(SupplierNoFile);
 Assign(AddressFile, 'ADDRESS.TXT');
 Rewrite(AddressFile);
 Randomize;
 WriteLn('Generating 2000 items for product...');
 for ProductsGenerated := 0 to 1999 do
  begin
   if ProductsGenerated mod 66=0 then { Generate 30 suppliers }
    begin
     Inc(SuppliersGenerated);
     if SuppliersGenerated<=30 then
      begin
       GenerateSupplierNo(Supplier);
       SupplierAddress.SupplierNo := Supplier.SupplierNo;
       GenerateSupplierAddress(SupplierAddress);
       WriteLn(AddressFile, Supplier.SupplierNo, ' ',SupplierAddress.Address);
       InsertResult := SupplierAddressTable^.InsertItem(@SupplierAddress,
                       BucketProbes, ItemProbes, nil, nil);
      end;
    end;
   Write('Generating item ', ProductsGenerated+1:4, #13);
   repeat
    GenerateProductData(ProductData);
    InsertResult := ProductTable^.InsertItem(@ProductData, BucketProbes,
                                             ItemProbes, nil, nil);
   until InsertResult=bktInserted;
   WriteLn(CodeFile, ProductData.ProductCode);
   Supplier.ProductCode := ProductData.ProductCode;
   Supplier.BucketPos := -1; Supplier.Pos := -1;
   WriteLn(SupplierNoFile, Supplier.SupplierNo:5, ' ', Supplier.ProductCode);
   InsertResult := SupplierTable^.InsertItem(@Supplier, BucketProbes,
                                             ItemProbes, @LinkData, @OldSupplier);
  end;
 WriteLn(ProductsGenerated+1, ' items generated!');
 Close(AddressFile);
 Close(SupplierNoFile);
 Close(CodeFile);
end;

function ProductVerify: Boolean; far;
var
 ProductData: TProductData; SupplierAddress: TSupplierAddress;
 s: string;
 ProductTable: PProductHashTable;
 SupplierAddressTable: PSupplierAddressTable;
 Quit: Boolean;
 Ch: Char;
 BucketProbes, ItemProbes: Integer;
 Found, J, I, Error: Integer;
 f: Text;
begin
 ProductVerify := False;
 Assign(f, 'CODES.TXT');
 {$I-} Reset(f); {$I+}
 if IOResult=2 then
  begin
   WriteLn('You must generate all files first!!!');
   exit;
  end;
 ProductTable := New(PProductHashTable, OpenTable('PRODUCT.DAT',
                     NumberOfBuckets, SizeOf(TProductBucket)));
 Found := 0; J := 0;
 while not eof(f) do
  begin
   Readln(f, s);
   Inc(J);
   UpStr(s);
   ProductData.ProductCode := s;
   if ProductTable^.FindItem(@ProductData, nil, BucketProbes,
                             ItemProbes)=bktFound then
    begin
     Inc(Found);
    end;
   Write('Verifying for product item ', J: 4, ': ', s, ' found: ', Found: 4, #13);
  end;
 WriteLn;
 WriteLn('Verifying products done!');
 SupplierAddressTable:= New(PSupplierAddressTable, OpenTable('ADDRESS.DAT',
                            NumberOfBuckets, SizeOf(TSupplierAddressBucket)));
 Close(f);
 Assign(f, 'ADDRESS.TXT');
 Reset(f);
 Found := 0; J := 0;
 while not eof(f) do
  begin
   Readln(f, s);
   I := Pos(' ',s);
   Delete(s, I, Length(s));
   Val(s, I, Error);
   SupplierAddress.SupplierNo := I;
   Inc(J);
   if SupplierAddressTable^.FindItem(@SupplierAddress, nil, BucketProbes,
                                     ItemProbes)=bktFound then
    begin
     Inc(Found);
    end;
   Write('Verifying for address item ', J, ': ', s, ' found: ', Found, #13);
  end;
 WriteLn;
 WriteLn('Verifying addresses done!');
 Dispose(SupplierAddressTable, Done);
 Dispose(ProductTable, Done);
end;

function QuitWarehouse: Boolean; far;
begin
 QuitWarehouse := True;
end;

{
 Tries and open each table...
 PRODUCT  - 1st file
 SUPPLIER - 2nd file
 ADDRESS  - 3rd file

 If the open fails, then creates the file...
}
procedure Init;
begin
 ProductTable := New(PProductHashTable, OpenTable('PRODUCT.DAT',
                     NumberOfBuckets, SizeOf(TProductBucket)));
 SupplierTable:= New(PSupplierTable, OpenTable('SUPPLIER.DAT',
                     NumberOfBuckets, SizeOf(TSupplierBucket)));
 SupplierAddressTable:= New(PSupplierAddressTable, OpenTable('ADDRESS.DAT',
                            NumberOfBuckets, SizeOf(TSupplierAddressBucket)));
 if ProductTable=nil then
  ProductTable := New(PProductHashTable, CreateTable('PRODUCT.DAT',
                      NumberOfBuckets, SizeOf(TProductBucket)));
 if SupplierTable=nil then
  SupplierTable:= New(PSupplierTable, CreateTable('SUPPLIER.DAT',
                      NumberOfBuckets, SizeOf(TSupplierBucket)));
 if SupplierAddressTable=nil then
  SupplierAddressTable:= New(PSupplierAddressTable, CreateTable('ADDRESS.DAT',
                             NumberOfBuckets, SizeOf(TSupplierAddressBucket)));
end;

procedure Run;

 type
  TMenuChoice = (tmDisplayProduct, tmDisplaySupplier, tmAdd,
                 tmDelete, tmUpdateQuantity,
                 tmUpdateReorder, tmOrderForm,
                 tmGenerate,
                 tmVerify,
                 tmQuit);
  TWarehouseFunc = function: Boolean;


   {
    Pre:  Menu options displayed
    Post: Selected function to execute
   }
   function getchoice: TMenuChoice;
   const
    SelectionLow = 0; {v1.1} {v1.0 value is 0}
    SelectionHigh = 9;
    SelLowChar = Chr(SelectionLow+Ord('0'));
    SelHighChar = Chr(SelectionHigh+Ord('0'));
    displaytext: array[SelectionLow..SelectionHigh] of string = (
    'Display product',
    'Display supplier and all it''s products',
    'Add new item',
    'Delete an item',
    'Update quantity on hand',
    'Update reorder level and reorder quantity',
    'Check and prepare order form',
    '**FOR TESTING** Generate all necessary files',
    '**FOR TESTING** Verify all files (only generated data is verified)',
    'Quit'
    );
   var
    X, i: Integer;
    ch: Char;
   begin
    WriteLn('        Chee Wee''s Warehouse Monitor');
    for i := SelectionLow to SelectionHigh do
     begin
      Writeln('    ', i,'. ', displaytext[i]);
     end;
    WriteLn;
    Write('Enter your choice > ');
    repeat
     ch := ReadKey;
     if not (ch in [SelLowChar..SelHighChar]) then
      begin
       X := WhereX;
       Write('Invalid Choice...');
       Write(^G);
       Delay(1000);
       GotoXY(X, WhereY);
       ClrEol;
      end;
    until ch in [SelLowChar..SelHighChar];
    WriteLn(ch);
    getchoice := TMenuChoice(Ord(ch)-ord(SelLowChar));
    end;

const
    WarehouseFunc: array[TMenuChoice] of TWarehouseFunc = (
                   ProductDisplay,
                   SupplierDisplay, {v1.1}
                   ProductAdd,
                   ProductDelete,
                   ProductUpdateQuantity,
                   ProductUpdateReorder,
                   ProductOrderForm,
                   ProductGenerate,
                   ProductVerify,
                   QuitWarehouse
    );

var
 quit: Boolean;
 choice: TMenuChoice;
begin
 quit := False;
 repeat
  choice := GetChoice;
  quit := WarehouseFunc[choice];
 until quit;
end;

procedure Done;
begin
 Dispose(SupplierAddressTable, Done);
 Dispose(SupplierTable, Done);
 Dispose(ProductTable, Done);
end;

begin
 Init; { Initialises the program }
 Run; { Run!!! }
 Done; { Cleans up the program... }
end.
