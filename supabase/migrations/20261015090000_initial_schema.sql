-- PH SERVICE FORTAL: initial schema. Apply only to a dedicated Supabase project.
create extension if not exists pgcrypto with schema extensions;
create type public.ticket_status as enum ('open','review','awaiting_quote','quote_sent','awaiting_approval','approved','scheduled','in_progress','completed','closed','cancelled','quote_declined','awaiting_payment');
create type public.quote_status as enum ('draft','sent','approved','declined','change_requested','expired','cancelled');
create type public.work_order_status as enum ('scheduled','in_progress','completed','closed','cancelled');

create table public.companies (
  id uuid primary key default gen_random_uuid(), name text not null default 'PH SERVICE FORTAL', phone text, whatsapp_url text default 'https://wa.me/558699490316', website text default 'https://ph-service-fortal.vercel.app/', review_url text default 'https://g.page/r/CQPH4XoL5ddeEBM/review', legal_id text, address jsonb not null default '{}'::jsonb, pix_key text, bank_details jsonb not null default '{}'::jsonb, logo_path text, created_at timestamptz not null default now()
);
create table public.company_members (
  company_id uuid not null references public.companies(id) on delete cascade, user_id uuid not null references auth.users(id) on delete cascade, role text not null default 'admin' check (role in ('admin','staff','technician','finance')), created_at timestamptz not null default now(), primary key(company_id,user_id)
);
create function public.is_company_member(p_company_id uuid) returns boolean language sql stable security invoker set search_path = '' as $$ select exists(select 1 from public.company_members m where m.company_id=p_company_id and m.user_id=(select auth.uid())) $$;

