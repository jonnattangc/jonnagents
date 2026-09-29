# Guía Técnica: Mejores Prácticas de Desarrollo y Arquitectura en Claude Code u otros agentes

Esta guía detalla la arquitectura de extensión de **Claude Code** (Agentes, Skills y Plugins), la matriz de decisión para su uso y las mejores prácticas de ingeniería de software al desarrollar productos con el modelo.

---

## 1. Arquitectura de Componentes: Agentes, Skills y Plugins

### **A. Agente (Subagent)**
Un **Agente** (o Subagente) es un proceso de razonamiento independiente con su propio prompt de sistema, ventana de contexto aislada, asignación de modelo (ej. Haiku para exploración rápida, Sonnet/Opus para refactorización profunda) y un conjunto explícito y restringido de herramientas (`allowed-tools`).

* **¿Para qué sirve?** Para ejecutar tareas ruidosas, complejas o de lectura masiva sin contaminar la ventana de contexto principal de la conversación.
* **Dónde ocuparlo:**
  * Ejecución y análisis de suites de prueba (*test runners*).
  * Auditorías de código y revisiones de seguridad en segundo plano.
  * Mapeo y exploración de bases de código grandes (*codebase mapping*).
  * Refactorizaciones aisladas que generan extensos logs de terminal.

### **B. Skill (Habilidad)**
Una **Skill** es un flujo de trabajo procedimental o guía técnica reutilizable definida dentro de un archivo `SKILL.md`. Define procedimientos paso a paso, listas de verificación o estándares de formato.

* **¿Para qué sirve?** Para estandarizar procesos repetitivos y proporcionarle a Claude contexto instructivo *bajo demanda* (a través de invocaciones explícitas con `/skill-name` o implícitas por coincidencia de contexto).
* **Dónde ocuparlo:**
  * Checklist y plantillas para Pull Requests (PRs).
  * Guías de estilo de código y arquitectura específicas del proyecto.
  * Flujos de trabajo paso a paso (ej. "Cómo crear una migración de base de datos de Prisma").
  * Scripts deterministas de soporte en Bash o Python.

### **C. Plugin**
Un **Plugin** es el **paquete de distribución y empaquetado**. No ejecuta lógica directa en tiempo de conversación; su función es agrupar y distribuir un conjunto de Skills, Subagentes, Hooks y servidores MCP dentro de un repositorio o directorio (`.claude-plugin/plugin.json`).

* **¿Para qué sirve?** Para empaquetar conjuntos completos de herramientas y compartirlos de forma consistente entre equipos de desarrollo o en un marketplace.
* **Dónde ocuparlo:**
  * Compartir estándares de ingeniería entre múltiples repositorios de la empresa.
  * Distribuir integraciones corporativas internas (ej. Plugin de infraestructura AWS + CI/CD + Linter corporativo).

---

## 2. Diagrama de Relación e Invocación