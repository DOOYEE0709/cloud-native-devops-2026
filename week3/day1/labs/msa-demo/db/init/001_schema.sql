CREATE TABLE IF NOT EXISTS service_bootstrap (
    id serial PRIMARY KEY,
    service_name text NOT NULL,
    created_at timestamptz DEFAULT now()
);

INSERT INTO service_bootstrap(service_name)
VALUES ('week3-msa-demo')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    price integer NOT NULL,
    stock integer NOT NULL DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS customers (
    id serial PRIMARY KEY,
    name text NOT NULL,
    email text NOT NULL UNIQUE,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS orders (
    id serial PRIMARY KEY,
    customer_id integer REFERENCES customers(id),
    status text NOT NULL DEFAULT 'pending',
    total_price integer NOT NULL DEFAULT 0,
    request_id text,
    created_at timestamptz DEFAULT now(),
    processed_at timestamptz
);

CREATE TABLE IF NOT EXISTS order_items (
    id serial PRIMARY KEY,
    order_id integer REFERENCES orders(id),
    product_id integer REFERENCES products(id),
    quantity integer NOT NULL DEFAULT 1,
    unit_price integer NOT NULL
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id serial PRIMARY KEY,
    service_name text NOT NULL,
    request_id text,
    event text NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

INSERT INTO products(name, price, stock)
VALUES
    ('msa-starter-kit', 39000, 15),
    ('observability-notebook', 22000, 30),
    ('kubernetes-preview-card', 18000, 20)
ON CONFLICT DO NOTHING;

INSERT INTO customers(name, email)
VALUES
    ('Paperclip Student', 'student@example.com')
ON CONFLICT (email) DO NOTHING;
