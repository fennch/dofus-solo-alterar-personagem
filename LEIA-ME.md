# Alterar Personagem (Dofus Solo)

Aplicação para Windows que altera os personagens do **Dofus Solo**, a versão offline do jogo, sem precisar mexer em arquivos na mão.

- **Resetar características:** os pontos naturais voltam para o capital livre e os pontos de pergaminho ficam.
- **Resetar feitiços:** todos os feitiços voltam ao nível 1 e os pontos gastos voltam. Nenhum feitiço é esquecido, nem os aprendidos com pergaminho de feitiço.
- **Pergaminhos:** escolha quanto de pergaminho cada característica tem, de 0 a 101 (Vitalidade, Sabedoria, Força, Inteligência, Sorte e Agilidade).

Antes de cada alteração, a aplicação guarda uma cópia do save na pasta de backups do próprio jogo.

## Como instalar

1. Na página do repositório, clique em **Releases** (à direita) e baixe o arquivo **AlterarPersonagem.zip**.
   Ou clique no botão verde **Code** e depois em **Download ZIP**.
2. Clique com o botão direito no ZIP baixado e escolha **Extrair Tudo**.
3. Abra a pasta extraída e dê dois cliques em **Instalar.cmd**.
4. O instalador cria a pasta **Alterar Personagem** na sua área de trabalho. Use sempre o **Alterar Personagem.cmd** dessa pasta.

Se o Windows mostrar "O Windows protegeu o computador", clique em **Mais informações** e depois em **Executar assim mesmo**. Isso aparece porque o arquivo veio da internet e não tem assinatura digital.

Para desinstalar, basta apagar a pasta **Alterar Personagem** da área de trabalho.

## Como usar

1. **Feche o jogo.** O servidor do jogo guarda os personagens na memória e gravaria por cima da alteração. Se ele ainda estiver ligado, a aplicação pergunta se pode desligá-lo do jeito normal do jogo, que salva antes.
2. Abra o **Alterar Personagem.cmd**.
3. Escolha o personagem na lista da esquerda.
4. Use uma das abas:
   - **Resetar:** mostra cada característica como está agora, quanto veio de pergaminho e como fica depois. Marque características, feitiços ou os dois e clique em **Resetar**.
   - **Pergaminhos:** para cada característica aparecem os pontos naturais, o pergaminho atual e o novo valor. Use o botão **101** de cada linha ou **101 em todos** e clique em **Aplicar pergaminhos**.
5. Confirme. Quando aparecer a mensagem verde, pode abrir o jogo.

## Onde a aplicação procura o jogo

Ela procura sozinha, nesta ordem:

1. A pasta que você já escolheu antes.
2. O lugar padrão de instalação: `%LOCALAPPDATA%\Programs\Dofus Solo`.
3. Os atalhos do Dofus Solo na área de trabalho e no Menu Iniciar.
4. A lista de programas instalados do Windows.
5. Pastas com "Dofus" no nome em cada disco (`C:\`, `D:\`, `Program Files`, `Games`, `Jogos`) e em Downloads e Documentos.

Se não achar, ela explica como encontrar a pasta e abre uma janela para você escolher. A pasta certa é a que tem dentro as pastas **data**, **jogo**, **scripts**, **server** e **tools**. Um jeito fácil de achar: clique com o botão direito no atalho do Dofus Solo e escolha **Abrir local do arquivo**.

Para trocar a pasta depois, use o botão **Pasta do jogo...** no canto de baixo da janela.

## Regras usadas

As regras de reset são as mesmas do reinício do próprio servidor do jogo, o mesmo que o Mestre de classe faz nos templos, só que sem custo:

- **Características:** cada característica volta para o valor que veio de pergaminho. O capital livre volta para (nível − 1) × 5.
- **Feitiços:** um feitiço no nível N devolve N × (N − 1) / 2 pontos. Exemplo: nível 5 devolve 10 pontos.
- **Pergaminhos:** o valor escolhido (até 101) fica registrado como pergaminho, separado dos pontos naturais. Exemplo: 120 de Vitalidade natural mais 101 de pergaminho dá 221. Num reset depois, os 101 continuam.

## Segurança

- Antes de cada alteração, uma cópia do save vai para `data\saves_backup`, dentro da pasta do jogo. Para voltar atrás, use **Importar backup** no launcher do jogo.
- Cada alteração é gravada de uma vez: se algo falhar no meio, nada fica pela metade.
- Se uma versão nova do jogo mudar a forma de guardar os personagens, a aplicação avisa e não grava nada.
- Tudo o que foi alterado fica registrado no arquivo `alteracoes.log`, na pasta da aplicação.

## Requisitos

- Windows 10 ou 11 (usa o PowerShell que já vem no Windows, não precisa instalar nada).
- Dofus Solo instalado.

## Aviso

Ferramenta feita por fã, independente e não oficial. Não tem ligação com o criador do Dofus Solo nem com a Ankama. Use por sua conta: os backups automáticos existem para isso.
