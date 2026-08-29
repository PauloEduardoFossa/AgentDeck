unit uMain.Form;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Variants, System.Classes,
  System.Types, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls,
  Vcl.StdCtrls, Vcl.Buttons, Vcl.Menus, Vcl.Imaging.PngImage, System.Generics.Collections,
  System.DateUtils, System.StrUtils, uSessionStatus, uServiceControl, uBatRunner, uHookServer,
  uSvnBranch, uConfiguracoes, uOpenVpn, uTicketDocs;

type
  // TSpeedButton não publica Color (protected em TGraphicControl); sem isso
  // não dá pra pintar o botão de comando com a cor de fundo do mockup.
  TBotaoComando = class(TSpeedButton)
  published
    property Color;
  end;

  // Objeto guardado em FListaSessoes.Items.Objects[i]: precisa ser liberado
  // a cada atualização (ver AtualizarSessoes/LimparItensSessoes).
  TItemSessaoUI = class
    SessionId: string;
    Cwd: string;
    Status: TStatusSessao;
    UltimoEvento: TDateTime;
  end;

  TFormPrincipal = class(TForm)
    TrayIcon: TTrayIcon;
    TimerAtualiza: TTimer;
    TimerBranch: TTimer;
    PopupTray: TPopupMenu;
    ItemAbrir: TMenuItem;
    ItemSair: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure TimerAtualizaTimer(Sender: TObject);
    procedure TimerBranchTimer(Sender: TObject);
    procedure ItemAbrirClick(Sender: TObject);
    procedure ItemSairClick(Sender: TObject);
  private
    FListaSessoes: TListBox;
    FBtnModoDev: TButton;
    FLblModoDev: TLabel;
    FMemoServicos: TMemo;
    FScrollComandos: TScrollBox;
    FDotHooks: TShape;
    FLblBranch: TLabel;
    FLblNovoTicket: TLabel;
    FPopupMonitores: TPopupMenu;
    FAtualizandoModoDev: Boolean;
    FAtualizandoBranch: Boolean;
    FGerandoTicket: Boolean;
    FBats: TArray<TBatInfo>;

    procedure MontarLayout;
    procedure PosicionarNaLateral;
    procedure AtualizarSessoes;
    procedure AtualizarModoDev;
    procedure AtualizarBranchSVN;
    procedure MontarBotoesComandos;
    procedure LimparItensSessoes;
    procedure ListaSessoesDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure BtnModoDevClick(Sender: TObject);
    procedure BotaoBatClick(Sender: TObject);
    procedure BtnMonitorClick(Sender: TObject);
    procedure ItemMonitorClick(Sender: TObject);
    procedure ItemNovoTicketClick(Sender: TObject);
    procedure MostrarPainel;
    procedure MostrarBalao(const Titulo, Texto: string; Flags: TBalloonFlags);
    procedure NaThreadPrincipal(const Proc: TThreadProcedure);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
  end;

var
  FormPrincipal: TFormPrincipal;

implementation

{$R *.dfm}
{$R 'Icones.res'}

const
  SegundosLimiteSessaoInativa = 12 * 3600;
  AlturaCabecalho = 48;

  // Paleta do mockup (Artifact "AgentDeck", aprovado em 25/08/2026).
  // Convertida de #RRGGBB pra TColor ($00BBGGRR — bytes invertidos).
  ClrBgPanel     = $00231B16; // #161b23 fundo do painel
  ClrBgPanel2    = $002C221C; // #1c222c cards (sessão, dev-mode)
  ClrBgPanel3    = $00362821; // #212836 cabeçalho
  ClrBorder      = $00403129; // #29313f linha de borda
  ClrBorderSoft  = $00372A23; // #232a37 divisor suave
  ClrText        = $00F1EBE7; // #e7ebf1 texto principal
  ClrTextMuted   = $00A69389; // #8993a6 texto secundário
  ClrTextFaint   = $0077655C; // #5c6577 texto apagado
  ClrAccent      = $003DA0F2; // #f2a03d âmbar (marca, toggle ligado)
  ClrOk          = $008ECF3E; // #3ecf8e verde (ocioso)
  ClrOkDim       = $001F2616; // fundo do pill verde
  ClrBusy        = $00FF965B; // #5b96ff azul (processando)
  ClrBusyDim     = $002F2016; // fundo do pill azul
  ClrWarn        = $006B6BFF; // #ff6b6b vermelho (esperando permissão)
  ClrWarnDim     = $001A1A2F; // fundo do pill vermelho

function TextoStatus(Status: TStatusSessao): string;
begin
  case Status of
    ssOcioso: Result := 'ocioso';
    ssProcessando: Result := 'processando';
    ssEsperandoPermissao: Result := 'esperando permissão';
  else
    Result := '?';
  end;
end;

