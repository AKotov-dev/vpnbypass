unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  ExtCtrls, IniPropStorage, Process, Types, DefaultTranslator, LCLType,
  LCLTranslator, FileUtil;

type

  { TMainForm }

  TMainForm = class(TForm)
    IFBox: TComboBox;
    GWBox: TEdit;
    ImageList1: TImageList;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    BListBox: TListBox;
    Label5: TLabel;
    Label6: TLabel;
    OpenDialog1: TOpenDialog;
    RTableBox: TListBox;
    RListBox: TListBox;
    Panel1: TPanel;
    Panel2: TPanel;
    ApplyBtn: TSpeedButton;
    DelBtn: TSpeedButton;
    AddBtn: TSpeedButton;
    StopBtn: TSpeedButton;
    OpenBtn: TSpeedButton;
    SaveBtn: TSpeedButton;
    SaveDialog1: TSaveDialog;
    Splitter1: TSplitter;
    StaticText1: TStaticText;
    procedure BListBoxDrawItem(Control: TWinControl; Index: integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure DelBtnClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure AddBtnClick(Sender: TObject);
    procedure ApplyBtnClick(Sender: TObject);
    procedure StopBtnClick(Sender: TObject);
    procedure SaveBtnClick(Sender: TObject);
    procedure OpenBtnClick(Sender: TObject);
  private

  public

  end;

//Ресурсы перевода
resourcestring
  SDeleteRecord = 'Remove selected domains and routes?';
  SAppendRecord = 'Append a domain and routes';
  SDomainNotFound = 'Domain not found!';
  SNoData = 'Specify interface (IF) and gateway (GW)!';

var
  MainForm: TMainForm;

implementation

uses
  show_routes_trd;

{$R *.lfm}

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
var
  s: ansistring;
  SL: TStringList;
  i: integer;
begin
  try
    SL := TStringList.Create;

    MainForm.Caption := Application.Title;

    if not DirectoryExists('/etc/vpnbypass') then MkDir('/etc/vpnbypass');
    IniPropStorage1.IniFileName := '/etc/vpnbypass/vpnbypass.conf';

    //Список интерфейсов
    RunCommand('/bin/bash', ['-c',
      'ip a | grep ^[[:digit:]] | cut -f2 -d":" | tr -d " " | tr "\n" ";"'], s);

    //Разделяем два пришедших значения
    SL.Delimiter := ';';
    SL.StrictDelimiter := True;
    SL.DelimitedText := Trim(s);

    for i := 0 to SL.Count - 2 do
      IFBox.Items.Append(SL[i]);

    //Загрузка списка сайтов
    if FileExists('/etc/vpnbypass/blistbox') then
      BListBox.Items.LoadFromFile('/etc/vpnbypass/blistbox');
    //Загрузка списка маршрутов
    if FileExists('/etc/vpnbypass/rlistbox') then
      RListBox.Items.LoadFromFile('/etc/vpnbypass/rlistbox');
    //Загрузка IF и GW
    if FileExists('/etc/vpnbypass/if_gwbox') then
    begin
      SL.LoadFromFile('/etc/vpnbypass/if_gwbox');
      IFBox.Text := SL[0];
      GWBox.Text := SL[1];
    end;

  finally
    SL.Free;
  end;
end;

procedure TMainForm.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  case Key of
    //    VK_DELETE: DelBtn.Click;
    VK_INSERT: AddBtn.Click;
  end;

  //Отлуп после закрытия InputQery (окно модальное)
  Key := $0;
end;

//Удаление выбранных
procedure TMainForm.DelBtnClick(Sender: TObject);
var
  s, s1: ansistring;
  i: integer;
begin
  if BListBox.Count = 0 then Exit;

  if MessageDlg(SDeleteRecord, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin

    //Поиск выбранных
    for i := 0 to BListBox.Count - 1 do
      if BListBox.Selected[i] then
      begin
        //Заменяем a на d и применяем
        RunCommand('/bin/bash', ['-c', 'cat /etc/vpnbypass/rlistbox | grep ' +
          BListBox.Items[i] + ' | cut -f1 -d";" | tr "\n" ";" | sed ' +
          '''' + 's/ip r a*/ip r d/g' + ''''], s);

        RunCommand('/bin/bash', ['-c', s], s1);

        //Удаляем из списка маршрутов
        RunCommand('/bin/bash', ['-c', 'sed -i "/' + BListBox.Items[i] +
          '/d" /etc/vpnbypass/rlistbox'], s);
      end;

    RListBox.Items.LoadFromFile('/etc/vpnbypass/rlistbox');

    if RListBox.Count <> 0 then RListBox.ItemIndex := 0;

    //Удаляем из списка сайтов
    for i := -1 + BListBox.Items.Count downto 0 do
      if BListBox.Selected[i] then BListBox.Items.Delete(i);
    BListBox.Items.SaveToFile('/etc/vpnbypass/blistbox');

    if BListBox.Count <> 0 then BListBox.ItemIndex := 0;
  end;
end;

//Сохраняем IF и GW в отдельный файл
procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
var
  S: TStringList;
begin
  try
    S := TStringList.Create;
    S.Add(IFBox.Text);
    S.Add(GWBox.Text);
    S.SaveToFile('/etc/vpnbypass/if_gwbox');
  finally
    S.Free;
  end;
end;

procedure TMainForm.BListBoxDrawItem(Control: TWinControl; Index: integer;
  ARect: TRect; State: TOwnerDrawState);
var
  BitMap: TBitMap;
begin
  try
    BitMap := TBitMap.Create;
    with BListBox do
    begin
      Canvas.FillRect(aRect);

      //Название (текст по центру-вертикали)
      Canvas.TextOut(aRect.Left + 30, aRect.Top + ItemHeight div 2 -
        Canvas.TextHeight('A') div 2 + 1, Items[Index]);

      //Иконка
      ImageList1.GetBitMap(0, BitMap);

      Canvas.Draw(aRect.Left + 2, aRect.Top + (ItemHeight - 24) div 2 + 2, BitMap);
    end;
  finally
    BitMap.Free;
  end;
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  FShowRoutesThread: TThread;
begin
  IniPropStorage1.Restore;

  if BListBox.Items.Count <> 0 then BListBox.ItemIndex := 0;
  if RListBox.Items.Count <> 0 then RListBox.ItemIndex := 0;

  //Поток проверки состояния
  FShowRoutesThread := ShowRoutes.Create(False);
  FShowRoutesThread.Priority := tpNormal;
  if RTableBox.Items.Count <> 0 then RTableBox.ItemIndex := 0;
end;

//Add
procedure TMainForm.AddBtnClick(Sender: TObject);
var
  Value: string;
  s: ansistring;
  SL: TStringList;
  i: integer;
begin
  if (Trim(IFBox.Text) = '') or (Trim(GWBox.Text) = '') then
  begin
    MessageDlg(SNoData, mtWarning, [mbOK], 0);
    Exit;
  end;

  Value := '';
  repeat
    if not InputQuery(SAppendRecord, '', Value) then
      Exit;
  until Trim(Value) <> '';

  //Очистка от https:// и http://
  Value := StringReplace(Value, '/', '', [rfReplaceAll, rfIgnoreCase]);
  Value := StringReplace(Value, 'http:', '', [rfReplaceAll, rfIgnoreCase]);
  Value := StringReplace(Value, 'https:', '', [rfReplaceAll, rfIgnoreCase]);
  Value := Trim(Value);

  //Если домен существует - показать в списке и выйти
  if BListBox.Items.IndexOf(Value) <> -1 then
  begin
    BListBox.ItemIndex := BListBox.Items.IndexOf(Value);
    Exit;
  end;

  SL := TStringList.Create;

  Label6.Visible := True;
  Application.ProcessMessages;
  RunCommand('/bin/bash', ['-c', 'host ' + Value +
    ' | grep "has address" | cut -f4 -d" " | tr "\n" ";" || echo "error"'], s);

  Label6.Visible := False;
  s := Trim(s);

  if (s = 'error') or (s = '') then MessageDlg(SDomainNotFound, mtWarning, [mbOK], 0)
  else
  begin
    //Разделяем два пришедших значения
    SL.Delimiter := ';';
    SL.StrictDelimiter := True;
    SL.DelimitedText := Trim(s);

    for i := 0 to SL.Count - 2 do
    begin
      RListBox.Items.Append('ip r a ' + SL[i] + ' via ' + GWBox.Text +
        ' dev ' + IFBox.Text + '; # ' + Value);
    end;

    BListBox.Items.Append(Value);

    BListBOx.Items.SaveToFile('/etc/vpnbypass/blistbox');
    RListBOx.Items.SaveToFile('/etc/vpnbypass/rlistbox');

    RunCommand('/bin/bash', ['-c', 'chmod +x /etc/vpnbypass/rlistbox'], s);

    //Применить
    //ApplyBtn.Click;
  end;
  SL.Free;
end;

//Restart
procedure TMainForm.ApplyBtnClick(Sender: TObject);
var
  s, s1: ansistring;
begin
  if (Trim(IFBox.Text) = '') or (Trim(GWBox.Text) = '') or (RListBox.Count = 0) then
    Exit;

  RunCommand('/bin/bash', ['-c',
    'cat /etc/vpnbypass/rlistbox | cut -f1 -d";" | tr "\n" ";"'], s);

  RunCommand('/bin/bash', ['-c', s], s1);

  Application.ProcessMessages;
  RunCommand('/bin/bash', ['-c', 'systemctl enable vpnbypass'], s);
end;

//Disable
procedure TMainForm.StopBtnClick(Sender: TObject);
var
  s, s1: ansistring;
begin
  RunCommand('/bin/bash', ['-c',
    'cat /etc/vpnbypass/rlistbox | cut -f1 -d";" | tr "\n" ";" | sed ' +
    '''' + 's/ip r a*/ip r d/g' + ''''], s);

  RunCommand('/bin/bash', ['-c', s], s1);

  Application.ProcessMessages;
  RunCommand('/bin/bash', ['-c', 'systemctl disable vpnbypass'], s);
end;

//Save
procedure TMainForm.SaveBtnClick(Sender: TObject);
var
  s: ansistring;
  SL: TStringList;
begin
  try
    SL := TStringList.Create;

    if SaveDialog1.Execute then
    begin
      SL.Add(IFBox.Text);
      SL.Add(GWBox.Text);
      SL.SaveToFile('/etc/vpnbypass/if_gwbox');

      Application.ProcessMessages;
      RunCommand('/bin/bash', ['-c',
        'cd /etc/vpnbypass && tar -cjvf 111.tar.bz2 *box; ' +
        'mv -f 111.tar.bz2 "' + SaveDialog1.FileName + '"'], s);
    end;
  finally
    SL.Free;
  end;
end;

//Load
procedure TMainForm.OpenBtnClick(Sender: TObject);
var
  s: ansistring;
  SL: TStringList;
begin
  try
    SL := TStringList.Create;

    if OpenDialog1.Execute then
    begin
      Application.ProcessMessages;

      StopBtn.Click;
      RunCommand('/bin/bash', ['-c', 'cd /etc/vpnbypass && tar -xjvf "' +
        OpenDialog1.FileName + '"'], s);

      //Загрузка IF и GW
      if FileExists('/etc/vpnbypass/if_gwbox') then
      begin
        SL.LoadFromFile('/etc/vpnbypass/if_gwbox');
        IFBox.Text := SL[0];
        GWBox.Text := SL[1];
      end;

      BListBox.Items.LoadFromFile('/etc/vpnbypass/blistbox');
      RListBox.Items.LoadFromFile('/etc/vpnbypass/rlistbox');

      if BListBox.Items.Count <> 0 then BListBox.ItemIndex := 0;
      if RListBox.Items.Count <> 0 then RListBox.ItemIndex := 0;
    end;
  finally
    SL.Free;
  end;
end;

end.
