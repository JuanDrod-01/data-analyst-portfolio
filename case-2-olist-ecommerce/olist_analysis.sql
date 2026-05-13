-- =============================================
-- OLIST E-COMMERCE ANALYSIS
-- Analista: Juan Diego Rodríguez Ávila
-- Fecha: Mayo 2026
-- Dataset: Brazilian E-Commerce Public Dataset (Olist)
-- Fuente: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
-- Base de datos: olist_ecommerce (SQL Server)
-- =============================================
-- TABLAS UTILIZADAS:
--   orders            - 99,441 órdenes
--   order_items       - 112,650 items
--   customers         - 99,441 clientes
--   products          - 32,951 productos
--   olist_order_reviews_dataset - 99,224 reseñas
-- =============================================
-- CASO DE NEGOCIO:
-- Olist es un marketplace brasileño que conecta vendedores
-- con clientes. Este análisis responde preguntas clave sobre
-- revenue, crecimiento, retención, logística y vendedores
-- para apoyar decisiones estratégicas del negocio.
-- =============================================

USE olist_ecommerce;


-- =============================================
-- 1. REVENUE TOTAL Y GMV
-- ¿Cuánto ingreso generó Olist en total?
-- Resultado: 96,478 órdenes · GMV R$1.54 mil millones
-- =============================================
SELECT 
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.freight_value), 2) AS total_freight,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS total_gmv
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';


-- =============================================
-- 2. TENDENCIA DE VENTAS MENSUAL
-- ¿Cómo crecieron las ventas mes a mes?
-- Resultado: Crecimiento 17x de 2016 a 2017
-- =============================================
SELECT 
    YEAR(o.order_purchase_timestamp) AS year,
    MONTH(o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS monthly_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY 
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY year, month;


-- =============================================
-- 3. PRECIO PROMEDIO VS VOLUMEN POR MES
-- ¿El crecimiento fue por precios más altos o más clientes?
-- Resultado: Precio estable — crecimiento por adquisición de clientes
-- =============================================
SELECT 
    YEAR(o.order_purchase_timestamp) AS year,
    MONTH(o.order_purchase_timestamp) AS month,
    ROUND(AVG(oi.price), 2) AS avg_order_price,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY 
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY year, month;


-- =============================================
-- 4. CLIENTES Y REVENUE POR ESTADO
-- ¿De qué estados vienen los clientes y cuánto generan?
-- Resultado: SP concentra 39,156 clientes y R$506M
-- =============================================
SELECT 
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    ROUND(SUM(oi.price), 2) AS state_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_customers DESC;


-- =============================================
-- 5. TIEMPO PROMEDIO DE ENTREGA POR ESTADO
-- ¿Qué estados reciben sus pedidos más tarde?
-- Resultado: Brecha de 21 días entre SP (8 días) y RR (29 días)
-- =============================================
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(DATEDIFF(day, 
        o.order_purchase_timestamp, 
        o.order_delivered_customer_date)), 1) AS avg_delivery_days
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_delivery_days DESC;


-- =============================================
-- 6. CATEGORÍAS POR REVENUE
-- ¿Qué categorías generan más ingresos?
-- Resultado: beleza_saude lidera con R$123M
-- =============================================
SELECT 
    p.product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS category_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
AND p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY category_revenue DESC;


-- =============================================
-- 7. CATEGORÍAS POR AÑO
-- ¿El mix de productos cambió entre 2016, 2017 y 2018?
-- Resultado: Mismas categorías top — crecimiento orgánico
-- =============================================
SELECT 
    YEAR(o.order_purchase_timestamp) AS year,
    p.product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS category_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
AND p.product_category_name IS NOT NULL
GROUP BY 
    YEAR(o.order_purchase_timestamp),
    p.product_category_name
ORDER BY year, category_revenue DESC;


-- =============================================
-- 8. RETENCIÓN DE CLIENTES
-- ¿Los clientes compran más de una vez?
-- Resultado: 97% compró solo una vez — baja retención crítica
-- =============================================
SELECT 
    total_orders,
    COUNT(customer_unique_id) AS total_customers,
    ROUND(COUNT(customer_unique_id) * 100.0 / 
        SUM(COUNT(customer_unique_id)) OVER(), 2) AS percentage
FROM (
    SELECT 
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) AS customer_orders
GROUP BY total_orders
ORDER BY total_orders;


-- =============================================
-- 9. PRODUCTOS COMPRADOS POR CLIENTES DE UNA SOLA COMPRA
-- ¿Qué compraron los clientes que no volvieron?
-- Resultado: Consumibles como beleza_saude y perfumaria
--            lideran — problema de retención en productos urgentes
-- =============================================
SELECT 
    p.product_category_name,
    COUNT(DISTINCT c.customer_unique_id) AS one_time_buyers,
    ROUND(AVG(oi.price), 2) AS avg_price
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
AND p.product_category_name IS NOT NULL
AND c.customer_unique_id IN (
    SELECT c2.customer_unique_id
    FROM orders o2
    JOIN customers c2 ON o2.customer_id = c2.customer_id
    WHERE o2.order_status = 'delivered'
    GROUP BY c2.customer_unique_id
    HAVING COUNT(DISTINCT o2.order_id) = 1
)
GROUP BY p.product_category_name
ORDER BY one_time_buyers DESC;


