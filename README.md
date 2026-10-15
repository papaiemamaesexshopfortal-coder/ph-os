# PH O.S. — PH SERVICE FORTAL

Aplicação web responsiva e instalável (PWA) para organizar clientes, catálogo, chamados, orçamentos, ordens de serviço, pagamentos e relatórios.

## Identidade configurada

- Empresa: PH SERVICE FORTAL
- Região de atendimento: Fortaleza — CE
- Telefone e WhatsApp: (86) 99949-0316
- WhatsApp: <https://wa.me/558699490316>
- Site: <https://ph-service-fortal.vercel.app/>
- Avaliações: <https://g.page/r/CQPH4XoL5ddeEBM/review>
- Projeto Supabase dedicado: hyixoosgozqyehegfzlh
- Logo comercial: public/logo-ph-service-fortal.webp

CPF/CNPJ, endereço completo, dados bancários e Pix permanecem vazios até serem informados pelo administrador. Os preços dos serviços também permanecem vazios.

## Estado da configuração

A estrutura inicial está aplicada ao Supabase. As tabelas operacionais usam RLS. A empresa PH SERVICE FORTAL, suas seis categorias e os 20 serviços do catálogo inicial foram cadastrados sem preços fictícios.

Falta criar o primeiro usuário administrador no Supabase Auth e vinculá-lo à empresa. A tela de login não permite cadastro público. No painel do Supabase, abra Authentication → Users e crie o usuário administrador. Depois, a associação à empresa deve ser feita por operação administrativa segura em company_members. Não coloque a chave service_role no frontend.

## Desenvolvimento local

1. Copie .env.example para .env.local.
2. Configure VITE_SUPABASE_URL como https://hyixoosgozqyehegfzlh.supabase.co.
3. Use somente a chave publicável do projeto em VITE_SUPABASE_PUBLISHABLE_KEY.
4. Rode npm install, npm run dev e npm run build.

Para publicar, importe https://github.com/papaiemamaesexshopfortal-coder/ph-os no Vercel e configure as mesmas variáveis de ambiente.

## O que já está implementado

- Autenticação por e-mail e senha Supabase.
- Isolamento por empresa via RLS.
- Cadastro e pesquisa de clientes, catálogo e abertura de chamados.
- Orçamento inicial com total calculado no PostgreSQL e validações de valores.
- Registro de pagamentos, dashboard e relatório imprimível.
- Layout responsivo, manifesto PWA e atalho de WhatsApp.

## Pendências antes de uso comercial

Este é o primeiro incremento funcional, não uma liberação comercial final. Faltam completar e validar aprovação segura de orçamentos, versões e múltiplos itens, PDFs, aceite de contrato, execução e conclusão de OS, anexos privados, notificações, exportação CSV, recuperação de senha, testes automatizados, publicação e revisão de segurança. O envio por WhatsApp permanece manual. Revise o modelo contratual com assessoria jurídica antes do uso.
