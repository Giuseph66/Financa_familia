-- =============================================================
-- 0001 — Fundação: extensões, sequência de sync, funções auxiliares
-- =============================================================
-- Nada de tabela de domínio aqui. Só o que todo o resto precisa.

create extension if not exists pgcrypto;

-- -------------------------------------------------------------
-- Sequência global de versão de sync
-- -------------------------------------------------------------
-- Toda escrita em tabela sincronizável consome um número desta
-- sequência. Serve como desempate estável de ordenação quando duas
-- linhas têm o mesmo updated_at (o que acontece sempre que várias
-- linhas são gravadas na mesma transação, já que now() é constante
-- dentro da transação).
create sequence if not exists public.sync_version_seq as bigint;

-- Sem este grant, TODA inserção vinda do aplicativo falha com
-- "permission denied for sequence sync_version_seq".
--
-- O motivo é sutil: o trigger touch_row() chama nextval(), e trigger
-- comum roda com os privilégios de quem disparou — o papel
-- `authenticated` — e não do dono da tabela. A coluna sync_version
-- também tem nextval() como DEFAULT, com o mesmo efeito.
--
-- O Supabase configura ALTER DEFAULT PRIVILEGES para sequências, então
-- na prática costuma funcionar sem isto. Não dependa: é uma linha, e o
-- erro que ela evita aparece só em runtime, no primeiro lançamento que
-- o usuário tentar salvar.
grant usage, select on sequence public.sync_version_seq to authenticated;

-- -------------------------------------------------------------
-- touch_row() — carimba created_at / updated_at / sync_version
-- -------------------------------------------------------------
-- O cliente NUNCA escreve updated_at. Relógio de celular erra, muda
-- com fuso e pode ser ajustado à mão; se o cliente controlasse esse
-- campo, um relógio adiantado venceria toda disputa de conflito para
-- sempre. Aqui o horário é sempre o do servidor.
create or replace function public.touch_row()
returns trigger
language plpgsql
as $$
begin
  new.updated_at   := now();
  new.sync_version := nextval('public.sync_version_seq');

  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
  else
    -- created_at é imutável: ignora qualquer tentativa de alterá-lo
    new.created_at := old.created_at;
  end if;

  return new;
end;
$$;

-- -------------------------------------------------------------
-- try_uuid() — cast defensivo, usado nas políticas de Storage
-- -------------------------------------------------------------
-- O nome do objeto no Storage é controlado pelo cliente. Um cast
-- direto `texto::uuid` sobre lixo derruba a avaliação da política
-- com erro em vez de simplesmente negar. Aqui, lixo vira NULL, e
-- is_household_member(NULL) devolve false.
create or replace function public.try_uuid(t text)
returns uuid
language plpgsql
immutable
as $$
begin
  return t::uuid;
exception when others then
  return null;
end;
$$;

-- -------------------------------------------------------------
-- unaccent_simple() — normalização de nome de estabelecimento
-- -------------------------------------------------------------
-- Não usa a extensão `unaccent` porque ela não é IMMUTABLE por
-- padrão, o que impede seu uso em índice. Translate cobre o
-- português inteiro e é immutable de verdade.
create or replace function public.normalize_name(t text)
returns text
language sql
immutable
as $$
  select nullif(
    trim(regexp_replace(
      lower(translate(
        coalesce(t, ''),
        'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ',
        'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN'
      )),
      '[^a-z0-9]+', ' ', 'g'
    )),
    ''
  );
$$;

-- -------------------------------------------------------------
-- attach_sync_triggers() — aplica touch_row em lote
-- -------------------------------------------------------------
-- Chamada ao fim de cada migration que cria tabelas sincronizáveis.
-- Evita 15 blocos CREATE TRIGGER idênticos e garante que nenhuma
-- tabela nova fique sem o carimbo por esquecimento.
-- NOTA DE SINTAXE: nada de format('%1$s') aqui dentro. Dentro de um
-- corpo delimitado por $$, a sequência `$s` faz o parser procurar um
-- fechamento de dollar-quote e o resultado é imprevisível. Use sempre
-- %s/%I posicionais simples, repetindo o argumento.
create or replace function public.attach_sync_triggers(p_tables text[])
returns void
language plpgsql
as $$
declare
  t text;
begin
  foreach t in array p_tables loop
    execute format('drop trigger if exists trg_touch_%s on public.%I', t, t);
    execute format(
      'create trigger trg_touch_%s before insert or update on public.%I '
      'for each row execute function public.touch_row()', t, t);
  end loop;
end;
$$;
