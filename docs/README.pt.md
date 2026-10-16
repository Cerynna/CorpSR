<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/art/icons-coin-64.png" width="96" alt="CorpSR">
</p>

<h1 align="center">CorpSR</h1>

<p align="center">
  <b>Soft Reserve de guilda com pontos, tudo dentro do jogo.</b><br>
  World of Warcraft Classic · cliente «Forever» (Interface 16001)
</p>

<p align="center">
  <a href="https://github.com/Cerynna/CorpSR/blob/main/README.md">🇬🇧 English</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.fr.md">🇫🇷 Français</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.de.md">🇩🇪 Deutsch</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.es.md">🇪🇸 Español</a> ·
  <b>🇧🇷 Português</b> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.it.md">🇮🇹 Italiano</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ru.md">🇷🇺 Русский</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-CN.md">🇨🇳 简体中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.zh-TW.md">🇹🇼 繁體中文</a> ·
  <a href="https://github.com/Cerynna/CorpSR/blob/main/docs/README.ko.md">🇰🇷 한국어</a>
</p>

![Meus SR](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/MesSR.png)

O CorpSR gerencia os Soft Reserve (SR) da sua guilda dentro do jogo: cada membro reserva os itens que quer, o mestre saqueador distribui o saque e o addon lê as `/roll`, classifica e guarda o histórico. Cada SR que você perde dá pontos nesse item: sua próxima rolagem fica mais forte.

Sem site, sem exportação, sem planilha. Os dados passam só pelo canal de addon da guilda, e cada membro guarda uma cópia completa: um oficial ausente nunca faz ninguém perder nada.

## Recursos

- **SR da semana**: 2 por semana (ajuste do GM), em qualquer item de qualquer raide. SR duplo permitido.
- **Pontos**: você perde um item que reservou → +10 pontos nele. Sua rolagem SR = rolagem + pontos.
- **Prioridade clara**: SR > +1 > +1 já saqueou > +2 > Transmog, lida na faixa da rolagem.
- **Janela do raider**: o item, seus pontos, um botão por tipo de rolagem, uma barra de tempo, «Passar».
- **Janela de distribuição** para o mestre saqueador: rolagens ao vivo, empates, vencedor à escolha, sobras (rolagem livre, banco da guilda, desencantar).
- **Anúncios na raide** no início e no fim de cada item.
- **Entrega**: tentativa de troca, sussurro pronto, lista do que falta entregar, um desencantador para a sessão.
- **`!SR` por sussurro** para membros sem o addon.
- **Histórico completo**: tudo fica registrado; correções e anulações com motivo, reversíveis.
- **Ajustes do GM**: valores e direitos patente por patente, reinício completo.
- **Modo demo** para testar tudo sem enviar nada à guilda.
- **10 idiomas**: inglês, francês, alemão, espanhol, português, italiano, russo, chinês simplificado e tradicional, coreano.

## As regras

| Tipo de rolagem | Rolagem | Total |
|---|---|---|
| **SR** | `/roll 110` | rolagem + seus pontos no item |
| **+1** (especialização principal) | `/roll 100` | rolagem |
| **+1 já saqueou** (especialização principal, já ganhou um item em +1 nesta semana) | `/roll 100` | rolagem |
| **+2** (segunda especialização) | `/roll 50` | rolagem |
| **Transmog** | `/roll 20` | rolagem |

- **A melhor categoria vence**, sejam quais forem as rolagens: um SR sempre vence um +1. Dentro de uma categoria, vence o maior total. Em caso de empate, os empatados rolam de novo.
- **Pontos**: você rola com os pontos que já tem (0 na primeira vez). Depois que o item é rolado, todos que o reservaram, estavam na raide e não o levaram ganham **+10 por SR** nele (+20 com SR duplo). O vencedor não ganha nada e, se venceu com SR, volta a 0 nesse item. Quem clica em «Passar» também não ganha nada.
- **Os pontos ficam guardados** quando você troca de item: eles esperam na reserva até você reservá-lo de novo.
- **Um item ganho gasta seu SR** da semana: se vários chefes podem derrubá-lo, você não rola SR por ele de novo até a semana seguinte.
- **+1 já saqueou**: a partir da sua primeira vitória em +1 da semana (ou da sessão, ajuste do GM). Vitórias em SR, +2, transmog ou rolagem livre não contam.
- **Só a sua primeira rolagem válida conta.** Se caírem N cópias, os N melhores vencem.
- Todos os valores (pontos, número de SR, SR duplo, faixas de rolagem) são ajustes do GM.

## Uma noite de raide