function CorPrincipalStatus(Status: TStatusSessao): TColor;
begin
  case Status of
    ssOcioso: Result := ClrOk;
    ssProcessando: Result := ClrBusy;
  else
    Result := ClrWarn;
  end;
end;

function CorFundoStatus(Status: TStatusSessao): TColor;
begin
  case Status of
    ssOcioso: Result := ClrOkDim;
    ssProcessando: Result := ClrBusyDim;
  else
    Result := ClrWarnDim;
  end;
end;

function TempoRelativo(Segundos: Int64): string;
begin
  if Segundos < 60 then
    Result := Format('há %ds', [Segundos])
  else if Segundos < 3600 then
    Result := Format('há %dm', [Segundos div 60])
  else
    Result := Format('há %dh', [Segundos div 3600]);
end;

// Corta pelo início (mantendo o final visível) até caber em LarguraMax —
// equivalente ao truque de ellipsis-à-esquerda usado no mockup HTML.
function TruncarInicio(Canvas: TCanvas; const Texto: string; LarguraMax: Integer): string;
begin
  Result := Texto;
  if Canvas.TextWidth(Result) <= LarguraMax then
    Exit;
  while (Length(Result) > 1) and (Canvas.TextWidth('...' + Result) > LarguraMax) do
    Delete(Result, 1, 1);
  Result := '...' + Result;
end;

function CategoriaBat(const Nome: string): string;
begin
  if Nome.StartsWith('Compilar') then
    Result := 'Compilar'
  else if Nome.StartsWith('Serviços') then
    Result := 'Serviços'
  else if Nome.StartsWith('SVN') then
    Result := 'SVN'
  else
    Result := 'Outros';
end;

const
  // Projeto usado como referência pra mostrar a branch SVN atual no
  // cabeçalho — C:\TopSystem\Delphi tem vários working copies SVN
  // independentes, o TopERP é o projeto principal/flagship.
  CaminhoSVNReferencia = 'C:\TopSystem\Delphi\TopERP';

  // Comandos de compilação pouco usados, ocultados do painel pra evitar
  // scrollbar na lista de comandos.
  ComandosOcultos: array[0..3] of string = (
    'Compilar - Gerar ServerERP',
    'Compilar - Gerar TopACBrBoletoService',
    'Compilar - Gerar TopNFCeService',
    'Compilar - Gerar TopServerService'
  );

function ComandoOculto(const Nome: string): Boolean;
var
  Item: string;
begin
  for Item in ComandosOcultos do
    if SameText(Item, Nome) then
      Exit(True);
  Result := False;
end;

// Carrega um PNG embutido como recurso (RCDATA, ver Icones.rc) — evita
// depender de um caminho de arquivo em disco pra achar o ícone.
procedure CarregarIconeRecurso(const NomeRecurso: string; const Destino: TPicture);
var
  Stream: TResourceStream;
  Png: TPngImage;
begin
  Stream := TResourceStream.Create(HInstance, NomeRecurso, RT_RCDATA);
  try
    Png := TPngImage.Create;
    try
      Png.LoadFromStream(Stream);
      Destino.Graphic := Png;
    finally
      Png.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TFormPrincipal.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Sem isso o form aparece na barra de tarefas: WS_EX_TOOLWINDOW tira o
  // botão de lá, restando só o ícone da bandeja pra abrir/fechar o painel.
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW;
end;

procedure TFormPrincipal.FormCreate(Sender: TObject);
begin
  BorderStyle := bsNone;
  Color := ClrBgPanel;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  Font.Color := ClrText;

  MontarLayout;
  PosicionarNaLateral;
  MontarBotoesComandos;
  AtualizarSessoes;
  AtualizarModoDev;
  AtualizarBranchSVN;

  TrayIcon.Icon := Application.Icon;
  TrayIcon.Hint := 'AgentDeck';
  TrayIcon.Visible := True;

  MostrarPainel;

  try
    IniciarServidorHooks;
  except
    on E: Exception do
    begin
      FDotHooks.Brush.Color := ClrWarn;
      FDotHooks.Pen.Color := ClrWarn;
      MostrarBalao('AgentDeck', 'Servidor de hooks não iniciou: ' + E.Message, bfError);
    end;
  end;
end;

procedure TFormPrincipal.FormDestroy(Sender: TObject);
begin
  LimparItensSessoes;
end;

procedure TFormPrincipal.MostrarBalao(const Titulo, Texto: string; Flags: TBalloonFlags);
begin
  TrayIcon.BalloonTitle := Titulo;
  TrayIcon.BalloonHint := Texto;
  TrayIcon.BalloonFlags := Flags;
  TrayIcon.ShowBalloonHint;
end;

// TThread.Queue(nil, <literal anônimo>) direto confunde a resolução de
// overload deste compilador (TThreadMethod vs TThreadProcedure). Passar por
// aqui, com Proc já tipado como TThreadProcedure, resolve sem ambiguidade.
procedure TFormPrincipal.NaThreadPrincipal(const Proc: TThreadProcedure);
begin
  TThread.Queue(nil, Proc);
