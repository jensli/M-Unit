unit fMUnit;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  ComCtrls, StdCtrls, ExtCtrls, ImgList, Trpcb, RPCConf1, Fmcmpnts,
  Diaccess, Fmlookup, Menus, ActnList, System.Actions;

type
  TDoNextReturn = (dnrFine, dnrFailure, dnrError);
  
  TForm1 = class(TForm)
    edtPrimaryTestRoutine: TEdit;
    lblPrimaryTestRoutine: TLabel;
    btnList: TButton;
    Image1: TImage;
    btnRun: TButton;
    ImageList1: TImageList;
    lblRun: TLabel;
    lblTests: TLabel;
    lblErrors: TLabel;
    lblFailed: TLabel;
    lblElapsed: TLabel;
    btnConnect: TButton;
    lblConnected: TLabel;
    lbl1: TLabel;
    lbl2: TLabel;
    lbl3: TLabel;
    lbl4: TLabel;
    RPCBroker1: TRPCBroker;
    edtServer: TEdit;
    edtPort: TEdit;
    lblServer: TLabel;
    lblPort: TLabel;
    btnSelectServer: TButton;
    btnSelectGroup: TButton;
    FMLookUp1: TFMLookUp;
    FMLister1: TFMLister;
    MainMenu1: TMainMenu;
    File1: TMenuItem;
    Exit1: TMenuItem;
    About1: TMenuItem;
    About2: TMenuItem;
    PageControl1: TPageControl;
    tsTestHierarchy: TTabSheet;
    TreeView1: TTreeView;
    tsFailuresErrors: TTabSheet;
    ListView1: TListView;
    lblTagValue: TLabel;
    lblTestValue: TLabel;
    lblErrorsValue: TLabel;
    lblFailedValue: TLabel;
    lblElapsedValue: TLabel;
    Button1: TButton;
    ActionList1: TActionList;
    actExit: TAction;
    procedure btnListClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
    procedure btnConnectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnExitClick(Sender: TObject);
    procedure btnSelectServerClick(Sender: TObject);
    procedure btnSelectGroupClick(Sender: TObject);
    procedure About2Click(Sender: TObject);
    procedure actExitExecute(Sender: TObject);
  private
    { Private declarations }
  protected
    function DoNext(Location: String): TDoNextReturn;
  public
    procedure ClearRun;
    procedure ClearList;
    procedure NoTagsMesssage;
    { Public declarations }
  end;

var
  Form1: TForm1;
  IsNotOK: Boolean;
  LastOK: Integer;
  TotTests: Integer;
  CurrTest: Integer;
  IsOK: Boolean;
  ElapsedTime: TDateTime;
  NewVersion: Boolean;
  Separator: String;

implementation

uses MFunStr, fVistAAbout;

{$R *.DFM}

var
  GroupIEN: String;
  ImageColor: TColor;
  step: integer;

const
  NewSeparator = '~~^~~';
  OldSeparator = '^';

procedure TForm1.btnListClick(Sender: TObject);
var
  I: Integer;
  CurNode, NewChild: TTreeNode;
  Str: String;
