-- ============================================================
-- Gestão de Ações — schema Supabase (Postgres)
-- Estado final, já com a evolução das policies de escrita.
-- ============================================================

create table if not exists acoes_revops (
  id uuid primary key default gen_random_uuid(),
  acao text not null,
  tipo_acao text not null check (tipo_acao in ('Estratégica', 'Rotina')),
  area_envolvida text not null,
  etapa text not null check (etapa in ('Backlog', 'Planejamento', 'Operação', 'Validação', 'Inteligência', 'Finalização')),
  status text not null check (status in ('Não iniciado', 'Em andamento', 'Parcial', 'Concluído')),
  pct_conclusao numeric(4,3) not null default 0 check (pct_conclusao between 0 and 1),
  data_finalizacao date,
  importancia_acao text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Mantém updated_at correto sem depender de a aplicação lembrar de setar.
-- search_path fixo por segurança (evita search_path hijacking em functions
-- SECURITY DEFINER; o linter de segurança do Supabase aponta isso).
create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_acoes_revops_updated_at on acoes_revops;
create trigger trg_acoes_revops_updated_at
  before update on acoes_revops
  for each row execute function set_updated_at();

alter table acoes_revops enable row level security;

-- Leitura pública: o dashboard precisa funcionar sem login.
create policy "Leitura pública"
  on acoes_revops for select
  using (true);

-- Escrita: só o dono, verificado pelo e-mail no JWT da sessão.
--
-- Versão anterior liberava insert/update/delete pra qualquer usuário
-- autenticado (to authenticated, using/with check (true)). Funcionava,
-- mas o linter de segurança do próprio Supabase (get_advisors) marcou
-- como "RLS Policy Always True": qualquer pessoa consegue criar conta
-- via link mágico (é o comportamento padrão do Supabase Auth), então
-- "autenticado" não era o mesmo que "sou eu". Substituí pela versão
-- abaixo, que trava por e-mail específico.
create policy "Inserir só o dono"
  on acoes_revops for insert
  to authenticated
  with check ((auth.jwt() ->> 'email') = 'seu-email@exemplo.com');

create policy "Atualizar só o dono"
  on acoes_revops for update
  to authenticated
  using ((auth.jwt() ->> 'email') = 'seu-email@exemplo.com')
  with check ((auth.jwt() ->> 'email') = 'seu-email@exemplo.com');

create policy "Excluir só o dono"
  on acoes_revops for delete
  to authenticated
  using ((auth.jwt() ->> 'email') = 'seu-email@exemplo.com');
