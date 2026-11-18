# Entregas de SQL y Estadística Aplicada al Negocio

- **Preentrega 5:** [Consulta de análisis avanzado, instrucciones y resultados](preentrega_5/README.md).
- **Preentrega 4:** consultas, dataset e instrucciones detalladas a continuación.
- **Preentrega 2:** [script e instrucciones originales](preentrega_2/README.md).

---

# Preentrega 4 - Consultas multicapa para análisis de negocio

**Autor:** Augusto Rinaldi Davids.  
**Materia:** SQL y Estadística Aplicada al Negocio - Coderhouse.  
**Motor comprobado:** PostgreSQL 18.6.

## Archivos

- `pre-entrega-modulo4.sql`: entregable principal con exactamente tres consultas de análisis comentadas.
- `preparar-vista-ventas.sql`: adaptación de lectura que permite consultar los pedidos y sus detalles como ventas.
- `dataset/ddl-tienda.sql`: copia exacta del archivo de datos de clases que ya se encontraba en `CLASES/VARIOS/ddl tienda.txt`.
- `resultados-verificados.txt`: resultados de las tres consultas y comprobaciones realizadas.

## Fuente y continuidad

Se utiliza el dataset de tienda disponible en los materiales de clases del alumno. No se agregan ni inventan clientes, categorías, productos, pedidos, importes o fechas para esta entrega. La copia incluida tiene el mismo contenido y SHA256 que el archivo original:

```text
70282cc33304b7dbe6cb7caafcf777812569d9f01f89c8d9a1454c990b9530c3
```

La consigna indica que deben estar cargadas las tablas del módulo anterior, pero no identifica una descarga ni un archivo de datos concreto. La Preentrega 3 local trabajaba con una tabla de productos para practicar nulos. Se declara expresamente el dataset de clases usado en esta solución; no se afirma que sea una descarga específica u obligatoria de la Preentrega 4.

El archivo de clases tiene las relaciones necesarias, pero registra las compras en `pedidos` y `detalle_pedidos`. Para alinearlo con la denominación `ventas` de la consigna se crea la vista `preentrega_4.ventas`. Una vista muestra información existente mediante una consulta: no agrega registros a las tablas originales.

## Definición de compra e ingresos

Se consideran compras completadas únicamente los pedidos cuyo `estado = 'Completado'`. Se excluyen pedidos cancelados, enviados y en proceso. Por lo tanto, un cliente sin compras en el reporte es un cliente sin pedidos completados, aunque tenga pedidos en otros estados.

Cada fila de la vista corresponde a un detalle de pedido completado y conserva el identificador del pedido. Las ocasiones de compra se cuentan con `COUNT(DISTINCT id_pedido)`: dos detalles del mismo producto dentro de un pedido cuentan como una sola ocasión. Las unidades se suman por separado.

El ingreso procede de `detalle_pedidos.subtotal`, calculado en el DDL original como `cantidad * precio_unitario`. No se usa el precio actual del catálogo ni se presume que el total de cabecera sustituya a la suma de los detalles.

La fecha se toma de `pedidos.fecha_pedido`, conservando la hora original. No se usa `pedidos.fecha`, que recibe la fecha de carga por su valor predeterminado `CURRENT_DATE`.

La fuente no identifica una divisa. Los importes se reportan como unidades monetarias del dataset, sin asignar ARS, USD u otra moneda ni convertir entre países. Aunque la consigna denomina rentabilidad a la primera consulta, se calcula ingreso y no ganancia neta, porque no hay costos.

## Ejecución en DBeaver

### Si ya está cargada la base tienda

1. Conectarse a la base `tienda`, donde están las nueve tablas del DDL en `public`.
2. Ejecutar completo `preparar-vista-ventas.sql` como script con **Alt+X**.
3. Ejecutar completo `pre-entrega-modulo4.sql` como script con **Alt+X**.
4. Revisar los tres resultados y compararlos con `resultados-verificados.txt`.

No volver a ejecutar los INSERT del dataset si ya se cargaron. La adaptación de la vista y las tres consultas pueden repetirse. No se modifican las bases `retail_project` ni las entregas anteriores.

### Para reproducir desde una base vacía

1. Crear una base de práctica vacía y conectarse a ella. El nombre recomendado es `tienda`, pero el SQL funciona en otra base vacía.
2. Seleccionar `public` como esquema activo.
3. Ejecutar `dataset/ddl-tienda.sql` con **Alt+X**. Crea nueve tablas y carga los datos originales en el orden de sus referencias. La línea de creación de base del archivo original está comentada.
4. Ejecutar `preparar-vista-ventas.sql`.
5. Ejecutar `pre-entrega-modulo4.sql`.

El usuario de conexión necesita poder crear tablas en public y un esquema/vista para la adaptación.

### Ejecución equivalente en psql

Con la base creada y vacía, desde la carpeta del repositorio:

