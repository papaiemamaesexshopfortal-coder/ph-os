create or replace function public.admin_record_quote_approval(
  p_quote_id uuid,
  p_customer_name text,
  p_evidence text
) returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  quote_row record;
  approval_id uuid;
  evidence_text text := btrim(coalesce(p_evidence, ''));
  customer_name text := btrim(coalesce(p_customer_name, ''));
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;
  if length(customer_name) < 2 or length(customer_name) > 160 then
    raise exception 'enter the name of the customer who accepted the quote';
  end if;
  if length(evidence_text) < 4 or length(evidence_text) > 500 then
    raise exception 'record how the customer confirmed acceptance';
  end if;

  select q.company_id, q.status, q.current_version, q.valid_until
    into quote_row
    from public.quotes q
    where q.id = p_quote_id
    for update;

  if not found then
    raise exception 'quote not found';
  end if;
  if not exists (
    select 1 from public.company_members m
    where m.company_id = quote_row.company_id
      and m.user_id = auth.uid()
      and m.role = 'admin'
  ) then
    raise exception 'only a company administrator can record a manual approval';
  end if;
  if quote_row.status not in ('draft', 'sent', 'change_requested') then
    raise exception 'quote cannot be manually approved from its current status';
  end if;
  if quote_row.valid_until is not null and quote_row.valid_until < current_date then
    raise exception 'quote validity has expired';
  end if;

  insert into public.quote_approvals(
    company_id, quote_id, quote_version, outcome, approver_name,
    accepted_conditions, viewed_at, decided_at, audit
  ) values (
    quote_row.company_id, p_quote_id, quote_row.current_version, 'approved', customer_name,
    true, null, now(), jsonb_build_object(
      'source', 'manual_by_company_admin',
      'customer_acceptance_confirmed', true,
      'portal_viewed', false,
      'evidence', left(evidence_text, 500),
      'admin_user_id', auth.uid()
    )
  ) returning id into approval_id;

  update public.quotes set status = 'approved' where id = p_quote_id;
  insert into public.audit_log(company_id, actor_id, entity_type, entity_id, action, details)
  values (
    quote_row.company_id, auth.uid(), 'quote', p_quote_id, 'manual_customer_approval_recorded',
    jsonb_build_object(
      'version', quote_row.current_version,
      'customer_name', customer_name,
      'evidence', left(evidence_text, 500),
      'approval_id', approval_id
    )
  );
  return approval_id;
end;
$$;

revoke all on function public.admin_record_quote_approval(uuid, text, text) from public, anon;
grant execute on function public.admin_record_quote_approval(uuid, text, text) to authenticated;