end;

procedure TFormPrincipal.MontarLayout;
var
  PnlHeader: TPanel;
  Marca: TShape;
  LblApp, LblHook: TLabel;
  LblSessoes, LblModoDevTitulo: TLabel;
  Divisor1, Divisor2: TPanel;
  CardTicket, CardMonitor: TPanel;
  ImgTicket, ImgMonitor: TImage;
  LblMonitor: TLabel;
  Y: Integer;
begin
  PnlHeader := TPanel.Create(Self);
  PnlHeader.Parent := Self;
  PnlHeader.BevelOuter := bvNone;
  PnlHeader.Color := ClrBgPanel3;
  PnlHeader.SetBounds(0, 0, ClientWidth, AlturaCabecalho);
  PnlHeader.Anchors := [akLeft, akTop, akRight];

  Marca := TShape.Create(Self);
  Marca.Parent := PnlHeader;
  Marca.Shape := stRoundRect;
  Marca.Brush.Color := ClrAccent;
  Marca.Pen.Color := ClrAccent;
  Marca.SetBounds(14, 11, 26, 26);

  LblApp := TLabel.Create(Self);
  LblApp.Parent := PnlHeader;
  LblApp.Caption := 'AgentDeck';
  LblApp.Font.Style := [fsBold];
  LblApp.Font.Size := 11;
  LblApp.Font.Color := ClrText;
  LblApp.SetBounds(50, 8, 220, 18);

  FDotHooks := TShape.Create(Self);
  FDotHooks.Parent := PnlHeader;
  FDotHooks.Shape := stCircle;
  FDotHooks.Brush.Color := ClrOk;
  FDotHooks.Pen.Color := ClrOk;
  FDotHooks.SetBounds(50, 30, 7, 7);

  LblHook := TLabel.Create(Self);
  LblHook.Parent := PnlHeader;
  LblHook.Caption := 'hooks :47311';
  LblHook.Font.Name := 'Consolas';
  LblHook.Font.Size := 8;
  LblHook.Font.Color := ClrTextFaint;
  LblHook.SetBounds(62, 27, 180, 14);

  FLblBranch := TLabel.Create(Self);
  FLblBranch.Parent := PnlHeader;
  FLblBranch.Caption := '';
  FLblBranch.Alignment := taRightJustify;
  FLblBranch.Font.Name := 'Consolas';
  FLblBranch.Font.Size := 8;
  FLblBranch.Font.Color := ClrTextMuted;
  FLblBranch.SetBounds(ClientWidth - 166, 10, 152, 16);
  FLblBranch.Anchors := [akTop, akRight];

  Y := AlturaCabecalho + 12;

  CardTicket := TPanel.Create(Self);
  CardTicket.Parent := Self;
  CardTicket.BevelOuter := bvNone;
  CardTicket.Color := ClrBgPanel2;
  CardTicket.Cursor := crHandPoint;
  CardTicket.SetBounds(12, Y, ClientWidth - 24, 40);
  CardTicket.Anchors := [akLeft, akTop, akRight];
  CardTicket.OnClick := ItemNovoTicketClick;

  ImgTicket := TImage.Create(Self);
  ImgTicket.Parent := CardTicket;
  ImgTicket.Cursor := crHandPoint;
  ImgTicket.Center := True;
  ImgTicket.Stretch := True;
  ImgTicket.Proportional := True;
  ImgTicket.SetBounds(8, 4, 32, 32);
  ImgTicket.OnClick := ItemNovoTicketClick;
  CarregarIconeRecurso('TICKET_NOVO', ImgTicket.Picture);

  FLblNovoTicket := TLabel.Create(Self);
  FLblNovoTicket.Parent := CardTicket;
  FLblNovoTicket.Caption := 'Novo Ticket (tiFlux)';
  FLblNovoTicket.Font.Style := [fsBold];
  FLblNovoTicket.Font.Color := ClrText;
  FLblNovoTicket.Cursor := crHandPoint;
  FLblNovoTicket.Transparent := True;
  FLblNovoTicket.SetBounds(50, 13, ClientWidth - 90, 18);
  FLblNovoTicket.Anchors := [akLeft, akTop, akRight];
  FLblNovoTicket.OnClick := ItemNovoTicketClick;

  Y := Y + 40 + 8;

  CardMonitor := TPanel.Create(Self);
  CardMonitor.Parent := Self;
  CardMonitor.BevelOuter := bvNone;
  CardMonitor.Color := ClrBgPanel2;
  CardMonitor.Cursor := crHandPoint;
  CardMonitor.SetBounds(12, Y, ClientWidth - 24, 40);
  CardMonitor.Anchors := [akLeft, akTop, akRight];
  CardMonitor.OnClick := BtnMonitorClick;

  ImgMonitor := TImage.Create(Self);
  ImgMonitor.Parent := CardMonitor;
  ImgMonitor.Cursor := crHandPoint;
  ImgMonitor.Center := True;
  ImgMonitor.Stretch := True;
  ImgMonitor.Proportional := True;
  ImgMonitor.SetBounds(8, 4, 32, 32);
  ImgMonitor.OnClick := BtnMonitorClick;
  CarregarIconeRecurso('MONITOR_ICONE', ImgMonitor.Picture);

  LblMonitor := TLabel.Create(Self);
  LblMonitor.Parent := CardMonitor;
  LblMonitor.Caption := 'Monitor';
  LblMonitor.Font.Style := [fsBold];
  LblMonitor.Font.Color := ClrText;
  LblMonitor.Cursor := crHandPoint;
  LblMonitor.Transparent := True;
  LblMonitor.SetBounds(50, 13, ClientWidth - 90, 18);
  LblMonitor.Anchors := [akLeft, akTop, akRight];
  LblMonitor.OnClick := BtnMonitorClick;

  Y := Y + 40 + 12;

  LblSessoes := TLabel.Create(Self);
  LblSessoes.Parent := Self;
  LblSessoes.Caption := 'SESSÕES CLAUDE CODE';
  LblSessoes.Font.Style := [fsBold];
  LblSessoes.Font.Size := 8;
  LblSessoes.Font.Color := ClrTextMuted;
  LblSessoes.SetBounds(14, Y, 300, 16);

  FListaSessoes := TListBox.Create(Self);
  FListaSessoes.Parent := Self;
  FListaSessoes.Style := lbOwnerDrawFixed;
  FListaSessoes.ItemHeight := 42;
  FListaSessoes.BorderStyle := bsNone;
  FListaSessoes.Color := ClrBgPanel;
  FListaSessoes.OnDrawItem := ListaSessoesDrawItem;
  FListaSessoes.SetBounds(12, Y + 18, ClientWidth - 24, 190);
  FListaSessoes.Anchors := [akLeft, akTop, akRight];

  Y := Y + 18 + 190 + 12;

  Divisor1 := TPanel.Create(Self);
  Divisor1.Parent := Self;
  Divisor1.BevelOuter := bvNone;
  Divisor1.Color := ClrBorderSoft;
  Divisor1.SetBounds(12, Y, ClientWidth - 24, 1);
  Divisor1.Anchors := [akLeft, akTop, akRight];

  Y := Y + 13;

  LblModoDevTitulo := TLabel.Create(Self);
  LblModoDevTitulo.Parent := Self;
  LblModoDevTitulo.Caption := 'MODO DESENVOLVIMENTO';
  LblModoDevTitulo.Font.Style := [fsBold];
  LblModoDevTitulo.Font.Size := 8;
  LblModoDevTitulo.Font.Color := ClrTextMuted;
  LblModoDevTitulo.SetBounds(14, Y, 300, 16);

  Y := Y + 20;

  FLblModoDev := TLabel.Create(Self);
  FLblModoDev.Parent := Self;
  FLblModoDev.Caption := '...';
  FLblModoDev.Font.Style := [fsBold];
  FLblModoDev.SetBounds(14, Y, ClientWidth - 160, 18);
  FLblModoDev.Anchors := [akLeft, akTop, akRight];

  FBtnModoDev := TButton.Create(Self);
  FBtnModoDev.Parent := Self;
  FBtnModoDev.Caption := 'Ativar';
  FBtnModoDev.OnClick := BtnModoDevClick;
  FBtnModoDev.SetBounds(ClientWidth - 108, Y - 3, 96, 26);
  FBtnModoDev.Anchors := [akTop, akRight];

  Y := Y + 30;

  FMemoServicos := TMemo.Create(Self);
  FMemoServicos.Parent := Self;
  FMemoServicos.ReadOnly := True;
  FMemoServicos.BorderStyle := bsNone;
  FMemoServicos.Color := ClrBgPanel;
  FMemoServicos.Font.Name := 'Consolas';
  FMemoServicos.Font.Size := 8;
  FMemoServicos.Font.Color := ClrTextMuted;
  FMemoServicos.ScrollBars := ssNone;
  FMemoServicos.SetBounds(12, Y, ClientWidth - 24, 100);
  FMemoServicos.Anchors := [akLeft, akTop, akRight];

  Y := Y + 100 + 12;

  Divisor2 := TPanel.Create(Self);
  Divisor2.Parent := Self;
  Divisor2.BevelOuter := bvNone;
  Divisor2.Color := ClrBorderSoft;
  Divisor2.SetBounds(12, Y, ClientWidth - 24, 1);
  Divisor2.Anchors := [akLeft, akTop, akRight];

  Y := Y + 13;

  FScrollComandos := TScrollBox.Create(Self);
  FScrollComandos.Parent := Self;
  FScrollComandos.Color := ClrBgPanel;
  FScrollComandos.BorderStyle := bsNone;
  FScrollComandos.SetBounds(12, Y, ClientWidth - 24, ClientHeight - Y - 12);
  FScrollComandos.Anchors := [akLeft, akTop, akRight, akBottom];
