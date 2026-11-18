-- PREENTREGA 4: CONSULTAS MULTICAPA PARA ANALISIS DE NEGOCIO
-- Autor: Augusto Rinaldi Davids | PostgreSQL 18
-- Ejecutar conectado a tienda, con el dataset de clases cargado en public.
-- Antes de este archivo ejecutar preparar-vista-ventas.sql una sola vez.
-- Fuente: copia exacta de CLASES/VARIOS/ddl tienda.txt en dataset/ddl-tienda.sql.
-- Las tres consultas solo leen datos existentes. No crean clientes ni ventas.
-- preentrega_4.ventas es una vista de pedidos y detalles originales Completado.
-- La adaptacion permite usar el nombre ventas solicitado por la consigna.
-- En este analisis, compra significa pedido completado; se excluyen otros estados.

-- CONSULTA 1: RENTABILIDAD POR CATEGORIA
-- Pregunta de negocio: que categorias superan 10000 unidades monetarias de
-- ingreso y cuantas unidades de productos se vendieron en cada una.
-- Se unen ventas, productos y categorias; GROUP BY resume por categoria.
-- SUM usa el precio unitario de cada detalle, no el precio actual del catalogo.
-- HAVING filtra el ingreso agregado. Sin costos, este indicador es ingreso,
-- no ganancia neta. La fuente no identifica moneda; no se presume una divisa.
SELECT
    cat.nombre_categoria AS categoria,
    SUM(v.cantidad) AS unidades_vendidas,
    SUM(v.importe) AS ingreso_total
FROM preentrega_4.ventas AS v
INNER JOIN public.productos AS p
    ON p.producto_id = v.id_producto
INNER JOIN public.categorias AS cat
    ON cat.categoria_id = p.categoria_id
GROUP BY cat.categoria_id, cat.nombre_categoria
HAVING SUM(v.importe) > 10000.00
ORDER BY ingreso_total DESC, cat.nombre_categoria;

-- CONSULTA 2: CLIENTES ESCURRIDIZOS
-- Pregunta de negocio: a que clientes registrados se puede dirigir una campana
-- de primera compra, porque no tienen ninguna compra completada.
-- LEFT JOIN conserva a todos los clientes. WHERE detecta ausencia de coincidencia
-- comprobando id_venta, que nunca es NULL en un detalle original.
-- COALESCE muestra cero unidades en lugar de NULL para esos clientes.
-- Un cliente con solo pedidos cancelados, enviados o en proceso tampoco tiene
-- una compra completada y por eso se incluye en este resultado.
SELECT
    c.cliente_id AS id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_cliente,
    c.email,
    COALESCE(v.cantidad, 0) AS unidades_compradas
FROM public.clientes AS c
LEFT JOIN preentrega_4.ventas AS v
    ON v.id_cliente = c.cliente_id
WHERE v.id_venta IS NULL
ORDER BY c.cliente_id;

-- CONSULTA 3: TOP DE COMPRAS POR CLIENTE
-- Pregunta de negocio: cuales son los clientes con mayor ingreso acumulado,
-- que producto compran mas veces y cuando fue su ultima transaccion.
-- Se agrupa por cliente-producto para contar ocasiones con COUNT(DISTINCT
-- id_pedido), evitando contar dos veces un producto repetido en el mismo pedido.
-- SUM(cantidad) informa unidades, una medida distinta de ocasiones de compra.
-- La segunda agrupacion obtiene importe total, pedidos y ultima transaccion
-- de cada cliente sobre TODOS sus productos. Por eso su ultima transaccion
-- puede ser posterior a la ultima compra de su producto favorito.
-- NOT EXISTS conserva el producto si no hay otro del cliente con mas ocasiones.
-- HAVING compara conteos agrupados. Todos los favoritos empatados se conservan.
-- DENSE_RANK agrega el ranking de clientes por ingreso total, tal como pide
-- la rubrica; un empate de importes recibe la misma posicion sin dejar saltos.
-- Los clientes sin compras se informan en la consulta 2, sin favorito ni ranking.
SELECT
    DENSE_RANK() OVER (
        ORDER BY totales.ingreso_total_cliente DESC
    ) AS ranking_cliente,
    c.cliente_id AS id_cliente,
    c.nombre || ' ' || c.apellido AS nombre_cliente,
    totales.ingreso_total_cliente,
    totales.pedidos_completados,
    p.nombre_producto AS producto_mas_comprado,
    compras.veces_comprado,
    compras.unidades_producto,
    compras.ultima_compra_producto,
    totales.ultima_transaccion_cliente
FROM (
    SELECT
        v.id_cliente,
        v.id_producto,
        COUNT(DISTINCT v.id_pedido) AS veces_comprado,
        SUM(v.cantidad) AS unidades_producto,
        MAX(v.fecha_venta) AS ultima_compra_producto
    FROM preentrega_4.ventas AS v
    GROUP BY v.id_cliente, v.id_producto
) AS compras
INNER JOIN public.clientes AS c
    ON c.cliente_id = compras.id_cliente
INNER JOIN public.productos AS p
    ON p.producto_id = compras.id_producto
INNER JOIN (
    SELECT
        vc.id_cliente,
        SUM(vc.importe) AS ingreso_total_cliente,
        COUNT(DISTINCT vc.id_pedido) AS pedidos_completados,
        MAX(vc.fecha_venta) AS ultima_transaccion_cliente
    FROM preentrega_4.ventas AS vc
    GROUP BY vc.id_cliente
) AS totales
    ON totales.id_cliente = c.cliente_id
WHERE NOT EXISTS (
    SELECT 1
    FROM preentrega_4.ventas AS otra
    WHERE otra.id_cliente = compras.id_cliente
    GROUP BY otra.id_producto
    HAVING COUNT(DISTINCT otra.id_pedido) > compras.veces_comprado
)
ORDER BY ranking_cliente, c.cliente_id, p.producto_id;
