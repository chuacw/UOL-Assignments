Program HuffmanCoding_CIS206_2;
{This program is written in December 1998 by Ong Hui Meng in fulfilment for CIS 206
 CourseWork Two. It implements the Huffman Coding Scheme.}
uses CRT;
Type
    point = ^nodetype;
    nodetype = record
               binary : string;
               frequency : integer;
               character : char;
               next : point;
               left : point;
               right : point;
               end;
    listtype = record
               text : string;
               listCount : integer;
               charCount : integer;
               head : point;
               end;
Var
 IList: listtype;
 m : point;
 choice : char;
 totalbit, CompressedBits : integer;
 saving, totalbits : real;

Procedure InitialiseList(var List:listtype);
{Uses : None.
 Pre  : None.
 Pos  : Initialises the input List.}
Begin
with List do
     begin
        text := '';
        listCount := 0;
        charCount := 0;
        head := nil;
     end;
End;

Procedure InsertionSort(var List:listtype);
{Uses : None.
 Pre  : Input List must be initialsed and not empty.
 Pos  : List has been sorted using the insertion sort technique and sorted
        in nondescending order.}
var
firstunsorted, lastsorted, current, trail : point;
Begin
  if List.Head <> nil then
     begin
       lastsorted := List.Head;
       while lastsorted^.next <> nil do
         begin
           firstunsorted := lastsorted^.next;
           if firstunsorted^.frequency < List.Head^.frequency then
              begin
                lastsorted^.next := firstunsorted^.next;
                firstunsorted^.next := List.Head;
                List.Head := firstunsorted;
              end
           else
              begin
                trail := List.Head;
                current := trail^.next;
                while firstunsorted^.frequency > current^.frequency do
                  begin
                    trail := current;
                    current := trail^.next
                  end;
                if firstunsorted = current then
                  lastsorted := firstunsorted
                else
                  begin
                    lastsorted^.next := firstunsorted^.next;
                    firstunsorted^.next := current;
                    trail^.next := firstunsorted
                  end
              end
           end
    end
End;

Procedure AddNode(var List:listtype; Item:char);
{Uses : None.
 Pre  : Input list must be initialised.
 Pos  : List has been added with new nodes containing Items of characters which is not
        in the list, otherwise, the frequency for the existing item is increased.}
var
newNode, node : point;
Begin
     if List.Head = nil then
        begin
          new(newNode);
          List.Head := newNode;
          newNode^.Character := Item;
          newNode^.next := Nil;
          newNode^.left := Nil;
          newNode^.right := Nil;
          newNode^.frequency := 1;
          inc(List.charCount);
        end
     else
        begin
          node := List.Head;
            while node^.next<>nil do
                  node := node^.Next;
          new(newNode);
          node^.next := newNode;
          newNode^.character := Item;
          newNode^.next := nil;
          newNode^.left := nil;
          newNode^.right := nil;
          newNode^.frequency := 1;
          inc(List.charCount);
        end;
End;

Procedure SearchItem(var List:listtype; Item:char; var PointingTo:Point; var Found:boolean);
{Uses : None.
 Pre  : Input list must be initialised.
 Pos  : The entire list is searched for the input Item. Returns the pointer if item is found,
        otherwise, returns found to be false.}
var
reference : point;
Begin
  Found := False;
  if List.Head = nil then
     exit
  else
     begin
        reference := List.Head;
        While (Item <> reference^.character) and (reference^.next <> nil) do
               reference := reference^.next;
        if Item = reference^.character then
           begin
             PointingTo := reference;
             Found := true;
           end;
     end;
End;

Procedure CreateList(var List:listtype);
{Uses : Procedures "SearchItem" and "AddNode".
 Pre  : The input list must be initialised.
 Pos  : The list has been created.}
var
node : point;
PointingTo: Point;
Found: Boolean;
i: Integer;
Begin
  for i := 1 to Length(List.Text) do
   begin
     SearchItem(List, List.Text[i], PointingTo, Found);
     if not Found then
      begin
      inc(List.listCount);
      AddNode(List, List.Text[i]); end else
      Inc(PointingTo^.frequency);
   end;
End;

Procedure Insert(var List:listtype; var Node:point);
{Uses : None.
 Pre  : Input list must be initialised and not empty and sorted in nondescending order.
 Pos  : The input Node is inserted into the correct position in the list.}
var
   temp, previous : point;
begin
   temp := List.Head;
   previous := temp;
   while (temp^.frequency <= node^.frequency)and (temp <> nil) do
     begin
       previous := temp;
       temp := temp^.next;
     end;
   node^.next := temp;
   previous^.next := node;
end;

Procedure FormTree(var list:listtype; var firstnode:point);
{Uses : Prcedure "Insert".
 Pre  : The list must be initialised and created according to the nondecsending order.
 Pos  : The list has been formed into a tree by combining 2 nodes of the lowest frequency.
        The newly formed tree is reinserted into the list. The assignment of the '0's and
        '1's will also be assigned into the list according to the Huffman Coding requirements.}
