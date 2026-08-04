# Case: Gestão de Ações — dashboard público e app de gestão privado

## Contexto

Times de RevOps normalmente centralizam o acompanhamento de ações em uma planilha: o que está sendo feito, quem é responsável, em que etapa está, qual a prioridade. Funciona até certo ponto. Quando mais de uma pessoa precisa editar ao mesmo tempo, ou alguém precisa só visualizar sem ter acesso de edição, ou falta rastro de quem mudou o quê, a planilha vira o gargalo em vez de resolver o problema.

Construí esse projeto pessoal pra simular a alternativa: um banco de dados relacional de verdade, com regra de negócio garantida no próprio schema, e dois pontos de acesso separados por nível de permissão, um painel público de leitura e um aplicativo privado de gestão.

![Dashboard público](screenshot-dashboard.png)

## Decisão técnica e por quê

O ponto de partida foi migrar os dados de uma planilha para o Postgres do Supabase, com os campos de vocabulário fechado (tipo de ação, etapa, status) travados por `check constraint` no schema. A diferença prática: se um bug no formulário deixasse passar um valor fora da lista esperada, o banco recusaria a escrita, não só a interface.

A parte mais interessante do projeto foi decidir quem pode escrever. O dashboard público precisa funcionar sem login, então a leitura ficou aberta. Já a escrita (criar, editar, excluir ações) precisa ser restrita a mim. Na primeira versão, liberei escrita para qualquer usuário autenticado, pensando que o login por link mágico já era barreira suficiente. O próprio verificador de segurança do Supabase apontou o problema: como qualquer pessoa consegue se autenticar por link mágico (é o comportamento padrão da ferramenta, não uma falha), "estar autenticado" não é o mesmo que "ser eu". Reescrevi a política para travar por e-mail específico, e o alerta de segurança desapareceu.

![App de gestão privado](screenshot-app.png)

Outra decisão que mudei no meio do caminho foi sobre a sessão de login. Na primeira versão, por uma postura mais conservadora de segurança, a sessão não ficava salva em lugar nenhum do navegador. Na prática, isso obrigava um link mágico novo toda vez que a página recarregava, e o serviço de e-mail gratuito do Supabase permite só 2 envios por hora. Testando o fluxo normal de uso, essa cota estourou rápido, e ficou claro que um app que pede login a cada abertura não é utilizável no dia a dia. Passei a salvar a sessão no navegador, e o login deixou de ser um evento frequente.

Pra parte mobile, optei por um web app responsivo (adicionável à tela inicial do celular) em vez de um aplicativo nativo. Entrega a mesma experiência de uso, sem loja de aplicativo e sem processo de build, reaproveitando a mesma stack HTML, CSS e JavaScript do dashboard.

## Arquitetura

Um único banco Postgres serve dois front-ends sem nenhum backend próprio no meio. Os dois se conectam direto na REST API do Supabase:

- **Dashboard público**: leitura aberta, sem autenticação
- **App de gestão**: login por link mágico, escrita restrita ao e-mail autorizado

## Resultado

- Schema com constraints reais aplicando regra de negócio no banco, não só na interface
- Separação de acesso público (leitura) e privado (escrita), como qualquer sistema real de produção
- Um problema de segurança real identificado por ferramenta e corrigido antes de ir ao ar
- Custo de infraestrutura: R$0 por mês

## O que eu faria diferente hoje

Hoje o e-mail autorizado a escrever está fixo na política do banco. Funciona para um único usuário, mas não escala: pra abrir esse app pra outra pessoa, o caminho certo seria uma tabela de usuários e papéis, não outro e-mail hardcoded na regra. Também deixaria preparado desde o início para SMTP próprio, porque o limite de 2 e-mails por hora do serviço padrão do Supabase é uma armadilha silenciosa assim que o app sai do modo teste isolado.
