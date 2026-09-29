unit uTicketDocs;

interface

type
  TProgressoTicket = reference to procedure(const Mensagem: string);

// Consulta o ticket no tiFlux, cria a pasta "<Numero> - <Titulo>" dentro de
// "<PastaBase>\<Ciclo>" (ex.: 2609) e grava o Ticket.md (descricao geral +
// comunicacoes internas em ordem de cadastro). Retorna o caminho da pasta criada.
function GerarPastaTicket(const Numero, Ciclo, ApiKey, PastaBase: string;
  const OnProgresso: TProgressoTicket = nil): string;

// Ciclo valido = 4 digitos (ex.: 2609).
function CicloValido(const Ciclo: string): Boolean;

// Maior pasta de ciclo (4 digitos) ja existente em PastaBase, ou vazio se nao
// houver nenhuma. Serve so de sugestao pro usuario.
function CicloVigenteSugerido(const PastaBase: string): string;

// Sem chave de API: cria so a pasta "<Numero>" (ou "<Numero> - <Titulo>" se um
// titulo for informado) e um Ticket.md vazio, pra preencher manualmente.
// Retorna o caminho da pasta criada.
function CriarPastaTicketManual(const Numero, Ciclo, Titulo, PastaBase: string): string;

implementation

uses
  System.SysUtils, System.IOUtils, System.DateUtils, System.Net.HttpClient,
  uTiFlux, uSanitizacao, uHtmlTexto, uTicketImagens;

const
  Separador = '_________________________________________________________________________________________________________________';

function MontarConteudoMarkdown(const Ticket: TTiFluxTicket; const CaminhoPasta: string;
  const Http: THTTPClient; const OnProgresso: TProgressoTicket): string;
var
  SB: TStringBuilder;
  Comunicacao: TTiFluxComunicacao;
  PastaArquivos: string;
  ContadorImagens: Integer;
begin
  PastaArquivos := TPath.Combine(CaminhoPasta, 'Arquivos');
  ContadorImagens := 0;

  SB := TStringBuilder.Create;
  try
    SB.AppendLine(HtmlParaTexto(
      ExtrairImagens(Ticket.Descricao, PastaArquivos, ContadorImagens, Http, OnProgresso)));

    if Length(Ticket.Comunicacoes) > 0 then
    begin
      SB.AppendLine;
      SB.AppendLine(Separador);

      for Comunicacao in Ticket.Comunicacoes do
      begin
        SB.AppendLine;
        SB.AppendLine(Format('**%s** — %s',
          [Comunicacao.Autor, FormatDateTime('dd/mm/yyyy hh:nn', Comunicacao.DataCriacao)]));
        SB.AppendLine;
        SB.AppendLine(HtmlParaTexto(
          ExtrairImagens(Comunicacao.Texto, PastaArquivos, ContadorImagens, Http, OnProgresso)));
        SB.AppendLine;
        SB.AppendLine(Separador);
      end;
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function CicloValido(const Ciclo: string): Boolean;
var
  I: Integer;
begin
  Result := Length(Ciclo) = 4;
  if Result then
    for I := 1 to Length(Ciclo) do
      if (Ciclo[I] < '0') or (Ciclo[I] > '9') then
        Exit(False);
end;

function CicloVigenteSugerido(const PastaBase: string): string;
var
  Pasta, Nome: string;
begin
  Result := EmptyStr;
  if not TDirectory.Exists(PastaBase) then
    Exit;
  for Pasta in TDirectory.GetDirectories(PastaBase) do
  begin
    Nome := TPath.GetFileName(Pasta);
    if CicloValido(Nome) and (Nome > Result) then
      Result := Nome;
  end;
end;

procedure ValidarCiclo(const Ciclo: string);
begin
  if not CicloValido(Ciclo) then
    raise Exception.CreateFmt('Ciclo inválido "%s": informe 4 dígitos (ex.: 2609).', [Ciclo]);
end;

