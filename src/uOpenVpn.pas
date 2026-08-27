unit uOpenVpn;

interface

procedure ConectarVPN;
procedure DesconectarVPN;

implementation

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, uConfiguracoes;

procedure ExecutarOpenVpnGui(const Parametro: string);
var
  Resultado: NativeInt;
begin
  Resultado := ShellExecute(0, 'open', PChar(CaminhoOpenVpnGui),
    PChar(Parametro + ' ' + PerfilVPN), nil, SW_SHOWNORMAL);
  if Resultado <= 32 then
    RaiseLastOSError;
end;

procedure ConectarVPN;
begin
  ExecutarOpenVpnGui('--connect');
end;

procedure DesconectarVPN;
begin
  ExecutarOpenVpnGui('--disconnect');
end;

end.
