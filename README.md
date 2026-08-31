<p align="center">
  <img src="img/AgentDeck-128.png" width="96" alt="Ícone do AgentDeck">
</p>

<h1 align="center">AgentDeck</h1>

<p align="center">
  <img src="https://img.shields.io/badge/Delphi-10.3_Rio-E62430?logo=delphi&logoColor=white" alt="Delphi 10.3 Rio">
  <img src="https://img.shields.io/badge/Plataforma-Windows-0078D6?logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/UI-VCL-F2A03D" alt="VCL">
  <img src="https://img.shields.io/badge/status-uso%20interno-3ECF8E" alt="Uso interno">
</p>

<p align="center">
  Painel de bandeja com os utilitários do dia a dia de desenvolvimento no TopSystem:<br>
  sessões do Claude Code, Modo Desenvolvimento, branch SVN, runner de comandos e documentação automática de tickets do tiFlux.
</p>

---

## ✨ Funcionalidades

| | | |
|:---:|---|---|
| 🖥️ | **Sessões Claude Code** | Recebe hooks do Claude Code (`POST` em `http://localhost:47311`) e mostra o status de cada sessão — 🟢 ocioso, 🔵 processando, 🔴 esperando permissão — e o diretório de trabalho. |
| ⚡ | **Modo Desenvolvimento** | Liga/desliga de uma vez os serviços do Windows do ambiente local (Firebird, TopServer, TopCIOTService, TopServerAPI, Nginx) e conecta/desconecta a VPN (OpenVPN GUI). |
| 🌿 | **Branch SVN** | Mostra no cabeçalho a branch atual do working copy de referência (`C:\TopSystem\Delphi\TopERP`), atualizada periodicamente. |
| ▶️ | **Runner de comandos** | Lista os `.bat`/`.lnk` de compilação, serviços e SVN configurados, agrupados por categoria — incluindo o `Compilar - Script`, que compila um subconjunto de projetos escolhido na hora (ou só os alterados no branch SVN atual), gera os zips e envia por FTP num fluxo único guiado por menu, sem apagar o que já está em produção. |
| <img src="img/ticket-novo-48.png" width="28" alt=""> | **Novo Ticket (tiFlux)** | Informa o número do ticket, consulta a API do tiFlux e monta `<Ano>\<Número> - <Título>\Ticket.md` com a descrição geral e as comunicações internas (Comunicação → Equipe interna), em ordem de cadastro. Sem chave de API, cria só a pasta e um `Ticket.md` vazio pra preenchimento manual. |
| <img src="img/monitor-48.png" width="28" alt=""> | **Monitor** | Escolhe em qual monitor o painel fica ancorado; a lista é reconstruída a cada clique, refletindo monitores plugados/desplugados na hora — sem precisar reiniciar o app. |

## 📁 Estrutura do projeto

```
prj/      projeto Delphi (.dpr/.dproj) — saída de build em dcu/ e bin/
src/      unidades .pas da aplicação
modules/  dependências de terceiros (Horse, usado no servidor de hooks)
img/      ícones da aplicação e dos cards do painel
```

## 🛠️ Build

Requer Delphi/RAD Studio (testado com a versão 10.3 Rio, compilador 33.0) com suporte a VCL para Win32.

**Pela IDE:** abra `prj/AgentDeck.dproj` e compile normalmente.

**Por linha de comando** (a partir de `prj/`, com o ambiente do `rsvars.bat`/MSBuild do RAD Studio carregado):

```
msbuild AgentDeck.dproj /t:Build /p:Config=Base /p:Platform=Win32
```

Os ícones dos cards do painel (🎫 Novo Ticket, 🖥️ Monitor) são embutidos no executável como recurso (`src/Icones.res`, gerado a partir de `src/Icones.rc` via `brcc32`). Se os PNGs de origem em `img/` mudarem, recompile o `.res`:

```
brcc32 src\Icones.rc
```

## ⚙️ Configuração

Config fica em `%APPDATA%\AgentDeck\settings.ini`, criado automaticamente. Principais chaves:

| Seção | Chave | Descrição |
|---|---|---|
| `Painel` | `Monitor` | Índice do monitor preferido (definido pelo card "Monitor"). |
| `VPN` | `CaminhoOpenVpnGui` / `Perfil` | Caminho do OpenVPN GUI e perfil usado pelo Modo Desenvolvimento. |
| `TiFlux` | `ApiKey` | Chave de API do tiFlux — pedida pelo app na primeira vez que "Novo Ticket" é usado; gerada em *Configurações → Minha conta → Sessões → Sessões API* no tiFlux. |
| `TiFlux` | `PastaBaseTickets` | Pasta onde as pastas de ticket são criadas (padrão: `OneDrive\Documentos\Obsidian Vault\01. ERP Top System\99. Ticket` dentro do perfil do usuário). |