begin
  if edtPrimaryTestRoutine.Text = '' then
  begin
    ShowMessage('Enter a test routine name first.');
    Exit;
  end;
  if not RPCBroker1.Connected then
    btnConnectClick(Self);
  if RPCBroker1.Connected then
  begin
    with RPCBroker1 do
    begin
      CreateContext('XTMUNIT');
      if GroupIEN = '' then     //  based on ROUTINE name
      begin
        RemoteProcedure := 'utMUNIT-TEST LOAD';
        Param[0].Value := edtPrimaryTestRoutine.Text;
      end
      else begin               //  based on MUnit Test Group entry
        RemoteProcedure := 'utMUNIT-TEST GROUP LOAD';
        Param[0].Value := GroupIEN;
      end;
      Param[0].PType := Literal;
      call;
      TreeView1.Items.Clear;
      TotTests := 0;
      CurNode := nil;
      if (CompareText(Separator,'') = 0) then
      begin
        Separator := OldSeparator;
        if (CompareText(Piece(Results[0],'^',4),'1') = 0) then
          Separator := NewSeparator;
      end;
      for I := 1 to Results.Count do    // Iterate
      begin
        Str := Results[I-1];
        if Piece(Str,'^',2) = '' then
        begin
          if CurNode = nil then
          begin
            CurNode := TreeView1.Items.GetFirstNode;
            CurNode := TreeView1.Items.Add(CurNode, Piece(Str,'^',1)+' - '+Piece(Str,'^',3));
          end
          else
            CurNode := TreeView1.Items.Add(CurNode, Piece(Str,'^',1)+' - '+Piece(Str,'^',3));
          CurNode.ImageIndex := -1;
          CurNode.StateIndex := -1;
          CurNode.SelectedIndex := -1;
          if Pos('ROUTINE NAME NOT FOUND',Piece(Str,'^',3)) > 0 then
            CurNode.ImageIndex := 6;
        end
        else
        begin
          NewChild := TreeView1.Items.AddChild(CurNode, Piece(Str,'^',2) + ' - ' + Piece(Str,'^',3));
          NewChild.ImageIndex := -1;
          NewChild.StateIndex := -1;
          NewChild.SelectedIndex := -1;

          Inc(TotTests);
        end;
      end;    // for
    end;    // with
    lblTagValue.Caption := IntToStr(TotTests);
    btnRun.Enabled := True;
    ClearRun;
    PageControl1.ActivePage := tsTestHierarchy;
    TreeView1.FullExpand;
    if not (TotTests >0) then
    begin
      NoTagsMesssage;
      btnRun.Enabled := False;
      for I := 0 to TreeView1.Items.Count-1 do    // Iterate
      begin
        CurNode := TreeView1.Items[I];
        if CurNode.Level = 0 then
          if CurNode.ImageIndex <> 6 then
            CurNode.ImageIndex := 6;
      end;
      TreeView1.Invalidate;
    end
    else
    begin
      btnRun.Enabled := True;
      btnRun.Default := True;
      btnList.Default := False;
    end;
  end;
end;


procedure TForm1.btnRunClick(Sender: TObject);
var
  I,J: Integer;
  CurNode: TTreeNode;
  CurChildNode: TTreeNode;
  RoutineName: String;
  EntryTag: String;
  DateTime1,DateTime2: TDateTime;
  RetVal: TDoNextReturn;
begin
  CurrTest := 0;
  IsNotOK := False;
  lblTestValue.Caption := '0';
  lblErrorsValue.Caption := '0';
  lblFailedValue.Caption := '0';
  ElapsedTime := 0.0;
  ListView1.Items.Clear;
  if not (TotTests > 0) then
  begin
    NoTagsMesssage;
    exit;
  end;
  step := TreeView1.Items.Count;
  step := Trunc((494/step) + 0.5);
  Image1.Width := 0;
  for I := 0 to TreeView1.Items.Count-1 do    // Iterate
  begin
    CurNode := TreeView1.Items[I];
    if CurNode.Level = 0 then
    begin
      RoutineName := Piece(CurNode.Text,' - ',1);
      if CurNode.ImageIndex <> 6 then
      begin
        CurNode.ImageIndex := 1;
        CurNode.StateIndex := -1;
        CurNode.SelectedIndex := 1;
      end;
      for J := 1 to CurNode.Count do    // Iterate
      begin
        CurChildNode := CurNode.Item[J-1];
        EntryTag := Piece(CurChildNode.Text,' - ',1);
        RetVal := DoNext(EntryTag+'^'+RoutineName);
        if RetVal = dnrFine then
        begin
          CurChildNode.ImageIndex := 1;
          CurChildNode.StateIndex := -1;
          CurChildNode.SelectedIndex := 1;
        end
        else if RetVal = dnrFailure then
        begin
          CurNode.ImageIndex := 2;
          CurNode.SelectedIndex := 2;
          CurChildNode.ImageIndex := 2;
          CurChildNode.StateIndex := -1;
          CurChildNode.SelectedIndex := 2;
        end
        else if RetVal = dnrError then
        begin
          CurNode.ImageIndex := 2;
          CurNode.SelectedIndex := 2;
          CurChildNode.ImageIndex := 5;
          CurChildNode.StateIndex := -1;
          CurChildNode.SelectedIndex := 5;
        end;
      end;    // for
    end;
  end;    // for
  DoNext(''); // Clear system
  Image1.Width := 494;
  TreeView1.FullCollapse;
  if ImageColor = clRed then
  begin
    for I := 0 to TreeView1.Items.Count-1 do    // Iterate
    begin
      CurNode := TreeView1.Items[I];
      if CurNode.Level = 0 then
        if CurNode.ImageIndex = 2 then
          CurNode.Expand(True);
    end;
  end
  else
    TreeView1.FullExpand;
end;

