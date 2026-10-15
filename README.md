# PH O.S. — PH SERVICE FORTAL

Aplicação web responsiva e instalável (PWA) para organizar clientes, catálogo, chamados, orçamentos, ordens de serviço, pagamentos e relatórios.

## Criar os serviços necessários

1. Crie um repositório GitHub privado em <https://github.com/new> com o nome `ph-os`.
2. Crie um projeto Supabase em <https://supabase.com/dashboard/new> com o nome `ph-os-fortal`. Escolha a região mais próxima disponível e guarde a senha do banco em local seguro.
3. No repositório recém-criado, envie o conteúdo desta pasta. Os comandos iniciais no computador com Git são:

   ```bash
   git init
   git add .
   git commit -m "Inicializa PH O.S."
   git branch -M main
   git remote add origin https://github.com/SEU-USUARIO/ph-os.git
   git push -u origin main
   ```

4. No Supabase, abra **SQL Editor** e execute `supabase/migrations/20261015090000_initial_schema.sql`.
5. Em **Authentication → Users**, convide/crie o primeiro usuário administrador. Copie o UUID desse usuário.
6. No SQL Editor, inicialize a empresa, a conta e as categorias padrão. Não há preços no catálogo:

   ```sql
   insert into public.companies (name)
   values ('PH SERVICE FORTAL') returning id;
   ```

   Copie o UUID retornado e o UUID do usuário criado; substitua os dois valores abaixo:

   ```sql
   insert into public.company_members (company_id, user_id, role)
   values ('UUID_DA_EMPRESA', 'UUID_DO_ADMIN', 'admin');

   insert into public.service_categories (company_id, name, sort_order) values
   ('UUID_DA_EMPRESA','Presença Digital',1),
   ('UUID_DA_EMPRESA','Informática',2),
   ('UUID_DA_EMPRESA','TV Box e Entretenimento Digital',3),
   ('UUID_DA_EMPRESA','Montagem de Móveis e Instalações',4),
   ('UUID_DA_EMPRESA','Desenvolvimento de Aplicativos',5),
   ('UUID_DA_EMPRESA','Sistemas de Mídia Indoor',6);
   ```

7. Copie `.env.example` para `.env.local` e preencha `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` com a URL e a chave **publicável** exibidas em **Project Settings → API Keys**. Nunca use `service_role` no frontend.
8. Para rodar localmente: `npm install`, `npm run dev`. Para conferir a compilação: `npm run build`.
9. Importe o repositório no Vercel e configure as mesmas duas variáveis de ambiente antes de publicar.

## O que já está implementado

- Autenticação de acesso por e-mail e senha Supabase.
- Isolamento por empresa via RLS; associação inicial de administrador feita pelo proprietário do projeto no SQL Editor.
- Cadastro e pesquisa de clientes, catálogo de serviços sem preço fictício e abertura de chamados.
- Criação inicial de orçamento com total calculado no PostgreSQL, valores monetários em centavos, validação de descontos e associação opcional a chamado.
- Registro de pagamentos, dashboard com indicadores baseados em registros, relatório imprimível, configuração de dados comerciais e atalho de WhatsApp.
- Layout responsivo, manifesto PWA e navegação adaptada a celular.

## Pendências antes de uso comercial

Este é o primeiro incremento funcional e a fundação de dados, não uma liberação comercial final. O schema já separa versões de orçamento e registra aprovações, contratos, OS, anexos e auditoria; a interface ainda precisa completar os fluxos de link seguro de aprovação/recusa, versões e múltiplos itens, geração e armazenamento privado de PDF, assinatura/aceite de contrato, criação e conclusão de OS, anexos com Storage privado, notificações, exportação CSV, fluxo de recuperação de senha, testes automatizados e revisão de segurança. O envio por WhatsApp permanece manual pelo link; abrir o WhatsApp nunca é tratado como confirmação de envio. Integração oficial de mensagens exige configuração autorizada. Revise o modelo contratual com assessoria jurídica antes do uso.

## Comandos

```bash
npm install
npm run dev
npm run build
```
