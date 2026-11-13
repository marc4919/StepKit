//
//  BrandLayout.swift
//  StepKit
//

import SwiftUI

/// Coloca las vistas en filas y salta a la siguiente cuando no caben (chips del paso).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    /// Posición de cada vista con un ancho dado; se usa igual al medir y al colocar,
    /// para que la altura calculada coincida siempre con lo que se dibuja.
    private func layout(_ subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (origins, CGSize(width: maxX, height: y + rowHeight))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let result = layout(subviews, width: width)
        // Ocupa todo el ancho propuesto: así el padre lo coloca con ese mismo ancho.
        return CGSize(width: proposal.width ?? result.size.width, height: result.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews, width: bounds.width)
        for (subview, origin) in zip(subviews, result.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                          proposal: .unspecified)
        }
    }
}

// MARK: - Ancho de lectura

/// En pantallas anchas (iPhone Duo abierto, iPad) el contenido de una sola columna no se estira:
/// se centra con un ancho cómodo de lectura. En iPhone no cambia nada.
struct ReadableContentWidth: ViewModifier {
    var maxWidth: CGFloat = 680
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        Group {
            // Solo cuando sobra ancho: un margen 0 quitaría los márgenes propios de la lista en iPhone.
            if width > maxWidth + 40 {
                content.contentMargins(.horizontal, (width - maxWidth) / 2, for: .scrollContent)
            } else {
                content
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

extension View {
    func readableContentWidth(_ maxWidth: CGFloat = 680) -> some View {
        modifier(ReadableContentWidth(maxWidth: maxWidth))
    }
}

// MARK: - Dos columnas

/// Modelo del dispositivo, para lo poco que depende de él (la barra vertical del iPhone Duo).
enum DeviceKind {
    static let modelIdentifier: String = {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(validatingCString: $0) ?? "" }
        }
    }()
    /// iPhone Duo (plegable): iPhone19,4.
    static let isDuo = modelIdentifier == "iPhone19,4"
}

/// Tamaño de la columna de detalle de la vista dividida (Duo abierto, iPad): lo publica el contenedor
/// para que una pantalla recién empujada acierte su disposición en el primer fotograma, antes de medirse.
struct DetailColumnSizeKey: EnvironmentKey {
    static let defaultValue: CGSize? = nil
}

extension EnvironmentValues {
    var detailColumnSize: CGSize? {
        get { self[DetailColumnSizeKey.self] }
        set { self[DetailColumnSizeKey.self] = newValue }
    }
}

/// Vuelve a Mis Kits desde cualquier pantalla del Kit (la vista dividida lo cumple quitando la
/// selección, que en ancho compacto deshace toda la pila). Sin él, «Volver a Mis Kits» solo cerraba
/// una pantalla y dejaba al usuario en el Kit.
struct ReturnToKitsKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var returnToKits: (() -> Void)? {
        get { self[ReturnToKitsKey.self] }
        set { self[ReturnToKitsKey.self] = newValue }
    }
}

enum TwoColumnLayout {
    /// Dos columnas solo en pantallas anchas y apaisadas (iPhone Duo abierto en horizontal, iPad en horizontal).
    /// Con el Duo abierto en vertical la pantalla es casi cuadrada y una sola columna, como cerrado, se lee mejor.
    static func fits(_ size: CGSize) -> Bool {
        size.width >= 700 && size.width > size.height
    }
}

// MARK: - Márgenes equilibrados

/// En el iPhone Duo abierto en horizontal, la hora y las pestañas ocupan una franja a la derecha.
/// Ese hueco solo existe en un lado, así que el contenido se veía desplazado a la izquierda.
/// Este modificador añade al lado contrario el mismo margen para que el bloque quede centrado en la pantalla.
struct BalancedHorizontalSafeArea: ViewModifier {
    @State private var insets = EdgeInsets()
    @State private var landscape = false

    func body(content: Content) -> some View {
        // Solo en horizontal y solo para la franja del sistema (unos 60–90 pt). En una columna de
        // detalle junto al panel lateral la diferencia puede ser enorme y aplastaba el contenido.
        let difference = insets.trailing - insets.leading
        let applies = landscape && abs(difference) <= 120
        let extraLeading = applies ? max(0, difference) : 0
        let extraTrailing = applies ? max(0, -difference) : 0
        content
            .padding(.leading, extraLeading)
            .padding(.trailing, extraTrailing)
            .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { insets = $0 }
            .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { landscape = $0 }
    }
}

extension View {
    func balancedHorizontalSafeArea() -> some View {
        modifier(BalancedHorizontalSafeArea())
    }
}

// MARK: - Respuesta táctil

/// Tarjeta pulsable: se hunde un poco al tocarla y vibra suave al soltar, para que se note la elección.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in !pressed }
    }
}

