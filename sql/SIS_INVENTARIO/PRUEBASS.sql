-- =========================================================
-- CONFIGURACIÓN DE ORACLE SQL DEVELOPER
-- =========================================================

SET SERVEROUTPUT ON;
SET DEFINE OFF;


-- =========================================================
-- PRUEBA 1: FUNCIONES
-- =========================================================

-- 1.1 Verificar el stock total y el estado de cada producto.
-- La función FN_OBTENER_STOCK_TOTAL suma el stock disponible
-- del producto en las diferentes bodegas.
--
-- La función FN_ESTADO_STOCK_PRODUCTO determina si el producto
-- se encuentra NORMAL, CRÍTICO o AGOTADO.

SELECT 
    p.id_producto,
    p.nombre AS producto,
    fn_obtener_stock_total(p.id_producto) AS stock_total_calculado,
    fn_estado_stock_producto(p.id_producto) AS estado_stock
FROM productos p
ORDER BY p.id_producto;


-- 1.2 Calcular el valor financiero total del inventario.

SELECT 
    fn_valor_inventario_total() AS valor_total_inventario
FROM DUAL;



-- =========================================================
-- PRUEBA 2: PROCEDIMIENTO SP_REGISTRAR_COMPRA
-- =========================================================

-- El procedimiento debe:
-- 1. Crear el registro en COMPRAS.
-- 2. Crear el detalle en DETALLE_COMPRAS.
-- 3. Incrementar el stock de INVENTARIO_BODEGA.
-- 4. El trigger TRG_RECALCULAR_TOTAL_COMPRA
--    debe actualizar el total de la compra.

BEGIN
    sp_registrar_compra(
        p_id_proveedor    => 1,
        p_num_factura     => 'FAC-C003',
        p_id_producto     => 1,
        p_id_bodega       => 1,
        p_cantidad        => 5,
        p_precio_unitario => 900.00
    );
END;
/


-- Verificar la compra registrada.

SELECT *
FROM compras
ORDER BY id_compra DESC;


-- Verificar el detalle de la compra.

SELECT *
FROM detalle_compras
ORDER BY id_detalle_compra DESC;


-- Verificar el stock actualizado del producto 1
-- en la bodega 1.

SELECT *
FROM inventario_bodega
WHERE id_producto = 1
AND id_bodega = 1;


-- Verificar específicamente el total calculado
-- por el trigger.

SELECT
    c.id_compra,
    c.numero_factura,
    c.total,
    dc.cantidad,
    dc.precio_unitario,
    dc.subtotal
FROM compras c
INNER JOIN detalle_compras dc
    ON c.id_compra = dc.id_compra
WHERE c.numero_factura = 'FAC-C003';



-- =========================================================
-- PRUEBA 3: PROCEDIMIENTO SP_REGISTRAR_VENTA
-- =========================================================

-- El procedimiento debe:
-- 1. Verificar que exista stock suficiente.
-- 2. Registrar la venta.
-- 3. Registrar el detalle de venta.
-- 4. Descontar el stock de la bodega.

-- Consultar el stock antes de la venta.

SELECT *
FROM inventario_bodega
WHERE id_producto = 2
AND id_bodega = 1;


-- Registrar la venta.

BEGIN
    sp_registrar_compra(
        p_id_proveedor    => 1,
        p_num_factura     => 'FAC-V005',
        p_id_producto     => 2,
        p_id_bodega       => 1,
        p_cantidad        => 2,
        p_precio_unitario => 20.00
    );
END;
/


-- Verificar la venta registrada.

SELECT *
FROM ventas
WHERE numero_factura = 'FAC-V005';


-- Verificar el detalle de la venta.

SELECT *
FROM detalle_ventas
WHERE id_venta = (
    SELECT id_venta
    FROM ventas
    WHERE numero_factura = 'FAC-V005'
);


-- Verificar el stock después de la venta.

SELECT *
FROM inventario_bodega
WHERE id_producto = 2
AND id_bodega = 1;



-- =========================================================
-- PRUEBA 4: VALIDACIÓN DE STOCK INSUFICIENTE
-- =========================================================

-- Se intenta registrar una venta con una cantidad
-- superior al stock disponible.
--
-- El procedimiento debe rechazar la operación y generar
-- el error ORA-20001.

BEGIN

    sp_registrar_venta(
        1,
        1,
        'FAC-V-ERROR',
        2,
        1,
        999999,
        20.00
    );

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ÉXITO - VALIDACIÓN DE STOCK: ' || SQLERRM
        );
