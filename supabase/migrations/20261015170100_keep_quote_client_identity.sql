create or replace function public.prevent_quote_client_change()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if old.client_id is distinct from new.client_id and exists(select 1 from public.quote_versions v where v.quote_id=old.id) then
    raise exception 'quote client cannot change after its first version';
  end if;
  return new;
end $$;
create trigger quotes_client_identity_immutable before update of client_id on public.quotes
for each row execute function public.prevent_quote_client_change();