procedure TForm1.btnConnectClick(Sender: TObject);
begin
  if btnConnect.Caption = 'Connect' then
  begin
    if edtServer.Text = '' then
    begin
      ShowMessage('Please Enter or Select a Server and Port to connect');
      exit;
    end;
    RPCBroker1.Server := edtServer.Text;
    RPCBroker1.ListenerPort := StrToInt(edtPort.Text);
    RPCBroker1.Connected := True;
    if RPCBroker1.Connected then
    begin
      lblConnected.Caption := 'Connected';
      lblConnected.Font.Color := clGreen;
      btnConnect.Caption := 'Disconnect';
      ClearRun;
      ClearList;
    end
    else
      ShowMessage('Couldn''t Connect Successfully');
  end
  else
  begin
    RPCBroker1.Connected := False;
    lblConnected.Caption := 'Disconnected';
    lblConnected.Font.Color := clRed;
    btnConnect.Caption := 'Connect';
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  j: Integer;
begin
  TreeView1.Items.Clear;
  ListView1.Items.Clear;
  ClearList;
  with RPCBroker1 do
  begin
    for j := 1 to ParamCount do    // Iterate through possible command line arguments
    begin
      if (Pos('P=',UpperCase(ParamStr(j))) > 0) or (Pos('PORT=',UpperCase(ParamStr(j))) > 0) then
      begin
        ListenerPort := StrToInt(Copy(ParamStr(j),
                         (Pos('=',ParamStr(j))+1),length(ParamStr(j))));
        edtPort.Text := IntToStr(ListenerPort);
      end;
      if (Pos('S=',UpperCase(ParamStr(j))) > 0) or (Pos('SERVER=',UpperCase(ParamStr(j))) > 0) then
      begin
        Server := Copy(ParamStr(j),
                         (Pos('=',ParamStr(j))+1),length(ParamStr(j)));
        edtServer.Text := Server;
      end;
    end;
  end;    // with RPCBroker1
end;

function TForm1.DoNext(Location: String): TDoNextReturn;
var
  I: Integer;
  NFailed, NErrs: Integer;
  Str, Str1: String;
  LeftLoc,TopLoc,BottomLoc,RightLoc: Integer;
  Rect1: TRect;
  Rect2: TRect;
  ListItem: TListItem;
  DateTime1,DateTime2: TDateTime;
  TempStr,TempHr,TempMin,TempSec,TempTime: String;
begin
  Result := dnrFine;  // no failure or error
  with RPCBroker1 do
  begin
    RemoteProcedure := 'utMUNIT-TEST NEXT';
    Param[0].Value := Location;
    Param[0].PType := Literal;
    if (CompareText(Separator,NewSeparator) = 0) then
    begin
      Param[1].Value := NewSeparator;
      Param[1].PType := Literal;
    end;
    DateTime1 := Now;
    call;
    DateTime2 := Now;
    ElapsedTime := ElapsedTime + (DateTime2-DateTime1);
    TempStr := FormatDateTime('hh:nn:ss.zzz',ElapsedTime);
    TempHr := Piece(TempStr,':');
    TempMin := Piece(TempStr,':',2);
    TempSec := Piece(Piece(TempStr,':',3),'.');
    TempTime := IntToStr((3600*StrToInt(TempHr))+(60*StrToInt(TempMin))+StrToInt(TempSec));
    lblElapsedValue.Caption := TempTime+'.'+Piece(TempStr,'.',2);
    if Results.Count > 0 then
    begin
      Str := Results[0];
      Str := Piece(Str,Separator,1);
      if Str = '' then
        Str := '0';
      lblTestValue.Caption := IntToStr(StrToInt(lblTestValue.Caption) + StrToInt(Str));
      Str := Piece(Results[0],Separator,2);
      if Str = '' then
        Str := '0';
      Result := dnrFine;  // 0 = no problem
      NFailed := StrToInt(Str);
      if NFailed > 0 then
      begin
        Result := dnrFailure;  // 1 = failure
        lblFailedValue.Caption := IntToStr(StrToInt(lblFailedValue.Caption)+NFailed);
      end;
      Str := Piece(Results[0],Separator,3);
      if Str = '' then
        Str := '0';
      NErrs := StrToInt(Str);
      if NErrs > 0 then
      begin
        Result := dnrError;
        lblErrorsValue.Caption := IntToStr(StrToInt(lblErrorsValue.Caption)+NErrs);
      end;
      for I := 1 to Results.Count-1 do    // Iterate
      begin
        Str := Results[I];
        ListItem := ListView1.Items.Add;
        if (CompareText(Separator,OldSeparator) = 0) then
        begin
          ListItem.Caption := Piece(Str,Separator,1)+'^'+Piece(Str,Separator,2);
          ListItem.SubItems.Add(Piece(Str,Separator,3));
          Str1 := Piece(Str,Separator,4);
          if Piece(Str,Separator,5) <> '' then
            Str1 := Str1 + ' - ' + Piece(Str,Separator,5);
          ListItem.SubItems.Add(Str1);
        end
        else
        begin
          ListItem.Caption := Piece(Str,Separator,1);
          ListItem.SubItems.Add(Piece(Str,Separator,2));
          Str1 := Piece(Str,Separator,3);
          if Piece(Str,Separator,4) <> '' then
            Str1 := Str1 + ' - ' + Piece(Str,Separator,4);
          ListItem.SubItems.Add(Str1);
        end;
      end;    // for
    end;
  end;    // with
  CurrTest := CurrTest + 1;
  Image1.Width := Image1.Width + step;
  with Image1.Canvas do // .ClipRect do
  begin
    Rect1 := ClipRect;
  end;    // with

  if not (Result = dnrFine) then
    IsNotOK := True;

  if not IsNotOK then
  begin
    Image1.Width := Image1.Width + step;
    Image1.Canvas.Brush.Color := clGreen;
    Image1.Canvas.Brush.Style := bsSolid;
    ImageColor := clGreen;
    Image1.Canvas.FillRect(Rect1);
    Image1.Update;
  end;

  if IsNotOK then
  begin
    Image1.Canvas.Brush.Color := clRed;
    Image1.Canvas.Brush.Style := bsSolid;
    ImageColor := clRed;
    Image1.Canvas.FillRect(Rect1);
    Image1.Update;
  end;
