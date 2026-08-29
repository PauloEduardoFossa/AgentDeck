unit uTiFlux;

interface

uses
  System.SysUtils;

type
  ETiFluxErro = class(Exception);

  TTiFluxComunicacao = record
    Autor: string;
    DataCriacao: TDateTime;
    Texto: string; // HTML cru — converter com uHtmlTexto antes de gravar
  end;

  TTiFluxTicket = record
    Numero: string;
    Titulo: string;
    Descricao: string; // HTML cru
    Comunicacoes: TArray<TTiFluxComunicacao>; // em ordem de cadastro (mais antiga primeiro)
  end;

// Busca o ticket (aba "Informacoes gerais") e as comunicacoes internas
// (Comunicacao > Equipe interna), paginando ate esgotar. Levanta ETiFluxErro
// em caso de token invalido, ticket inexistente ou erro de rede/HTTP.
function BuscarTicketTiFlux(const Numero, ApiKey: string): TTiFluxTicket;

implementation

uses
  System.Net.HttpClient, System.Net.URLClient, System.JSON, System.DateUtils,
  System.Generics.Collections, System.Generics.Defaults;

const
  UrlBase = 'https://api.tiflux.com/api/v2';
  ItensPorPagina = 200; // limite maximo aceito pela API
  MaximoPaginas = 50;   // guarda contra loop indevido

function ObterTexto(const Obj: TJSONObject; const Campo: string): string;
var
  Valor: TJSONValue;
begin
  Result := '';
  if not Assigned(Obj) then
    Exit;
  Valor := Obj.FindValue(Campo);
  if Assigned(Valor) and not (Valor is TJSONNull) then
    Result := Valor.Value;
end;

function ObterObjeto(const Obj: TJSONObject; const Campo: string): TJSONObject;
var
  Valor: TJSONValue;
begin
  Result := nil;
  if not Assigned(Obj) then
    Exit;
  Valor := Obj.FindValue(Campo);
  if Assigned(Valor) and (Valor is TJSONObject) then
    Result := TJSONObject(Valor);
end;

function LerDataISO(const Obj: TJSONObject; const Campo: string): TDateTime;
var
  Texto: string;
begin
  Texto := ObterTexto(Obj, Campo);
  if (Texto = '') or not TryISO8601ToDate(Texto, Result, False) then
    Result := 0;
end;

function ExecutarGet(const Http: THTTPClient; const Endpoint, ApiKey: string): TJSONValue;
var
  Resposta: IHTTPResponse;
begin
  Resposta := Http.Get(UrlBase + Endpoint, nil, [
    TNetHeader.Create('Authorization', 'Bearer ' + ApiKey),
    TNetHeader.Create('Accept', 'application/json')
  ]);

  case Resposta.StatusCode of
    200: ;
    401: raise ETiFluxErro.Create('Token de API do tiFlux inválido ou expirado.');
    404: raise ETiFluxErro.Create('Ticket não encontrado no tiFlux (verifique o número).');
  else
    raise ETiFluxErro.CreateFmt('Erro HTTP %d ao consultar o tiFlux.', [Resposta.StatusCode]);
  end;

  Result := TJSONObject.ParseJSONValue(Resposta.ContentAsString(TEncoding.UTF8));
  if not Assigned(Result) then
    raise ETiFluxErro.Create('Resposta inválida do tiFlux (JSON malformado).');
end;

function BuscarTicketTiFlux(const Numero, ApiKey: string): TTiFluxTicket;
var
  Http: THTTPClient;
  JsonTicket: TJSONValue;
  ObjTicket, ObjItem, ObjAutor: TJSONObject;
  JsonPagina: TJSONValue;
  ArrPagina: TJSONArray;
  ItemJson: TJSONValue;
  Lista: TList<TTiFluxComunicacao>;
  Item: TTiFluxComunicacao;
  Pagina, ItensNestaPagina: Integer;
begin
  if Trim(ApiKey) = '' then
    raise ETiFluxErro.Create('Configure a chave de API do tiFlux antes de continuar.');
  if Trim(Numero) = '' then
    raise ETiFluxErro.Create('Informe o número do ticket.');

  Http := THTTPClient.Create;
  Lista := TList<TTiFluxComunicacao>.Create;
  try
    JsonTicket := ExecutarGet(Http, '/tickets/' + Numero, ApiKey);
    try
      if not (JsonTicket is TJSONObject) then
        raise ETiFluxErro.Create('Resposta inesperada do tiFlux ao buscar o ticket.');
      ObjTicket := TJSONObject(JsonTicket);

      Result.Numero := Numero;
      Result.Titulo := ObterTexto(ObjTicket, 'title');
      Result.Descricao := ObterTexto(ObjTicket, 'description');
    finally
      JsonTicket.Free;
    end;

    Pagina := 1;
    repeat
      JsonPagina := ExecutarGet(Http,
        Format('/tickets/%s/internal_communications?offset=%d&limit=%d', [Numero, Pagina, ItensPorPagina]),
        ApiKey);
      try
        if not (JsonPagina is TJSONArray) then
          Break;
        ArrPagina := TJSONArray(JsonPagina);
        ItensNestaPagina := ArrPagina.Count;

        for ItemJson in ArrPagina do
        begin
          if not (ItemJson is TJSONObject) then
            Continue;
          ObjItem := TJSONObject(ItemJson);

          Item.Texto := ObterTexto(ObjItem, 'text');
          Item.DataCriacao := LerDataISO(ObjItem, 'created_at');

          ObjAutor := ObterObjeto(ObjItem, 'user');
          Item.Autor := ObterTexto(ObjAutor, 'name');
          if Item.Autor = '' then
            Item.Autor := 'Equipe interna';

          Lista.Add(Item);
        end;
      finally
        JsonPagina.Free;
      end;
      Inc(Pagina);
    until (ItensNestaPagina < ItensPorPagina) or (Pagina > MaximoPaginas);

    // "Ordem de cadastro": mais antiga primeiro.
    Lista.Sort(TComparer<TTiFluxComunicacao>.Construct(
      function(const A, B: TTiFluxComunicacao): Integer
      begin
        Result := CompareDateTime(A.DataCriacao, B.DataCriacao);
      end));

    Result.Comunicacoes := Lista.ToArray;
  finally
    Lista.Free;
    Http.Free;
  end;
end;

end.
