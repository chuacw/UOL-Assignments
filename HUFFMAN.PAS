{ Chua Chee Wee
 CIS 206 Assignment 2
 U/96/0237638
}
program Huffman;
uses CRT;
type
 TBinary = string[8];
var
{ Structures used for building code tree }
 Father: array[0..511] of Integer;
 Code: array[0..255] of Word;
 HeapLength: Word;
 CompressCharCount, FileLength: Longint;
 Heap: array[0..256] of Word;
 CodeLength: array[0..255] of Byte;
 FrequencyCount: array[0..511] of Longint;
 Message: string;

 InFile, OutFile: File;
 OutDataIndex, InDataIndex: Longint;
 InData, OutData: array[1..4096] of Byte;
 SizeRead: Word;
 Dirty: Boolean; { Keeps track of whether data has been written }

function DataSize: Longint;
begin
 if Length(Message)>0 then
  DataSize := Length(Message) else
  DataSize := FileSize(InFile);
end;

function GetData: Byte;
begin
 if Length(Message)>0 then
  begin
   GetData := Ord(Message[InDataIndex]);
  end else
  begin
   if (InDataIndex=0) or (InDataIndex>SizeRead) then
    begin
     BlockRead(InFile, InData, SizeOf(InData), SizeRead);
     InDataIndex := 1;
    end;
   GetData := InData[InDataIndex];
  end;
 Inc(InDataIndex);
end;

procedure ResetDataIndex;
begin
 if Length(Message)>0 then
  InDataIndex := 1 else
  begin
   InDataIndex := 0;
   Seek(InFile, 0);
  end;
end;

procedure WriteData(Ch: Byte);
begin
 Inc(OutDataIndex);
 if OutDataIndex>SizeOf(OutData) then
  begin
   BlockWrite(OutFile, OutData, SizeOf(OutData));
   OutDataIndex := 1;
   Dirty := False;
  end;
 OutData[OutDataIndex] := Ch;
 Dirty := True;
end;

procedure FlushData;
begin
 if Dirty then
  BlockWrite(OutFile, OutData, OutDataIndex);
end;

procedure Reheap (HeapEntry: Word);
var
   index: Word;
   HeapValue: Longint;
begin

   HeapValue := Heap[HeapEntry];

   while HeapEntry <= HeapLength div 2 do
   begin
      Index := HeapEntry+HeapEntry;

      if Index < HeapLength then
       if FrequencyCount[Heap[Index]] >= FrequencyCount[Heap[Index+1]] then
        Inc(Index);

      if (FrequencyCount[HeapValue] < FrequencyCount[Heap[Index]]) then
       Break;

      Heap[HeapEntry] := Heap[Index];
      HeapEntry       := Index;
   end;

   Heap[HeapEntry] := HeapValue;
end;

procedure CompressImage;
var
   CurrBit, CurrentLength, dvalue, Loop1: Integer;
   CurrentCode: Word;
   CurrByte, Loop: Longint;
   TheByte: Word;
begin
   CurrBit := 7; CurrByte := 0; TheByte := 0;

   for Loop := 1 to DataSize do
   begin
      dvalue        := GetData;
      CurrentCode   := Code[dvalue];
      CurrentLength := CodeLength[dvalue];

      for Loop1 := CurrentLength-1 downto 0 do
      begin
         if ((CurrentCode shr Loop1) and 1)<>0 then
            thebyte := thebyte or (1 shl CurrBit);

         Dec(CurrBit);
         if (CurrBit < 0) then
         begin
            WriteData(thebyte);
            TheByte := 0;
            Inc(CurrByte);
            CurrBit := 7;
         end;
      end;
   end;
   WriteData(thebyte);
   Inc(CurrByte);
   CompressCharCount := CurrByte;
end;

function GenerateCodeTable: Boolean;
var
   BitCode,
   Loop,
   CurrentLength,
   CurrentBit: Word;

   Parent: Integer;

begin
   for Loop := 0 to 255 do
    if FrequencyCount[Loop]>0 then
      begin
         CurrentLength := 0;
         BitCode := 0;
         CurrentBit := 1;
         Parent := Father[Loop];

         while (Parent<>0) do
         begin
            if (Parent < 0) then
            begin
               Inc(BitCode, CurrentBit);
               Parent := -Parent;
            end;
            Parent := Father[Parent];
            CurrentBit := CurrentBit*2;
            Inc(CurrentLength);
         end;

         Code[Loop] := BitCode;

         if CurrentLength > 16 then
            GenerateCodeTable := False
         else
            CodeLength[Loop] := CurrentLength;
      end else
      begin
       Code[Loop] := 0;
       CodeLength[Loop] := 0;
      end;
   GenerateCodeTable := True;
end;


procedure BuildCodeTree;
var
   findex: Word;
   HeapValue: Longint;
begin

   while HeapLength <> 1 do
   begin
      HeapValue := Heap[1];
      Heap[1]    := Heap[HeapLength];
      Dec(HeapLength);

      Reheap (1);
      findex := HeapLength + 255;

      FrequencyCount[findex] := FrequencyCount[Heap[1]] +
                                FrequencyCount[HeapValue];
      Father[HeapValue] :=  findex;
      Father[Heap[1]]    := -findex;
      Heap[1]            :=  findex;

      Reheap (1);
   end;

   Father[256] := 0;
