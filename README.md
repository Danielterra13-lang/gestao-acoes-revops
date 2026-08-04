# Gestão de Ações — dashboard público + app de gestão privado

Case pessoal de RevOps aplicado a dados: um banco Postgres único (Supabase) servindo dois front-ends com níveis de acesso diferentes, um dashboard público de leitura e um app mobile privado de escrita.

![Dashboard público]((https://danielterra13-lang.github.io/gestao-acoes-revops/revops-dashboard))

## Contexto

Times de RevOps costumam ter um lugar só pra acompanhar as ações em andamento (o que está sendo feito, por quem, em que etapa, com que prioridade), e esse lugar quase sempre é uma planilha. Funciona até o momento em que mais de uma pessoa precisa editar ao mesmo tempo, ou até alguém precisar visualizar o status sem ter acesso de edição, ou até faltar controle de quem mudou o quê.

Esse projeto simula esse cenário do zero: banco relacional de verdade, regra de negócio garantida no schema (não só na interface), separação clara entre quem só visualiza e quem edita.

## Arquitetura

```
                         ┌─────────────────────┐
                         │   Supabase (Postgres) │
                         │   tabela acoes_revops │
                         │   RLS habilitado      │
                         └──────────┬───────────┘
                                    │
                 ┌──────────────────┴──────────────────┐
                 │                                       │
      leitura pública (REST API)              escrita autenticada (REST API)
                 │                                       │
     ┌───────────▼────────────┐          ┌───────────────▼────────────────┐
     │ revops-dashboard.html   │          │ app-gestao.html                 │
     │ sem login               │          │ login por link mágico           │
     │ filtros, KPIs, cards    │          │ criar / editar / excluir ações  │
     └─────────────────────────┘          └──────────────────────────────────┘
```

Os dois arquivos são HTML/CSS/JS puro, sem build step, hospedados no GitHub Pages. Não existe backend próprio: os dois front-ends conversam direto com a REST API do Supabase (PostgREST), autenticados de formas diferentes.

## Decisões técnicas e por quê

### Regra de negócio no banco, não só na aplicação

Os campos de vocabulário fechado (`tipo_acao`, `etapa`, `status`) usam `check constraint` no schema, não só validação no front-end:

```sql
tipo_acao text not null check (tipo_acao in ('Estratégica', 'Rotina'))
```

Se um bug no formulário deixar passar um valor fora da lista, o Postgres recusa a escrita antes de chegar na tabela. A UI é a primeira camada de proteção, não a única.

### Leitura pública, escrita restrita por e-mail

A tabela tem Row Level Security habilitado com uma política de `select` aberta (`using (true)`), porque o dashboard precisa funcionar sem autenticação. As políticas de `insert`, `update` e `delete` exigem que o e-mail do JWT da sessão bata com um e-mail específico:

```sql
with check ((auth.jwt() ->> 'email') = 'seu-email@exemplo.com')
```

Isso não é a versão que eu escrevi primeiro. A primeira liberava escrita pra qualquer usuário autenticado (`to authenticated, using (true)`), pensando que magic link já era barreira suficiente. O próprio linter de segurança do Supabase (`get_advisors`) apontou o problema: como qualquer pessoa consegue criar conta via link mágico (é o comportamento padrão do Supabase Auth, não uma falha), "autenticado" não é o mesmo que "sou eu". Reescrevi a política pra travar por e-mail específico e o alerta sumiu. Documentar esse ajuste é mais honesto do que só mostrar a versão final como se tivesse saído certa de primeira.

### PWA em vez de app nativo

App mobile não precisou ser um app nativo (React Native, Flutter). Um web app responsivo, adicionável à tela inicial, entrega a mesma experiência de uso (abrir, lançar ação, visualizar lista) sem loja de aplicativo, sem processo de build, e reaproveitando a mesma stack HTML/CSS/JS do dashboard. Pra um app de uso pessoal e baixo volume, o custo de ir nativo não se paga.

### Login sem senha

Autenticação via link mágico (Supabase Auth, `signInWithOtp`) em vez de e-mail e senha. Elimina gestão de senha (reset, hash, política de complexidade) para um único usuário autorizado, e o Supabase já entrega o fluxo pronto.

### Sessão: por que voltei atrás da primeira decisão

Na primeira versão, a sessão de autenticação não era persistida em nenhum lugar do navegador, de propósito, para não deixar token gravado em disco. Na prática, isso forçava um link mágico novo a cada vez que a página era recarregada. O Supabase, no serviço de e-mail padrão do plano gratuito, limita o envio a **2 e-mails por hora** — testando o fluxo normalmente, essa cota estourou rápido, e um app que pede login a cada abertura não é utilizável no dia a dia.

Reescrevi a sessão para persistir em `localStorage`. Você loga uma vez e continua logado entre sessões de uso, e o limite de e-mail deixa de ser relevante porque o login deixa de ser um evento frequente.

## Trade-offs e limitações conhecidas

- **Um único e-mail autorizado, fixo na policy.** Funciona para uso pessoal. Escalar para mais de uma pessoa exigiria uma tabela de usuários/papéis em vez de um e-mail hardcoded na regra.
- **Serviço de e-mail padrão do Supabase (2 e-mails/hora).** Suficiente pra esse volume de uso. Um cenário multiusuário real precisaria de SMTP próprio (Resend, SendGrid) para não esbarrar nesse limite.
- **Sem suporte offline.** Os dois front-ends dependem de conexão ativa com o Supabase; não há cache local de dados.
- **Sessão em `localStorage`.** Em um dispositivo compartilhado, a sessão logada fica acessível até um logout manual.

## Resultado

- Schema com 8 colunas e constraints reais, tabela populada com 17 ações de exemplo
- Dashboard público consumindo a REST API do Supabase diretamente, sem backend próprio
- App privado com CRUD completo (criar, editar, excluir), autenticado por link mágico
- Um problema real de segurança (policy permissiva demais) identificado por ferramenta e corrigido antes de ir para produção
- Custo de infraestrutura: R$0/mês (Supabase free tier + GitHub Pages)

## Estrutura do repositório

- `revops-dashboard.html` — dashboard público, somente leitura
- `app-gestao.html` — app de gestão privado, CRUD autenticado
- `supabase-schema.sql` — schema completo do banco, incluindo a evolução das políticas de escrita

## Stack

Postgres (Supabase) · Row Level Security · Supabase Auth (magic link) · PostgREST · HTML/CSS/JS vanilla · GitHub Pages
