-- 1. Obtener Stock Total de un Producto en todas las Bodegas
CREATE OR REPLACE FUNCTION fn_obtener_stock_total(p_id_producto IN NUMBER)
RETURN NUMBER AS
    v_total_stock NUMBER := 0;
BEGIN
    SELECT NVL(SUM(stock_actual), 0) INTO v_total_stock
    FROM inventario_bodega
    WHERE id_producto = p_id_producto;
    
    RETURN v_total_stock;
END fn_obtener_stock_total;
/

-- 2. Calcular Valor del Inventario Total
CREATE OR REPLACE FUNCTION fn_valor_inventario_total
RETURN NUMBER AS
    v_valor_total NUMBER(14,2) := 0;
BEGIN
    SELECT NVL(SUM(ib.stock_actual * p.precio_compra), 0) INTO v_valor_total
    FROM inventario_bodega ib
    JOIN productos p ON ib.id_producto = p.id_producto;
    
    RETURN v_valor_total;
END fn_valor_inventario_total;
/

-- 3. Generar Estado de Alerta de Stock
CREATE OR REPLACE FUNCTION fn_estado_stock_producto(p_id_producto IN NUMBER)
RETURN VARCHAR2 AS
    v_stock_total NUMBER := 0;
    v_stock_min NUMBER := 0;
BEGIN
    v_stock_total := fn_obtener_stock_total(p_id_producto);
    
    BEGIN
        SELECT stock_minimo INTO v_stock_min FROM productos WHERE id_producto = p_id_producto;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_stock_min := 0;
    END;

    IF v_stock_total = 0 THEN
        RETURN 'AGOTADO';
    ELSIF v_stock_total <= v_stock_min THEN
        RETURN 'CRÍTICO';
    ELSE
        RETURN 'NORMAL';
    END IF;
END fn_estado_stock_producto;
/