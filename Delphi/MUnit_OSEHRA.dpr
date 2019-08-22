program MUnit_OSEHRA;

uses
  Forms,
  fMUnit in 'fMUnit.pas' {Form1},
  fVistAAbout in 'fVistAAbout.pas' {frmVistAAbout};

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'MUnit Test Framework';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