end;

procedure TFormPrincipal.PosicionarNaLateral;
var
  Indice: Integer;
  Area: TRect;
begin
  Indice := MonitorPreferido;
  if (Indice < 0) or (Indice > Screen.MonitorCount - 1) then
    Indice := Screen.PrimaryMonitor.MonitorNum;

  Area := Screen.Monitors[Indice].WorkareaRect;
  Width := 340;
  Height := Area.Height;
  Left := Area.Right - Width;
  Top := Area.Top;
end;

procedure TFormPrincipal.MostrarPainel;
begin
  PosicionarNaLateral;
  Show;
  SetForegroundWindow(Handle);
  if not FAtualizandoBranch then
    AtualizarBranchSVN;
end;

procedure TFormPrincipal.TrayIconDblClick(Sender: TObject);
begin
  if Visible then
    Hide
  else
    MostrarPainel;
end;

procedure TFormPrincipal.ItemAbrirClick(Sender: TObject);
begin
  MostrarPainel;
end;

procedure TFormPrincipal.ItemSairClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TFormPrincipal.TimerAtualizaTimer(Sender: TObject);
begin
  AtualizarSessoes;
  if not FAtualizandoModoDev then
    AtualizarModoDev;
end;

procedure TFormPrincipal.TimerBranchTimer(Sender: TObject);
begin
  if not FAtualizandoBranch then
    AtualizarBranchSVN;