END;
/



-- =========================================================
-- PRUEBA 5: TRIGGER DE AUDITORÍA DE INVENTARIO
-- =========================================================

-- Primero consultar el inventario actual.

SELECT *
FROM inventario_bodega
WHERE id_producto = 3
AND id_bodega = 1;


-- Modificar manualmente el stock.
--
-- El trigger TRG_AUDITORIA_INVENTARIO debe registrar
-- el cambio realizado.

UPDATE inventario_bodega
SET stock_actual = 15
WHERE id_producto = 3
AND id_bodega = 1;


-- Consultar los registros generados por la auditoría.

SELECT *
FROM auditoria_inventario
ORDER BY id_auditoria DESC;



-- =========================================================
-- PRUEBA 6: TRIGGER DE VALIDACIÓN DE PRECIO
-- =========================================================

-- El trigger TRG_VALIDAR_PRECIO_PRODUCTO
-- impide que el precio de venta sea menor o igual
-- al precio de compra.

-- Primero consultar los valores actuales.

SELECT
    id_producto,
    nombre,
    precio_compra,
    precio_venta
FROM productos
WHERE id_producto = 2;


-- Intentar establecer un precio de venta menor
-- al precio de compra.
-- El error es INTENCIONAL y demuestra que el trigger funciona.

BEGIN

    UPDATE productos
    SET precio_venta = 5.00
    WHERE id_producto = 2;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ÉXITO - TRIGGER DE PRECIO CAPTURÓ EL ERROR: '
            || SQLERRM
        );

END;
/



-- =========================================================
-- PRUEBA 7: PROCEDIMIENTO SP_TRANSFERIR_INVENTARIO
-- =========================================================

-- Transferir 2 unidades del producto 2
-- desde la bodega 1 hacia la bodega 2.
-- Consultar el stock antes de la transferencia.

SELECT
    id_producto,
    id_bodega,
    stock_actual
FROM inventario_bodega
WHERE id_producto = 2
AND id_bodega IN (1, 2)
ORDER BY id_bodega;


-- Ejecutar la transferencia.
BEGIN
sp_transferir_inventario(
    2,
    1,
    2,
    2
);s
END;
/

-- Verificar el stock después de la transferencia.

SELECT
    id_producto,
    id_bodega,
    stock_actual
FROM inventario_bodega
WHERE id_producto = 2
AND id_bodega IN (1, 2)
ORDER BY id_bodega;



-- =========================================================
-- PRUEBA 8: TRANSFERENCIA CON STOCK INSUFICIENTE
-- =========================================================
-- Intentar transferir una cantidad superior
-- al stock disponible.

BEGIN

    sp_transferir_inventario(
        2,
        1,
        2,
        999999
    );

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(
            'ÉXITO - VALIDACIÓN DE TRANSFERENCIA: '
            || SQLERRM
        );

END;
/



-- =========================================================
-- PRUEBA 9: SP_ACTUALIZAR_PRECIOS_CATEGORIA
-- =========================================================
-- Consultar los productos pertenecientes a la categoría 3
-- antes de modificar sus precios.

SELECT
    id_producto,
    nombre,
    id_categoria,
    precio_compra,
    precio_venta
FROM productos
WHERE id_categoria = 3
ORDER BY id_producto;


-- Incrementar en 10% el precio de venta
-- de los productos activos de la categoría 3.
BEGIN
 sp_actualizar_precios_categoria(
    3,
    10
);
END;
/


-- Verificar los precios después de la actualización.

SELECT
    id_producto,
    nombre,
    id_categoria,
    precio_compra,
    precio_venta
FROM productos
WHERE id_categoria = 3
ORDER BY id_producto;



-- =========================================================
-- PRUEBA 10: CURSOR DE PRODUCTOS BAJO STOCK
-- =========================================================

-- Activar salida de DBMS_OUTPUT.
SET SERVEROUTPUT ON;
-- Ejecutar el cursor.
-- Debe mostrar los productos cuyo stock total
-- sea menor o igual al stock mínimo.

EXEC sp_cursor_productos_bajo_stock;



-- =========================================================
-- PRUEBA 11: CURSOR DE DEPRECIACIÓN DE PRECIOS
-- =========================================================

-- Ejecutar el segundo cursor.
-- Este procedimiento identifica inventario antiguo
-- y aplica la depreciación definida en el proyecto.

EXEC sp_cursor_depreciar_precios;


