SET DEFINE OFF;

-- 1. Registrar una Compra e Incrementar Inventario
CREATE OR REPLACE PROCEDURE sp_registrar_compra(
    p_id_proveedor IN NUMBER,
    p_num_factura IN VARCHAR2,
    p_id_producto IN NUMBER,
    p_id_bodega IN NUMBER,
    p_cantidad IN NUMBER,
    p_precio_unitario IN NUMBER
) AS
    v_id_compra NUMBER;
    v_existe NUMBER := 0;
BEGIN
    INSERT INTO compras (id_proveedor, numero_factura, total)
    VALUES (p_id_proveedor, p_num_factura, (p_cantidad * p_precio_unitario))
    RETURNING id_compra INTO v_id_compra;

    INSERT INTO detalle_compras (id_compra, id_producto, id_bodega, cantidad, precio_unitario)
    VALUES (v_id_compra, p_id_producto, p_id_bodega, p_cantidad, p_precio_unitario);

    SELECT COUNT(*) INTO v_existe 
    FROM inventario_bodega 
    WHERE id_producto = p_id_producto AND id_bodega = p_id_bodega;

    IF v_existe > 0 THEN
        UPDATE inventario_bodega 
        SET stock_actual = stock_actual + p_cantidad,
            ultima_actualizacion = CURRENT_TIMESTAMP
        WHERE id_producto = p_id_producto AND id_bodega = p_id_bodega;
    ELSE
        INSERT INTO inventario_bodega (id_producto, id_bodega, stock_actual)
        VALUES (p_id_producto, p_id_bodega, p_cantidad);
    END IF;
    
    COMMIT;
END sp_registrar_compra;
/

-- 2. Registrar una Venta y Descontar Inventario
CREATE OR REPLACE PROCEDURE sp_registrar_venta(
    p_id_cliente IN NUMBER,
    p_id_empleado IN NUMBER,
    p_num_factura IN VARCHAR2,
    p_id_producto IN NUMBER,
    p_id_bodega IN NUMBER,
    p_cantidad IN NUMBER,
    p_precio_unitario IN NUMBER
) AS
    v_id_venta NUMBER;
    v_stock_disponible NUMBER := 0;
BEGIN
    BEGIN
        SELECT stock_actual INTO v_stock_disponible 
        FROM inventario_bodega 
        WHERE id_producto = p_id_producto AND id_bodega = p_id_bodega;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_stock_disponible := 0;
    END;

    IF v_stock_disponible < p_cantidad THEN
        RAISE_APPLICATION_ERROR(-20001, 'Stock insuficiente en la bodega seleccionada.');
    END IF;

    INSERT INTO ventas (id_cliente, id_empleado, numero_factura, total)
    VALUES (p_id_cliente, p_id_empleado, p_num_factura, (p_cantidad * p_precio_unitario))
    RETURNING id_venta INTO v_id_venta;

    INSERT INTO detalle_ventas (id_venta, id_producto, id_bodega, cantidad, precio_unitario)
    VALUES (v_id_venta, p_id_producto, p_id_bodega, p_cantidad, p_precio_unitario);

    UPDATE inventario_bodega 
    SET stock_actual = stock_actual - p_cantidad,
        ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE id_producto = p_id_producto AND id_bodega = p_id_bodega;

    COMMIT;
END sp_registrar_venta;
/

-- 3. Transferencia de Inventario entre Bodegas
CREATE OR REPLACE PROCEDURE sp_transferir_inventario(
    p_id_producto IN NUMBER,
    p_bodega_origen IN NUMBER,
    p_bodega_destino IN NUMBER,
    p_cantidad IN NUMBER
) AS
    v_stock_origen NUMBER := 0;
    v_existe_destino NUMBER := 0;
BEGIN
    BEGIN
        SELECT stock_actual INTO v_stock_origen 
        FROM inventario_bodega 
        WHERE id_producto = p_id_producto AND id_bodega = p_bodega_origen;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_stock_origen := 0;
    END;

    IF v_stock_origen < p_cantidad THEN
        RAISE_APPLICATION_ERROR(-20002, 'No hay stock suficiente en la bodega de origen.');
    END IF;

    -- Descontar de Origen
    UPDATE inventario_bodega 
    SET stock_actual = stock_actual - p_cantidad,
        ultima_actualizacion = CURRENT_TIMESTAMP
    WHERE id_producto = p_id_producto AND id_bodega = p_bodega_origen;

    -- Aumentar o Insertar en Destino
    SELECT COUNT(*) INTO v_existe_destino 
    FROM inventario_bodega 
    WHERE id_producto = p_id_producto AND id_bodega = p_bodega_destino;

    IF v_existe_destino > 0 THEN
        UPDATE inventario_bodega 
        SET stock_actual = stock_actual + p_cantidad,
            ultima_actualizacion = CURRENT_TIMESTAMP
        WHERE id_producto = p_id_producto AND id_bodega = p_bodega_destino;
    ELSE
        INSERT INTO inventario_bodega (id_producto, id_bodega, stock_actual)
        VALUES (p_id_producto, p_bodega_destino, p_cantidad);
    END IF;

    COMMIT;
END sp_transferir_inventario;
/

-- 4. Actualización Masiva de Precios por Categoría
CREATE OR REPLACE PROCEDURE sp_actualizar_precios_categoria(
    p_id_categoria IN NUMBER,
    p_porcentaje_incremento IN NUMBER
) AS
BEGIN
    UPDATE productos
    SET precio_venta = precio_venta * (1 + (p_porcentaje_incremento / 100))
    WHERE id_categoria = p_id_categoria AND estado = 'ACTIVO';
    
    COMMIT;
END sp_actualizar_precios_categoria;
/

-- 5. Anular Venta y Restablecer Inventario
CREATE OR REPLACE PROCEDURE sp_anular_venta(p_id_venta IN NUMBER) AS
BEGIN
    UPDATE ventas SET estado = 'ANULADA' WHERE id_venta = p_id_venta;

    FOR r_detalle IN (SELECT id_producto, id_bodega, cantidad FROM detalle_ventas WHERE id_venta = p_id_venta)
    LOOP
        UPDATE inventario_bodega 
        SET stock_actual = stock_actual + r_detalle.cantidad,
            ultima_actualizacion = CURRENT_TIMESTAMP
        WHERE id_producto = r_detalle.id_producto AND id_bodega = r_detalle.id_bodega;
    END LOOP;

    COMMIT;
END sp_anular_venta;
/