-- 1. Trigger para Auditar Cambios en el Stock
CREATE OR REPLACE TRIGGER trg_auditoria_inventario
AFTER UPDATE ON inventario_bodega
FOR EACH ROW
BEGIN
    IF :OLD.stock_actual <> :NEW.stock_actual THEN
        INSERT INTO auditoria_inventario (id_producto, id_bodega, accion, stock_anterior, stock_nuevo)
        VALUES (:NEW.id_producto, :NEW.id_bodega, 'ACTUALIZACION_STOCK', :OLD.stock_actual, :NEW.stock_actual);
    END IF;
END;
/

-- 2. Trigger para Validar que el Precio de Venta sea mayor al de Compra
CREATE OR REPLACE TRIGGER trg_validar_precio_producto
BEFORE INSERT OR UPDATE ON productos
FOR EACH ROW
BEGIN
    IF :NEW.precio_venta <= :NEW.precio_compra THEN
        RAISE_APPLICATION_ERROR(-20003, 'El precio de venta debe ser estrictamente mayor al precio de compra.');
    END IF;
END;
/

-- 3. Trigger para Recalcular Total de Compra
CREATE OR REPLACE TRIGGER trg_recalcular_total_compra
FOR INSERT OR UPDATE ON detalle_compras
COMPOUND TRIGGER

    TYPE t_compras IS TABLE OF NUMBER
        INDEX BY PLS_INTEGER;

    v_compras t_compras;
    v_contador PLS_INTEGER := 0;

    -- =====================================================
    -- Se ejecuta por cada fila afectada
    -- Solo guardamos el ID de la compra.
    -- No consultamos DETALLE_COMPRAS aquí.
    -- =====================================================
    AFTER EACH ROW IS
    BEGIN

        v_contador := v_contador + 1;
        v_compras(v_contador) := :NEW.id_compra;

    END AFTER EACH ROW;


    -- =====================================================
    -- Se ejecuta cuando termina toda la sentencia.
    -- Aquí ya podemos consultar DETALLE_COMPRAS.
    -- =====================================================
    AFTER STATEMENT IS

        v_total NUMBER;

    BEGIN

        FOR i IN 1 .. v_contador LOOP

            SELECT NVL(SUM(subtotal), 0)
            INTO v_total
            FROM detalle_compras
            WHERE id_compra = v_compras(i);

            UPDATE compras
            SET total = v_total
            WHERE id_compra = v_compras(i);

        END LOOP;

    END AFTER STATEMENT;

END trg_recalcular_total_compra;
/