end;

procedure TFormPrincipal.LimparItensSessoes;
var
  I: Integer;
begin
  for I := 0 to FListaSessoes.Items.Count - 1 do
    FListaSessoes.Items.Objects[I].Free;
end;

procedure TFormPrincipal.AtualizarSessoes;
var
  Sessoes: TArray<TSessaoInfo>;
  Info: TSessaoInfo;
  Item: TItemSessaoUI;
  IndiceSelecionado: Integer;
begin
  SessionStatusStore.RemoverInativas(SegundosLimiteSessaoInativa);
  Sessoes := SessionStatusStore.Listar;

  IndiceSelecionado := FListaSessoes.ItemIndex;
  FListaSessoes.Items.BeginUpdate;
  try
    LimparItensSessoes;
    FListaSessoes.Items.Clear;

    for Info in Sessoes do
    begin
      Item := TItemSessaoUI.Create;
      Item.SessionId := Copy(Info.SessionId, 1, 8);
      Item.Cwd := Info.Cwd;
      Item.Status := Info.Status;
      Item.UltimoEvento := Info.UltimoEvento;
      FListaSessoes.Items.AddObject(Item.SessionId, Item);
    end;

    if (IndiceSelecionado >= 0) and (IndiceSelecionado < FListaSessoes.Items.Count) then
      FListaSessoes.ItemIndex := IndiceSelecionado;
  finally
    FListaSessoes.Items.EndUpdate;
  end;
end;

procedure TFormPrincipal.ListaSessoesDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
const
  LarguraFaixa = 3;
  Margem = 10;
var
  ListBox: TListBox;
  Item: TItemSessaoUI;
  CorPrincipal, CorFundo: TColor;
  TextoStatusStr, TextoTempo, TextoCwd: string;
  LarguraPill, LarguraCwdMax: Integer;
  RectPill: TRect;
