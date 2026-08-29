program AgentDeck;

uses
  Vcl.Forms,
  uMain.Form in '..\src\uMain.Form.pas' {FormPrincipal},
  uSessionStatus in '..\src\uSessionStatus.pas',
  uServiceControl in '..\src\uServiceControl.pas',
  uBatRunner in '..\src\uBatRunner.pas',
  uHookServer in '..\src\uHookServer.pas',
  uSvnBranch in '..\src\uSvnBranch.pas',
  uConfiguracoes in '..\src\uConfiguracoes.pas',
  uOpenVpn in '..\src\uOpenVpn.pas',
  uSanitizacao in '..\src\uSanitizacao.pas',
  uHtmlTexto in '..\src\uHtmlTexto.pas',
  uTiFlux in '..\src\uTiFlux.pas',
  uTicketDocs in '..\src\uTicketDocs.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.ShowMainForm := False;
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.
