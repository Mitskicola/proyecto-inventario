SET DEFINE OFF;

-- =========================================================
-- 1. ESQUEMA ESTRELLA (DATA WAREHOUSE)
-- =========================================================

CREATE TABLE dim_tiempo (
    id_tiempo NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha DATE NOT NULL,
    anio NUMBER(4) NOT NULL,
    trimestre NUMBER(1) NOT NULL,
    mes NUMBER(2) NOT NULL,
    nombre_mes VARCHAR2(20) NOT NULL,
    dia NUMBER(2) NOT NULL
);
/

CREATE TABLE dim_producto (
    id_dim_producto NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_producto_oltp NUMBER NOT NULL,
    nombre_producto VARCHAR2(100) NOT NULL,
    categoria VARCHAR2(50) NOT NULL,
    precio_actual NUMBER(10,2) NOT NULL
);
/

CREATE TABLE dim_cliente (
    id_dim_cliente NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente_oltp NUMBER NOT NULL,
    nombre_completo VARCHAR2(100) NOT NULL,
    identificacion VARCHAR2(20) NOT NULL
);
/

CREATE TABLE fact_ventas (
    id_fact_venta NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_tiempo NUMBER NOT NULL,
    id_dim_producto NUMBER NOT NULL,
    id_dim_cliente NUMBER NOT NULL,
    cantidad_vendida NUMBER(10) NOT NULL,
    monto_total NUMBER(12,2) NOT NULL,
    CONSTRAINT fk_fact_tiempo FOREIGN KEY (id_tiempo) REFERENCES dim_tiempo(id_tiempo),
    CONSTRAINT fk_fact_producto FOREIGN KEY (id_dim_producto) REFERENCES dim_producto(id_dim_producto),
    CONSTRAINT fk_fact_cliente FOREIGN KEY (id_dim_cliente) REFERENCES dim_cliente(id_dim_cliente)
);
/


-- =========================================================
-- 2. VISTA MATERIALIZADA
-- =========================================================

CREATE MATERIALIZED VIEW mv_resumen_ventas_mensual
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT 
    p.nombre_producto,
    p.categoria,
    t.anio,
    t.nombre_mes,
    SUM(f.cantidad_vendida) AS total_unidades,
    SUM(f.monto_total) AS total_ingresos
FROM fact_ventas f
JOIN dim_producto p ON f.id_dim_producto = p.id_dim_producto
JOIN dim_tiempo t ON f.id_tiempo = t.id_tiempo
GROUP BY p.nombre_producto, p.categoria, t.anio, t.nombre_mes;
/