begin
  ListBox := Control as TListBox;
  Item := TItemSessaoUI(ListBox.Items.Objects[Index]);

  ListBox.Canvas.Brush.Color := ClrBgPanel2;
  ListBox.Canvas.Pen.Color := ClrBgPanel2;
  ListBox.Canvas.FillRect(Rect);

  CorPrincipal := CorPrincipalStatus(Item.Status);
  CorFundo := CorFundoStatus(Item.Status);

  ListBox.Canvas.Brush.Color := CorPrincipal;
  ListBox.Canvas.FillRect(TRect.Create(Rect.Left, Rect.Top, Rect.Left + LarguraFaixa, Rect.Bottom));

  // id da sessão (linha 1) e diretório (linha 2), em monoespaçada
  ListBox.Canvas.Brush.Style := bsClear;
  ListBox.Canvas.Font.Name := 'Consolas';
  ListBox.Canvas.Font.Size := 9;
  ListBox.Canvas.Font.Style := [];
  ListBox.Canvas.Font.Color := ClrText;
  ListBox.Canvas.TextOut(Rect.Left + LarguraFaixa + Margem, Rect.Top + 5, Item.SessionId);

  TextoStatusStr := TextoStatus(Item.Status);
  ListBox.Canvas.Font.Style := [fsBold];
  ListBox.Canvas.Font.Size := 8;
  ListBox.Canvas.Font.Color := CorPrincipal;
  LarguraPill := ListBox.Canvas.TextWidth(TextoStatusStr) + 16;

  RectPill.Left := Rect.Right - LarguraPill - Margem;
  RectPill.Right := Rect.Right - Margem;
  RectPill.Top := Rect.Top + 6;
  RectPill.Bottom := RectPill.Top + 16;

  ListBox.Canvas.Brush.Style := bsSolid;
  ListBox.Canvas.Brush.Color := CorFundo;
  ListBox.Canvas.Pen.Color := CorFundo;
  ListBox.Canvas.RoundRect(RectPill.Left, RectPill.Top, RectPill.Right, RectPill.Bottom, 10, 10);

  ListBox.Canvas.Brush.Style := bsClear;
  ListBox.Canvas.TextOut(RectPill.Left + 8, RectPill.Top + 1, TextoStatusStr);

  TextoTempo := TempoRelativo(SecondsBetween(Now, Item.UltimoEvento));
  ListBox.Canvas.Font.Style := [];
  ListBox.Canvas.Font.Name := 'Segoe UI';
  ListBox.Canvas.Font.Color := ClrTextFaint;
  ListBox.Canvas.TextOut(Rect.Right - ListBox.Canvas.TextWidth(TextoTempo) - Margem, RectPill.Bottom + 3, TextoTempo);

  LarguraCwdMax := (RectPill.Left - Margem) - (Rect.Left + LarguraFaixa + Margem);
  ListBox.Canvas.Font.Name := 'Consolas';
  ListBox.Canvas.Font.Size := 8;
  ListBox.Canvas.Font.Color := ClrTextFaint;
  TextoCwd := TruncarInicio(ListBox.Canvas, Item.Cwd, LarguraCwdMax);
  ListBox.Canvas.TextOut(Rect.Left + LarguraFaixa + Margem, Rect.Top + 22, TextoCwd);
end;

procedure TFormPrincipal.AtualizarModoDev;
var
  Item: TServicoInfo;
  Ligado: Boolean;
begin
  Ligado := ModoDesenvolvimentoRodando;
  FLblModoDev.Caption := IfThen(Ligado, 'Ligado', 'Desligado');
  if Ligado then
    FLblModoDev.Font.Color := ClrAccent
  else
    FLblModoDev.Font.Color := ClrTextMuted;
  FBtnModoDev.Caption := IfThen(Ligado, 'Desativar', 'Ativar');

  FMemoServicos.Lines.BeginUpdate;
  try
    FMemoServicos.Lines.Clear;
    for Item in ServicosModoDesenvolvimento do
    begin
      case StatusDoServico(Item.Nome) of
        stRodando:   FMemoServicos.Lines.Add(Item.Descricao + ': rodando');
        stParado:    FMemoServicos.Lines.Add(Item.Descricao + ': parado');
        stIniciando: FMemoServicos.Lines.Add(Item.Descricao + ': iniciando...');
        stParando:   FMemoServicos.Lines.Add(Item.Descricao + ': parando...');
      else
        FMemoServicos.Lines.Add(Item.Descricao + ': desconhecido');
      end;
    end;
  finally
    FMemoServicos.Lines.EndUpdate;
  end;
end;

procedure TFormPrincipal.AtualizarBranchSVN;
begin
  if FAtualizandoBranch then
    Exit;
  FAtualizandoBranch := True;

  TThread.CreateAnonymousThread(
    procedure
    var
      Branch: string;
    begin
      Branch := BranchAtualSVN(CaminhoSVNReferencia);
      NaThreadPrincipal(
        procedure
        begin
          FAtualizandoBranch := False;
          if Branch <> '' then
          begin
            FLblBranch.Caption := Branch;
            FLblBranch.Font.Color := ClrTextMuted;
            FLblBranch.Hint := 'TopERP: ' + Branch;
            FLblBranch.ShowHint := True;
          end
          else
          begin
            FLblBranch.Caption := '';
            FLblBranch.ShowHint := False;
          end;
        end);
    end).Start;
end;

procedure TFormPrincipal.BtnModoDevClick(Sender: TObject);
var
  Ligar: Boolean;
