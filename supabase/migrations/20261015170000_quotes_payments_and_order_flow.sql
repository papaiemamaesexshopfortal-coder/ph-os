alter table public.quote_versions
  add column if not exists payment_method text check (payment_method is null or payment_method in ('pix','cash','debit','credit','transfer','installment','entry_balance')),
  add column if not exists entry_amount numeric(12,2) not null default 0 check (entry_amount >= 0),
  add column if not exists installments_count integer not null default 1 check (installments_count > 0),
  add column if not exists card_fee_rate numeric(7,4) not null default 0 check (card_fee_rate >= 0 and card_fee_rate <= 100),
  add column if not exists card_fee_amount numeric(12,2) not null default 0 check (card_fee_amount >= 0);

create or replace function public.save_quote_version(
  p_company_id uuid, p_quote_id uuid, p_client_id uuid, p_valid_until date,
  p_description text, p_service_address jsonb, p_items jsonb,
  p_additions numeric, p_expenses numeric, p_discount numeric,
  p_duration text, p_payment_terms text, p_warranty text, p_notes text,
  p_payment_method text, p_entry_amount numeric, p_installments_count integer,
  p_card_fee_rate numeric
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  qid uuid := p_quote_id; next_version integer; v_sub numeric(12,2) := 0;
  v_base numeric(12,2); v_fee numeric(12,2); v_total numeric(12,2); it jsonb;
begin
  if not public.is_company_member(p_company_id) then raise exception 'not authorized'; end if;
  if p_client_id is null or not exists(select 1 from public.clients c where c.id=p_client_id and c.company_id=p_company_id) then raise exception 'invalid client'; end if;
  if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'at least one item is required'; end if;
  if p_payment_method not in ('pix','cash','debit','credit','transfer','installment','entry_balance') then raise exception 'invalid payment method'; end if;
  if coalesce(p_entry_amount,0)<0 or coalesce(p_installments_count,0)<1 or coalesce(p_card_fee_rate,0)<0 or coalesce(p_card_fee_rate,0)>100 then raise exception 'invalid payment conditions'; end if;
  for it in select value from jsonb_array_elements(p_items) loop
    if coalesce((it->>'quantity')::numeric,0)<=0 or coalesce((it->>'unit_price')::numeric,0)<0 then raise exception 'invalid item amount'; end if;
    v_sub:=v_sub+round((it->>'quantity')::numeric*(it->>'unit_price')::numeric,2);
  end loop;
  v_sub:=round(v_sub,2);
  p_additions:=round(coalesce(p_additions,0),2); p_expenses:=round(coalesce(p_expenses,0),2); p_discount:=round(coalesce(p_discount,0),2);
  if p_additions<0 or p_expenses<0 or p_discount<0 then raise exception 'amounts cannot be negative'; end if;
  v_base:=round(v_sub+p_additions+p_expenses-p_discount,2);
  if v_base<0 then raise exception 'discount exceeds quote amount'; end if;
  v_fee:=case when p_payment_method in ('debit','credit','installment') then round(v_base*coalesce(p_card_fee_rate,0)/100,2) else 0 end;
  v_total:=round(v_base+v_fee,2);
  if coalesce(p_entry_amount,0)>v_total then raise exception 'entry amount exceeds total'; end if;
  if qid is null then
    insert into public.quotes(company_id,client_id,valid_until) values(p_company_id,p_client_id,p_valid_until) returning id,current_version into qid,next_version;
  else
    select current_version+1 into next_version from public.quotes where id=qid and company_id=p_company_id for update;
    if not found then raise exception 'quote not found'; end if;
    update public.quotes set client_id=p_client_id,valid_until=p_valid_until,current_version=next_version,status='draft' where id=qid;
  end if;
  insert into public.quote_versions(company_id,quote_id,version,description,service_address,items,subtotal,additions,expenses,discount,total,estimated_duration,payment_terms,warranty,notes,payment_method,entry_amount,installments_count,card_fee_rate,card_fee_amount)
  values(p_company_id,qid,next_version,coalesce(p_description,''),coalesce(p_service_address,'{}'),p_items,v_sub,p_additions,p_expenses,p_discount,v_total,p_duration,p_payment_terms,p_warranty,p_notes,p_payment_method,coalesce(p_entry_amount,0),p_installments_count,coalesce(p_card_fee_rate,0),v_fee);
  insert into public.audit_log(company_id,entity_type,entity_id,action,details)
  values(p_company_id,'quote',qid,case when next_version=1 then 'created' else 'new_version_created' end,jsonb_build_object('version',next_version,'total',v_total,'payment_method',p_payment_method,'card_fee_amount',v_fee));
  return qid;
end $$;
revoke all on function public.save_quote_version(uuid,uuid,uuid,date,text,jsonb,jsonb,numeric,numeric,numeric,text,text,text,text,text,numeric,integer,numeric) from public, anon;
grant execute on function public.save_quote_version(uuid,uuid,uuid,date,text,jsonb,jsonb,numeric,numeric,numeric,text,text,text,text,text,numeric,integer,numeric) to authenticated;

create or replace function public.create_work_order_from_approved_quote(p_quote_id uuid,p_scheduled_at timestamptz default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare q public.quotes%rowtype; new_id uuid; v_items jsonb;
begin
  select * into q from public.quotes where id=p_quote_id for update;
  if not found or not public.is_company_member(q.company_id) then raise exception 'not authorized'; end if;
  if q.status<>'approved' then raise exception 'customer approval is required before creating a work order'; end if;
  if exists(select 1 from public.work_orders where quote_id=q.id and quote_version=q.current_version) then raise exception 'work order already exists for this approved quote version'; end if;
  select items into v_items from public.quote_versions where quote_id=q.id and version=q.current_version;
  insert into public.work_orders(company_id,quote_id,quote_version,client_id,ticket_id,status,scheduled_at,activities,checklist)
  values(q.company_id,q.id,q.current_version,q.client_id,q.ticket_id,'scheduled',p_scheduled_at,v_items,
    jsonb_build_array(jsonb_build_object('task','Confirmar escopo e acesso','done',false),jsonb_build_object('task','Registrar fotos antes do serviço','done',false),jsonb_build_object('task','Executar serviços aprovados','done',false),jsonb_build_object('task','Registrar fotos após o serviço','done',false),jsonb_build_object('task','Confirmar entrega com o cliente','done',false))) returning id into new_id;
  insert into public.audit_log(company_id,actor_id,entity_type,entity_id,action,details)
  values(q.company_id,auth.uid(),'work_order',new_id,'created_from_approved_quote',jsonb_build_object('quote_id',q.id,'version',q.current_version));
  return new_id;
end $$;
revoke all on function public.create_work_order_from_approved_quote(uuid,timestamptz) from public, anon;
grant execute on function public.create_work_order_from_approved_quote(uuid,timestamptz) to authenticated;

create or replace function public.get_public_quote(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare l public.quote_approval_links%rowtype; result jsonb;
begin
  if p_token is null or length(p_token)<64 or length(p_token)>256 then raise exception 'invalid or expired link'; end if;
  select * into l from public.quote_approval_links where token_hash=encode(extensions.digest(convert_to(p_token,'UTF8'),'sha256'),'hex') for update;
  if not found or l.consumed_at is not null or l.expires_at<=now() then raise exception 'invalid or expired link'; end if;
  update public.quote_approval_links set viewed_at=coalesce(viewed_at,now()) where id=l.id returning * into l;
  select jsonb_build_object('quote_id',q.id,'quote_no',q.quote_no,'version',l.quote_version,'valid_until',q.valid_until,'status',q.status,
    'description',v.description,'service_address',v.service_address,'items',v.items,'subtotal',v.subtotal,'additions',v.additions,'expenses',v.expenses,
    'discount',v.discount,'total',v.total,'estimated_duration',v.estimated_duration,'payment_terms',v.payment_terms,'payment_method',v.payment_method,
    'entry_amount',v.entry_amount,'installments_count',v.installments_count,'card_fee_rate',v.card_fee_rate,'card_fee_amount',v.card_fee_amount,
    'warranty',v.warranty,'notes',v.notes,'client_name',c.name,'company_name',co.name,'company_phone',co.phone,'expires_at',l.expires_at) into result
  from public.quotes q join public.quote_versions v on v.quote_id=l.quote_id and v.version=l.quote_version
  join public.clients c on c.id=q.client_id and c.company_id=q.company_id join public.companies co on co.id=q.company_id
  where q.id=l.quote_id and q.company_id=l.company_id and q.status='sent' and (q.valid_until is null or q.valid_until>=current_date);
  if result is null then raise exception 'invalid or expired link'; end if;
  return result;
end $$;
revoke all on function public.get_public_quote(text) from public, authenticated;
grant execute on function public.get_public_quote(text) to anon;