-- =============================================
-- 10. RESEÑAS VS ENTREGA — PRODUCTOS CONSUMIBLES
-- ¿La baja retención en consumibles es por calidad o entrega?
-- Resultado: Buenas reseñas (4.2/5) pero 10-11 días de entrega
--            El problema es velocidad, no calidad del producto
-- =============================================
SELECT 
    p.product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(CAST(r.review_score AS FLOAT)), 2) AS avg_review_score,
    ROUND(AVG(DATEDIFF(day, 
        o.order_purchase_timestamp, 
        o.order_delivered_customer_date)), 1) AS avg_delivery_days
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
AND p.product_category_name IN (
    'beleza_saude', 'perfumaria', 'alimentos', 
    'bebidas', 'utilidades_domesticas'
)
GROUP BY p.product_category_name
ORDER BY avg_review_score ASC;


-- =============================================
-- 11. RESEÑAS VS ENTREGA — PRODUCTOS DURADEROS
-- ¿Los duraderos tienen el mismo tiempo de entrega?
-- Resultado: Similar tiempo (12-13 días) pero retención aceptable
--            Para duraderos la urgencia no aplica
-- =============================================
SELECT 
    p.product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(CAST(r.review_score AS FLOAT)), 2) AS avg_review_score,
    ROUND(AVG(DATEDIFF(day, 
        o.order_purchase_timestamp, 
        o.order_delivered_customer_date)), 1) AS avg_delivery_days
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL
AND p.product_category_name IN (
    'cama_mesa_banho', 'esporte_lazer', 
    'moveis_decoracao', 'relogios_presentes',
    'informatica_acessorios', 'automotivo'
)
GROUP BY p.product_category_name
ORDER BY avg_review_score ASC;


-- =============================================
-- 12. TOP VENDEDORES POR REVENUE
-- ¿Quiénes son los vendedores más exitosos?
-- Resultado: Dos estrategias — alto volumen vs alto precio
-- =============================================
SELECT 
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price,
    COUNT(DISTINCT oi.product_id) AS unique_products
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id
ORDER BY total_revenue DESC;


-- =============================================
-- 13. CATEGORÍAS POR VENDEDOR (TOP 10)
-- ¿En qué categorías se especializan los top vendedores?
-- Resultado: Mayoría son especialistas en 1-2 categorías
-- =============================================
SELECT 
    oi.seller_id,
    p.product_category_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS category_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
AND oi.seller_id IN (
    '4869f7a5dfa277a7dca6462dcf3b52b2',
    '53243585a1d6dc2643021fd1853d8905',
    '4a3ca9315b744ce9f8e9374361493884',
    'fa1c13f2614d7b5c4749cbc52fecda94',
    '7c67e1448b00f6e969d365cea6b010ab',
    '7e93a43ef30c4f03f38b393420bc753a',
    'da8622b14eb17ae2831f4ac5b9dab84a',
    '7a67c85e85bb2ce8582c35f2203ad736',
    '1025f0e2d44d7041d6cf58b6550e0bfa',
    '955fee9216a65b617aa5c0531780ce60'
)
GROUP BY oi.seller_id, p.product_category_name
ORDER BY oi.seller_id, category_revenue DESC;


-- =============================================
-- 14. VENTAS MENSUALES POR VENDEDOR (TOP 10)
-- ¿En qué meses venden más los top vendedores?
-- Resultado: Noviembre sube en todos (Black Friday Brasil)
--            Vendedor 7e93a43 cayó dramáticamente en 2018
-- =============================================
SELECT 
    oi.seller_id,
    YEAR(o.order_purchase_timestamp) AS year,
    MONTH(o.order_purchase_timestamp) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS monthly_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
AND oi.seller_id IN (
    '4869f7a5dfa277a7dca6462dcf3b52b2',
    '53243585a1d6dc2643021fd1853d8905',
    '4a3ca9315b744ce9f8e9374361493884',
    'fa1c13f2614d7b5c4749cbc52fecda94',
    '7c67e1448b00f6e969d365cea6b010ab',
    '7e93a43ef30c4f03f38b393420bc753a',
    'da8622b14eb17ae2831f4ac5b9dab84a',
    '7a67c85e85bb2ce8582c35f2203ad736',
    '1025f0e2d44d7041d6cf58b6550e0bfa',
    '955fee9216a65b617aa5c0531780ce60'
)
GROUP BY 
    oi.seller_id,
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY oi.seller_id, year, month;


-- =============================================
-- 15. RETENCIÓN POR VENDEDOR (TOP 10)
-- ¿Los clientes de los top vendedores repiten compra?
-- Resultado: Hogar/tech mejor retención (14%) vs relojes (2.8%)
-- =============================================
SELECT 
    oi.seller_id,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) * 100.0 / 
        COUNT(DISTINCT c.customer_unique_id), 2) AS retention_rate
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
JOIN (
    SELECT 
        c2.customer_unique_id,
        COUNT(DISTINCT o2.order_id) AS order_count
    FROM orders o2
    JOIN customers c2 ON o2.customer_id = c2.customer_id
    WHERE o2.order_status = 'delivered'
    GROUP BY c2.customer_unique_id
) AS customer_freq ON c.customer_unique_id = customer_freq.customer_unique_id
WHERE o.order_status = 'delivered'
AND oi.seller_id IN (
    '4869f7a5dfa277a7dca6462dcf3b52b2',
    '53243585a1d6dc2643021fd1853d8905',
    '4a3ca9315b744ce9f8e9374361493884',
    'fa1c13f2614d7b5c4749cbc52fecda94',
    '7c67e1448b00f6e969d365cea6b010ab',
    '7e93a43ef30c4f03f38b393420bc753a',
    'da8622b14eb17ae2831f4ac5b9dab84a',
    '7a67c85e85bb2ce8582c35f2203ad736',
    '1025f0e2d44d7041d6cf58b6550e0bfa',
    '955fee9216a65b617aa5c0531780ce60'
)
GROUP BY oi.seller_id
ORDER BY retention_rate DESC;