end;

procedure BuildInitialHeap;
var
   Loop: Word;
begin

   HeapLength := 0;

   for Loop := 0 to 255 do
    if FrequencyCount[Loop]>0 then
     begin
      Inc(HeapLength);
      Heap[HeapLength] := Loop;
     end;

   for Loop := HeapLength downto 1 do
    Reheap (Loop);
end;

procedure GetFrequencyCount;
var
   Loop: Longint;
begin

 for Loop := 0 to 511 do
  FrequencyCount[Loop] := 0;

 for Loop := 1 to DataSize do
  Inc(FrequencyCount[GetData]);
end;

procedure Initialise;
begin
 ResetDataIndex;
 OutDataIndex := 0;
 Dirty := False;
end;

procedure Deinitialise;
begin
 FlushData;
 Close(OutFile);
 if Length(Message)=0 then
  begin
   Close(InFile);
  end;
end;


var
   DecompTree: array[0..511] of Integer;

procedure BuildDecompTree;
var
   CurrentNode, Loop, Loop1, CurrentIndex: Word;
begin

   CurrentNode := 1;
   DecompTree[1] := 1;

   for Loop := 0 to 255 do
   begin
      if CodeLength[loop]<>0 then
      begin
	 CurrentIndex := 1;
	 for Loop1 := CodeLength[Loop] - 1 downto 1 do
	 begin
	    CurrentIndex := (DecompTree[CurrentIndex] shl 1) +
			    ((Code[Loop] shr Loop1) and 1);
	    if DecompTree[CurrentIndex]=0 then
	     begin
              Inc(CurrentNode);
              DecompTree[CurrentIndex] := CurrentNode;
             end;
	 end;
	 DecompTree[(DecompTree[CurrentIndex] shl 1) +
	   (Code[Loop] and 1)] := -Loop;
      end;
   end;
end;

procedure DecompressImage;
var
   CurrChar: Byte;
   BitShift: Integer;
   cindex: Word;
   CharCount: Longint;
begin
   cindex := 1;
   CharCount := 0;

   while CharCount < FileLength do
   begin
      CurrChar := GetData;

      for BitShift := 7 downto 0 do
      begin
	 cindex := (cindex shl 1) + ((CurrChar shr BitShift) and 1);

	 if (DecompTree[cindex] <= 0) then
	 begin
	    WriteData(-DecompTree[cindex]);
            Inc(CharCount);
	    if CharCount = FileLength then
               bitshift := 0
            else
               cindex := 1;
	 end
	 else
	    cindex := DecompTree[cindex];
      end;
   end;
end;


function GetInputText: Boolean; far;
begin
 GetInputText := False;
 repeat
  Write('Enter message to compress: ');
  ReadLn(Message);
  if Length(Message)=0 then
   begin
    WriteLn('You must enter a message to encode!!!');
    WriteLn;
   end;
 until Length(Message)>0;
 Initialise;
 GetFrequencyCount;
 BuildInitialHeap;
 BuildCodeTree;
 if not GenerateCodeTable then
  begin
   WriteLn('Failure in building code table!!!');
   WriteLn('Only maximum of 65535 occurances of each character is allowed.');
   WriteLn('Program failure...');
   WriteLn('Quitting...');
   Halt;
  end;
end;

function Binary(B: Byte; Len: Integer): TBinary;
var
 S: string[8];
 I: Integer;
begin
 S := '';
 for I := Len-1 downto 0 do
  S := S+Chr(((B shr I) and 1)+Ord('0'));
 Binary := S;
end;

function DisplayFrequencyTable: Boolean; far;
var
 I: Integer;
begin
 DisplayFrequencyTable := False;
 WriteLn('Frequency Table');
 WriteLn('Char      Frequency');
 WriteLn('-------------------');
 for I := 0 to 255 do
  if FrequencyCount[I]<>0 then
   begin
    if I=Ord(' ') then
     Write('SP') else
     Write(Chr(I):2);
    WriteLn('':14, FrequencyCount[I]);
   end;
 WriteLn('Press Enter to continue...');
 ReadLn;
end;

function DisplayHuffmanCodingPattern: Boolean; far;
var
 I: Integer;
begin
  ResetDataIndex;
  CompressImage;
  DisplayHuffmanCodingPattern := False;
  for I := 0 to 255 do
   if CodeLength[I]>0 then
    begin
     if I=Ord(' ') then
      Write('SP') else
      Write(Chr(I):2);
     WriteLn('':4, Binary(Code[I], CodeLength[I]));
    end;
 WriteLn('Press Enter to continue...');
 ReadLn;
end;

function DisplayCompressedFile: Boolean; far;
var
 I: Integer;
 Data: Byte;
begin
 DisplayCompressedFile := False;
 ResetDataIndex;
 for I := 1 to DataSize do
  begin
   Data := GetData;
   Write(Binary(Code[Data], CodeLength[Data]));
  end;
 WriteLn;