begin
  if FAtualizandoModoDev then
    Exit;

  Ligar := not ModoDesenvolvimentoRodando;
  FAtualizandoModoDev := True;
  FBtnModoDev.Enabled := False;
  FLblModoDev.Caption := 'Aguarde...';

  TThread.CreateAnonymousThread(
    procedure
    var
      Progresso: TProgressoModoDev;
      MensagemErro: string;
    begin
      Progresso :=
        procedure(const Mensagem: string)
        begin
          NaThreadPrincipal(
            procedure
            begin
              FLblModoDev.Caption := Mensagem;
            end);
        end;
      try
        if Ligar then
        begin
          Progresso('Conectando na VPN...');
          ConectarVPN;
          AtivarModoDesenvolvimento(Progresso);
        end
        else
        begin
          DesativarModoDesenvolvimento(Progresso);
          Progresso('Desconectando da VPN...');
          DesconectarVPN;
        end;
      except
        on E: Exception do
        begin
          // Captura o texto aqui: TThread.Queue e assincrono, entao o objeto E
          // ja estara liberado quando a procedure abaixo realmente rodar na
          // thread principal (E.Message la dentro leria memoria liberada).
          MensagemErro := E.ClassName + ': ' + E.Message;
          NaThreadPrincipal(
            procedure
            begin
              MostrarBalao('AgentDeck', 'Erro no Modo Desenvolvimento: ' + MensagemErro, bfError);
            end);
        end;
      end;
      NaThreadPrincipal(
        procedure
        begin
          FAtualizandoModoDev := False;
          FBtnModoDev.Enabled := True;
          AtualizarModoDev;
        end);
    end).Start;
end;

procedure TFormPrincipal.MontarBotoesComandos;
const
  OrdemCategorias: array[0..3] of string = ('Compilar', 'Serviços', 'SVN', 'Outros');
var
  Categoria: string;
  I, TopoAtual: Integer;
  Botao: TBotaoComando;
  LblGrupo: TLabel;
  PrimeiroDoGrupo: Boolean;
begin
  FBats := ListarBats;
  TopoAtual := 2;
  for Categoria in OrdemCategorias do
  begin
    PrimeiroDoGrupo := True;
    for I := 0 to High(FBats) do
    begin
      if CategoriaBat(FBats[I].Nome) <> Categoria then
        Continue;
      if ComandoOculto(FBats[I].Nome) then
        Continue;

      if PrimeiroDoGrupo then
      begin
        LblGrupo := TLabel.Create(Self);
        LblGrupo.Parent := FScrollComandos;
        LblGrupo.Caption := AnsiUpperCase(Categoria);
        LblGrupo.Font.Size := 8;
        LblGrupo.Font.Style := [fsBold];
        LblGrupo.Font.Color := ClrTextFaint;
        LblGrupo.SetBounds(2, TopoAtual, FScrollComandos.ClientWidth - 24, 14);
        Inc(TopoAtual, 18);
        PrimeiroDoGrupo := False;
      end;

      Botao := TBotaoComando.Create(Self);
      Botao.Parent := FScrollComandos;
      Botao.Flat := True;
      Botao.Color := ClrBgPanel2;
      Botao.Font.Color := ClrText;
      Botao.Caption := '   ' + FBats[I].Nome;
      Botao.Tag := I;
      Botao.OnClick := BotaoBatClick;
      Botao.SetBounds(2, TopoAtual, FScrollComandos.ClientWidth - 20, 28);
      Botao.Anchors := [akLeft, akTop, akRight];
      Inc(TopoAtual, 32);
    end;
    if not PrimeiroDoGrupo then
      Inc(TopoAtual, 8);
  end;
end;

procedure TFormPrincipal.BotaoBatClick(Sender: TObject);
var
  Indice: Integer;
begin
  Indice := (Sender as TBotaoComando).Tag;
  if (Indice < 0) or (Indice > High(FBats)) then
    Exit;
  try
    ExecutarBat(FBats[Indice].Caminho);
  except
    on E: Exception do
      MostrarBalao('AgentDeck', 'Erro ao executar: ' + E.Message, bfError);
  end;
end;

// Reconstrói a lista de monitores NESTE momento (Screen.MonitorCount é
// reavaliado a cada clique) — antes isso só era montado uma vez, no
// FormCreate, e ficava desatualizado se um monitor fosse ligado/desligado
// depois de o app já estar aberto.
procedure TFormPrincipal.BtnMonitorClick(Sender: TObject);
var
  I, PreferidoAtual: Integer;
  Item: TMenuItem;
  PontoTela: TPoint;
begin
  if not Assigned(FPopupMonitores) then
    FPopupMonitores := TPopupMenu.Create(Self);
  FPopupMonitores.Items.Clear;

  PreferidoAtual := MonitorPreferido;
  if (PreferidoAtual < 0) or (PreferidoAtual > Screen.MonitorCount - 1) then
    PreferidoAtual := Screen.PrimaryMonitor.MonitorNum;

  for I := 0 to Screen.MonitorCount - 1 do
  begin
    Item := TMenuItem.Create(FPopupMonitores);
    Item.Caption := Format('Monitor %d (%dx%d)%s',
      [I + 1, Screen.Monitors[I].Width, Screen.Monitors[I].Height,
       IfThen(Screen.Monitors[I].Primary, ' — principal', '')]);
    Item.RadioItem := True;
    Item.GroupIndex := 1;
    Item.Tag := I;
    Item.Checked := I = PreferidoAtual;
    Item.OnClick := ItemMonitorClick;
    FPopupMonitores.Items.Add(Item);
  end;

  PontoTela := Mouse.CursorPos;
  FPopupMonitores.Popup(PontoTela.X, PontoTela.Y);
