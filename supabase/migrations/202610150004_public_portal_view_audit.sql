alter table public.quote_approval_links add column if not exists viewed_at timestamptz;

create or replace function public.get_public_quote(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare l public.quote_approval_links%rowtype; result jsonb;
begin
  if p_token is null or length(p_token) < 64 or length(p_token) > 256 then raise exception 'invalid or expired link'; end if;
  select * into l from public.quote_approval_links
   where token_hash=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex')
   for update;
  if not found or l.consumed_at is not null or l.expires_at <= now() then raise exception 'invalid or expired link'; end if;
  update public.quote_approval_links set viewed_at=coalesce(viewed_at,now()) where id=l.id returning * into l;
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
  from public.quotes q
  join public.quote_versions v on v.quote_id=l.quote_id and v.version=l.quote_version
  join public.clients c on c.id=q.client_id and c.company_id=q.company_id
  join public.companies co on co.id=q.company_id
  where q.id=l.quote_id and q.company_id=l.company_id and q.status='sent'
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
declare l public.quote_approval_links%rowtype; q public.quotes%rowtype;
begin
  if p_token is null or length(p_token) < 64 or length(p_token) > 256 then raise exception 'invalid or expired link'; end if;
  if p_outcome not in ('approved', 'declined', 'change_requested') then raise exception 'invalid decision'; end if;
  if coalesce(length(btrim(p_approver_name)),0)<2 or length(p_approver_name)>160 then raise exception 'enter the approver name'; end if;
  if p_outcome='approved' and p_accepted_conditions is distinct from true then raise exception 'conditions must be accepted'; end if;
  select * into l from public.quote_approval_links
   where token_hash=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex')
   for update;
  if not found or l.consumed_at is not null or l.expires_at<=now() or l.viewed_at is null then raise exception 'invalid, unviewed, or expired link'; end if;
  select * into q from public.quotes where id=l.quote_id and company_id=l.company_id for update;
  if not found or q.status<>'sent' or q.current_version<>l.quote_version or (q.valid_until is not null and q.valid_until<current_date) then raise exception 'quote is no longer available'; end if;
  update public.quote_approval_links set consumed_at=now() where id=l.id;
  insert into public.quote_approvals(company_id,quote_id,quote_version,outcome,approver_name,accepted_conditions,viewed_at,decided_at,audit)
  values(l.company_id,l.quote_id,l.quote_version,p_outcome,btrim(p_approver_name),coalesce(p_accepted_conditions,false),l.viewed_at,now(),
    jsonb_build_object('user_agent',left(coalesce(p_audit->>'user_agent',''),300),'language',left(coalesce(p_audit->>'language',''),20)));
  update public.quotes set status=p_outcome::public.quote_status where id=q.id;
  if q.ticket_id is not null then
    update public.tickets set status=case p_outcome when 'approved' then 'approved'::public.ticket_status when 'declined' then 'quote_declined'::public.ticket_status else 'awaiting_quote'::public.ticket_status end where id=q.ticket_id;
  end if;
  insert into public.audit_log(company_id,entity_type,entity_id,action,details)
  values(l.company_id,'quote',l.quote_id,'customer_decision',jsonb_build_object('version',l.quote_version,'outcome',p_outcome,'approver_name',btrim(p_approver_name),'accepted_conditions',coalesce(p_accepted_conditions,false),'viewed_at',l.viewed_at,'user_agent',left(coalesce(p_audit->>'user_agent',''),300)));
  return jsonb_build_object('outcome',p_outcome,'quote_no',q.quote_no,'version',l.quote_version);
end;
$$;

revoke all on function public.get_public_quote(text) from public, authenticated;
grant execute on function public.get_public_quote(text) to anon;
revoke all on function public.submit_public_quote_decision(text,text,text,boolean,jsonb) from public, authenticated;
grant execute on function public.submit_public_quote_decision(text,text,text,boolean,jsonb) to anon;
