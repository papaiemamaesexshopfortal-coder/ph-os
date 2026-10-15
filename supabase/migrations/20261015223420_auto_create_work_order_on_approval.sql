create or replace function public.auto_create_work_order_on_approval()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  items_json jsonb;
  new_order_id uuid;
begin
  if new.status is distinct from 'approved'::public.quote_status
     or old.status = 'approved'::public.quote_status then
    return new;
  end if;

  if not exists (
    select 1 from public.quote_approvals a
    where a.company_id = new.company_id
      and a.quote_id = new.id
      and a.quote_version = new.current_version
      and a.outcome = 'approved'
      and a.accepted_conditions = true
  ) then
    raise exception 'recorded customer acceptance is required before creating a work order';
  end if;

  if exists (
    select 1 from public.work_orders w
    where w.quote_id = new.id and w.quote_version = new.current_version
  ) then
    return new;
  end if;

  select v.items into items_json
  from public.quote_versions v
  where v.company_id = new.company_id
    and v.quote_id = new.id
    and v.version = new.current_version;
  if not found then
    raise exception 'approved quote version was not found';
  end if;

  insert into public.work_orders(
    company_id, quote_id, quote_version, client_id, ticket_id,
    status, scheduled_at, activities, checklist
  ) values (
    new.company_id, new.id, new.current_version, new.client_id, new.ticket_id,
    'scheduled', null, coalesce(items_json, '[]'::jsonb),
    jsonb_build_array(
      jsonb_build_object('task', 'Confirmar escopo e acesso', 'done', false),
      jsonb_build_object('task', 'Registrar fotos antes do serviço', 'done', false),
      jsonb_build_object('task', 'Executar serviços aprovados', 'done', false),
      jsonb_build_object('task', 'Registrar fotos após o serviço', 'done', false),
      jsonb_build_object('task', 'Confirmar entrega com o cliente', 'done', false)
    )
  ) returning id into new_order_id;

  insert into public.audit_log(company_id, actor_id, entity_type, entity_id, action, details)
  values (
    new.company_id, auth.uid(), 'work_order', new_order_id,
    'automatically_created_from_approved_quote',
    jsonb_build_object('quote_id', new.id, 'version', new.current_version, 'approval_required', true)
  );
  return new;
end;
$$;

revoke all on function public.auto_create_work_order_on_approval() from public, anon, authenticated;
create unique index if not exists work_orders_quote_version_unique
  on public.work_orders(quote_id, quote_version);

drop trigger if exists quotes_auto_create_work_order on public.quotes;
create trigger quotes_auto_create_work_order
after update of status on public.quotes
for each row
when (new.status = 'approved'::public.quote_status and old.status is distinct from 'approved'::public.quote_status)
execute function public.auto_create_work_order_on_approval();

with approved_without_order as (
  select q.company_id, q.id as quote_id, q.current_version, q.client_id, q.ticket_id, v.items
  from public.quotes q
  join public.quote_versions v
    on v.company_id = q.company_id and v.quote_id = q.id and v.version = q.current_version
  where q.status = 'approved'
    and exists (
      select 1 from public.quote_approvals a
      where a.company_id = q.company_id and a.quote_id = q.id
        and a.quote_version = q.current_version and a.outcome = 'approved'
        and a.accepted_conditions = true
    )
    and not exists (
      select 1 from public.work_orders w
      where w.quote_id = q.id and w.quote_version = q.current_version
    )
), created as (
  insert into public.work_orders(
    company_id, quote_id, quote_version, client_id, ticket_id,
    status, scheduled_at, activities, checklist
  )
  select company_id, quote_id, current_version, client_id, ticket_id,
    'scheduled', null, coalesce(items, '[]'::jsonb),
    jsonb_build_array(
      jsonb_build_object('task', 'Confirmar escopo e acesso', 'done', false),
      jsonb_build_object('task', 'Registrar fotos antes do serviço', 'done', false),
      jsonb_build_object('task', 'Executar serviços aprovados', 'done', false),
      jsonb_build_object('task', 'Registrar fotos após o serviço', 'done', false),
      jsonb_build_object('task', 'Confirmar entrega com o cliente', 'done', false)
    )
  from approved_without_order
  returning id, company_id, quote_id, quote_version
)
insert into public.audit_log(company_id, actor_id, entity_type, entity_id, action, details)
select company_id, null, 'work_order', id, 'backfilled_from_approved_quote',
  jsonb_build_object('quote_id', quote_id, 'version', quote_version, 'approval_required', true)
from created;
