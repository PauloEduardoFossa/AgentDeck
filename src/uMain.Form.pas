unit uMain.Form;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,
  Vcl.Menus, System.Generics.Collections, System.DateUtils, System.StrUtils,
  uSessionStatus, uServiceControl, uBatRunner, uHookServer;

type
  TFormPrincipal = class(TForm)
    TrayIcon: TTrayIcon;
    TimerAtualiza: TTimer;
    PopupTray: TPopupMenu;
    ItemAbrir: TMenuItem;
    ItemSair: TMenuItem;
    procedure FormCreate(Sender: TObject);
    procedure TrayIconDblClick(Sender: TObject);
    procedure TimerAtualizaTimer(Sender: TObject);
    procedure ItemAbrirClick(Sender: TObject);
    procedure ItemSairClick(Sender: TObject);
  private
    FListaSessoes: TListBox;
    FBtnModoDev: TButton;
    FLblModoDev: TLabel;
    FMemoServicos: TMemo;
    FScrollComandos: TScrollBox;
    FAtualizandoModoDev: Boolean;
    FBats: TArray<TBatInfo>;

    procedure MontarLayout;
    procedure PosicionarNaLateral;
    procedure AtualizarSessoes;
    procedure AtualizarModoDev;
    procedure MontarBotoesComandos;
    procedure ListaSessoesDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure BtnModoDevClick(Sender: TObject);
    procedure BotaoBatClick(Sender: TObject);
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

const
  CorOcioso = $00A46A3B;         // verde (BGR)
  CorProcessando = $000AC8FF;    // amarelo (BGR)
  CorEsperandoPermissao = $002222D0; // vermelho (BGR)
  SegundosLimiteSessaoInativa = 12 * 3600;

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

function CorStatus(Status: TStatusSessao): TColor;
begin
  case Status of
    ssOcioso: Result := CorOcioso;
    ssProcessando: Result := CorProcessando;
    ssEsperandoPermissao: Result := CorEsperandoPermissao;
  else
    Result := clBtnFace;
  end;
end;

procedure TFormPrincipal.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  // Sem isso o form aparece na barra de tarefas: WS_EX_TOOLWINDOW tira o
  // botao de la, restando so o icone da bandeja pra abrir/fechar o painel.
  Params.ExStyle := Params.ExStyle or WS_EX_TOOLWINDOW;
end;

procedure TFormPrincipal.FormCreate(Sender: TObject);
begin
  BorderStyle := bsNone;
  Color := clWindow;

  MontarLayout;
  PosicionarNaLateral;
  MontarBotoesComandos;
  AtualizarSessoes;
  AtualizarModoDev;

  TrayIcon.Icon := Application.Icon;
  TrayIcon.Hint := 'AgentDeck';
  TrayIcon.Visible := True;

  try
    IniciarServidorHooks;
  except
    on E: Exception do
      MostrarBalao('AgentDeck', 'Servidor de hooks não iniciou: ' + E.Message, bfError);
  end;
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
  LblSessoes, LblModoDevTitulo, LblComandos: TLabel;
  Divisor1, Divisor2: TBevel;
begin
  LblSessoes := TLabel.Create(Self);
  LblSessoes.Parent := Self;
  LblSessoes.Caption := 'Sessões Claude Code';
  LblSessoes.Font.Style := [fsBold];
  LblSessoes.SetBounds(12, 12, 300, 18);

  FListaSessoes := TListBox.Create(Self);
  FListaSessoes.Parent := Self;
  FListaSessoes.Style := lbOwnerDrawFixed;
  FListaSessoes.ItemHeight := 34;
  FListaSessoes.OnDrawItem := ListaSessoesDrawItem;
  FListaSessoes.SetBounds(12, 34, ClientWidth - 24, 220);
  FListaSessoes.Anchors := [akLeft, akTop, akRight];

  Divisor1 := TBevel.Create(Self);
  Divisor1.Parent := Self;
  Divisor1.Shape := bsTopLine;
  Divisor1.SetBounds(12, 264, ClientWidth - 24, 8);
  Divisor1.Anchors := [akLeft, akTop, akRight];

  LblModoDevTitulo := TLabel.Create(Self);
  LblModoDevTitulo.Parent := Self;
  LblModoDevTitulo.Caption := 'Modo Desenvolvimento';
  LblModoDevTitulo.Font.Style := [fsBold];
  LblModoDevTitulo.SetBounds(12, 280, 300, 18);

  FLblModoDev := TLabel.Create(Self);
  FLblModoDev.Parent := Self;
  FLblModoDev.Caption := '...';
  FLblModoDev.SetBounds(12, 302, ClientWidth - 24, 18);
  FLblModoDev.Anchors := [akLeft, akTop, akRight];

  FBtnModoDev := TButton.Create(Self);
  FBtnModoDev.Parent := Self;
  FBtnModoDev.Caption := 'Ativar';
  FBtnModoDev.OnClick := BtnModoDevClick;
  FBtnModoDev.SetBounds(12, 324, 140, 28);

  FMemoServicos := TMemo.Create(Self);
  FMemoServicos.Parent := Self;
  FMemoServicos.ReadOnly := True;
  FMemoServicos.BorderStyle := bsNone;
  FMemoServicos.Color := clWindow;
  FMemoServicos.ScrollBars := ssNone;
  FMemoServicos.SetBounds(12, 358, ClientWidth - 24, 100);
  FMemoServicos.Anchors := [akLeft, akTop, akRight];

  Divisor2 := TBevel.Create(Self);
  Divisor2.Parent := Self;
  Divisor2.Shape := bsTopLine;
  Divisor2.SetBounds(12, 464, ClientWidth - 24, 8);
  Divisor2.Anchors := [akLeft, akTop, akRight];

  LblComandos := TLabel.Create(Self);
  LblComandos.Parent := Self;
  LblComandos.Caption := 'Comandos';
  LblComandos.Font.Style := [fsBold];
  LblComandos.SetBounds(12, 480, 300, 18);

  FScrollComandos := TScrollBox.Create(Self);
  FScrollComandos.Parent := Self;
  FScrollComandos.SetBounds(12, 502, ClientWidth - 24, ClientHeight - 514);
  FScrollComandos.Anchors := [akLeft, akTop, akRight, akBottom];
  FScrollComandos.BorderStyle := bsNone;