```text
psql -h localhost -U postgres -d tienda -v ON_ERROR_STOP=1 -c "SET search_path TO public;" -f dataset/ddl-tienda.sql
psql -h localhost -U postgres -d tienda -v ON_ERROR_STOP=1 -f preparar-vista-ventas.sql
psql -h localhost -U postgres -d tienda -v ON_ERROR_STOP=1 -f pre-entrega-modulo4.sql
```

Si los datos ya están cargados, ejecutar solo los dos últimos comandos. La autenticación corresponde a la configuración local de PostgreSQL.

## Consulta 1: rentabilidad por categoría

Combina `ventas`, `productos` y `categorias`. Agrupa por identificador y nombre de categoría, suma unidades e ingresos y aplica `HAVING` con un ingreso estrictamente mayor a **10000.00**. Sirve para identificar las categorías que más contribuyen a los ingresos.

| Categoría | Unidades vendidas | Ingreso total |
| --- | ---: | ---: |
| Electrónica | 203 | 137055.43 |
| Hogar y Decoración | 114 | 32123.63 |
| Deportes y Outdoors | 94 | 24509.36 |
| Ropa y Calzado | 126 | 18370.26 |

Las otras cuatro categorías quedan fuera del umbral, sin eliminar sus datos.

## Consulta 2: clientes escurridizos

Utiliza `LEFT JOIN` entre clientes y ventas y selecciona la falta de coincidencia con `WHERE v.id_venta IS NULL`. `COALESCE` presenta cero unidades compradas. Permite identificar destinatarios de una campaña de primera compra.

Resultado: **27 clientes sin compras completadas**. Sus nombres y correos son los del archivo original. Entre ellos aparecen Martín García, Santiago Martínez y Catalina Torres. La lista completa está en el registro de resultados.

## Consulta 3: top de compras por cliente

Cubre tanto la consigna detallada como la rúbrica:

- Agrupa por cliente y calcula ingreso total, número de pedidos completados y última transacción.
- Añade `DENSE_RANK` por ingreso total de cliente, con igual posición ante ingresos iguales y sin saltos.
- Identifica el producto comprado en más ocasiones, usando el número de pedidos distintos.
- Conserva todos los favoritos empatados.
- Muestra unidades y última compra del favorito por separado.
- La última transacción del cliente considera todos sus productos, no solo el favorito.

El resultado contiene **263 filas para 73 clientes compradores**: hay más filas que clientes porque varios tienen favoritos empatados. Los clientes sin compras se presentan en la consulta 2.

La primera posición corresponde a Verónica Torres, con ingreso acumulado de **21945.47**. Tiene dos favoritos con dos ocasiones de compra cada uno: Laptop HP ProBook 450 y Café Origen Etiopía 250g. Su última transacción es **2024-08-13 10:28:00**.

## Correspondencia con los criterios

| Criterio | Implementación |
| --- | --- |
| Rentabilidad por categoría | Consulta 1: JOIN de tres relaciones, SUM, GROUP BY y HAVING |
| Clientes escurridizos | Consulta 2: LEFT JOIN, ausencia de venta y COALESCE |
| Top ranking | Consulta 3: agrupación por cliente y ranking por ingreso, más producto favorito y última transacción |
| Comentarios y documentación | Pregunta de negocio y decisiones explicadas antes de cada consulta; origen de datos documentado |
| Estructura y cumplimiento | Script principal con el nombre solicitado, archivos auxiliares separados y orden de ejecución explícito |

Todas las tablas y subconsultas tienen alias. Los bloques que calculan agregados contienen GROUP BY. Los filtros sobre SUM y COUNT se aplican con HAVING. La vista de ventas se construye desde pedidos y detalles originales; se documenta esa equivalencia para mantener el dato de origen.

## Verificación

Se ejecutaron el DDL original, la adaptación y las tres consultas en PostgreSQL 18.6, en una instancia temporal separada de las bases del usuario. Se comprobó:

- Igualdad byte por byte entre el dataset original y la copia incluida.
- Carga de 100 clientes, 39 productos, 8 categorías, 200 pedidos y 597 detalles.
- Vista con 374 detalles correspondientes a 124 pedidos completados.
- Coincidencia de las tres consultas con un cálculo independiente sobre todas las filas originales.
- Conservación del contenido de las nueve tablas después de ejecutar la vista y los reportes.
- Resultados estables al repetir las consultas y recrear la vista.

Estas comprobaciones verifican la ejecución técnica; no constituyen una calificación del corrector académico. La publicación del repositorio y el envío de su URL quedan a cargo de la instancia de entrega.

## Entregas anteriores

La [Preentrega 2](preentrega_2/README.md) se conserva en la carpeta `preentrega_2`, con su script y README originales. La entrega actual de este repositorio es la Preentrega 4, disponible en la raíz.
