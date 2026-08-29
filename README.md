# AgentDeck

Painel de bandeja (Windows/VCL) com utilitários do dia a dia de desenvolvimento no TopSystem: monitor de sessões do Claude Code, atalho pro Modo Desenvolvimento (serviços + VPN), branch SVN atual, runner de `.bat`/`.lnk` e, agora, documentação automática de tickets do tiFlux.

## Funcionalidades

- **Sessões Claude Code** — recebe hooks do Claude Code (`POST` em `http://localhost:47311`) e mostra na lista o status de cada sessão (ocioso / processando / esperando permissão) e o diretório de trabalho.
- **Modo Desenvolvimento** — liga/desliga de uma vez os serviços do Windows do ambiente local (Firebird, TopServer, TopCIOTService, TopServerAPI, Nginx) e conecta/desconecta a VPN (OpenVPN GUI).
- **Branch SVN** — mostra no cabeçalho a branch atual do working copy de referência (`C:\TopSystem\Delphi\TopERP`), atualizada periodicamente.
- **Runner de comandos** — lista os `.bat`/`.lnk` de compilação, serviços e SVN configurados, agrupados por categoria.
- **Novo Ticket (tiFlux)** — card no painel: informa o número do ticket, consulta a API do tiFlux e monta automaticamente `<Ano>\<Número> - <Título>\Ticket.md` com a descrição geral e as comunicações internas (aba Comunicação → Equipe interna), em ordem de cadastro. Sem uma chave de API configurada, cria só a pasta e um `Ticket.md` vazio para preenchimento manual.
- **Monitor** — card no painel pra escolher em qual monitor o painel deve ficar ancorado; a lista de monitores é reconstruída a cada clique (reflete monitores plugados/desplugados na hora, sem precisar reiniciar o app).

## Estrutura do projeto

```
prj/      projeto Delphi (.dpr/.dproj) — saída de build em dcu/ e bin/
src/      unidades .pas da aplicação
modules/  dependências de terceiros (Horse, usado no servidor de hooks)
img/      ícones da aplicação e dos botões do painel
```

## Build

Requer Delphi/RAD Studio (testado com a versão 10.3 Rio, compilador 33.0) com suporte a VCL para Win32.

Pela IDE: abra `prj/AgentDeck.dproj` e compile normalmente.

Por linha de comando (a partir de `prj/`, com o ambiente do `rsvars.bat`/MSBuild do RAD Studio carregado):

```
msbuild AgentDeck.dproj /t:Build /p:Config=Base /p:Platform=Win32
```

Os ícones do painel (`Novo Ticket`, `Monitor`) são embutidos no executável como recurso (`src/Icones.res`, gerado a partir de `src/Icones.rc` via `brcc32`). Se os PNGs de origem em `img/` mudarem, recompile o `.res`:

```
brcc32 src\Icones.rc
```

## Configuração

Config fica em `%APPDATA%\AgentDeck\settings.ini`, criado automaticamente. Principais chaves:

- `[Painel] Monitor` — índice do monitor preferido (definido pelo card "Monitor").
- `[VPN] CaminhoOpenVpnGui` / `Perfil` — caminho do OpenVPN GUI e perfil usado pelo Modo Desenvolvimento.
- `[TiFlux] ApiKey` — chave de API do tiFlux (pedida pelo app na primeira vez que "Novo Ticket" é usado; gerada em *Configurações → Minha conta → Sessões → Sessões API* no tiFlux).
- `[TiFlux] PastaBaseTickets` — pasta onde as pastas de ticket são criadas (padrão: `OneDrive\Documentos\Obsidian Vault\01. ERP Top System\99. Ticket` dentro do perfil do usuário).