-- =========================================================
-- PRUEBA 12: ANULACIÓN DE VENTA
-- =========================================================

-- Buscar la venta creada en la prueba anterior.

SELECT
    id_venta,
    id_cliente,
    id_empleado,
    numero_factura,
    total,
    estado
FROM ventas
WHERE numero_factura = 'FAC-V005';


-- Consultar el detalle de dicha venta.

SELECT *
FROM detalle_ventas
WHERE id_venta = (
    SELECT id_venta
    FROM ventas
    WHERE numero_factura = 'FAC-V005'
);


-- Consultar el inventario antes de la anulación.

SELECT *
FROM inventario_bodega
WHERE id_producto = 2
AND id_bodega = 1;


-- Anular la venta.
--
-- Se utiliza la venta FAC-V005 creada durante esta prueba,
-- evitando asumir que la venta número 1 corresponde
-- a nuestra prueba.

DECLARE
    v_id_venta ventas.id_venta%TYPE;
BEGIN
    SELECT id_venta
    INTO v_id_venta
    FROM ventas
    WHERE numero_factura = 'FAC-V005';

    sp_anular_venta(v_id_venta);
END;
/


-- Verificar que la venta quedó ANULADA.

SELECT
    id_venta,
    numero_factura,
    total,
    estado
FROM ventas
WHERE numero_factura = 'FAC-V005';


-- Verificar que el inventario fue restituido.

SELECT *
FROM inventario_bodega
WHERE id_producto = 2
AND id_bodega = 1;



-- =========================================================
-- PRUEBA 13: VERIFICACIÓN DEL DATA WAREHOUSE
-- =========================================================

-- Verificar la dimensión de tiempo.

SELECT *
FROM dim_tiempo
ORDER BY fecha;


-- Verificar la dimensión de productos.

SELECT *
FROM dim_producto
ORDER BY id_dim_producto;


-- Verificar la dimensión de clientes.

SELECT *
FROM dim_cliente
ORDER BY id_dim_cliente;


-- Verificar la tabla de hechos.

SELECT *
FROM fact_ventas
ORDER BY id_fact_venta;



-- =========================================================
-- PRUEBA 14: CONSULTA INTEGRADA DEL DATA WAREHOUSE
-- =========================================================

-- Relacionar la tabla de hechos con sus dimensiones.

SELECT
    t.fecha,
    p.nombre_producto,
    p.categoria,
    c.nombre_completo,
    f.cantidad_vendida,
    f.monto_total
FROM fact_ventas f

INNER JOIN dim_tiempo t
    ON f.id_tiempo = t.id_tiempo

INNER JOIN dim_producto p
    ON f.id_dim_producto = p.id_dim_producto

INNER JOIN dim_cliente c
    ON f.id_dim_cliente = c.id_dim_cliente

ORDER BY t.fecha;

-- =========================================================
-- PRUEBA 15: VISTA MATERIALIZADA
-- =========================================================
-- Consultar el resumen mensual de ventas.
SELECT
    nombre_producto,
    categoria,
    anio,
    nombre_mes,
    total_unidades,
    total_ingresos
FROM mv_resumen_ventas_mensual
ORDER BY
    anio,
    nombre_mes,
    total_ingresos DESC;



-- =========================================================
-- PRUEBA 16: VERIFICACIÓN DE OBJETOS DEL PROYECTO
-- =========================================================

-- Comprobar que procedimientos, funciones y triggers
-- se encuentran correctamente compilados.

SELECT
    object_name,
    object_type,
    status
FROM user_objects
WHERE object_name IN (

    'SP_REGISTRAR_COMPRA',
    'SP_REGISTRAR_VENTA',
    'SP_TRANSFERIR_INVENTARIO',
    'SP_ACTUALIZAR_PRECIOS_CATEGORIA',
    'SP_ANULAR_VENTA',

    'FN_OBTENER_STOCK_TOTAL',
    'FN_VALOR_INVENTARIO_TOTAL',
    'FN_ESTADO_STOCK_PRODUCTO',

    'SP_CURSOR_PRODUCTOS_BAJO_STOCK',
    'SP_CURSOR_DEPRECIAR_PRECIOS',

    'TRG_AUDITORIA_INVENTARIO',
    'TRG_VALIDAR_PRECIO_PRODUCTO',
    'TRG_RECALCULAR_TOTAL_COMPRA'

)
ORDER BY object_type, object_name;



-- =========================================================
-- FINALIZACIÓN
-- =========================================================

COMMIT;