**Oficiais**

1. Aba **Sessão** → **Nova sessão**.
2. O mestre saqueador abre o saque do chefe: a **janela de distribuição** abre sozinha. Você também pode usar Alt + clique esquerdo em um item das suas bolsas.
3. Escolha o item e depois **Iniciar**: seu clique anuncia o item no chat da raide, com as faixas e o tempo.
4. As rolagens chegam ao vivo. Quando o tempo acaba, **Validar** (ou **Rolar empate**): seu clique anuncia o vencedor.
5. O CorpSR tenta abrir uma troca com o vencedor e coloca o item nela. Se não der, um sussurro fica pronto em um botão. A aba **A entregar** lembra quem ainda espera o quê.
6. Ninguém quer? Rolagem livre, banco da guilda ou desencantar.

![Janela de distribuição](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Attribution.png)

**Raiders**

- Aba **Meus SR**: clique em um item para reservá-lo, de novo para um SR duplo, clique direito para tirar um. Os SR travam no primeiro item rolado da semana (ou quando um oficial os trava).
- Quando um item cai, sua **janela de rolagem** mostra o que você pode rolar. Um clique faz a `/roll` certa para você.

<p align="center">
  <img src="https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raideur.png" width="450" alt="Janela do raider">
</p>

- Aba **Pontos**: os pontos de todos, item por item. Aba **Histórico**: tudo o que aconteceu, por quem e quando.
- Sem o addon? Sussurre a um oficial `!SR [item] [item]` (links de itens, juntos ou separados, ou números de itens). `!SR` sozinho devolve seus SR da semana.

## Direitos por patente

O GM escolhe, patente por patente, quem pode fazer o quê (aba Ajustes). Pôr os próprios SR não exige nenhum direito.

| Direito | Permite |
|---|---|
| **Sessão** | abrir, travar, fechar, reabrir, renomear ou excluir uma sessão; registrar os SR de um membro que sussurra `!SR` |
| **Distribuir** | iniciar um item, ler as rolagens, validar o vencedor, mandar para o banco ou para desencantar |
| **Corrigir** | corrigir os pontos de um jogador em um item, com motivo obrigatório |
| **Anular** | anular uma linha do histórico, com motivo obrigatório |
| **Itens** | tirar um item dos itens conhecidos (qualquer um pode adicionar) |

## Comandos

| Comando | Efeito |
|---|---|
| `/csr` | abre ou fecha a janela do CorpSR |
| `/csr attrib` | abre ou fecha a janela de distribuição (também: clique direito no botão do minimapa) |
| `/csr demo` | inicia ou para o modo demo |
| `/csr minimap` | mostra ou esconde o botão do minimapa |
| `/csr sync` | pede à guilda os dados mais recentes |

O CorpSR também adiciona uma aba à janela **Guilda e Comunidades**, e uma página ao `/corp` quando o [CorpUI](https://github.com/Cerynna/CorpUI) está instalado (opcional).

## Bom saber

- **O jogo proíbe addons de escrever sozinhos no chat ou de sussurrar.** Por isso os anúncios e sussurros passam por botões: seu clique envia a mensagem, como se você a tivesse digitado. Esses botões ficam escondidos em combate.
- **Em instâncias**, o texto dos sussurros pode ficar oculto para os addons: mande seu `!SR` antes de entrar.
- Os dados são compartilhados **só com a sua guilda**, pelo canal de addon. Nada sai do jogo.

## Instalação

- **Wago**: [addons.wago.io/addons/corpsr](https://addons.wago.io/addons/corpsr), com o aplicativo do Wago ou à mão.
- **À mão**: coloque a pasta `CorpSR` em `Interface\AddOns` da sua pasta do WoW Classic e reinicie o jogo.

## Imagens

| | |
|---|---|
| ![Pontos](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Points.png) | ![Histórico](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Historique.png) |
| ![Sessão](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Session.png) | ![A entregar](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Remise.png) |
| ![Ajustes](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Reglages.png) | ![Itens conhecidos](https://raw.githubusercontent.com/Cerynna/CorpSR/main/docs/images/en/Raids.png) |

As imagens mostram o addon em inglês; no jogo ele está em português. Todas as janelas, em inglês e em francês: [`docs/images`](https://github.com/Cerynna/CorpSR/tree/main/docs/images). Elas são desenhadas a partir do layout real do addon, no modo demo.

## Desenvolvimento

Organização do código, regras detalhadas e testes (em francês): [`docs/DEVELOPMENT.md`](https://github.com/Cerynna/CorpSR/blob/main/docs/DEVELOPMENT.md).
