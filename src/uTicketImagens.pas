unit uTicketImagens;

interface

uses
  System.Net.HttpClient, uTicketDocs;

// Localiza tags <img src="URL"> no HTML cru (descricao ou comunicacao),
// baixa cada imagem para "<PastaArquivos>\imagemN.<ext>" (N compartilhado
// entre todas as chamadas via Contador) e troca a tag pela referencia
// Markdown "![](Arquivos/imagemN.ext)". Falha no download de uma imagem
// nao aborta o processo — vira "[imagem indisponivel]" no texto.
// A pasta PastaArquivos so e criada na primeira imagem baixada com sucesso.
function ExtrairImagens(const Html, PastaArquivos: string; var Contador: Integer;
  const Http: THTTPClient; const OnProgresso: TProgressoTicket): string;

implementation

uses
  System.SysUtils, System.IOUtils, System.Classes, System.StrUtils,
  System.RegularExpressions;

const
  ExtensoesValidas: array[0..5] of string = ('.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp');

function ExtensaoDaUrl(const Url: string): string;
var
  SemQuery, Ext: string;
  P: Integer;
begin
  SemQuery := Url;
  P := Pos('?', SemQuery);
  if P > 0 then
    SemQuery := Copy(SemQuery, 1, P - 1);

  Ext := LowerCase(TPath.GetExtension(SemQuery));
  if MatchStr(Ext, ExtensoesValidas) then
    Result := Ext
  else
    Result := '.png';
end;

function BaixarImagem(const Http: THTTPClient; const Url, PastaArquivos, NomeArquivo: string): Boolean;
var
  MS: TMemoryStream;
  Resposta: IHTTPResponse;
begin
  Result := False;
  try
    if not TDirectory.Exists(PastaArquivos) then
      TDirectory.CreateDirectory(PastaArquivos);

    MS := TMemoryStream.Create;
    try
      Resposta := Http.Get(Url, MS);
      if (Resposta.StatusCode = 200) and (MS.Size > 0) then
      begin
        MS.SaveToFile(TPath.Combine(PastaArquivos, NomeArquivo));
        Result := True;
      end;
    finally
      MS.Free;
    end;
  except
    Result := False;
  end;
end;

type
  // TMatchEvaluator neste RTL e "of object" (metodo vinculado a uma
  // instancia), nao aceita "reference to function" — por isso o estado
  // (contador, pasta, http, progresso) vira campo de objeto em vez de
  // captura de closure.
  TAvaliadorImagem = class
  private
    FPastaArquivos: string;
    FHttp: THTTPClient;
    FOnProgresso: TProgressoTicket;
    FContador: Integer;
  public
    constructor Create(const PastaArquivos: string; const Http: THTTPClient;
      const OnProgresso: TProgressoTicket; ContadorInicial: Integer);
    function Avaliar(const Match: TMatch): string;
    property Contador: Integer read FContador;
  end;

constructor TAvaliadorImagem.Create(const PastaArquivos: string; const Http: THTTPClient;
  const OnProgresso: TProgressoTicket; ContadorInicial: Integer);
begin
  inherited Create;
  FPastaArquivos := PastaArquivos;
  FHttp := Http;
  FOnProgresso := OnProgresso;
  FContador := ContadorInicial;
end;

function TAvaliadorImagem.Avaliar(const Match: TMatch): string;
var
  Url, NomeArquivo: string;
begin
  Url := Match.Groups[1].Value;
  if Trim(Url) = '' then
    Exit('');

  Inc(FContador);
  NomeArquivo := Format('imagem%d%s', [FContador, ExtensaoDaUrl(Url)]);

  if Assigned(FOnProgresso) then
    FOnProgresso(Format('Baixando imagem %d...', [FContador]));

  if BaixarImagem(FHttp, Url, FPastaArquivos, NomeArquivo) then
    Result := Format('![](Arquivos/%s)', [NomeArquivo])
  else
    Result := '[imagem indisponível]';
end;

function ExtrairImagens(const Html, PastaArquivos: string; var Contador: Integer;
  const Http: THTTPClient; const OnProgresso: TProgressoTicket): string;
var
  Avaliador: TAvaliadorImagem;
begin
  if Html = '' then
    Exit('');

  Avaliador := TAvaliadorImagem.Create(PastaArquivos, Http, OnProgresso, Contador);
  try
    Result := TRegEx.Replace(Html, '<img\s+[^>]*?src\s*=\s*"([^"]*)"[^>]*?/?>',
      Avaliador.Avaliar, [TRegExOption.roIgnoreCase]);
    Contador := Avaliador.Contador;
  finally
    Avaliador.Free;
  end;
end;

end.
