unit uTicketDocs;

interface

type
  TProgressoTicket = reference to procedure(const Mensagem: string);

// Consulta o ticket no tiFlux, cria a pasta "<Numero> - <Titulo>" dentro de
// "<PastaBase>\<AnoAtual>" e grava o Ticket.md (descricao geral + comunicacoes
// internas em ordem de cadastro). Retorna o caminho da pasta criada.
function GerarPastaTicket(const Numero, ApiKey, PastaBase: string;
  const OnProgresso: TProgressoTicket = nil): string;

// Sem chave de API: cria so a pasta "<Numero>" (ou "<Numero> - <Titulo>" se um
// titulo for informado) e um Ticket.md vazio, pra preencher manualmente.
// Retorna o caminho da pasta criada.
function CriarPastaTicketManual(const Numero, Titulo, PastaBase: string): string;

implementation

uses
  System.SysUtils, System.IOUtils, System.DateUtils,
  uTiFlux, uSanitizacao, uHtmlTexto;

const
  Separador = '_________________________________________________________________________________________________________________';

function MontarConteudoMarkdown(const Ticket: TTiFluxTicket): string;
var
  SB: TStringBuilder;
  Comunicacao: TTiFluxComunicacao;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine(HtmlParaTexto(Ticket.Descricao));

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
        SB.AppendLine(HtmlParaTexto(Comunicacao.Texto));
        SB.AppendLine;
        SB.AppendLine(Separador);
      end;
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function CaminhoPastaDoTicket(const NomePasta, PastaBase: string): string;
begin
  Result := TPath.Combine(TPath.Combine(PastaBase, FormatDateTime('yyyy', Now)), NomePasta);
end;

function GerarPastaTicket(const Numero, ApiKey, PastaBase: string;
  const OnProgresso: TProgressoTicket): string;
var
  Ticket: TTiFluxTicket;
  NomePasta, CaminhoPasta, CaminhoArquivo: string;
begin
  if Assigned(OnProgresso) then
    OnProgresso('Consultando ticket no tiFlux...');

  Ticket := BuscarTicketTiFlux(Numero, ApiKey);

  NomePasta := NomeArquivoValido(Numero + ' - ' + Ticket.Titulo);
  CaminhoPasta := CaminhoPastaDoTicket(NomePasta, PastaBase);

  if TDirectory.Exists(CaminhoPasta) then
    raise Exception.CreateFmt('A pasta do ticket já existe:' + sLineBreak + '%s', [CaminhoPasta]);

  if Assigned(OnProgresso) then
    OnProgresso('Montando Ticket.md...');

  TDirectory.CreateDirectory(CaminhoPasta);

  CaminhoArquivo := TPath.Combine(CaminhoPasta, 'Ticket.md');
  TFile.WriteAllText(CaminhoArquivo, MontarConteudoMarkdown(Ticket), TEncoding.UTF8);

  Result := CaminhoPasta;
end;

function CriarPastaTicketManual(const Numero, Titulo, PastaBase: string): string;
var
  NomePasta, CaminhoPasta: string;
begin
  if Trim(Titulo) = '' then
    NomePasta := NomeArquivoValido(Numero)
  else
    NomePasta := NomeArquivoValido(Numero + ' - ' + Titulo);

  CaminhoPasta := CaminhoPastaDoTicket(NomePasta, PastaBase);

  if TDirectory.Exists(CaminhoPasta) then
    raise Exception.CreateFmt('A pasta do ticket já existe:' + sLineBreak + '%s', [CaminhoPasta]);

  TDirectory.CreateDirectory(CaminhoPasta);
  TFile.WriteAllText(TPath.Combine(CaminhoPasta, 'Ticket.md'), '', TEncoding.UTF8);

  Result := CaminhoPasta;
end;

end.
