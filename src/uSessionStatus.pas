unit uSessionStatus;

interface

uses
  System.SysUtils, System.Generics.Collections, System.SyncObjs, System.DateUtils;

type
  TStatusSessao = (ssOcioso, ssProcessando, ssEsperandoPermissao);

  TSessaoInfo = record
    SessionId: string;
    Cwd: string;
    Status: TStatusSessao;
    UltimoEvento: TDateTime;
  end;

  TSessionStatusStore = class
  private
    FLock: TCriticalSection;
    FSessoes: TDictionary<string, TSessaoInfo>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Atualizar(const SessionId, Cwd: string; Status: TStatusSessao);
    function Listar: TArray<TSessaoInfo>;

    // Sessões sem evento novo há mais desse tempo saem da lista: a sessão do
    // Claude Code pode ter sido fechada sem mandar um Stop final.
    procedure RemoverInativas(SegundosLimite: Integer);
  end;

var
  SessionStatusStore: TSessionStatusStore;

implementation

{ TSessionStatusStore }

constructor TSessionStatusStore.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FSessoes := TDictionary<string, TSessaoInfo>.Create;
end;

destructor TSessionStatusStore.Destroy;
begin
  FSessoes.Free;
  FLock.Free;
  inherited;
end;

procedure TSessionStatusStore.Atualizar(const SessionId, Cwd: string; Status: TStatusSessao);
var
  Info: TSessaoInfo;
  CwdAnterior: string;
begin
  FLock.Enter;
  try
    CwdAnterior := '';
    if FSessoes.ContainsKey(SessionId) then
      CwdAnterior := FSessoes[SessionId].Cwd;

    Info.SessionId := SessionId;
    if Cwd <> '' then
      Info.Cwd := Cwd
    else
      Info.Cwd := CwdAnterior;
    Info.Status := Status;
    Info.UltimoEvento := Now;
    FSessoes.AddOrSetValue(SessionId, Info);
  finally
    FLock.Leave;
  end;
end;

function TSessionStatusStore.Listar: TArray<TSessaoInfo>;
begin
  FLock.Enter;
  try
    Result := FSessoes.Values.ToArray;
  finally
    FLock.Leave;
  end;
end;

procedure TSessionStatusStore.RemoverInativas(SegundosLimite: Integer);
var
  Chave: string;
  ChavesRemover: TArray<string>;
  Info: TSessaoInfo;
begin
  FLock.Enter;
  try
    ChavesRemover := [];
    for Chave in FSessoes.Keys do
    begin
      Info := FSessoes[Chave];
      if SecondsBetween(Now, Info.UltimoEvento) > SegundosLimite then
        ChavesRemover := ChavesRemover + [Chave];
    end;
    for Chave in ChavesRemover do
      FSessoes.Remove(Chave);
  finally
    FLock.Leave;
  end;
end;

initialization
  SessionStatusStore := TSessionStatusStore.Create;

finalization
  FreeAndNil(SessionStatusStore);

end.
