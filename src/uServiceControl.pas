unit uServiceControl;

interface

uses
  Winapi.Windows, Winapi.WinSvc, System.SysUtils, System.Classes;

type
  TStatusServico = (stParado, stIniciando, stParando, stRodando, stDesconhecido);

  TServicoInfo = record
    Nome: string;
    Descricao: string;
  end;

  TProgressoModoDev = reference to procedure(const Mensagem: string);

const
  // Ordem de start do Modo Desenvolvimento. Stop usa a ordem inversa.
  // Mesma dependencia documentada no CLAUDE.md do TopSystem, com Firebird
  // (banco) antes e o Nginx (proxy reverso na frente da API) depois.
  ServicosModoDesenvolvimento: array[0..4] of TServicoInfo = (
    (Nome: 'FirebirdServerDefaultInstance'; Descricao: 'Banco de dados (Firebird)'),
    (Nome: 'TopServer';                     Descricao: 'TopServer'),
    (Nome: 'TopSystem-TopCIOTService';      Descricao: 'TopCIOTService'),
    (Nome: 'TopSystem-TopServerAPI';        Descricao: 'TopServerAPI'),
    (Nome: 'TopSystem-Nginx';               Descricao: 'Nginx (proxy)')
  );

function StatusDoServico(const NomeServico: string): TStatusServico;
procedure IniciarServico(const NomeServico: string; TimeoutMs: Cardinal = 30000);
procedure PararServico(const NomeServico: string; TimeoutMs: Cardinal = 30000);

// Muda o tipo de inicializacao pra Manual, pra o Windows parar de subir o
// servico sozinho no boot. Setup unico, feito uma vez por maquina.
procedure DefinirInicioManual(const NomeServico: string);

function ModoDesenvolvimentoRodando: Boolean;
procedure AtivarModoDesenvolvimento(const OnProgresso: TProgressoModoDev = nil);
procedure DesativarModoDesenvolvimento(const OnProgresso: TProgressoModoDev = nil);
procedure AplicarInicioManualEmTodos(const OnProgresso: TProgressoModoDev = nil);

implementation

function AbrirGerenciador(Acesso: DWORD): SC_HANDLE;
begin
  Result := OpenSCManager(nil, nil, Acesso);
  if Result = 0 then
    RaiseLastOSError;
end;

function AbrirServico(GerenciadorHandle: SC_HANDLE; const NomeServico: string; Acesso: DWORD): SC_HANDLE;
begin
  Result := OpenService(GerenciadorHandle, PChar(NomeServico), Acesso);
  if Result = 0 then
    RaiseLastOSError;
end;

function StatusDoServico(const NomeServico: string): TStatusServico;
var
  GerenciadorHandle, ServicoHandle: SC_HANDLE;
  Status: TServiceStatus;
begin
  Result := stDesconhecido;
  GerenciadorHandle := OpenSCManager(nil, nil, SC_MANAGER_CONNECT);
  if GerenciadorHandle = 0 then
    Exit;
  try
    ServicoHandle := OpenService(GerenciadorHandle, PChar(NomeServico), SERVICE_QUERY_STATUS);
    if ServicoHandle = 0 then
      Exit;
    try
      if not QueryServiceStatus(ServicoHandle, Status) then
        Exit;
      case Status.dwCurrentState of
        SERVICE_RUNNING:      Result := stRodando;
        SERVICE_STOPPED:      Result := stParado;
        SERVICE_START_PENDING: Result := stIniciando;
        SERVICE_STOP_PENDING:  Result := stParando;
      else
        Result := stDesconhecido;
      end;
    finally
      CloseServiceHandle(ServicoHandle);
    end;
  finally
    CloseServiceHandle(GerenciadorHandle);
  end;
end;

procedure EsperarEstado(const NomeServico: string; EstadoEsperado: TStatusServico; TimeoutMs: Cardinal);
var
  Inicio: Cardinal;
begin
  Inicio := GetTickCount;
  while StatusDoServico(NomeServico) <> EstadoEsperado do
  begin
    if GetTickCount - Inicio > TimeoutMs then
      raise Exception.CreateFmt('Timeout esperando o serviço %s chegar ao estado esperado.', [NomeServico]);
    Sleep(300);
  end;
end;

