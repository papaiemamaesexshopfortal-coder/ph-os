create table if not exists public.quote_approval_links (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  quote_id uuid not null references public.quotes(id) on delete cascade,
  quote_version integer not null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  foreign key (quote_id, quote_version) references public.quote_versions(quote_id, version)
);

create index if not exists quote_approval_links_active_idx
  on public.quote_approval_links (quote_id, expires_at desc)
  where consumed_at is null;

alter table public.quote_approval_links enable row level security;
create policy quote_approval_links_company_read on public.quote_approval_links
  for select to authenticated using (public.is_company_member(company_id));
revoke insert, update, delete, truncate, references, trigger on public.quote_approval_links from anon, authenticated;
grant select on public.quote_approval_links to authenticated;

create or replace function public.issue_quote_approval_link(p_quote_id uuid, p_days integer default 14)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare q public.quotes%rowtype; token text; v_company uuid;
begin
  select * into q from public.quotes where id = p_quote_id for update;
  if not found or not public.is_company_member(q.company_id) then raise exception 'not authorized'; end if;
  if q.status not in ('draft', 'change_requested', 'sent') then raise exception 'quote is not available for approval'; end if;
  if q.valid_until is not null and q.valid_until < current_date then raise exception 'quote has expired'; end if;
  if p_days < 1 or p_days > 30 then raise exception 'link duration must be between 1 and 30 days'; end if;
  v_company := q.company_id;
  token := replace(gen_random_uuid()::text || gen_random_uuid()::text || gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  update public.quote_approval_links set consumed_at = now() where quote_id = q.id and consumed_at is null;
  insert into public.quote_approval_links(company_id, quote_id, quote_version, token_hash, expires_at, created_by)
  values (q.company_id, q.id, q.current_version, encode(extensions.digest(convert_to(token, 'UTF8'), 'sha256'), 'hex'), now() + make_interval(days => p_days), auth.uid());
  update public.quotes set status = 'sent' where id = q.id;
  if q.ticket_id is not null then update public.tickets set status = 'awaiting_approval' where id = q.ticket_id; end if;
  insert into public.audit_log(company_id, actor_id, entity_type, entity_id, action, details)
  values (v_company, auth.uid(), 'quote', q.id, 'approval_link_issued', jsonb_build_object('version', q.current_version, 'expires_in_days', p_days));
  return token;
end;
$$;

create or replace function public.get_public_quote(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare result jsonb;
begin
  if p_token is null or length(p_token) < 64 or length(p_token) > 256 then raise exception 'invalid or expired link'; end if;
  select jsonb_build_object(
    'quote_id', q.id, 'quote_no', q.quote_no, 'version', l.quote_version,
    'valid_until', q.valid_until, 'status', q.status,
    'description', v.description, 'service_address', v.service_address, 'items', v.items,
    'subtotal', v.subtotal, 'additions', v.additions, 'expenses', v.expenses,
    'discount', v.discount, 'total', v.total, 'estimated_duration', v.estimated_duration,
    'payment_terms', v.payment_terms, 'warranty', v.warranty, 'notes', v.notes,
    'client_name', c.name, 'company_name', co.name, 'company_phone', co.phone,
    'expires_at', l.expires_at
  ) into result
  from public.quote_approval_links l
  join public.quotes q on q.id = l.quote_id and q.company_id = l.company_id
  join public.quote_versions v on v.quote_id = l.quote_id and v.version = l.quote_version
  join public.clients c on c.id = q.client_id and c.company_id = q.company_id
  join public.companies co on co.id = q.company_id
  where l.token_hash = encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex')
    and l.consumed_at is null and l.expires_at > now() and q.status = 'sent'
    and (q.valid_until is null or q.valid_until >= current_date);
  if result is null then raise exception 'invalid or expired link'; end if;
  return result;
end;
$$;

create or replace function public.submit_public_quote_decision(
  p_token text, p_approver_name text, p_outcome text, p_accepted_conditions boolean, p_audit jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare l public.quote_approval_links%rowtype; q public.quotes%rowtype; result jsonb;
begin
  if p_token is null or length(p_token) < 64 or length(p_token) > 256 then raise exception 'invalid or expired link'; end if;
  if p_outcome not in ('approved', 'declined', 'change_requested') then raise exception 'invalid decision'; end if;
  if coalesce(length(btrim(p_approver_name)), 0) < 2 or length(btrim(p_approver_name)) > 160 then raise exception 'enter the approver name'; end if;
  if p_outcome = 'approved' and p_accepted_conditions is distinct from true then raise exception 'conditions must be accepted'; end if;
  select * into l from public.quote_approval_links
   where token_hash = encode(extensions.digest(convert_to(p_token, 'UTF8'), 'sha256'), 'hex')
   for update;
  if not found or l.consumed_at is not null or l.expires_at <= now() then raise exception 'invalid or expired link'; end if;
  select * into q from public.quotes where id = l.quote_id and company_id = l.company_id for update;
  if not found or q.status <> 'sent' or q.current_version <> l.quote_version or (q.valid_until is not null and q.valid_until < current_date) then raise exception 'quote is no longer available'; end if;
  update public.quote_approval_links set consumed_at = now() where id = l.id;
  insert into public.quote_approvals(company_id, quote_id, quote_version, outcome, approver_name, accepted_conditions, viewed_at, decided_at, audit)
  values (l.company_id, l.quote_id, l.quote_version, p_outcome, btrim(p_approver_name), coalesce(p_accepted_conditions, false), now(), now(), coalesce(p_audit, '{}'::jsonb));
  update public.quotes set status = p_outcome::public.quote_status where id = q.id;
  if q.ticket_id is not null then
    update public.tickets set status = case p_outcome when 'approved' then 'approved'::public.ticket_status when 'declined' then 'quote_declined'::public.ticket_status else 'awaiting_quote'::public.ticket_status end where id = q.ticket_id;
  end if;
  insert into public.audit_log(company_id, entity_type, entity_id, action, details)
  values (l.company_id, 'quote', l.quote_id, 'customer_decision', jsonb_build_object('version', l.quote_version, 'outcome', p_outcome, 'approver_name', btrim(p_approver_name), 'accepted_conditions', coalesce(p_accepted_conditions, false), 'audit', coalesce(p_audit, '{}'::jsonb)));
  result := jsonb_build_object('outcome', p_outcome, 'quote_no', q.quote_no, 'version', l.quote_version);
  return result;
end;
$$;

create or replace function public.create_contract_for_approved_quote(p_quote_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare q public.quotes%rowtype; v public.quote_versions%rowtype; c public.clients%rowtype; co public.companies%rowtype; new_id uuid;
begin
  select * into q from public.quotes where id = p_quote_id for update;
  if not found or not public.is_company_member(q.company_id) then raise exception 'not authorized'; end if;
  if q.status <> 'approved' then raise exception 'only approved quotes can become contracts'; end if;
  if exists(select 1 from public.contracts where quote_id=q.id and quote_version=q.current_version) then raise exception 'contract already exists for this quote version'; end if;
  select * into v from public.quote_versions where quote_id=q.id and version=q.current_version;
  select * into c from public.clients where id=q.client_id and company_id=q.company_id;
  select * into co from public.companies where id=q.company_id;
  insert into public.contracts(company_id, quote_id, quote_version, contract_no, status, body)
  values (q.company_id, q.id, q.current_version,
    coalesce((select max(contract_no)+1 from public.contracts where company_id=q.company_id),1), 'draft',
    jsonb_build_object('company', jsonb_build_object('name',co.name,'legal_id',co.legal_id,'phone',co.phone,'address',co.address),
      'client', jsonb_build_object('name',c.name,'client_type',c.client_type,'document',c.document,'email',c.email,'phone',c.phone,'address',c.address),
      'quote_no',q.quote_no,'quote_version',q.current_version,'object',v.description,'service_address',v.service_address,
      'items',v.items,'subtotal',v.subtotal,'additions',v.additions,'expenses',v.expenses,'discount',v.discount,'total',v.total,
      'estimated_duration',v.estimated_duration,'payment_terms',v.payment_terms,'warranty',v.warranty,'notes',v.notes,
      'terms',jsonb_build_array('O prestador executará os serviços conforme o escopo descrito neste instrumento.','O contratante fornecerá acesso ao local e as informações necessárias para a execução.','Materiais e despesas seguem exclusivamente o que estiver discriminado no orçamento aprovado.','Reagendamentos devem ser combinados entre as partes.','Serviços adicionais dependem de autorização prévia do contratante.','A garantia aplicável é a indicada no orçamento aprovado, respeitados os direitos previstos na legislação.','O contrato será encerrado após a execução e a quitação dos valores acordados.'))
  ) returning id into new_id;
  insert into public.audit_log(company_id,actor_id,entity_type,entity_id,action,details)
  values(q.company_id,auth.uid(),'contract',new_id,'created_from_approved_quote',jsonb_build_object('quote_id',q.id,'version',q.current_version));
  return new_id;
end;
$$;

create or replace function public.record_contract_acceptance(p_contract_id uuid,p_accepted_by text,p_acknowledged boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare c public.contracts%rowtype;
begin
  select * into c from public.contracts where id=p_contract_id for update;
  if not found or not public.is_company_member(c.company_id) then raise exception 'not authorized'; end if;
  if p_acknowledged is distinct from true or coalesce(length(btrim(p_accepted_by)),0)<2 then raise exception 'confirm customer acceptance and enter their name'; end if;
  if c.status not in ('draft','sent') then raise exception 'contract is not awaiting acceptance'; end if;
  update public.contracts set status='accepted',accepted_by=btrim(p_accepted_by),accepted_at=now() where id=c.id;
  insert into public.audit_log(company_id,actor_id,entity_type,entity_id,action,details)
  values(c.company_id,auth.uid(),'contract',c.id,'customer_acceptance_recorded_by_company',jsonb_build_object('accepted_by',btrim(p_accepted_by),'note','Recorded by an authenticated company member; not a qualified digital signature.'));
end;
$$;

create or replace function public.create_work_order_from_contract(p_contract_id uuid,p_scheduled_at timestamptz default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare c public.contracts%rowtype; q public.quotes%rowtype; new_id uuid;
begin
  select * into c from public.contracts where id=p_contract_id for update;
  if not found or not public.is_company_member(c.company_id) then raise exception 'not authorized'; end if;
  if c.status <> 'accepted' then raise exception 'contract acceptance must be recorded first'; end if;
  if exists(select 1 from public.work_orders where quote_id=c.quote_id and quote_version=c.quote_version) then raise exception 'work order already exists for this quote version'; end if;
  select * into q from public.quotes where id=c.quote_id and company_id=c.company_id;
  insert into public.work_orders(company_id,quote_id,quote_version,client_id,ticket_id,status,scheduled_at,activities,checklist)
  values(c.company_id,c.quote_id,c.quote_version,q.client_id,q.ticket_id,
    case when p_scheduled_at is null then 'scheduled'::public.work_order_status else 'scheduled'::public.work_order_status end,
    p_scheduled_at,coalesce(c.body->'items','[]'::jsonb),
    jsonb_build_array(jsonb_build_object('task','Confirmar escopo e acesso','done',false),jsonb_build_object('task','Registrar fotos antes do serviço','done',false),jsonb_build_object('task','Executar serviços contratados','done',false),jsonb_build_object('task','Registrar fotos após o serviço','done',false),jsonb_build_object('task','Confirmar entrega com o cliente','done',false)))
  returning id into new_id;
  insert into public.audit_log(company_id,actor_id,entity_type,entity_id,action,details)
  values(c.company_id,auth.uid(),'work_order',new_id,'created_from_accepted_contract',jsonb_build_object('contract_id',c.id,'quote_id',c.quote_id,'version',c.quote_version));
  if q.ticket_id is not null then update public.tickets set status='scheduled' where id=q.ticket_id; end if;
  return new_id;
end;
$$;

revoke all on function public.issue_quote_approval_link(uuid,integer) from public, anon;
grant execute on function public.issue_quote_approval_link(uuid,integer) to authenticated;
revoke all on function public.get_public_quote(text) from public, authenticated;
grant execute on function public.get_public_quote(text) to anon;
revoke all on function public.submit_public_quote_decision(text,text,text,boolean,jsonb) from public, authenticated;
grant execute on function public.submit_public_quote_decision(text,text,text,boolean,jsonb) to anon;
revoke all on function public.create_contract_for_approved_quote(uuid) from public, anon;
grant execute on function public.create_contract_for_approved_quote(uuid) to authenticated;
revoke all on function public.record_contract_acceptance(uuid,text,boolean) from public, anon;
grant execute on function public.record_contract_acceptance(uuid,text,boolean) to authenticated;
revoke all on function public.create_work_order_from_contract(uuid,timestamptz) from public, anon;
grant execute on function public.create_work_order_from_contract(uuid,timestamptz) to authenticated;
