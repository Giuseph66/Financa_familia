-- =============================================================
-- 0008 — Catálogo de categorias (semente)
-- =============================================================
-- Copiado para cada casa nova pelo trigger trg_household_bootstrap.
-- Pensado para a realidade brasileira: "Mercado" separado de
-- "Delivery", "Uber/99" com nome próprio, benefícios (VR/VA) como
-- categoria de entrada, IPTU/IPVA no lugar certo.
--
-- Regra ao editar: os `key` são estáveis e nunca mudam. Renomear um
-- `name` afeta só casas criadas depois; casas existentes mantêm o
-- que já copiaram, que é o comportamento desejado.

insert into public.category_templates (key, parent_key, name, kind, icon, color, sort_order)
values
-- ================= DESPESAS =================
('housing',        null, 'Moradia',            'expense', 'home',            '#5D4037', 10),
('housing.rent',   'housing', 'Aluguel',        'expense', 'vpn_key',         '#5D4037', 11),
('housing.utils',  'housing', 'Água e luz',     'expense', 'bolt',            '#5D4037', 12),
('housing.gas',    'housing', 'Gás',            'expense', 'local_fire_department', '#5D4037', 13),
('housing.net',    'housing', 'Internet e TV',  'expense', 'wifi',            '#5D4037', 14),
('housing.condo',  'housing', 'Condomínio',     'expense', 'apartment',       '#5D4037', 15),
('housing.repair', 'housing', 'Reparos e móveis','expense','handyman',        '#5D4037', 16),

('food',           null, 'Alimentação',        'expense', 'restaurant',      '#E64A19', 20),
('food.market',    'food', 'Mercado',           'expense', 'shopping_cart',   '#E64A19', 21),
('food.dining',    'food', 'Restaurante',       'expense', 'restaurant_menu', '#E64A19', 22),
('food.delivery',  'food', 'Delivery',          'expense', 'delivery_dining', '#E64A19', 23),
('food.snack',     'food', 'Lanche e café',     'expense', 'local_cafe',      '#E64A19', 24),
('food.fair',      'food', 'Feira e açougue',   'expense', 'storefront',      '#E64A19', 25),

('transport',      null, 'Transporte',         'expense', 'directions_car',  '#1565C0', 30),
('transport.fuel', 'transport', 'Combustível',   'expense', 'local_gas_station','#1565C0', 31),
('transport.app',  'transport', 'Uber e 99',     'expense', 'local_taxi',     '#1565C0', 32),
('transport.pub',  'transport', 'Ônibus e metrô','expense', 'directions_bus', '#1565C0', 33),
('transport.park', 'transport', 'Estacionamento e pedágio','expense','local_parking','#1565C0', 34),
('transport.maint','transport', 'Manutenção',    'expense', 'build',          '#1565C0', 35),
('transport.doc',  'transport', 'IPVA e licenciamento','expense','description','#1565C0', 36),

('health',         null, 'Saúde',              'expense', 'favorite',        '#C62828', 40),
('health.plan',    'health', 'Plano de saúde',   'expense', 'health_and_safety','#C62828', 41),
('health.pharmacy','health', 'Farmácia',         'expense', 'medication',     '#C62828', 42),
('health.doctor',  'health', 'Consultas e exames','expense','stethoscope',    '#C62828', 43),
('health.dental',  'health', 'Dentista',         'expense', 'dentistry',      '#C62828', 44),
('health.therapy', 'health', 'Terapia',          'expense', 'psychology',     '#C62828', 45),

('education',      null, 'Educação',           'expense', 'school',          '#00838F', 50),
('education.school','education','Escola e faculdade','expense','menu_book',   '#00838F', 51),
('education.course','education','Cursos',        'expense', 'cast_for_education','#00838F', 52),
('education.books','education', 'Livros e material','expense','auto_stories', '#00838F', 53),

('leisure',        null, 'Lazer',              'expense', 'sports_esports',  '#7B1FA2', 60),
('leisure.stream', 'leisure', 'Assinaturas',     'expense', 'subscriptions',  '#7B1FA2', 61),
('leisure.trip',   'leisure', 'Viagem',          'expense', 'flight',         '#7B1FA2', 62),
('leisure.party',  'leisure', 'Bar e festa',     'expense', 'celebration',    '#7B1FA2', 63),
('leisure.hobby',  'leisure', 'Hobbies',         'expense', 'palette',        '#7B1FA2', 64),

('shopping',       null, 'Compras',            'expense', 'shopping_bag',    '#AD1457', 70),
('shopping.clothes','shopping','Roupas e calçados','expense','checkroom',     '#AD1457', 71),
('shopping.tech',  'shopping', 'Eletrônicos',     'expense', 'devices',       '#AD1457', 72),
('shopping.home',  'shopping', 'Casa e decoração','expense', 'chair',         '#AD1457', 73),
('shopping.gift',  'shopping', 'Presentes',       'expense', 'card_giftcard', '#AD1457', 74),

