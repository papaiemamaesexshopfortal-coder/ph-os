-- Dados iniciais específicos da PH SERVICE FORTAL. Sem preços ou cadastro legal inventado.
insert into public.companies (name, phone, whatsapp_url, website, review_url, address, logo_path)
select
  'PH SERVICE FORTAL',
  '(86) 99949-0316',
  'https://wa.me/558699490316',
  'https://ph-service-fortal.vercel.app/',
  'https://g.page/r/CQPH4XoL5ddeEBM/review',
  '{"city":"Fortaleza","state":"CE"}'::jsonb,
  '/logo-ph-service-fortal.webp'
where not exists (select 1 from public.companies where name='PH SERVICE FORTAL');

update public.companies
set logo_path='/logo-ph-service-fortal.webp'
where name='PH SERVICE FORTAL' and logo_path is distinct from '/logo-ph-service-fortal.webp';

insert into public.service_categories (company_id,name,sort_order)
select c.id, v.name, v.position
from public.companies c
cross join (values
  ('Presença Digital',1),
  ('Informática',2),
  ('TV Box e Entretenimento Digital',3),
  ('Montagem de Móveis e Instalações',4),
  ('Desenvolvimento de Aplicativos',5),
  ('Sistemas de Mídia Indoor',6)
) as v(name,position)
where c.name='PH SERVICE FORTAL'
  and not exists (select 1 from public.service_categories x where x.company_id=c.id and x.name=v.name);

insert into public.services (company_id,category_id,name,description,standard_price)
select c.id, cat.id, s.name, s.name, null
from public.companies c
join public.service_categories cat on cat.company_id=c.id
join (values
 ('Presença Digital','Criação e manutenção de sites'),
 ('Presença Digital','Páginas comerciais'),
 ('Presença Digital','Soluções para presença digital'),
 ('Informática','Manutenção de computadores'),
 ('Informática','Manutenção de notebooks'),
 ('Informática','Instalação e configuração de programas'),
 ('Informática','Diagnóstico técnico'),
 ('TV Box e Entretenimento Digital','Instalação de dispositivos'),
 ('TV Box e Entretenimento Digital','Configuração de equipamentos'),
 ('TV Box e Entretenimento Digital','Suporte técnico'),
 ('Montagem de Móveis e Instalações','Montagem e desmontagem de móveis'),
 ('Montagem de Móveis e Instalações','Instalação de cortinas'),
 ('Montagem de Móveis e Instalações','Instalação de varais'),
 ('Montagem de Móveis e Instalações','Instalação de quadros e acessórios'),
 ('Desenvolvimento de Aplicativos','Desenvolvimento de sistemas'),
 ('Desenvolvimento de Aplicativos','Aplicativos comerciais'),
 ('Desenvolvimento de Aplicativos','Manutenção e suporte de software'),
 ('Sistemas de Mídia Indoor','Instalação e configuração de sistemas de exibição'),
 ('Sistemas de Mídia Indoor','Cardápios digitais'),
 ('Sistemas de Mídia Indoor','Soluções de comunicação em telas')
) as s(category_name,name) on s.category_name=cat.name
where c.name='PH SERVICE FORTAL'
  and not exists (select 1 from public.services x where x.company_id=c.id and x.category_id=cat.id and x.name=s.name);