end;

function ComputeSavings: Boolean; far;
var
  TotalBits, HuffmanBits: Longint;
  I: Integer;
begin
 ComputeSavings := False;
 HuffmanBits := 0;
 for I := 0 to 255 do
  Inc(HuffmanBits, FrequencyCount[I]*CodeLength[I]);
 TotalBits := 8*DataSize;
 Write('You have saved ', (TotalBits-HuffmanBits)/TotalBits*100:0:2);
 WriteLn('% compared with a 8-bit coding.');
end;

function QuitHuffman: Boolean; far;
begin
 QuitHuffman := True;
end;

function Testing: Boolean; far;

  procedure ClearError;
  var Error: Integer;
  begin
   Error := IOResult;
  end;
var I: Integer;
begin
  WriteLn('This routine creates a Huffman compressed file (HUFFMAN.2) from');
  WriteLn('HUFFMAN.PAS itself.');
  WriteLn;
  WriteLn('It then tests the decompression by decompressing HUFFMAN.2 to create');
  WriteLn('HUFFMAN.3. HUFFMAN.3 should contain the same data as HUFFMAN.PAS');
  WriteLn;
  Testing := False; Message := '';
  Assign(InFile, 'HUFFMAN.PAS');
  Reset(InFile, 1);
  Initialise;

  WriteLn('Getting frequency counts...');
  GetFrequencyCount;

  WriteLn('Building initial heap...');
  BuildInitialHeap;

  WriteLn('Building code tree...');
  BuildCodeTree;

  WriteLn('Generating code table...');
  if not GenerateCodeTable then
   begin
    WriteLn('Failure in building code table!!!');
    WriteLn('Only maximum of 65535 occurances of each character is allowed.');
    WriteLn('Program failure...');
    WriteLn('Quitting...');
    Halt;
   end;

  FileLength := DataSize;
  Assign(OutFile, 'HUFFMAN.2');
  Rewrite(OutFile, 1);
  BlockWrite(OutFile, Code, SizeOf(Code));
  BlockWrite(OutFile, FileLength, SizeOf(FileLength));
  BlockWrite(OutFile, CodeLength, SizeOf(CodeLength));

  ResetDataIndex;

  WriteLn('Compressing file...');
  CompressImage;

  Deinitialise;
  Assign(OutFile, 'HUFFMAN.3');
  {$I-} Erase(OutFile); {$I+}
  ClearError;
(*  Assign(OutFile, 'HUFFMAN.2');
  {$I-}Rename(OutFile, 'HUFFMAN.3');{$I+}*)


  WriteLn('Reading compressed file...');
  Assign(InFile, 'HUFFMAN.2');
  Reset(InFile, 1);
  BlockRead(InFile, Code, SizeOf(Code));
  BlockRead(InFile, FileLength, SizeOf(FileLength));
  BlockRead(InFile, CodeLength, SizeOf(CodeLength));

  Initialise;
  Assign(OutFile, 'HUFFMAN.3');
  Rewrite(OutFile, 1);
  for I := 1 to SizeOf(Code)+SizeOf(FileLength)+SizeOf(CodeLength) do
   GetData;

  WriteLn('Building decompression tree...');
  BuildDecompTree;

  WriteLn('Decompressing file...');
  DecompressImage;
  Deinitialise;
  WriteLn('Done!');
end;

procedure Run;

 type
  TMenuChoice = (
                 tmGetInputText,
                 tmDisplayFrequencyTable,
                 tmDisplayHuffmanCodingPattern,
                 tmDisplayCompressedFile,
                 tmComputeSavings,
                 tmTesting,
                 tmQuitHuffman
                 );
  THuffmanFunc = function: Boolean;


   {
    Pre:  Menu options displayed
    Post: Selected function to execute
   }
   function getchoice: TMenuChoice;
   const
    SelectionLow = 1;
    SelectionHigh = 7;
    SelLowChar = Chr(SelectionLow+Ord('0'));
    SelHighChar = Chr(SelectionHigh+Ord('0'));
    displaytext: array[SelectionLow..SelectionHigh] of string = (
    'Input text',
    'Frequency table',
    'Huffman coding pattern',
    'Display compressed file',
    'Saving percentage',
    'Test Huffman compression and decompression',
    'Quit'
    );
   var
    X, i: Integer;
    ch: Char;
   begin
    WriteLn('        Chee Wee''s Huffman Compression program');
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
    HuffmanFunc: array[TMenuChoice] of THuffmanFunc = (
    GetInputText,
    DisplayFrequencyTable,
    DisplayHuffmanCodingPattern,
    DisplayCompressedFile,
    ComputeSavings,
    Testing,
    QuitHuffman
    );

var
 quit: Boolean;
 choice: TMenuChoice;
begin
 Textbackground(White); {For printing, save ink}
 TextColor(Black);
 Clrscr;
 quit := False;
 repeat
  choice := GetChoice;
  quit := HuffmanFunc[choice];
 until quit;
end;

begin
 Run;
end.
