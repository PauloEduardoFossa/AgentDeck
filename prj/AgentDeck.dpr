program AgentDeck;

uses
  Vcl.Forms,
  uMain.Form in '..\src\uMain.Form.pas' {FormPrincipal},
  uSessionStatus in '..\src\uSessionStatus.pas',
  uServiceControl in '..\src\uServiceControl.pas',
  uBatRunner in '..\src\uBatRunner.pas',
  uHookServer in '..\src\uHookServer.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ShowMainForm := False;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