var
   newnode, reference, newreference : point;
   i : integer;
Begin
  firstnode:=list.head;{keep a record of the first node}
    while list.listCount <> 1 do
       begin
         reference := list.head;
         newreference := list.head^.next;
            if newreference <> nil then
               begin
                 reference^.binary := '0';{mark left subtree}
                 newreference^.binary := '1';{mark right subtree}
                 list.head := newreference^.next;
                 new(newnode);{create parent}
                 newnode^.binary := '';
                 newnode^.character := '~';{set parent node}
                 newnode^.frequency := reference^.frequency + newreference^.frequency;
                 newnode^.left := reference;
                 newnode^.right := newreference;
                 newnode^.next := nil;
                 dec(List.listCount);
                   if List.listCount = 1 then
                     List.head := newnode
                   else
                     Insert(List,newnode);
              end;
        end;
End;

Procedure FormBinary(var node:point; binary:string);
{Uses : None.
 Pre  : The node input is the input for the start of the list of the binary tree.
 Pos  : The list will be traversed and the the appropriate binary strings added together
        to form the Huffman Coding for each individual character.}
Begin
     if node^.left <> NIL then
        begin
             binary := binary + node^.binary;
             FormBinary(node^.left, binary);
             FormBinary(node^.right, binary);
        end
     else{reach terminating root}
         node^.binary := binary + node^.binary;
End;

Procedure DisplayCompressedCode(var List : listtype; m:point; var Totalbits:integer);
{Uses : None.
 Pre  : The list has already been created and the binary strings inplace.
 Pos  : Will return the actual binary string of the input text and calculate the number
        of bits.}
var
Node : point;
i : integer;
chars : char;
Begin
  totalbits := 0;
  writeln;
  writeln('Compressed Code of the input text :');
  writeln;
  for i := 1 to length(List.text) do
     begin
     Node := m;
     Chars := List.text[i];
     while (chars <> Node^.character) and (Node <> nil) do
        Node := Node^.next;
     write(Node^.binary);
     totalbits := totalbits + length(Node^.binary);
     end;
End;

Procedure DisplayTable(var CList: ListType; m:point);
var
 Node: Point;
Begin
 Node := m;
 writeln('Char   Freq');
 writeln('-------------------');
 while Node<>nil do
  begin
   if node^.character<>'~' then
   begin
   writeln;
   Writeln(Node^.Character,'     ',Node^.Frequency);
   end;
   Node := Node^.Next;
  end;
End;

Procedure DisplayAll(var CList: ListType; m:point);
var
 Node: Point;
Begin
 Node := m;
 writeln('Char   Freq   Binary [Huffman Encoded]'  );
 writeln('--------------------------------------------');
 while Node<>nil do
  begin
   if node^.character<>'~' then
   begin
   writeln;
   Writeln(Node^.Character,'      ',Node^.Frequency,'        ',Node^.Binary);
   end;
   Node := Node^.Next;
  end;
End;


BEGIN{main}
     clrscr;
     repeat
     writeln;
     writeln('___________________________');
     writeln(' 1. Input Text');
     writeln(' 2. Frequency Table');
     writeln(' 3. Huffman Coding Pattern');
     writeln(' 4. Display Compressed File');
     writeln(' 5. Saving Percentage');
     writeln(' 6. Quit');
     writeln('___________________________');
     writeln;
     write('Please enter your choice > ');
     readln(choice);
     case choice of
           '1':begin
                    InitialiseList(IList);
                    Write('Enter message: ');
                    ReadLn(IList.Text);
                    writeln('Hit the return key to continue');
                    readln;
               end;
           '2':begin
                    CreateList(IList);
                    InsertionSort(IList);
                    DisplayTable(IList,Ilist.head);
                    writeln;
                    writeln('Hit the return key to continue');
                    readln;
               end;
           '3':begin
                    FormTree(Ilist,m);
                    FormBinary(Ilist.head,'');
                    DisplayAll(IList,m);
                    writeln;
                    writeln('Hit the return key to continue');
                    readln;
               end;
           '4':begin
                  DisplayCompressedCode(IList,m,totalbit);
                  writeln;
                  writeln('Hit the return key to continue');
                  readln;
               end;
           '5':begin
                   writeln;
                   DisplayCompressedCode(IList,m,totalbit);
                   writeln;
                   TotalBits := length(IList.text) * 8;
                   CompressedBits := totalbit;
                   saving := 100 - ((CompressedBits / TotalBits) * 100);
                   writeln;
                   writeln('You have saved ',saving:2:2,'% as compared to 8-bit codings.');
                   writeln;
                   writeln('Hit the return key to continue');
                   readln;
               end;
           '6':begin
                    writeln;
                    write('Thanks for using the program for Huffman Coding!');
                    readln;
               end;
     end;
     until choice = '6';
END. {main}