('personal',       null, 'Cuidado pessoal',    'expense', 'spa',             '#EF6C00', 80),
('personal.beauty','personal','Salão e barbearia','expense','content_cut',    '#EF6C00', 81),
('personal.gym',   'personal', 'Academia',        'expense', 'fitness_center','#EF6C00', 82),
('personal.hygiene','personal','Higiene',         'expense', 'soap',          '#EF6C00', 83),

('family',         null, 'Família',            'expense', 'family_restroom', '#00695C', 90),
('family.kids',    'family', 'Filhos',           'expense', 'child_care',     '#00695C', 91),
('family.pet',     'family', 'Pets',             'expense', 'pets',           '#00695C', 92),
('family.help',    'family', 'Ajuda a parentes', 'expense', 'volunteer_activism','#00695C', 93),

('finance',        null, 'Financeiro',         'expense', 'account_balance', '#37474F', 100),
('finance.fees',   'finance', 'Tarifas bancárias','expense','receipt_long',   '#37474F', 101),
('finance.interest','finance','Juros e multas',  'expense', 'trending_down',  '#37474F', 102),
('finance.loan',   'finance', 'Empréstimo',       'expense', 'request_quote', '#37474F', 103),
('finance.card',   'finance', 'Anuidade de cartão','expense','credit_card',   '#37474F', 104),
('finance.invest', 'finance', 'Aportes',          'expense', 'savings',       '#37474F', 105),

('taxes',          null, 'Impostos e taxas',   'expense', 'gavel',           '#455A64', 110),
('taxes.iptu',     'taxes', 'IPTU',              'expense', 'home_work',      '#455A64', 111),
('taxes.income',   'taxes', 'Imposto de renda',  'expense', 'description',    '#455A64', 112),
('taxes.other',    'taxes', 'Outras taxas',      'expense', 'receipt',        '#455A64', 113),

('insurance',      null, 'Seguros',            'expense', 'shield',          '#546E7A', 120),
('donation',       null, 'Doações',            'expense', 'favorite_border', '#8D6E63', 130),
('expense.other',  null, 'Outros gastos',      'expense', 'more_horiz',      '#9E9E9E', 999),

-- ================= RECEITAS =================
('salary',         null, 'Salário',            'income',  'work',            '#2E7D32', 10),
('salary.clt',     'salary', 'Salário mensal',   'income',  'payments',       '#2E7D32', 11),
('salary.13',      'salary', '13º salário',      'income',  'redeem',         '#2E7D32', 12),
('salary.vacation','salary', 'Férias',           'income',  'beach_access',   '#2E7D32', 13),
('salary.bonus',   'salary', 'Bônus e comissão', 'income',  'emoji_events',   '#2E7D32', 14),
('salary.overtime','salary', 'Horas extras',     'income',  'more_time',      '#2E7D32', 15),

('benefits',       null, 'Benefícios',         'income',  'card_membership', '#388E3C', 20),
('benefits.meal',  'benefits','Vale-refeição/alimentação','income','lunch_dining','#388E3C', 21),
('benefits.transp','benefits','Vale-transporte',  'income',  'commute',       '#388E3C', 22),
('benefits.gov',   'benefits','Benefício do governo','income','account_balance','#388E3C', 23),

('work.extra',     null, 'Trabalho extra',     'income',  'engineering',     '#00897B', 30),
('work.freelance', 'work.extra', 'Freelance',    'income',  'laptop',         '#00897B', 31),
('work.sales',     'work.extra', 'Vendas',       'income',  'sell',           '#00897B', 32),
('work.handmade',  'work.extra', 'Produção própria','income','handyman',      '#00897B', 33),

('passive',        null, 'Renda passiva',      'income',  'trending_up',     '#1565C0', 40),
('passive.invest', 'passive', 'Rendimentos',     'income',  'show_chart',     '#1565C0', 41),
('passive.rent',   'passive', 'Aluguel recebido','income',  'apartment',      '#1565C0', 42),

('income.refund',  null, 'Reembolso',          'income',  'undo',            '#5E35B1', 50),
('income.gift',    null, 'Presente recebido',  'income',  'card_giftcard',   '#5E35B1', 51),
('income.other',   null, 'Outras entradas',    'income',  'more_horiz',      '#9E9E9E', 999)

on conflict (key) do update set
  name       = excluded.name,
  icon       = excluded.icon,
  color      = excluded.color,
  sort_order = excluded.sort_order;

-- 'work.handmade' existe por causa de um caso real da persona: renda
-- de produtos fabricados pelo próprio usuário. Sem categoria própria,
-- isso vira "Outras entradas" e a pessoa nunca descobre quanto a
-- produção artesanal de fato rende.
