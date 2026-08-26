unit uHookServer;

interface

procedure IniciarServidorHooks(const Porta: Integer = 47311);

implementation

uses
  Horse, Horse.Provider.VCL,
  System.SysUtils, System.JSON,
  uSessionStatus;

function CampoTexto(Obj: TJSONObject; const Nome: string): string;
var
  Valor: TJSONValue;
begin
  Result := '';
  if Obj = nil then
    Exit;
  Valor := Obj.GetValue(Nome);
  if Assigned(Valor) then
    Result := Valor.Value;
end;

type
  TResolveStatus = reference to function(Obj: TJSONObject): TStatusSessao;

// Registra uma rota de hook: extrai session_id/cwd do corpo, calcula o
// status via Resolver (varia por evento) e atualiza a store em memória.
procedure RegistrarRotaHook(const Caminho: string; const Resolver: TResolveStatus);
begin
  THorse.Post(Caminho,
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      Json: TJSONObject;
      SessionId, Cwd: string;
    begin
      Json := nil;
      try
        try
          Json := TJSONObject.ParseJSONValue(Req.Body) as TJSONObject;
        except
          Json := nil;
        end;

        if Json = nil then
        begin
          Res.Status(400).Send('JSON inválido');
          Exit;
        end;

        SessionId := CampoTexto(Json, 'session_id');
        if SessionId = '' then
        begin
          Res.Status(400).Send('session_id ausente');
          Exit;
        end;
        Cwd := CampoTexto(Json, 'cwd');

        SessionStatusStore.Atualizar(SessionId, Cwd, Resolver(Json));
        Res.Status(200).Send('ok');
      finally
        Json.Free;
      end;
    end);
end;

procedure RegistrarRotas;
begin
  RegistrarRotaHook('/hooks/user-prompt-submit',
    function(Obj: TJSONObject): TStatusSessao
    begin
      Result := ssProcessando;
    end);

  RegistrarRotaHook('/hooks/pre-tool-use',
    function(Obj: TJSONObject): TStatusSessao
    begin
      Result := ssProcessando;
    end);

  RegistrarRotaHook('/hooks/post-tool-use',
    function(Obj: TJSONObject): TStatusSessao
    begin
      Result := ssProcessando;
    end);

  RegistrarRotaHook('/hooks/subagent-stop',
    function(Obj: TJSONObject): TStatusSessao
    begin
      Result := ssProcessando;
    end);

  RegistrarRotaHook('/hooks/stop',
    function(Obj: TJSONObject): TStatusSessao
    begin
      Result := ssOcioso;
    end);

  // Notification cobre vários casos (permission_prompt, idle_prompt, etc).
  // Só permission_prompt e idle_prompt têm significado claro pro painel.
  RegistrarRotaHook('/hooks/notification',
    function(Obj: TJSONObject): TStatusSessao
    var
      TipoNotificacao: string;
    begin
      TipoNotificacao := CampoTexto(Obj, 'notification_type');
      if TipoNotificacao = 'permission_prompt' then
        Result := ssEsperandoPermissao
      else if TipoNotificacao = 'idle_prompt' then
        Result := ssOcioso
      else
        Result := ssProcessando;
    end);
end;

procedure IniciarServidorHooks(const Porta: Integer);
begin
  RegistrarRotas;
  THorse.Listen(Porta);
end;

end.
