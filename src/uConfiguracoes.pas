unit uConfiguracoes;

interface

function MonitorPreferido: Integer;
procedure SalvarMonitorPreferido(Indice: Integer);

function CaminhoOpenVpnGui: string;
function PerfilVPN: string;

function TiFluxApiKey: string;
procedure SalvarTiFluxApiKey(const Chave: string);
function PastaBaseTickets: string;

implementation

uses
  System.SysUtils, System.IOUtils, System.IniFiles;

const
  SecaoPainel = 'Painel';
  ChaveMonitor = 'Monitor';
  SecaoVPN = 'VPN';
  ChaveCaminhoOpenVpnGui = 'CaminhoOpenVpnGui';
  ChavePerfilVPN = 'Perfil';
  PadraoCaminhoOpenVpnGui = 'C:\Program Files\OpenVPN\bin\openvpn-gui.exe';
  PadraoPerfilVPN = 'ns1-TCP4-33132-topsystem.19-config';
  SecaoTiFlux = 'TiFlux';
  ChaveApiKey = 'ApiKey';
  ChavePastaBase = 'PastaBaseTickets';
  SubcaminhoPastaBasePadrao = 'OneDrive\Documentos\Obsidian Vault\01. ERP Top System\99. Ticket';

function CaminhoArquivoConfig: string;
var
  Pasta: string;
begin
  Pasta := TPath.Combine(GetEnvironmentVariable('APPDATA'), 'AgentDeck');
  if not TDirectory.Exists(Pasta) then
    TDirectory.CreateDirectory(Pasta);
  Result := TPath.Combine(Pasta, 'settings.ini');
end;

function MonitorPreferido: Integer;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Result := Ini.ReadInteger(SecaoPainel, ChaveMonitor, -1);
  finally
    Ini.Free;
  end;
end;

procedure SalvarMonitorPreferido(Indice: Integer);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Ini.WriteInteger(SecaoPainel, ChaveMonitor, Indice);
  finally
    Ini.Free;
  end;
end;

function CaminhoOpenVpnGui: string;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Result := Ini.ReadString(SecaoVPN, ChaveCaminhoOpenVpnGui, PadraoCaminhoOpenVpnGui);
  finally
    Ini.Free;
  end;
end;

function PerfilVPN: string;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Result := Ini.ReadString(SecaoVPN, ChavePerfilVPN, PadraoPerfilVPN);
  finally
    Ini.Free;
  end;
end;

function TiFluxApiKey: string;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Result := Ini.ReadString(SecaoTiFlux, ChaveApiKey, '');
  finally
    Ini.Free;
  end;
end;

procedure SalvarTiFluxApiKey(const Chave: string);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Ini.WriteString(SecaoTiFlux, ChaveApiKey, Chave);
  finally
    Ini.Free;
  end;
end;

function PastaBaseTickets: string;
var
  Ini: TIniFile;
  Padrao: string;
begin
  Padrao := TPath.Combine(GetEnvironmentVariable('USERPROFILE'), SubcaminhoPastaBasePadrao);
  Ini := TIniFile.Create(CaminhoArquivoConfig);
  try
    Result := Ini.ReadString(SecaoTiFlux, ChavePastaBase, Padrao);
  finally
    Ini.Free;
  end;
end;

end.
