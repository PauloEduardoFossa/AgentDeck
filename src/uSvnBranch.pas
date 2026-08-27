unit uSvnBranch;

interface

function BranchAtualSVN(const CaminhoWorkingCopy: string; TimeoutMs: Cardinal = 8000): string;

implementation

uses
  Winapi.Windows, System.SysUtils, System.Classes;

// Roda um comando capturando a saída padrão via pipe anônimo, com timeout.
// Nunca lança exceção: qualquer falha (comando não encontrado, timeout,
// processo sem permissão) devolve False e Saida vazio.
function ExecutarCapturandoSaida(const LinhaComando: string; TimeoutMs: Cardinal; out Saida: string): Boolean;
var
  Seguranca: TSecurityAttributes;
  PipeLeitura, PipeEscrita: THandle;
  Inicio: TStartupInfo;
  Processo: TProcessInformation;
  Buffer: array[0..4095] of AnsiChar;
  BytesLidos: DWORD;
  Fluxo: TBytesStream;
  Comando: string;
begin
  Result := False;
  Saida := '';

  Seguranca.nLength := SizeOf(TSecurityAttributes);
  Seguranca.bInheritHandle := True;
  Seguranca.lpSecurityDescriptor := nil;

  if not CreatePipe(PipeLeitura, PipeEscrita, @Seguranca, 0) then
    Exit;

  try
    // Só o lado de escrita precisa ser herdado pelo processo filho.
    SetHandleInformation(PipeLeitura, HANDLE_FLAG_INHERIT, 0);

    FillChar(Inicio, SizeOf(Inicio), 0);
    Inicio.cb := SizeOf(Inicio);
    Inicio.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    Inicio.wShowWindow := SW_HIDE;
    Inicio.hStdOutput := PipeEscrita;
    Inicio.hStdError := PipeEscrita;
    Inicio.hStdInput := 0;

    FillChar(Processo, SizeOf(Processo), 0);

    Comando := LinhaComando;
    UniqueString(Comando);
    if not CreateProcess(nil, PChar(Comando), nil, nil, True, CREATE_NO_WINDOW, nil, nil, Inicio, Processo) then
      Exit;

    // O processo filho herdou o lado de escrita; fechar aqui evita que a
    // leitura fique esperando pra sempre depois que o filho terminar.
    CloseHandle(PipeEscrita);
    PipeEscrita := 0;

    try
      if WaitForSingleObject(Processo.hProcess, TimeoutMs) = WAIT_TIMEOUT then
      begin
        TerminateProcess(Processo.hProcess, 1);
        Exit;
      end;

      Fluxo := TBytesStream.Create;
      try
        while ReadFile(PipeLeitura, Buffer, SizeOf(Buffer), BytesLidos, nil) and (BytesLidos > 0) do
          Fluxo.Write(Buffer, BytesLidos);
        Saida := TEncoding.ANSI.GetString(Fluxo.Bytes, 0, Fluxo.Size);
        Result := True;
      finally
        Fluxo.Free;
      end;
    finally
      CloseHandle(Processo.hProcess);
      CloseHandle(Processo.hThread);
    end;
  finally
    CloseHandle(PipeLeitura);
    if PipeEscrita <> 0 then
      CloseHandle(PipeEscrita);
  end;
end;

function ExtrairNomeBranch(const RelativeUrl: string): string;
var
  Resto: string;
  Barra: Integer;
begin
  Result := '';
  if RelativeUrl = '' then
    Exit;

  if RelativeUrl.StartsWith('^/branches/') then
  begin
    Resto := RelativeUrl.Substring(Length('^/branches/'));
    Barra := Resto.IndexOf('/');
    if Barra >= 0 then
      Resto := Resto.Substring(0, Barra);
    Result := Resto;
  end
  else if RelativeUrl.StartsWith('^/trunk') then
    Result := 'trunk'
  else if RelativeUrl.StartsWith('^/tags/') then
  begin
    Resto := RelativeUrl.Substring(Length('^/tags/'));
    Barra := Resto.IndexOf('/');
    if Barra >= 0 then
      Resto := Resto.Substring(0, Barra);
    Result := 'tag: ' + Resto;
  end;
end;

function BranchAtualSVN(const CaminhoWorkingCopy: string; TimeoutMs: Cardinal): string;
var
  Saida, RelativeUrl: string;
begin
  Result := '';
  if not ExecutarCapturandoSaida(
    Format('svn.exe info --show-item relative-url "%s"', [CaminhoWorkingCopy]),
    TimeoutMs, Saida) then
    Exit;

  RelativeUrl := Saida.Trim;
  Result := ExtrairNomeBranch(RelativeUrl);
end;

end.
