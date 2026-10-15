revoke all on function public.get_public_quote(text) from public, anon, authenticated;
grant execute on function public.get_public_quote(text) to service_role;
revoke all on function public.submit_public_quote_decision(text,text,text,boolean,jsonb) from public, anon, authenticated;
grant execute on function public.submit_public_quote_decision(text,text,text,boolean,jsonb) to service_role;
