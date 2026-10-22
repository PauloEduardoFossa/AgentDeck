unit uOpenVpn;

interface

procedure ConectarVPN;
procedure DesconectarVPN;
function VPNConectada: Boolean;

implementation

uses
  Winapi.Windows, Winapi.ShellAPI, Winapi.IpTypes, Winapi.IpHlpApi,
  System.SysUtils, uConfiguracoes;

// Adaptadores virtuais do OpenVPN (TAP-Windows, Wintun ou DCO): só ficam
// com OperStatus = Up enquanto o túnel está conectado.
function VPNConectada: Boolean;
const
  TiposAdaptador: array[0..3] of string = ('TAP-Windows', 'Wintun', 'OpenVPN', 'Data Channel Offload');
var
  Tamanho: ULONG;
  Buffer: TBytes;
  Adaptador: PIP_ADAPTER_ADDRESSES;
  Descricao, Tipo: string;
begin
  Result := False;
  Tamanho := 0;
  if GetAdaptersAddresses(0 {AF_UNSPEC}, GAA_FLAG_SKIP_UNICAST or GAA_FLAG_SKIP_ANYCAST or
    GAA_FLAG_SKIP_MULTICAST or GAA_FLAG_SKIP_DNS_SERVER, nil, nil, @Tamanho) <> ERROR_BUFFER_OVERFLOW then
    Exit;
  SetLength(Buffer, Tamanho);
  Adaptador := PIP_ADAPTER_ADDRESSES(@Buffer[0]);
  if GetAdaptersAddresses(0 {AF_UNSPEC}, GAA_FLAG_SKIP_UNICAST or GAA_FLAG_SKIP_ANYCAST or
    GAA_FLAG_SKIP_MULTICAST or GAA_FLAG_SKIP_DNS_SERVER, nil, Adaptador, @Tamanho) <> NO_ERROR then
    Exit;
  while Adaptador <> nil do
  begin
    if Adaptador.OperStatus = IfOperStatusUp then
    begin
      Descricao := Adaptador.Description;
      for Tipo in TiposAdaptador do
        if Descricao.Contains(Tipo) then
          Exit(True);
    end;
    Adaptador := Adaptador.Next;
  end;
end;

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
