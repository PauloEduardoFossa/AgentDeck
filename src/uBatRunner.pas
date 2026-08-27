unit uBatRunner;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, Winapi.ActiveX, Winapi.ShlObj,
  System.SysUtils, System.IOUtils, System.Generics.Collections;

type
  TBatInfo = record
    Nome: string;      // sem extensão, pra exibir no botão
    Caminho: string;   // caminho completo do .bat
  end;

const
  PastaBatsPadrao = 'C:\TopSystem\zBat';

function ListarBats(const Pasta: string = PastaBatsPadrao): TArray<TBatInfo>;
procedure ExecutarBat(const CaminhoBat: string);

implementation

// Atalhos (.lnk) em PastaBatsPadrao apontam pro .bat de verdade em outro
// lugar (ex.: scripts de SVN mantidos fora da pasta de bats). Resolve via
// COM pra pegar o caminho real; '' se não conseguir (atalho quebrado, etc).
function ResolverAtalho(const CaminhoLnk: string): string;
var
  ShellLink: IShellLinkW;
  PersistFile: IPersistFile;
  Destino: array[0..MAX_PATH - 1] of WideChar;
  Dados: TWin32FindDataW;
begin
  Result := '';
  if Succeeded(CoCreateInstance(CLSID_ShellLink, nil, CLSCTX_INPROC_SERVER, IShellLinkW, ShellLink)) then
  begin
    PersistFile := ShellLink as IPersistFile;
    if Succeeded(PersistFile.Load(PWideChar(CaminhoLnk), STGM_READ)) then
      if Succeeded(ShellLink.GetPath(Destino, MAX_PATH, Dados, 0)) then
        Result := Destino;
  end;
end;

function ListarBats(const Pasta: string): TArray<TBatInfo>;
var
  Arquivos, Atalhos: TArray<string>;
  Arquivo, CaminhoReal: string;
  Lista: TList<TBatInfo>;
  Info: TBatInfo;
begin
  Lista := TList<TBatInfo>.Create;
  try
    if TDirectory.Exists(Pasta) then
    begin
      Arquivos := TDirectory.GetFiles(Pasta, '*.bat');
      for Arquivo in Arquivos do
      begin
        Info.Nome := TPath.GetFileNameWithoutExtension(Arquivo);
        Info.Caminho := Arquivo;
        Lista.Add(Info);
      end;

      Atalhos := TDirectory.GetFiles(Pasta, '*.lnk');
      for Arquivo in Atalhos do
      begin
        CaminhoReal := ResolverAtalho(Arquivo);
        if (CaminhoReal = '') or not TFile.Exists(CaminhoReal) then
          Continue;
        Info.Nome := TPath.GetFileNameWithoutExtension(CaminhoReal);
        Info.Caminho := CaminhoReal;
        Lista.Add(Info);
      end;
    end;
    Result := Lista.ToArray;
  finally
    Lista.Free;
  end;
end;

procedure ExecutarBat(const CaminhoBat: string);
var
  Pasta: string;
  Resultado: NativeInt;
begin
  Pasta := TPath.GetDirectoryName(CaminhoBat);
  // Verbo 'open' num .bat abre um cmd.exe novo com console próprio: preserva
  // 'pause' e cores, igual a dar 2 cliques nele. O app já está elevado
  // (manifest requireAdministrator), então o processo filho herda o privilégio.
  Resultado := ShellExecute(0, 'open', PChar(CaminhoBat), nil, PChar(Pasta), SW_SHOWNORMAL);
  if Resultado <= 32 then
    RaiseLastOSError;
end;

end.
