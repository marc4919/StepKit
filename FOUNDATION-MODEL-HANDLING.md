# Manejo del Foundation Model - Análisis Detallado

Este documento describe en detalle cómo la app maneja la ausencia o indisponibilidad del Foundation Model en cada componente.

## 📋 Índice

1. [ComplexityRouter](#complexityrouter)
2. [FastCreatorView](#fastcreatorview)
3. [TrainerView](#trainerview)
4. [DayInsightView](#dayinsightview)
5. [AssistantService](#assistantservice)

---

## 1. ComplexityRouter

**Ubicación:** `StepKit/Services/ComplexityRouter.swift`

### ¿Qué hace?
Determina si un objetivo requiere el modelo pesado (heavyweight) o ligero (lightweight) usando el Foundation Model.

### ¿Qué devuelve cuando NO hay Foundation Model?

**Valor devuelto:**
```swift
ComplexityResult(
    useHeavyweight: false,  // Siempre usa lightweight por defecto
    confidence: 0,           // Sin confianza (no hubo análisis)
    reasoning: "Default: Foundation model unavailable"
)
```

### Flujo cuando no está disponible:

1. **Verifica disponibilidad ANTES** de intentar usar el modelo:
   ```swift
   guard model.availability == .available else {
       // Retorna valor por defecto inmediatamente
   }
   ```

2. **Si no está disponible:**
   - Retorna `useHeavyweight: false` (siempre lightweight)
   - `confidence: 0` (sin análisis real)
   - `reasoning: "Default: Foundation model unavailable"`
   - Log en consola (solo DEBUG): muestra el estado de disponibilidad

3. **Si está disponible pero falla:**
   - Captura el error en el `catch`
   - Retorna el mismo valor por defecto
   - Log en consola con el error específico

### Impacto:
- ✅ **La app sigue funcionando**: siempre usa lightweight (v2) por defecto
- ✅ **No bloquea la creación de kits**: el usuario puede crear kits normalmente
- ⚠️ **No hay análisis inteligente**: todos los kits usan el mismo modelo

---

## 2. FastCreatorView

**Ubicación:** `StepKit/FastCreatorView.swift`

### ¿Qué hace?
Vista para crear nuevos kits usando IA. Usa `ComplexityRouter` para decidir qué modelo usar.

### ¿Qué pasa cuando NO hay Foundation Model?

**Flujo completo:**

1. **Usuario completa el formulario** y pulsa "Crear kit"

2. **Se llama a `createKit()`** que:
   ```swift
   // 1. Analizar complejidad
   let complexityResult = await ComplexityRouter.shared.analyzeComplexity(
       goal: description,
       dueDate: dueDate,
       obstacles: obstacles
   )
   ```

3. **Si no hay Foundation Model:**
   - `ComplexityRouter` retorna `useHeavyweight: false` inmediatamente
   - **No hay error visible para el usuario**
   - **No hay retraso adicional** (no intenta usar el modelo)

4. **Se crea el request:**
   ```swift
   let request = AIGenerateKitRequest(
       description: description,
       dueDate: dueDate,
       dailyMinutes: dailyMinutes,
       obstacles: obstacles,
       useHeavyweight: false  // ← Siempre false si no hay foundation
   )
   ```

5. **El request se envía al backend:**
   - `promptVersion: 2` (lightweight) en lugar de `1` (heavyweight)
   - El backend usa el modelo ligero (gpt-4.1-mini) en lugar del pesado (gpt-5-mini)

### Experiencia del usuario:

✅ **Funciona normalmente**: el usuario puede crear kits sin problemas
✅ **Sin errores visibles**: no se muestra ningún mensaje de error
✅ **Sin retrasos**: no espera a que falle el Foundation Model
⚠️ **Usa siempre lightweight**: todos los kits se crean con el modelo ligero

### Logs (solo DEBUG):
```
╔════════════════════════════════════════════════════════════════╗
║  ⚠️  FOUNDATION MODEL - No disponible                           ║
╠════════════════════════════════════════════════════════════════╣
║  Estado: unavailable(...)
║  → Usando LIGHTWEIGHT (v2) por defecto
╚════════════════════════════════════════════════════════════════╝
```

---

## 3. TrainerView

**Ubicación:** `StepKit/TrainerView.swift`

### ¿Qué hace?
Vista del asistente de chat que usa el Foundation Model para conversar con el usuario.

### ¿Qué se ve cuando NO hay Foundation Model?

**Diferentes vistas según el estado de disponibilidad:**

#### Caso 1: `.available` ✅
**Vista mostrada:** Chat normal o empty state
- Si tiene kits: muestra `chatView` (interfaz de chat completa)
- Si no tiene kits: muestra `emptyStateView` (mensaje para crear el primer kit)

#### Caso 2: `.unavailable(.deviceNotEligible)` ❌
**Vista mostrada:** `modelUnavailableView`

**Elementos visuales:**
- **Icono:** `sparkles.slash` (36pt) con gradiente naranja-rojo
- **Título:** "Dispositivo no compatible"
- **Mensaje:** "Este dispositivo no es compatible con Apple Intelligence."
- **Hint de ajustes:** NO se muestra
- **Fondo:** Gradiente naranja-rojo suave en círculo de 80x80

#### Caso 3: `.unavailable(.appleIntelligenceNotEnabled)` ⚠️
**Vista mostrada:** `modelUnavailableView`

**Elementos visuales:**
- **Icono:** `sparkles.slash` (36pt) con gradiente naranja-rojo
- **Título:** "Apple Intelligence desactivado"
- **Mensaje:** "Activa Apple Intelligence en Ajustes para usar el asistente."
- **Hint de ajustes:** ✅ SÍ se muestra: "Ajustes → Apple Intelligence y Siri"
- **Fondo:** Gradiente naranja-rojo suave en círculo de 80x80

#### Caso 4: `.unavailable(.modelNotReady)` ⏳
**Vista mostrada:** `modelUnavailableView`

**Elementos visuales:**
- **Icono:** `sparkles.slash` (36pt) con gradiente naranja-rojo
- **Título:** "Modelo en preparación"
- **Mensaje:** "El asistente se está descargando. Inténtalo de nuevo más tarde."
- **Hint de ajustes:** NO se muestra
- **Fondo:** Gradiente naranja-rojo suave en círculo de 80x80

#### Caso 5: `.unavailable` (genérico) ❓
**Vista mostrada:** `modelUnavailableView`

**Elementos visuales:**
- **Icono:** `sparkles.slash` (36pt) con gradiente naranja-rojo
- **Título:** "Asistente no disponible"
- **Mensaje:** "El asistente no está disponible en este momento."
- **Hint de ajustes:** NO se muestra
- **Fondo:** Gradiente naranja-rojo suave en círculo de 80x80

#### Caso 6: `@unknown default` 🔮
**Vista mostrada:** `modelUnavailableView`

**Elementos visuales:**
- **Icono:** `sparkles.slash` (36pt) con gradiente naranja-rojo
- **Título:** "Asistente no disponible"
- **Mensaje:** "El asistente no está disponible."
- **Hint de ajustes:** NO se muestra
- **Fondo:** Gradiente naranja-rojo suave en círculo de 80x80

### Estructura de `modelUnavailableView`:

```swift
VStack(spacing: 24) {
    Spacer()
    
    // Icono con gradiente
    ZStack {
        Circle() // 80x80
        Image(systemName: "sparkles.slash") // 36pt
    }
    
    VStack(spacing: 12) {
        Text(title) // .title2, .semibold
        Text(message) // .subheadline, .secondary
        if showSettingsHint {
            Text("Ajustes → Apple Intelligence y Siri") // .caption
        }
    }
    
    Spacer()
}
```

### Experiencia del usuario:

❌ **No puede usar el asistente**: la vista de chat está completamente bloqueada
✅ **Mensaje claro**: sabe exactamente por qué no funciona
✅ **Acción sugerida**: en algunos casos se indica cómo solucionarlo
⚠️ **No puede crear kits desde aquí**: aunque puede abrir `FastCreatorView` desde el fullScreenCover

---

## 4. DayInsightView

**Ubicación:** `StepKit/Views/Calendar/DayInsightView.swift`

### ¿Qué hace?
Muestra un insight generado por IA sobre el día seleccionado en el calendario.

### ¿Qué se ve cuando NO hay Foundation Model?

**Comportamiento:**

1. **Verifica disponibilidad ANTES** de intentar generar:
   ```swift
   guard model.availability == .available else {
       insight = nil
       return
   }
   ```

2. **Si no está disponible:**
   - `insight = nil`
   - No muestra ningún insight
   - No muestra error
   - **Muestra el `emptyStateView`**

### Vista mostrada (`emptyStateView`):

**Elementos visuales:**
- **Icono:** `sparkles` (subheadline) en color terciario
- **Texto:** "No hay datos para analizar este día"
- **Estilo:** 
  - Fondo: `Color(.secondarySystemGroupedBackground)`
  - Padding: 14pt
  - Esquinas redondeadas: 12pt
  - Alineación: leading

### Experiencia del usuario:

✅ **No hay error visible**: simplemente no se muestra el insight
✅ **Vista consistente**: muestra el mismo empty state que cuando no hay datos
⚠️ **No sabe por qué**: no hay indicación de que es por falta del Foundation Model
ℹ️ **Funcionalidad no crítica**: el calendario sigue funcionando normalmente

### Nota importante:

El `emptyStateView` se muestra en DOS casos:
1. Cuando no hay Foundation Model disponible
2. Cuando no hay datos para analizar (sin steps ni goals)

**El usuario no puede distinguir entre estos casos.**

---

## 5. AssistantService

**Ubicación:** `StepKit/Services/AssistantService.swift`

### ¿Qué hace?
Servicio que maneja la conversación con el Foundation Model. Usado por `TrainerView`.

### ¿Qué devuelve cuando NO hay Foundation Model?

**Métodos que verifican disponibilidad:**

#### 1. `chat()` - Streaming
```swift
func chat(...) async throws -> AsyncThrowingStream<String, Error> {
    guard isAvailable else {
        throw AssistantError.modelUnavailable(
            unavailabilityReason ?? "Modelo no disponible"
        )
    }
    // ...
}
```

**Error lanzado:**
- `AssistantError.modelUnavailable(String)`
- El string contiene la razón específica según el estado

#### 2. `respond()` - Sin streaming
```swift
func respond(...) async throws -> String {
    guard isAvailable else {
        throw AssistantError.modelUnavailable(
            unavailabilityReason ?? "Modelo no disponible"
        )
    }
    // ...
}
```

**Error lanzado:**
- `AssistantError.modelUnavailable(String)`
- El string contiene la razón específica según el estado

### Razones de indisponibilidad (`unavailabilityReason`):

| Estado | Mensaje devuelto |
|--------|------------------|
| `.available` | `nil` (no hay error) |
| `.unavailable(.deviceNotEligible)` | "Este dispositivo no es compatible con Apple Intelligence" |
| `.unavailable(.appleIntelligenceNotEnabled)` | "Activa Apple Intelligence en Ajustes para usar el asistente" |
| `.unavailable(.modelNotReady)` | "El modelo aún no está listo. Inténtalo de nuevo más tarde" |
| `.unavailable` (genérico) | "El asistente no está disponible en este momento" |
| `@unknown default` | "El asistente no está disponible" |

### Manejo de errores en TrainerView:

Cuando `AssistantService` lanza un error, `TrainerView` lo captura en `handleAssistantError()`:

```swift
private func handleAssistantError(_ error: AssistantError) async {
    // Oculta indicadores
    isTyping = false
    currentStreamingText = ""
    isResponding = false
    
    // Si es contextWindowExceeded, resetea la sesión
    if case .contextWindowExceeded = error {
        await assistantService.resetConversation(...)
    }
    
    // Muestra el error como mensaje del asistente
    let errorMessage = ChatMessage(
        sender: .assistant,
        text: error.localizedDescription ?? "Ha ocurrido un error..."
    )
    messages.append(errorMessage)
    
    // Feedback háptico
    UINotificationFeedbackGenerator().notificationOccurred(.error)
}
```

### Experiencia del usuario:

❌ **No puede chatear**: los métodos lanzan errores
✅ **Mensaje claro**: el error se muestra como mensaje del asistente en el chat
✅ **Feedback háptico**: vibración de error
⚠️ **Solo si llega a intentar**: normalmente `TrainerView` bloquea la vista antes

---

## 📊 Resumen Comparativo

| Componente | ¿Funciona sin Foundation? | ¿Muestra error? | ¿Qué hace? |
|------------|---------------------------|-----------------|------------|
| **ComplexityRouter** | ✅ Sí | ❌ No (solo log DEBUG) | Usa lightweight por defecto |
| **FastCreatorView** | ✅ Sí | ❌ No | Crea kits con modelo ligero |
| **TrainerView** | ❌ No | ✅ Sí (vista bloqueada) | Muestra vista de error específica |
| **DayInsightView** | ✅ Sí | ❌ No | No muestra insight (empty state) |
| **AssistantService** | ❌ No | ✅ Sí (error lanzado) | Lanza error descriptivo |

---

## 🎯 Conclusiones

### ✅ Puntos Fuertes:

1. **Graceful degradation**: La app sigue funcionando sin Foundation Model
2. **No bloquea funcionalidades críticas**: Crear kits funciona normalmente
3. **Mensajes claros**: Cuando no funciona, el usuario sabe por qué
4. **Verificación proactiva**: Se verifica disponibilidad antes de intentar usar

### ⚠️ Áreas de Mejora Potencial:

1. **DayInsightView**: No distingue entre "sin datos" y "sin Foundation Model"
2. **FastCreatorView**: El usuario no sabe que está usando lightweight por defecto
3. **ComplexityRouter**: No hay feedback visual cuando usa el valor por defecto

### 🔧 Recomendaciones:

1. **DayInsightView**: Podría mostrar un mensaje diferente cuando no hay Foundation Model
2. **FastCreatorView**: Podría mostrar un badge o indicador cuando usa lightweight por defecto
3. **ComplexityRouter**: Podría exponer un flag `isUsingDefault` para que las vistas sepan cuándo usar el valor por defecto

---

**Última actualización:** Diciembre 2025