end;

procedure TFormPrincipal.PosicionarNaLateral;
var
  Area: TRect;
begin
  Area := Screen.WorkAreaRect;
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

procedure TFormPrincipal.AtualizarSessoes;
var
  Sessoes: TArray<TSessaoInfo>;
  Info: TSessaoInfo;
  Texto, IdCurto: string;
  IndiceSelecionado: Integer;
begin
  SessionStatusStore.RemoverInativas(SegundosLimiteSessaoInativa);
  Sessoes := SessionStatusStore.Listar;

  IndiceSelecionado := FListaSessoes.ItemIndex;
  FListaSessoes.Items.BeginUpdate;
  try
    FListaSessoes.Items.Clear;
    for Info in Sessoes do
    begin
      IdCurto := Copy(Info.SessionId, 1, 8);
      Texto := Format('%s  [%s]'#13'%s', [IdCurto, TextoStatus(Info.Status), Info.Cwd]);
      FListaSessoes.Items.AddObject(Texto, TObject(Ord(Info.Status)));
    end;
    if (IndiceSelecionado >= 0) and (IndiceSelecionado < FListaSessoes.Items.Count) then
      FListaSessoes.ItemIndex := IndiceSelecionado;
  finally
    FListaSessoes.Items.EndUpdate;
  end;
end;

procedure TFormPrincipal.ListaSessoesDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  ListBox: TListBox;
  Status: TStatusSessao;
  Linhas: TArray<string>;
begin
  ListBox := Control as TListBox;
  Status := TStatusSessao(NativeInt(ListBox.Items.Objects[Index]));

  ListBox.Canvas.Brush.Color := CorStatus(Status);
  ListBox.Canvas.FillRect(Rect);

  Linhas := ListBox.Items[Index].Split([#13]);
  ListBox.Canvas.Font.Style := [fsBold];
  ListBox.Canvas.TextOut(Rect.Left + 8, Rect.Top + 3, Linhas[0]);
  if Length(Linhas) > 1 then
  begin
    ListBox.Canvas.Font.Style := [];
    ListBox.Canvas.TextOut(Rect.Left + 8, Rect.Top + 18, Linhas[1]);
  end;
end;

procedure TFormPrincipal.AtualizarModoDev;
var
  Item: TServicoInfo;
  Ligado: Boolean;
begin
  Ligado := ModoDesenvolvimentoRodando;
  FLblModoDev.Caption := 'Status: ' + IfThen(Ligado, 'ligado', 'desligado');
  FBtnModoDev.Caption := IfThen(Ligado, 'Desativar', 'Ativar');

  FMemoServicos.Lines.BeginUpdate;
  try
    FMemoServicos.Lines.Clear;
    for Item in ServicosModoDesenvolvimento do
    begin
      case StatusDoServico(Item.Nome) of
        stRodando:  FMemoServicos.Lines.Add(Item.Descricao + ': rodando');
        stParado:   FMemoServicos.Lines.Add(Item.Descricao + ': parado');
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
          AtivarModoDesenvolvimento(Progresso)
        else
          DesativarModoDesenvolvimento(Progresso);
      except
        on E: Exception do
          NaThreadPrincipal(
            procedure
            begin
              MostrarBalao('AgentDeck', 'Erro no Modo Desenvolvimento: ' + E.Message, bfError);
            end);
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
var
  I: Integer;
  Botao: TButton;
  TopoAtual: Integer;
begin
  FBats := ListarBats;
  TopoAtual := 4;
  for I := 0 to High(FBats) do
  begin
    Botao := TButton.Create(Self);
    Botao.Parent := FScrollComandos;
    Botao.Caption := FBats[I].Nome;
    Botao.Tag := I;
    Botao.OnClick := BotaoBatClick;
    Botao.SetBounds(4, TopoAtual, FScrollComandos.ClientWidth - 24, 28);
    Botao.Anchors := [akLeft, akTop, akRight];
    Inc(TopoAtual, 34);
  end;
end;

procedure TFormPrincipal.BotaoBatClick(Sender: TObject);
var
  Indice: Integer;
begin
  Indice := (Sender as TButton).Tag;
  if (Indice < 0) or (Indice > High(FBats)) then
    Exit;
  try
    ExecutarBat(FBats[Indice].Caminho);
  except
    on E: Exception do
      MostrarBalao('AgentDeck', 'Erro ao executar: ' + E.Message, bfError);
  end;
end;

end.