create table public.service_categories (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, name text not null, active boolean not null default true, sort_order int not null default 0, created_at timestamptz not null default now(), unique(company_id,name));
create table public.services (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, category_id uuid references public.service_categories on delete set null, code text, name text not null, description text not null default '', unit text not null default 'service' check(unit in ('service','hour','day','meter','unit','quantity')), standard_price numeric(12,2) check(standard_price is null or standard_price>=0), estimated_cost numeric(12,2) check(estimated_cost is null or estimated_cost>=0), estimated_duration text, materials text, notes text, warranty text, active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.clients (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, client_type text not null default 'person' check(client_type in ('person','business')), name text not null, document text, phone text, email text, address jsonb not null default '{}'::jsonb, service_address jsonb not null default '{}'::jsonb, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create unique index clients_document_unique on public.clients(company_id, regexp_replace(document, '\D','','g')) where document is not null and document<>'';
create index clients_search_idx on public.clients(company_id,lower(name));
create table public.tickets (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, ticket_no bigint generated always as identity, client_id uuid not null references public.clients, service_id uuid references public.services on delete set null, summary text not null, description text not null default '', address jsonb not null default '{}'::jsonb, priority text not null default 'normal' check(priority in ('low','normal','high','urgent')), status public.ticket_status not null default 'open', desired_at timestamptz, assigned_to uuid references auth.users on delete set null, created_by uuid not null default auth.uid() references auth.users, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(company_id,ticket_no));
create table public.ticket_events (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, ticket_id uuid not null references public.tickets on delete cascade, from_status public.ticket_status, to_status public.ticket_status not null, note text, actor_id uuid default auth.uid() references auth.users, created_at timestamptz not null default now());
create table public.quotes (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, quote_no bigint generated always as identity, client_id uuid not null references public.clients, ticket_id uuid references public.tickets on delete set null, status public.quote_status not null default 'draft', current_version int not null default 1 check(current_version>0), valid_until date, created_by uuid not null default auth.uid() references auth.users, created_at timestamptz not null default now(), unique(company_id,quote_no));
create table public.quote_versions (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, quote_id uuid not null references public.quotes on delete cascade, version int not null check(version>0), description text not null default '', service_address jsonb not null default '{}'::jsonb, items jsonb not null default '[]'::jsonb, subtotal numeric(12,2) not null check(subtotal>=0), additions numeric(12,2) not null default 0 check(additions>=0), expenses numeric(12,2) not null default 0 check(expenses>=0), discount numeric(12,2) not null default 0 check(discount>=0), total numeric(12,2) not null check(total>=0), estimated_duration text, payment_terms text, warranty text, notes text, created_by uuid not null default auth.uid() references auth.users, created_at timestamptz not null default now(), unique(quote_id,version));
create table public.quote_approvals (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, quote_id uuid not null references public.quotes on delete cascade, quote_version int not null, outcome text not null check(outcome in ('approved','declined','change_requested')), approver_name text not null, accepted_conditions boolean not null default false, viewed_at timestamptz, decided_at timestamptz not null default now(), audit jsonb not null default '{}'::jsonb);
create table public.contracts (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, quote_id uuid not null references public.quotes, quote_version int not null, contract_no bigint generated always as identity, status text not null default 'draft' check(status in ('draft','sent','accepted','archived','amendment')), body jsonb not null default '{}'::jsonb, accepted_by text, accepted_at timestamptz, created_at timestamptz not null default now(), unique(company_id,contract_no));
create table public.work_orders (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, order_no bigint generated always as identity, quote_id uuid not null references public.quotes, quote_version int not null, client_id uuid not null references public.clients, ticket_id uuid references public.tickets, status public.work_order_status not null default 'scheduled', scheduled_at timestamptz, assigned_to uuid references auth.users, activities jsonb not null default '[]'::jsonb, checklist jsonb not null default '[]'::jsonb, before_photos text[] not null default '{}', after_photos text[] not null default '{}', extra_expenses numeric(12,2) not null default 0 check(extra_expenses>=0), completion_notes text, customer_accepted_at timestamptz, created_at timestamptz not null default now());
create table public.payments (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, client_id uuid not null references public.clients, quote_id uuid references public.quotes, work_order_id uuid references public.work_orders, amount numeric(12,2) not null check(amount>0), method text not null check(method in ('pix','cash','debit','credit','transfer','installment','other')), status text not null default 'received' check(status in ('received','pending','refunded','cancelled')), paid_at timestamptz, due_at date, receipt_path text, notes text, created_at timestamptz not null default now());
create table public.attachments (id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies on delete cascade, entity_type text not null, entity_id uuid not null, storage_path text not null, file_name text not null, content_type text, created_by uuid not null default auth.uid() references auth.users, created_at timestamptz not null default now());
create table public.audit_log (id bigint generated always as identity primary key, company_id uuid not null references public.companies on delete cascade, actor_id uuid default auth.uid() references auth.users, entity_type text not null, entity_id uuid, action text not null, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now());

-- Composite tenant-aware foreign keys prevent cross-company links even when an ID is guessed.
alter table public.service_categories add constraint service_categories_id_company_unique unique(id,company_id);
alter table public.services add constraint services_id_company_unique unique(id,company_id), add constraint services_category_company_fk foreign key(category_id,company_id) references public.service_categories(id,company_id);
alter table public.clients add constraint clients_id_company_unique unique(id,company_id);
alter table public.tickets add constraint tickets_id_company_unique unique(id,company_id), add constraint tickets_client_company_fk foreign key(client_id,company_id) references public.clients(id,company_id), add constraint tickets_service_company_fk foreign key(service_id,company_id) references public.services(id,company_id);
alter table public.ticket_events add constraint ticket_events_ticket_company_fk foreign key(ticket_id,company_id) references public.tickets(id,company_id);
alter table public.quotes add constraint quotes_id_company_unique unique(id,company_id), add constraint quotes_client_company_fk foreign key(client_id,company_id) references public.clients(id,company_id), add constraint quotes_ticket_company_fk foreign key(ticket_id,company_id) references public.tickets(id,company_id);
alter table public.quote_versions add constraint quote_versions_quote_company_fk foreign key(quote_id,company_id) references public.quotes(id,company_id);
alter table public.quote_approvals add constraint quote_approvals_quote_company_fk foreign key(quote_id,company_id) references public.quotes(id,company_id);
alter table public.contracts add constraint contracts_quote_company_fk foreign key(quote_id,company_id) references public.quotes(id,company_id);
alter table public.work_orders add constraint work_orders_id_company_unique unique(id,company_id), add constraint work_orders_quote_company_fk foreign key(quote_id,company_id) references public.quotes(id,company_id), add constraint work_orders_client_company_fk foreign key(client_id,company_id) references public.clients(id,company_id), add constraint work_orders_ticket_company_fk foreign key(ticket_id,company_id) references public.tickets(id,company_id);
alter table public.payments add constraint payments_client_company_fk foreign key(client_id,company_id) references public.clients(id,company_id), add constraint payments_quote_company_fk foreign key(quote_id,company_id) references public.quotes(id,company_id), add constraint payments_work_order_company_fk foreign key(work_order_id,company_id) references public.work_orders(id,company_id);

create or replace function public.log_ticket_status_change() returns trigger language plpgsql security invoker set search_path = '' as $$
begin
 if tg_op='INSERT' then
   insert into public.ticket_events(company_id,ticket_id,from_status,to_status,note,actor_id) values(new.company_id,new.id,null,new.status,'Chamado aberto',auth.uid());
 elsif old.status is distinct from new.status then
   insert into public.ticket_events(company_id,ticket_id,from_status,to_status,actor_id) values(new.company_id,new.id,old.status,new.status,auth.uid());
 end if;
 return new;
end $$;
create trigger tickets_log_status after insert or update on public.tickets for each row execute function public.log_ticket_status_change();

create or replace function public.keep_quote_versions_immutable() returns trigger language plpgsql security invoker set search_path = '' as $$
begin raise exception 'Quote versions are immutable. Create a new version to change scope or pricing.'; end $$;
create trigger quote_versions_immutable before update or delete on public.quote_versions for each row execute function public.keep_quote_versions_immutable();

-- Company ownership checks keep every operational record tenant-scoped.
do $$ declare t text; begin foreach t in array array['service_categories','services','clients','tickets','ticket_events','quotes','quote_versions','quote_approvals','contracts','work_orders','payments','attachments','audit_log'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy %I on public.%I for all to authenticated using (public.is_company_member(company_id)) with check (public.is_company_member(company_id))',t||'_member_access',t);
end loop; end $$;
alter table public.companies enable row level security;
create policy companies_member_access on public.companies for select to authenticated using (public.is_company_member(id));
create policy companies_admin_update on public.companies for update to authenticated using (exists(select 1 from public.company_members m where m.company_id=id and m.user_id=(select auth.uid()) and m.role='admin')) with check (exists(select 1 from public.company_members m where m.company_id=id and m.user_id=(select auth.uid()) and m.role='admin'));
alter table public.company_members enable row level security;
create policy members_read_self on public.company_members for select to authenticated using (user_id=(select auth.uid()));
-- Membership changes are provisioned from the SQL editor by the project owner.
-- Do not let a user grant themselves an admin role from the client API.

-- Lock down the RPC: monetary totals are calculated server-side, rounded to cents, and discounts cannot exceed the gross amount.
create or replace function public.create_quote(p_company_id uuid,p_client_id uuid,p_ticket_id uuid,p_valid_until date,p_description text,p_service_address jsonb,p_items jsonb,p_additions numeric default 0,p_expenses numeric default 0,p_discount numeric default 0,p_duration text default null,p_payment_terms text default null,p_warranty text default null,p_notes text default null)
returns uuid language plpgsql security invoker set search_path = '' as $$
declare qid uuid; v_sub numeric(12,2); v_total numeric(12,2); it jsonb;
begin
 if not public.is_company_member(p_company_id) then raise exception 'not authorized'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'at least one item is required'; end if;
 v_sub:=0;
 for it in select value from jsonb_array_elements(p_items) loop
   if coalesce((it->>'quantity')::numeric,0)<=0 or coalesce((it->>'unit_price')::numeric,0)<0 then raise exception 'invalid item amount'; end if;
   v_sub:=v_sub+round((it->>'quantity')::numeric*(it->>'unit_price')::numeric,2);
 end loop;
 v_sub:=round(v_sub,2); p_additions:=round(coalesce(p_additions,0),2); p_expenses:=round(coalesce(p_expenses,0),2); p_discount:=round(coalesce(p_discount,0),2);
 if p_additions<0 or p_expenses<0 or p_discount<0 then raise exception 'amounts cannot be negative'; end if;
 v_total:=round(v_sub+p_additions+p_expenses-p_discount,2);
 if v_total<0 then raise exception 'discount exceeds quote amount'; end if;
 insert into public.quotes(company_id,client_id,ticket_id,valid_until) values(p_company_id,p_client_id,p_ticket_id,p_valid_until) returning id into qid;
 insert into public.quote_versions(company_id,quote_id,version,description,service_address,items,subtotal,additions,expenses,discount,total,estimated_duration,payment_terms,warranty,notes)
 values(p_company_id,qid,1,coalesce(p_description,''),coalesce(p_service_address,'{}'),p_items,v_sub,p_additions,p_expenses,p_discount,v_total,p_duration,p_payment_terms,p_warranty,p_notes);
 insert into public.audit_log(company_id,entity_type,entity_id,action,details) values(p_company_id,'quote',qid,'created',jsonb_build_object('version',1,'total',v_total));
 return qid;
end $$;
revoke all on function public.create_quote(uuid,uuid,uuid,date,text,jsonb,jsonb,numeric,numeric,numeric,text,text,text,text) from public, anon;
grant execute on function public.create_quote(uuid,uuid,uuid,date,text,jsonb,jsonb,numeric,numeric,numeric,text,text,text,text) to authenticated;

create index tickets_company_status_idx on public.tickets(company_id,status,created_at desc);
create index quotes_company_status_idx on public.quotes(company_id,status,created_at desc);
create index work_orders_schedule_idx on public.work_orders(company_id,scheduled_at);
create index payments_pending_idx on public.payments(company_id,status,due_at);