function CaminhoPastaDoTicket(const NomePasta, PastaBase, Ciclo: string): string;
begin
  Result := TPath.Combine(TPath.Combine(PastaBase, Ciclo), NomePasta);
end;

// Registra classe+mensagem da excecao (nunca a ApiKey) num log local, pra dar
// pra diagnosticar uma falha sem depender do balao do Windows (que some
// rapido). CaminhoPastaLog fica isolado do resto — falha ao gravar o log
// nunca pode mascarar a excecao original.
procedure RegistrarErroTicket(const Numero, Etapa: string; E: Exception);
var
  CaminhoLog, Linha: string;
begin
  try
    CaminhoLog := TPath.Combine(
      TPath.Combine(GetEnvironmentVariable('APPDATA'), 'AgentDeck'), 'ticket_erro.log');
    Linha := Format('[%s] Ticket #%s — falhou em "%s": %s: %s',
      [DateTimeToStr(Now), Numero, Etapa, E.ClassName, E.Message]);
    TFile.AppendAllText(CaminhoLog, Linha + sLineBreak, TEncoding.UTF8);
  except
    // Nunca deixa o log mascarar a excecao original.
  end;
end;

function GerarPastaTicket(const Numero, Ciclo, ApiKey, PastaBase: string;
  const OnProgresso: TProgressoTicket): string;
var
  Ticket: TTiFluxTicket;
  NomePasta, CaminhoPasta, CaminhoArquivo: string;
  Http: THTTPClient;
  Etapa: string;
begin
  Etapa := 'validar ciclo';
  try
    ValidarCiclo(Ciclo);
    Etapa := 'consultar ticket';
    if Assigned(OnProgresso) then
      OnProgresso('Consultando ticket no tiFlux...');

    Ticket := BuscarTicketTiFlux(Numero, ApiKey);

    Etapa := 'preparar pasta';
    NomePasta := NomeArquivoValido(Numero + ' - ' + Ticket.Titulo);
    CaminhoPasta := CaminhoPastaDoTicket(NomePasta, PastaBase, Ciclo);

    if TDirectory.Exists(CaminhoPasta) then
      raise Exception.CreateFmt('A pasta do ticket já existe:' + sLineBreak + '%s', [CaminhoPasta]);

    if Assigned(OnProgresso) then
      OnProgresso('Montando Ticket.md...');

    TDirectory.CreateDirectory(CaminhoPasta);

    Etapa := 'montar Ticket.md (texto/imagens)';
    Http := THTTPClient.Create;
    try
      CaminhoArquivo := TPath.Combine(CaminhoPasta, 'Ticket.md');
      TFile.WriteAllText(CaminhoArquivo,
        MontarConteudoMarkdown(Ticket, CaminhoPasta, Http, OnProgresso), TEncoding.UTF8);
    finally
      Http.Free;
    end;

    Result := CaminhoPasta;
  except
    on E: Exception do
    begin
      RegistrarErroTicket(Numero, Etapa, E);
      raise;
    end;
  end;
end;

function CriarPastaTicketManual(const Numero, Ciclo, Titulo, PastaBase: string): string;
var
  NomePasta, CaminhoPasta: string;
begin
  ValidarCiclo(Ciclo);

  if Trim(Titulo) = '' then
    NomePasta := NomeArquivoValido(Numero)
  else
    NomePasta := NomeArquivoValido(Numero + ' - ' + Titulo);

  CaminhoPasta := CaminhoPastaDoTicket(NomePasta, PastaBase, Ciclo);

  if TDirectory.Exists(CaminhoPasta) then
    raise Exception.CreateFmt('A pasta do ticket já existe:' + sLineBreak + '%s', [CaminhoPasta]);

  TDirectory.CreateDirectory(CaminhoPasta);
  TFile.WriteAllText(TPath.Combine(CaminhoPasta, 'Ticket.md'), '', TEncoding.UTF8);

  Result := CaminhoPasta;
end;

end.
