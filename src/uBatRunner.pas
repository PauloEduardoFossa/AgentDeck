unit uBatRunner;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.IOUtils, System.Generics.Collections;

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

function ListarBats(const Pasta: string): TArray<TBatInfo>;
var
  Arquivos: TArray<string>;
  Arquivo: string;
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
