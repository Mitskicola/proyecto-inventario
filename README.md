# Sistema de Gestión de Inventarios
Repositorio académico que documenta el desarrollo y la implementación de un sistema de gestión de inventarios. Este proyecto aborda desde la estructuración de la base de datos relacional hasta la implementación de procesos de integración para análisis de datos.

## Descripción Técnica
El sistema ha sido diseñado para gestionar las operaciones diarias de inventario, asegurando la integridad de la información mediante disparadores (triggers) y procedimientos almacenados. Se incluye una arquitectura orientada a Data Warehouse mediante el uso de vistas materializadas para la reportería.

## Contenido de la carpeta SIS_INVENTARIO
Los archivos contenidos en este directorio representan los componentes fundamentales de la base de datos:
* cursores.sql: Definición de cursores para el procesamiento de registros.
* ETL.sql: Scripts destinados al proceso de extracción, transformación y carga (ETL).
* Triggers.sql: Lógica de automatización para el control de stock y auditoría.
* Procedimientos_Almacenados.sql: Rutinas para la ejecución de transacciones complejas.
* DATAWAREHOUSE_VISTAMATERIALIZADA.sql: Estructuras optimizadas para consultas analíticas.
* Funcionesl.sql: Funciones auxiliares para la lógica del sistema.
* Tablas_Registros.sql: Esquema de tablas y registros iniciales.
* PRUBASS.sql: Scripts de validación y pruebas.
* logs.json: Archivos de registro de auditoría del sistema.
* 
## Tecnologías
- Base de Datos: Oracle.
- Procesamiento: SQL y Python (para integración ETL).
- Entorno: Proyecto desarrollado para la carrera de Ingeniería en Computación.
