create or replace function public.create_contract_for_approved_quote(p_quote_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare q public.quotes%rowtype; v public.quote_versions%rowtype; c public.clients%rowtype; co public.companies%rowtype; new_id uuid; next_no bigint;
begin
  select * into q from public.quotes where id = p_quote_id for update;
  if not found or not public.is_company_member(q.company_id) then raise exception 'not authorized'; end if;
  if q.status <> 'approved' then raise exception 'only approved quotes can become contracts'; end if;
  if exists(select 1 from public.contracts where quote_id=q.id and quote_version=q.current_version) then raise exception 'contract already exists for this quote version'; end if;
  perform 1 from public.companies where id=q.company_id for update;
  select coalesce(max(contract_no)+1,1) into next_no from public.contracts where company_id=q.company_id;
  select * into v from public.quote_versions where quote_id=q.id and version=q.current_version;
  select * into c from public.clients where id=q.client_id and company_id=q.company_id;
  select * into co from public.companies where id=q.company_id;
  insert into public.contracts(company_id, quote_id, quote_version, contract_no, status, body)
  values (q.company_id, q.id, q.current_version, next_no, 'draft',
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

create or replace function public.create_work_order_from_contract(p_contract_id uuid,p_scheduled_at timestamptz default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare c public.contracts%rowtype; q public.quotes%rowtype; new_id uuid; next_no bigint;
begin
  select * into c from public.contracts where id=p_contract_id for update;
  if not found or not public.is_company_member(c.company_id) then raise exception 'not authorized'; end if;
  if c.status <> 'accepted' then raise exception 'contract acceptance must be recorded first'; end if;
  if exists(select 1 from public.work_orders where quote_id=c.quote_id and quote_version=c.quote_version) then raise exception 'work order already exists for this quote version'; end if;
  perform 1 from public.companies where id=c.company_id for update;
  select coalesce(max(order_no)+1,1) into next_no from public.work_orders where company_id=c.company_id;
  select * into q from public.quotes where id=c.quote_id and company_id=c.company_id;
  insert into public.work_orders(company_id,order_no,quote_id,quote_version,client_id,ticket_id,status,scheduled_at,activities,checklist)
  values(c.company_id,next_no,c.quote_id,c.quote_version,q.client_id,q.ticket_id,'scheduled'::public.work_order_status,
    p_scheduled_at,coalesce(c.body->'items','[]'::jsonb),
    jsonb_build_array(jsonb_build_object('task','Confirmar escopo e acesso','done',false),jsonb_build_object('task','Registrar fotos antes do serviço','done',false),jsonb_build_object('task','Executar serviços contratados','done',false),jsonb_build_object('task','Registrar fotos após o serviço','done',false),jsonb_build_object('task','Confirmar entrega com o cliente','done',false)))
  returning id into new_id;
  insert into public.audit_log(company_id,actor_id,entity_type,entity_id,action,details)
  values(c.company_id,auth.uid(),'work_order',new_id,'created_from_accepted_contract',jsonb_build_object('contract_id',c.id,'quote_id',c.quote_id,'version',c.quote_version));
  if q.ticket_id is not null then update public.tickets set status='scheduled' where id=q.ticket_id; end if;
  return new_id;
end;
$$;

revoke all on function public.create_contract_for_approved_quote(uuid) from public, anon;
grant execute on function public.create_contract_for_approved_quote(uuid) to authenticated;
revoke all on function public.create_work_order_from_contract(uuid,timestamptz) from public, anon;
grant execute on function public.create_work_order_from_contract(uuid,timestamptz) to authenticated;