end;

procedure TForm1.btnExitClick(Sender: TObject);
begin
  Halt;
end;

procedure TForm1.btnSelectServerClick(Sender: TObject);
var
  Server: String;
  PortStr: String;
begin
  if GetServerInfo(Server,PortStr) <> mrCancel then
  begin
    edtServer.Text := Server;
    edtPort.Text := PortStr;
  end;
end;

procedure TForm1.btnSelectGroupClick(Sender: TObject);
var
  AddRecord: Boolean;
begin
  if btnSelectGroup.Caption = 'Select Group' then
  begin
    if not RPCBroker1.Connected then
      btnConnectClick(Self);
    if RPCBroker1.Connected then
    begin
      FMLookUp1.AllowNew := False;
      if FMLookUp1.Execute(AddRecord) then
      begin
        edtPrimaryTestRoutine.Text := FMLister1.GetRecord(FMLookUp1.RecordNumber).GetField('.01').FMDBExternal;
        lblPrimaryTestRoutine.Caption := 'Selected Test Group:';
        GroupIEN := FMLookUp1.RecordNumber;
        btnSelectGroup.Caption := 'Clear Group';
        ClearList;
        ClearRun;
        btnListClick(Self);
      end;
    end;
  end
  else
  begin
    GroupIEN := '';
    edtPrimaryTestRoutine.Text := '';
    lblPrimaryTestRoutine.Caption := 'Primary Test Routine';
    btnSelectGroup.Caption := 'Select Group';
    ClearList;
    ClearRun;
  end;
  PageControl1.ActivePage := tsTestHierarchy;
end;

procedure TForm1.ClearRun;
var
  Rect1: TRect;
begin
    lblTestValue.Caption := '';
    lblErrorsValue.Caption := '';
    lblFailedValue.Caption := '';
    lblElapsedValue.Caption := '';
    ElapsedTime := 0.0;
    ListView1.Items.Clear;
    Rect1 := Image1.Canvas.ClipRect;
    Image1.Canvas.Brush.Color := Color;      // form color
    ImageColor := Color;
    Image1.Canvas.Brush.Style := bsSolid;
    Image1.Canvas.FillRect(Rect1);
    Image1.Update;
end;

procedure TForm1.ClearList;
begin
  TreeView1.Items.Clear;
  ClearRun;
  btnList.Default := True;
  btnRun.Enabled := False;
  btnRun.Default := False;
  lblTagValue.Caption := '';
  lblTestValue.Caption := '';
  lblErrorsValue.Caption := '';
  lblFailedValue.Caption := '';
  lblElapsedValue.Caption := '';
end;

procedure TForm1.About2Click(Sender: TObject);
begin
  ShowAboutBox;
end;

procedure TForm1.actExitExecute(Sender: TObject);
begin
  RPCBroker1.Connected := False;
  Halt;
end;

procedure TForm1.NoTagsMesssage;
begin
  ShowMessage('There are no TAGS (i.e., tests) to be run in the selected routine(s)');
end;

end.
