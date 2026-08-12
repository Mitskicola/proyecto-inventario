-- 1. Cursor para Generar Reporte de Productos Bajo Stock Mínimo
CREATE OR REPLACE PROCEDURE sp_cursor_productos_bajo_stock AS
    CURSOR cur_productos IS
        SELECT p.nombre, p.stock_minimo, fn_obtener_stock_total(p.id_producto) AS actual
        FROM productos p
        WHERE p.estado = 'ACTIVO';
    v_registro cur_productos%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== ALERTA DE REABASTECIMIENTO DE PRODUCTOS ===');
    OPEN cur_productos;
    LOOP
        FETCH cur_productos INTO v_registro;
        EXIT WHEN cur_productos%NOTFOUND;
        
        IF v_registro.actual <= v_registro.stock_minimo THEN
            DBMS_OUTPUT.PUT_LINE('ALERTA: Producto: ' || v_registro.nombre || 
                                 ' | Stock Actual: ' || v_registro.actual || 
                                 ' | Mínimo Requerido: ' || v_registro.stock_minimo);
        END IF;
    END LOOP;
    CLOSE cur_productos;
END sp_cursor_productos_bajo_stock;
/

-- 2. Cursor para Aplicar Descuento a Productos con Inventario Antiguo
CREATE OR REPLACE PROCEDURE sp_cursor_depreciar_precios AS
    CURSOR cur_sin_movimiento IS
        SELECT ib.id_producto, ib.stock_actual, ib.ultima_actualizacion
        FROM inventario_bodega ib
        WHERE ib.ultima_actualizacion < SYSDATE - 180;
    v_rec cur_sin_movimiento%ROWTYPE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('=== APLICANDO DESCUENTO POR INACTIVIDAD ===');
    OPEN cur_sin_movimiento;
    LOOP
        FETCH cur_sin_movimiento INTO v_rec;
        EXIT WHEN cur_sin_movimiento%NOTFOUND;
        
        UPDATE productos 
        SET precio_venta = precio_venta * 0.90
        WHERE id_producto = v_rec.id_producto;
        
        DBMS_OUTPUT.PUT_LINE('Producto ID: ' || v_rec.id_producto || 
                             ' | Aplicado 10% de descuento por inactividad desde: ' || TO_CHAR(v_rec.ultima_actualizacion, 'YYYY-MM-DD'));
    END LOOP;
    CLOSE cur_sin_movimiento;
    COMMIT;
END sp_cursor_depreciar_precios;
/