procedure IniciarServico(const NomeServico: string; TimeoutMs: Cardinal);
var
  GerenciadorHandle, ServicoHandle: SC_HANDLE;
  SemArgumentos: PWideChar;
begin
  if StatusDoServico(NomeServico) = stRodando then
    Exit;

  GerenciadorHandle := AbrirGerenciador(SC_MANAGER_CONNECT);
  try
    ServicoHandle := AbrirServico(GerenciadorHandle, NomeServico, SERVICE_START);
    try
      SemArgumentos := nil;
      if not StartService(ServicoHandle, 0, SemArgumentos) then
        RaiseLastOSError;
    finally
      CloseServiceHandle(ServicoHandle);
    end;
  finally
    CloseServiceHandle(GerenciadorHandle);
  end;

  EsperarEstado(NomeServico, stRodando, TimeoutMs);
end;

procedure PararServico(const NomeServico: string; TimeoutMs: Cardinal);
var
  GerenciadorHandle, ServicoHandle: SC_HANDLE;
  Status: TServiceStatus;
begin
  if StatusDoServico(NomeServico) = stParado then
    Exit;

  GerenciadorHandle := AbrirGerenciador(SC_MANAGER_CONNECT);
  try
    ServicoHandle := AbrirServico(GerenciadorHandle, NomeServico, SERVICE_STOP);
    try
      if not ControlService(ServicoHandle, SERVICE_CONTROL_STOP, Status) then
        RaiseLastOSError;
    finally
      CloseServiceHandle(ServicoHandle);
    end;
  finally
    CloseServiceHandle(GerenciadorHandle);
  end;

  EsperarEstado(NomeServico, stParado, TimeoutMs);
end;

procedure DefinirInicioManual(const NomeServico: string);
var
  GerenciadorHandle, ServicoHandle: SC_HANDLE;
begin
  GerenciadorHandle := AbrirGerenciador(SC_MANAGER_CONNECT);
  try
    ServicoHandle := AbrirServico(GerenciadorHandle, NomeServico, SERVICE_CHANGE_CONFIG);
    try
      if not ChangeServiceConfig(ServicoHandle, SERVICE_NO_CHANGE, SERVICE_DEMAND_START,
        SERVICE_NO_CHANGE, nil, nil, nil, nil, nil, nil, nil) then
        RaiseLastOSError;
    finally
      CloseServiceHandle(ServicoHandle);
    end;
  finally
    CloseServiceHandle(GerenciadorHandle);
  end;
end;

function ModoDesenvolvimentoRodando: Boolean;
var
  Item: TServicoInfo;
begin
  Result := True;
  for Item in ServicosModoDesenvolvimento do
    if StatusDoServico(Item.Nome) <> stRodando then
      Exit(False);
end;

procedure AtivarModoDesenvolvimento(const OnProgresso: TProgressoModoDev);
var
  Item: TServicoInfo;
begin
  for Item in ServicosModoDesenvolvimento do
  begin
    if Assigned(OnProgresso) then
      OnProgresso('Iniciando ' + Item.Descricao + '...');
    IniciarServico(Item.Nome);
  end;
  if Assigned(OnProgresso) then
    OnProgresso('Modo Desenvolvimento ativado.');
end;

procedure DesativarModoDesenvolvimento(const OnProgresso: TProgressoModoDev);
var
  I: Integer;
  Item: TServicoInfo;
begin
  for I := High(ServicosModoDesenvolvimento) downto Low(ServicosModoDesenvolvimento) do
  begin
    Item := ServicosModoDesenvolvimento[I];
    if Assigned(OnProgresso) then
      OnProgresso('Parando ' + Item.Descricao + '...');
    PararServico(Item.Nome);
  end;
  if Assigned(OnProgresso) then
    OnProgresso('Modo Desenvolvimento desativado.');
end;

procedure AplicarInicioManualEmTodos(const OnProgresso: TProgressoModoDev);
var
  Item: TServicoInfo;
begin
  for Item in ServicosModoDesenvolvimento do
  begin
    if Assigned(OnProgresso) then
      OnProgresso('Configurando ' + Item.Descricao + ' para início manual...');
    DefinirInicioManual(Item.Nome);
  end;
  if Assigned(OnProgresso) then
    OnProgresso('Configuração aplicada: os serviços não sobem mais sozinhos no boot.');
end;

end.