end;

procedure TFormPrincipal.ItemMonitorClick(Sender: TObject);
var
  Indice: Integer;
begin
  Indice := (Sender as TMenuItem).Tag;
  SalvarMonitorPreferido(Indice);
  if Visible then
    PosicionarNaLateral;
end;

procedure TFormPrincipal.ItemNovoTicketClick(Sender: TObject);
var
  Numero, Chave, Titulo, CaminhoPasta: string;
begin
  if FGerandoTicket then
    Exit;

  Numero := '';
  if not InputQuery('Novo Ticket', 'Número do ticket no tiFlux:', Numero) then
    Exit;
  Numero := Trim(Numero.Replace('#', ''));
  if Numero = '' then
    Exit;

  Chave := TiFluxApiKey;
  if Chave = '' then
  begin
    if not InputQuery('tiFlux',
      'Chave de API do tiFlux (Configurações > Minha conta > Sessões > Sessões API).' + sLineBreak +
      'Deixe em branco pra só criar a pasta e preencher manualmente:', Chave) then
      Exit;
    Chave := Trim(Chave);

    if Chave = '' then
    begin
      // Sem API configurada: cria so o esqueleto (pasta + Ticket.md vazio) pra
      // o usuário colar as informações do tiFlux manualmente.
      Titulo := '';
      InputQuery('Novo Ticket', 'Título do ticket (opcional, pra nomear a pasta):', Titulo);
      try
        CaminhoPasta := CriarPastaTicketManual(Numero, Trim(Titulo), PastaBaseTickets);
        MostrarBalao('AgentDeck', 'Pasta do ticket #' + Numero + ' criada em: ' + CaminhoPasta, bfInfo);
        ShellExecute(0, 'open', PChar(CaminhoPasta), nil, nil, SW_SHOWNORMAL);
      except
        on E: Exception do
          MostrarBalao('AgentDeck', 'Erro ao criar pasta do ticket #' + Numero + ': ' + E.Message, bfError);
      end;
      Exit;
    end;

    SalvarTiFluxApiKey(Chave);
  end;

  FGerandoTicket := True;
  FLblNovoTicket.Caption := 'Consultando ticket #' + Numero + '...';

  TThread.CreateAnonymousThread(
    procedure
    var
      CaminhoPastaGerada, MensagemErro: string;
    begin
      try
        CaminhoPastaGerada := GerarPastaTicket(Numero, TiFluxApiKey, PastaBaseTickets);
        NaThreadPrincipal(
          procedure
          begin
            MostrarBalao('AgentDeck', 'Ticket #' + Numero + ' documentado em: ' + CaminhoPastaGerada, bfInfo);
            ShellExecute(0, 'open', PChar(CaminhoPastaGerada), nil, nil, SW_SHOWNORMAL);
          end);
      except
        on E: Exception do
        begin
          // Captura o texto aqui: TThread.Queue e assincrono, entao o objeto E
          // ja estara liberado quando a procedure abaixo realmente rodar na
          // thread principal (E.Message la dentro leria memoria liberada).
          MensagemErro := E.ClassName + ': ' + E.Message;
          NaThreadPrincipal(
            procedure
            var
              TituloManual, CaminhoManual: string;
            begin
              // Falhou a consulta no tiFlux (token invalido, rede, etc.): cai
              // pro mesmo fallback do fluxo "sem chave de API" — pergunta o
              // titulo e cria so o esqueleto (pasta + Ticket.md vazio).
              MostrarBalao('AgentDeck',
                'Não foi possível consultar o ticket #' + Numero + ' no tiFlux (' + MensagemErro + ').',
                bfWarning);

              TituloManual := '';
              InputQuery('Novo Ticket', 'Título do ticket (opcional, pra nomear a pasta):', TituloManual);
              try
                CaminhoManual := CriarPastaTicketManual(Numero, Trim(TituloManual), PastaBaseTickets);
                MostrarBalao('AgentDeck', 'Pasta do ticket #' + Numero + ' criada em: ' + CaminhoManual, bfInfo);
                ShellExecute(0, 'open', PChar(CaminhoManual), nil, nil, SW_SHOWNORMAL);
              except
                on E2: Exception do
                  MostrarBalao('AgentDeck',
                    'Erro ao criar pasta do ticket #' + Numero + ': ' + E2.ClassName + ': ' + E2.Message, bfError);
              end;
            end);
        end;
      end;
      NaThreadPrincipal(
        procedure
        begin
          FGerandoTicket := False;
          FLblNovoTicket.Caption := 'Novo Ticket (tiFlux)';
        end);
    end).Start;
end;

end.
