object FormPrincipal: TFormPrincipal
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'AgentDeck'
  ClientHeight = 700
  ClientWidth = 340
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesigned
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object TrayIcon: TTrayIcon
    PopupMenu = PopupTray
    OnDblClick = TrayIconDblClick
    Left = 16
    Top = 16
  end
  object TimerAtualiza: TTimer
    Interval = 2000
    OnTimer = TimerAtualizaTimer
    Left = 56
    Top = 16
  end
  object TimerBranch: TTimer
    Interval = 60000
    OnTimer = TimerBranchTimer
    Left = 56
    Top = 64
  end
  object PopupTray: TPopupMenu
    Left = 96
    Top = 16
    object ItemAbrir: TMenuItem
      Caption = 'Abrir'
      OnClick = ItemAbrirClick
    end
    object ItemSair: TMenuItem
      Caption = 'Sair'
      OnClick = ItemSairClick
    end
  end
end
