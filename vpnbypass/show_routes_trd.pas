unit show_routes_trd;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, Graphics;

type
  ShowRoutes = class(TThread)
  private

    { Private declarations }
  protected
  var
    Routes: TStringList;

    procedure Execute; override;
    procedure ShowStatus;

  end;

implementation

uses unit1;

{ TRD }

procedure ShowRoutes.Execute;
var
  ShowProcess: TProcess;
begin
  FreeOnTerminate := True; //Уничтожать по завершении

  while not Terminated do
    try
      Routes := TStringList.Create;
      ShowProcess := TProcess.Create(nil);

      ShowProcess.Executable := 'bash';
      ShowProcess.Parameters.Add('-c');
      ShowProcess.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];

      ShowProcess.Parameters.Add('ip r');
      ShowProcess.Execute;

      Routes.LoadFromStream(ShowProcess.Output);
      Synchronize(@ShowStatus);

      Sleep(1000);
    finally
      Routes.Free;
      ShowProcess.Free;
    end;
end;

procedure ShowRoutes.ShowStatus;
begin
  MainForm.RTableBox.Items.Assign(Routes);
end;

end.
