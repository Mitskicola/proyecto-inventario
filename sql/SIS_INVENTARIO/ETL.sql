SET SERVEROUTPUT ON;
SET DEFINE OFF;

-- ============================================================
-- PROCESO ETL - SISTEMA DE GESTIÓN DE INVENTARIOS
-- ============================================================
-- FLUJO:
--
--     BASE OLTP
--        |
--        +--> VENTAS
--        +--> DETALLE_VENTAS
--        +--> PRODUCTOS
--        +--> CATEGORIAS
--        +--> CLIENTES
--        |
--        v
--   TRANSFORMACIÓN
--        |
--        +--> DIM_TIEMPO
--        +--> DIM_PRODUCTO
--        +--> DIM_CLIENTE
--        |
--        v
--    FACT_VENTAS
--        |
--        v
-- MV_RESUMEN_VENTAS_MENSUAL
--
-- No crea tablas nuevas.
-- Utiliza únicamente los objetos existentes.
-- ============================================================


CREATE OR REPLACE PROCEDURE sp_ejecutar_etl
AS

    -- ========================================================
    -- VARIABLES DE CONTROL
    -- ========================================================

    v_registros_tiempo    NUMBER := 0;
    v_registros_producto  NUMBER := 0;
    v_registros_cliente   NUMBER := 0;
    v_registros_fact      NUMBER := 0;

