# PH O.S. — PH SERVICE FORTAL

Aplicação web responsiva e instalável (PWA) para organizar clientes, catálogo, orçamentos, ordens de serviço, pagamentos e relatórios. Chamados e contratos antigos permanecem preservados no banco, mas não fazem parte da navegação atual.

## Identidade configurada

- Empresa: PH SERVICE FORTAL
- Região de atendimento: Fortaleza — CE
- Telefone e WhatsApp: (86) 99949-0316
- WhatsApp: <https://wa.me/558699490316>
- Site institucional: <https://ph-service-fortal.vercel.app/>
- Avaliações: <https://g.page/r/CQPH4XoL5ddeEBM/review>
- Projeto Supabase: `hyixoosgozqyehegfzlh`
- Logo: `public/logo-ph-service-fortal.webp`

CPF/CNPJ, endereço completo, dados bancários, Pix e preços de serviços permanecem vazios até serem informados pelo administrador.

## Configuração

O projeto Supabase está conectado e o primeiro usuário administrador já está vinculado à empresa. As tabelas operacionais usam RLS. A chave `service_role` fica somente no ambiente server-side do Supabase; o frontend usa a chave publicável.

Aplicação: <https://ph-os-kappa.vercel.app>  
Repositório: <https://github.com/papaiemamaesexshopfortal-coder/ph-os>

Para desenvolvimento local, copie `.env.example` para `.env.local`, configure `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY`, rode `npm install`, `npm run dev` e `npm run build`.

## Implementado

- Autenticação por e-mail e senha e isolamento por empresa via RLS.
- Cadastros de clientes e serviços com ação de edição e formulários preenchidos com os dados atuais.
- Orçamentos com várias linhas, acréscimos, despesas, descontos, prazo, validade e versões históricas imutáveis.
- Formas de pagamento por orçamento: Pix, dinheiro, débito, crédito, transferência, parcelamento e entrada mais saldo; entrada, quantidade de parcelas e taxa de cartão são registradas.
- Taxa percentual configurável pelo administrador apenas em meios de cartão. O sistema calcula e discrimina o valor da taxa no servidor, sem inventar preços de operadoras ou processar cartões.
- Link de aprovação com token de alta entropia, hash no banco, validade e uso único. O cliente visualiza os valores e condições e pode aprovar, recusar ou solicitar alteração.
- Criação de ordem de serviço a partir de orçamento aprovado, com transições auditadas, despesas extras autorizadas e comprovante imprimível.
- Pagamentos com ação de edição, dashboard, relatórios, exportação CSV, WhatsApp com confirmação manual do envio e PWA.
- A tela de detalhes exibe campos legíveis e não mostra objetos técnicos serializados.

## Pendências antes de uso comercial amplo

- Faltam anexos privados e fotografias, checklist editável, notificações, comprovantes financeiros e testes automatizados ponta a ponta.
- O aceite é do orçamento; não é assinatura digital qualificada.
- A proteção contra senhas vazadas está desativada nas configurações de Auth do Supabase. Ative em **Authentication → Settings → Password Security**.
- Os papéis de administrador, equipe, técnico e financeiro ainda não têm permissões distintas na interface e nas políticas operacionais.

O sistema não processa cartões nem envia WhatsApp automaticamente. Confira os percentuais informados para cada operadora antes de apresentar o orçamento ao cliente.
