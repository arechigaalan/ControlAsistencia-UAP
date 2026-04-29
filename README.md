# 📱 Asistencia QR

Aplicación móvil desarrollada en Flutter para el registro de asistencia mediante códigos QR en instituciones educativas.

---

## 🎯 Objetivo

Facilitar el registro de asistencia de alumnos de forma rápida, precisa y organizada, eliminando procesos manuales y permitiendo un control eficiente por sesiones, grupos y parciales.

---

## 🚀 Funcionalidades principales

### 📷 Escaneo de asistencia
- Registro de alumnos mediante códigos QR.
- Validación automática de:
  - Grupo
  - Semestre
- Prevención de duplicados en la misma sesión.
- Feedback visual inmediato (éxito, error, duplicado).

---

### 🗂️ Gestión de sesiones
- Cada toma de asistencia se registra como una sesión independiente.
- Visualización de sesiones agrupadas por fecha y parcial.
- Posibilidad de continuar sesiones previas.

---

### 🧾 Justificación de faltas
- Permite justificar alumnos desde sesiones registradas.
- Las asistencias justificadas cuentan como asistencia válida.

---

### 📊 Estadísticas por grupo
- Cálculo automático por parcial:
  - Total de sesiones
  - Asistencias
  - Faltas
  - Porcentaje de asistencia
- Vista detallada por alumno:
  - Historial por día
  - Indicador de asistencia, falta o justificación

---

### 🗓️ Configuración de parciales
- Definición de rangos de fechas por parcial.
- Cálculo automático del parcial en cada asistencia.
- Validaciones:
  - Fechas obligatorias
  - Sin solapamientos
  - Orden cronológico correcto

---

### 📁 Exportación de datos
- Generación de archivo CSV con todos los registros.
- Estructura optimizada para análisis externo.

---

### 🧹 Gestión de datos
- Eliminación total de registros con confirmación segura.
- Reinicio completo de la aplicación (incluye configuración de parciales).

---

## 🧠 Lógica del sistema

- Cada escaneo genera un registro único asociado a:
  - Alumno
  - Sesión
  - Fecha de clase
- El sistema detecta automáticamente:
  - Grupo del alumno
  - Turno
  - Modalidad
  - Parcial correspondiente
- La asistencia se calcula considerando:
  - ✔ Asistencia
  - ✔ Justificada
  - ✖ Falta

---

## 🎨 Interfaz

- Diseño moderno con enfoque en claridad visual.
- Feedback inmediato para el usuario durante el escaneo.
- Componentes optimizados para dispositivos móviles.
- Uso de colores semánticos:
  - Verde: éxito
  - Rojo: error/falta
  - Amarillo: advertencia/justificación

---

## 🏫 Contexto de uso

Pensada para docentes que requieren:

- Registro rápido en clase
- Control por grupo y parcial
- Seguimiento detallado de asistencia
- Exportación de información para reportes

---

## 📌 Notas

- La aplicación funciona completamente de manera local.
- No requiere conexión a internet para su uso.
- Está diseñada para operar en dispositivos móviles con cámara.

---

## ✍️ Autor

Desarrollado como herramienta académica para optimizar el control de asistencia en entornos educativos.

---