BEGIN

    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('        INICIO DEL PROCESO ETL');
    DBMS_OUTPUT.PUT_LINE('==============================================');


    -- ========================================================
    -- 1. CARGA DE DIM_TIEMPO
    -- ========================================================
    -- Se obtiene la fecha desde VENTAS.FECHA_VENTA.
    --
    -- Solo se inserta una fecha si todavía no existe.
    -- ========================================================

    INSERT INTO dim_tiempo (
        fecha,
        anio,
        trimestre,
        mes,
        nombre_mes,
        dia
    )
    SELECT DISTINCT
        TRUNC(CAST(v.fecha_venta AS DATE)) AS fecha,

        EXTRACT(
            YEAR FROM CAST(v.fecha_venta AS DATE)
        ) AS anio,

        TO_NUMBER(
            TO_CHAR(
                CAST(v.fecha_venta AS DATE),
                'Q'
            )
        ) AS trimestre,

        EXTRACT(
            MONTH FROM CAST(v.fecha_venta AS DATE)
        ) AS mes,

        TO_CHAR(
            CAST(v.fecha_venta AS DATE),
            'MONTH',
            'NLS_DATE_LANGUAGE=SPANISH'
        ) AS nombre_mes,

        EXTRACT(
            DAY FROM CAST(v.fecha_venta AS DATE)
        ) AS dia

    FROM ventas v

    WHERE v.fecha_venta IS NOT NULL

      -- Evitar fechas repetidas
      AND NOT EXISTS (
          SELECT 1
          FROM dim_tiempo dt
          WHERE dt.fecha =
                TRUNC(CAST(v.fecha_venta AS DATE))
      );


    v_registros_tiempo := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(
        'DIM_TIEMPO: ' ||
        v_registros_tiempo ||
        ' registros nuevos.'
    );


    -- ========================================================
    -- 2. CARGA DE DIM_PRODUCTO
    -- ========================================================
    -- Relaciona:
    --
    -- PRODUCTOS
    --     |
    -- CATEGORIAS
    --
    -- Se utiliza id_producto_oltp para conservar la
    -- correspondencia con la base transaccional.
    -- ========================================================

    MERGE INTO dim_producto dp

    USING (
        SELECT
            p.id_producto,
            p.nombre,
            NVL(c.nombre, 'SIN CATEGORIA') AS categoria,
            p.precio_venta
        FROM productos p

        LEFT JOIN categorias c
            ON p.id_categoria = c.id_categoria

        WHERE p.estado = 'ACTIVO'
    ) origen

    ON (
        dp.id_producto_oltp = origen.id_producto
    )

    WHEN MATCHED THEN

        UPDATE SET
            dp.nombre_producto = origen.nombre,
            dp.categoria       = origen.categoria,
            dp.precio_actual   = origen.precio_venta

    WHEN NOT MATCHED THEN

        INSERT (
            id_producto_oltp,
            nombre_producto,
            categoria,
            precio_actual
        )

        VALUES (
            origen.id_producto,
            origen.nombre,
            origen.categoria,
            origen.precio_venta
        );


    v_registros_producto := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(
        'DIM_PRODUCTO: ' ||
        v_registros_producto ||
        ' registros procesados.'
    );


    -- ========================================================
    -- 3. CARGA DE DIM_CLIENTE
    -- ========================================================
    -- Se obtiene:
    --
    -- ID del cliente
    -- Nombres
    -- Apellidos
    -- Identificación
    --
    -- Se utiliza MERGE para insertar nuevos clientes y
    -- actualizar información de clientes existentes.
    -- ========================================================

    MERGE INTO dim_cliente dc

    USING (
        SELECT
            id_cliente,
            TRIM(
                nombres || ' ' || apellidos
            ) AS nombre_completo,
            identificacion
        FROM clientes
    ) origen

    ON (
        dc.id_cliente_oltp = origen.id_cliente
    )

    WHEN MATCHED THEN

        UPDATE SET
            dc.nombre_completo = origen.nombre_completo,
            dc.identificacion   = origen.identificacion

    WHEN NOT MATCHED THEN

        INSERT (
            id_cliente_oltp,
            nombre_completo,
            identificacion
        )

        VALUES (
            origen.id_cliente,
            origen.nombre_completo,
            origen.identificacion
        );


    v_registros_cliente := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(
        'DIM_CLIENTE: ' ||
        v_registros_cliente ||
        ' registros procesados.'
    );


    -- ========================================================
    -- 4. CARGA DE FACT_VENTAS
    -- ========================================================
    --
    -- NIVEL DE DETALLE:
    -- Una fila representa un detalle de una venta.
    --
    -- La información proviene de:
    --
    -- VENTAS
    --      |
    -- DETALLE_VENTAS
    --      |
    --      +--> PRODUCTOS
    --      |
    --      +--> DIM_PRODUCTO
    --      |
    --      +--> DIM_CLIENTE
    --      |
    --      +--> DIM_TIEMPO
    --
    -- No se cargan ventas ANULADAS.
    -- ========================================================

    INSERT INTO fact_ventas (
        id_tiempo,
        id_dim_producto,
        id_dim_cliente,
        cantidad_vendida,
        monto_total
    )

    SELECT

        dt.id_tiempo,

        dp.id_dim_producto,

        dc.id_dim_cliente,

        dv.cantidad,

        NVL(
            dv.subtotal,
            dv.cantidad * dv.precio_unitario
        )

    FROM ventas v

    INNER JOIN detalle_ventas dv
        ON v.id_venta = dv.id_venta

    INNER JOIN dim_tiempo dt
        ON dt.fecha =
           TRUNC(
               CAST(v.fecha_venta AS DATE)
           )

    INNER JOIN dim_producto dp
        ON dp.id_producto_oltp =
           dv.id_producto

    INNER JOIN dim_cliente dc
        ON dc.id_cliente_oltp =
           v.id_cliente

    WHERE v.estado <> 'ANULADA'

      AND v.fecha_venta IS NOT NULL

      -- ======================================================
      -- EVITAR DUPLICADOS
      -- ======================================================
      --
      -- Como FACT_VENTAS original no tiene el ID del detalle
      -- de venta, se utiliza la combinación de información
      -- disponible en el modelo existente.
      --
      -- Se compara:
      -- fecha + producto + cliente + cantidad + precio
      --
      -- para evitar volver a cargar exactamente el mismo
      -- registro.
      -- ======================================================

      AND NOT EXISTS (

          SELECT 1

          FROM fact_ventas f

          INNER JOIN dim_tiempo dt2
              ON f.id_tiempo = dt2.id_tiempo

          INNER JOIN dim_producto dp2
              ON f.id_dim_producto =
                 dp2.id_dim_producto

          INNER JOIN dim_cliente dc2
              ON f.id_dim_cliente =
                 dc2.id_dim_cliente

          WHERE dt2.fecha =
                TRUNC(
                    CAST(v.fecha_venta AS DATE)
                )

            AND dp2.id_producto_oltp =
                dv.id_producto

            AND dc2.id_cliente_oltp =
                v.id_cliente

            AND f.cantidad_vendida =
                dv.cantidad

            AND f.monto_total =
                NVL(
                    dv.subtotal,
                    dv.cantidad * dv.precio_unitario
                )
      );


    v_registros_fact := SQL%ROWCOUNT;

    DBMS_OUTPUT.PUT_LINE(
        'FACT_VENTAS: ' ||
        v_registros_fact ||
        ' registros nuevos.'
    );


    -- ========================================================
    -- 5. ACTUALIZAR VISTA MATERIALIZADA
    -- ========================================================
    --
    -- Tu vista materializada fue creada como:
    --
    -- REFRESH COMPLETE ON DEMAND
    --
    -- Por lo tanto, después del ETL se ejecuta un refresh
    -- completo.
    -- ========================================================

    DBMS_MVIEW.REFRESH(
        'MV_RESUMEN_VENTAS_MENSUAL',
        'C'
    );


    DBMS_OUTPUT.PUT_LINE(
        'MV_RESUMEN_VENTAS_MENSUAL: ACTUALIZADA.'
    );


    -- ========================================================
    -- 6. CONFIRMAR TRANSACCIÓN
    -- ========================================================

    COMMIT;


    -- ========================================================
    -- 7. MENSAJE FINAL
    -- ========================================================

    DBMS_OUTPUT.PUT_LINE('==============================================');
    DBMS_OUTPUT.PUT_LINE('        ETL EJECUTADO CORRECTAMENTE');
    DBMS_OUTPUT.PUT_LINE('==============================================');

    DBMS_OUTPUT.PUT_LINE(
        'Fechas nuevas       : ' ||
        v_registros_tiempo
    );

    DBMS_OUTPUT.PUT_LINE(
        'Productos procesados: ' ||
        v_registros_producto
    );

    DBMS_OUTPUT.PUT_LINE(
        'Clientes procesados : ' ||
        v_registros_cliente
    );

    DBMS_OUTPUT.PUT_LINE(
        'Ventas nuevas       : ' ||
        v_registros_fact
    );

    DBMS_OUTPUT.PUT_LINE('==============================================');


EXCEPTION

    -- ========================================================
    -- MANEJO DE ERRORES
    -- ========================================================

    WHEN OTHERS THEN

        ROLLBACK;

        DBMS_OUTPUT.PUT_LINE('==============================================');
        DBMS_OUTPUT.PUT_LINE('             ERROR EN EL PROCESO ETL');
        DBMS_OUTPUT.PUT_LINE('==============================================');

        DBMS_OUTPUT.PUT_LINE(
            'Código de error: ' ||
            SQLCODE
        );

        DBMS_OUTPUT.PUT_LINE(
            'Mensaje: ' ||
            SQLERRM
        );

        DBMS_OUTPUT.PUT_LINE('==============================================');

        RAISE;

END sp_ejecutar_etl;
/



BEGIN
    sp_ejecutar_etl;
END;
/



