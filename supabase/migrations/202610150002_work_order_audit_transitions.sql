create or replace function public.set_work_order_status(
  p_work_order_id uuid,
  p_status public.work_order_status,
  p_extra_expenses numeric default 0,
  p_completion_notes text default null,
  p_extra_expenses_authorized boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare w public.work_orders%rowtype; next_ticket public.ticket_status;
begin
  select * into w from public.work_orders where id=p_work_order_id for update;
  if not found or not public.is_company_member(w.company_id) then raise exception 'not authorized'; end if;
  if p_extra_expenses is null or p_extra_expenses < 0 then raise exception 'extra expenses cannot be negative'; end if;
  if p_extra_expenses > 0 and p_extra_expenses_authorized is distinct from true then raise exception 'customer authorization is required for additional charges'; end if;
  if not ((w.status='scheduled' and p_status in ('in_progress','cancelled')) or (w.status='in_progress' and p_status='completed') or (w.status='completed' and p_status='closed')) then raise exception 'invalid work order status transition'; end if;
  if p_status = 'completed' and coalesce(length(btrim(p_completion_notes)),0) < 4 then raise exception 'add completion notes before finishing'; end if;
  if p_status = 'closed' and w.status <> 'completed' then raise exception 'only completed work orders can be closed'; end if;
  if p_status = 'cancelled' and w.status in ('completed','closed') then raise exception 'completed work orders cannot be cancelled'; end if;
  update public.work_orders set status=p_status,
    extra_expenses=case when p_extra_expenses > 0 then p_extra_expenses else extra_expenses end,
    completion_notes=case when p_completion_notes is not null then btrim(p_completion_notes) else completion_notes end
  where id=w.id;
  insert into public.audit_log(company_id,actor_id,entity_type,entity_id,action,details)
  values(w.company_id,auth.uid(),'work_order',w.id,
    case when p_status='completed' then 'work_order_completed' else 'status_changed' end,
    jsonb_build_object('from',w.status,'to',p_status,'extra_expenses',p_extra_expenses,'customer_authorized_extra_expenses',coalesce(p_extra_expenses_authorized,false),'completion_notes',p_completion_notes));
  next_ticket := case p_status when 'in_progress' then 'in_progress'::public.ticket_status when 'completed' then 'completed'::public.ticket_status when 'closed' then 'closed'::public.ticket_status else null end;
  if next_ticket is not null and w.ticket_id is not null then update public.tickets set status=next_ticket where id=w.ticket_id; end if;
end;
$$;

revoke all on function public.set_work_order_status(uuid,public.work_order_status,numeric,text,boolean) from public, anon;
grant execute on function public.set_work_order_status(uuid,public.work_order_status,numeric,text,boolean) to authenticated;
