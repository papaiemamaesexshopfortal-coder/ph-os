# PH O.S. — PH SERVICE FORTAL

Aplicação web responsiva e instalável (PWA) para organizar clientes, catálogo, chamados, orçamentos, contratos, ordens de serviço, pagamentos e relatórios.

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
- Cadastro de clientes, catálogo e chamados com histórico de status.
- Orçamento calculado no PostgreSQL com proteção contra valores negativos e desconto acima do total.
- Link de aprovação com token de alta entropia, hash no banco, expiração e uso único. O portal exibe a versão exata e registra aprovação, recusa ou pedido de alteração com declaração de leitura.
- A aprovação externa passa pela Edge Function `quote-public`; as rotinas privilegiadas de banco são acessíveis apenas ao servidor.
- Contrato simplificado gerado como snapshot da versão aprovada e opção de impressão/PDF.
- Registro administrativo auditado de confirmação do aceite do contrato e criação de OS vinculada.
- Transições auditadas de início, conclusão e encerramento da OS. Despesas adicionais exigem registro de autorização do cliente.
- Comprovante de OS imprimível, pagamentos, dashboard, relatórios imprimíveis e PWA.
- WhatsApp é aberto com a mensagem e o link; o sistema não marca a mensagem como enviada.

## Pendências antes de uso comercial amplo

- Ainda faltam orçamento com múltiplos itens, edição e novas versões comerciais; anexos privados e fotografias; checklist editável; comprovantes; notificações; exportação CSV; recuperação de senha; e testes automatizados de integração ponta a ponta.
- O aceite de contrato é informado por um membro da empresa após confirmação recebida. Falta um portal seguro para o cliente aceitar diretamente; esse registro não é assinatura digital qualificada.
- A proteção contra senhas vazadas está desativada nas configurações de Auth do Supabase. Ative em **Authentication → Settings → Password Security**.
- O modelo contratual é simplificado e deve passar por revisão jurídica antes do uso comercial.

O sistema não processa cartões nem envia WhatsApp automaticamente. Verifique dados empresariais, privacidade, contrato e rotinas de backup antes de ampliar o uso.