/// Fila de lista que es un botón: toda la fila responde, se resalta al pulsarla como las del sistema
/// y vibra al soltar. Usar con `.listRowInsets(EdgeInsets())` para que el resalte llegue a los bordes.
struct ListRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background(configuration.isPressed ? Color(.systemFill) : .clear)
            .animation(configuration.isPressed ? nil : .easeOut(duration: 0.25), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed) { _, pressed in !pressed }
    }
}

/// Inserta su contenido tras un retardo (p. ej. una propuesta cuando termina de escribirse la respuesta).
/// Hasta entonces no ocupa sitio, para que la conversación no salte al final antes de tiempo.
struct DelayedReveal<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var shown = false

    var body: some View {
        // Un contenedor real (no Group): un Group vacío no lleva el `.task` a ningún sitio y nunca se mostraría.
        VStack(alignment: .leading, spacing: 0) {
            if shown {
                content().transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .task {
            guard delay > 0 else { shown = true; return }
            try? await Task.sleep(for: .seconds(delay))
            withAnimation(.smooth(duration: 0.45)) { shown = true }
        }
    }
}

// MARK: - Color de los botones principales

extension ShapeStyle where Self == Color {
    /// Azul de los botones principales: el blanco alcanza 5,4:1 (con el color de acento, 4,0:1).
    /// Solo en botones: en modo oscuro, los textos azules perderían contraste con este tono.
    static var primaryAction: Color { Color(red: 0, green: 0.4, blue: 0.84) }
}

// MARK: - Barra de pestañas oculta con transición

/// Pantallas que ocultan la barra de pestañas (paso, asistente, resultado). Mientras la pantalla está
/// presentada (en la pila), la barra se oculta; en cuanto empieza a cerrarse (`isPresented` pasa a
/// false al iniciarse el retroceso), la barra vuelve durante la transición y no un segundo después.
/// Es estado de navegación de SwiftUI, no del ciclo de vida de UIKit: plegar o desplegar el iPhone Duo
/// recoloca la vista pero no la saca de la pila, así que no la confunde (la variante con contador y
/// viewWillAppear/viewWillDisappear sí perdía la cuenta y dejaba la barra sobre el paso).
/// Al cerrarse pide `.automatic` y no `.visible`: un `.visible` en un paso abierto sobre otro paso
/// sacaba las pestañas encima de sus acciones, y afirmarlo en la raíz también.
/// También se oculta con las barras en vertical (Duo cerrado, o abierto en horizontal): las acciones
/// del paso van en esa franja y con las pestañas no cabían. Ahí el sistema anima la franja por fases
/// y, al volver al Kit, el hueco de las pestañas tarda medio segundo en llenarse; es su comportamiento.
struct HidesTabBarSmoothly: ViewModifier {
    @Environment(\.isPresented) private var isPresented

    func body(content: Content) -> some View {
        content.toolbarVisibility(isPresented ? .hidden : .automatic, for: .tabBar)
    }
}

extension View {
    func hidesTabBarSmoothly() -> some View { modifier(HidesTabBarSmoothly()) }
}


// MARK: - Título centrado en hojas de acción

/// Hojas con una acción y botones a los lados (Cancelar · título · Guardar): el título va centrado
/// en todos los iPhone. En el iPhone Duo el sistema lo pega a la izquierda, junto a «Cancelar».
/// Las pantallas a las que se navega o que solo se leen dejan el título donde lo pone iOS.
private struct CenteredNavigationTitle: ViewModifier {
    let title: Text
    var subtitle: Text? = nil

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        title.font(.headline).lineLimit(1)
                        if let subtitle {
                            subtitle.font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
            }
    }
}

extension View {
    func centeredNavigationTitle(_ title: LocalizedStringKey) -> some View {
        modifier(CenteredNavigationTitle(title: Text(title)))
    }

    func centeredNavigationTitle(verbatim title: String, subtitle: String? = nil) -> some View {
        modifier(CenteredNavigationTitle(title: Text(verbatim: title), subtitle: subtitle.map { Text(verbatim: $0) }))
    }
}

// MARK: - Modo de creación de un Kit

/// «Con IA» o «A mano», en la barra de «Nuevo Kit». Una cápsula con dos segmentos: el control segmentado
/// del sistema marca la selección con su fondo y su contraste, no solo con el color.
struct KitCreationModePicker: View {
    @Binding var manual: Bool

    var body: some View {
        Picker("Cómo crear el Kit", selection: $manual) {
            Image(systemName: "sparkles").accessibilityLabel(Text("Con IA")).tag(false)
            Image(systemName: "pencil").accessibilityLabel(Text("A mano")).tag(true)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 96)
        .sensoryFeedback(.selection, trigger: manual)
        .accessibilityLabel("Cómo crear el Kit")
        .accessibilityIdentifier("kitCreator.mode")
    }
}
