//
//  KitsHomeView.swift
//  StepKit
//
//  Mis Kits v4.4 (iPhone): tarjeta Continuar con el Kit que avanzaste por última vez,
//  otros Kits en curso y Kits terminados.
//

import SwiftUI
import TipKit
import SwiftData

struct KitsHomeView: View {
    let allActiveKits: [GoalEntity]
    let allCompletedKits: [GoalEntity]
    @Bindable var viewModel: KitsViewModel
    /// iPhone: abre el Kit en la pila. iPad: lo selecciona en la columna de detalle.
    /// Ancho compacto (iPhone, Duo cerrado): la vista dividida se colapsa a una pila y seleccionar
    /// un Kit lo empuja. El parámetro del inicializador ya no manda; se lee del entorno.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompact: Bool { horizontalSizeClass == .compact }
    @Query(sort: \ProgressEntryEntity.notedAt, order: .reverse) private var allEntries: [ProgressEntryEntity]
    @State private var reviewingKit: GoalEntity?
    @State private var continuingStep: StepEntity?
    @State private var openedLastKitAutomatically = false
    /// Hay columna de detalle a la vista. No sirve `isCompact`: dentro de la barra lateral el entorno es compacto.
    private let hasDetailColumn: Bool

    init(activeKits: [GoalEntity], completedKits: [GoalEntity], viewModel: KitsViewModel, isCompact: Bool = true, hasDetailColumn: Bool = false) {
        self.hasDetailColumn = hasDetailColumn
        self.allActiveKits = activeKits
        self.allCompletedKits = completedKits
        self.viewModel = viewModel
    }

    private var activeKits: [GoalEntity] { allActiveKits.filter { !viewModel.leavingKitIDs.contains($0.id) } }
    private var completedKits: [GoalEntity] { allCompletedKits.filter { !viewModel.leavingKitIDs.contains($0.id) } }

    /// Todos los pasos terminados pero el resultado aún sin confirmar.
    private var pendingResultKits: [GoalEntity] {
        completedKits.filter { $0.resultConfirmedAt == nil }.sorted { $0.lastActivity > $1.lastActivity }
    }

    private var confirmedKits: [GoalEntity] {
        completedKits.filter { $0.resultConfirmedAt != nil }
    }

    /// Última nota de avance del Kit (no bloqueos, no vacías). Los cambios del asistente no son
    /// avance de la persona: se quedan en el Registro del Kit y no ocupan «Dónde lo dejaste».
    private func lastProgress(of kit: GoalEntity) -> ProgressEntryEntity? {
        allEntries.first {
            $0.kitID == kit.id && $0.ownerID == kit.ownerID && $0.deletedAt == nil
                && $0.kind == .progress && !$0.note.isEmpty && !ProgressLog.isAssistantChange($0)
        }
    }

    /// La última nota de ese paso: la tarjeta la enseña junto a él, y la de otro paso confundiría.
    private func lastProgress(of kit: GoalEntity, onStep step: StepEntity?) -> ProgressEntryEntity? {
        guard let step else { return nil }
        return allEntries.first {
            $0.kitID == kit.id && $0.ownerID == kit.ownerID && $0.deletedAt == nil && $0.stepID == step.id
                && $0.kind == .progress && !$0.note.isEmpty && !ProgressLog.isAssistantChange($0)
        }
    }

    /// Kit que se avanzó por última vez: el cambio más reciente en el Kit o en sus pasos.
    private var continueKit: GoalEntity? {
        guard focusLayout else { return nil }
        return activeKits.max { $0.lastActivity < $1.lastActivity }
    }
    /// Perfil: destacar el último Kit que avanzaste (tarjeta Continuar) o lista simple.
    @AppStorage(KitsHomeLayout.focusKey) private var focusLayout = true

    private var otherKits: [GoalEntity] {
        activeKits
            .filter { $0.id != continueKit?.id }
            .sorted { $0.lastActivity > $1.lastActivity }
    }

    private var isEmpty: Bool { activeKits.isEmpty && completedKits.isEmpty }

    var body: some View {
        Group {
            if isEmpty {
                KitsEmptyView { openCreator() }
                    .transition(.opacity)
            } else {
                // List para conservar el gesto clásico de deslizar para eliminar. La selección enlazada
                // es lo que hace que, en ancho compacto, elegir un Kit lo empuje (y volver la limpie).
                List(selection: $viewModel.selectedKitId) {
                    Section { TipView(StartFromScratchTip()).tipListRow() }
                    if !pendingResultKits.isEmpty {
                        // Discretos: una fila con la bandera, sin tarjeta grande ni todo en verde.
                        Section {
                            ForEach(pendingResultKits) { kit in
                                Button { startReview(of: kit) } label: { PendingResultRow(kit: kit) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("kit.row")
                                    .accessibilityLabel("Kit: \(kit.title)")
                                    .accessibilityValue("Todos los pasos hechos, falta revisar el resultado")
                                    .listRowInsets(EdgeInsets())
                                    .tag(kit.id)
                                    .deletable { viewModel.prepareForDeletion(kit) }
                            }
                        } header: {
                            Text("Por revisar")
                                .font(.title3.bold())
                                .foregroundStyle(Color(.label))
                                .textCase(nil)
                        }
                    }
                    if let kit = continueKit {
                        Section {
                            ContinueCard(kit: kit, lastProgress: lastProgress(of: kit, onStep: kit.nextStep),
                                         isNextStepOpen: hasDetailColumn && kit.nextStep.map(viewModel.detailPath.contains) == true) {
                                if let step = kit.nextStep {
                                    if hasDetailColumn {
                                        openedLastKitAutomatically = false
                                        viewModel.continueStep(step, of: kit)
                                    } else {
                                        continuingStep = step
                                    }
                                } else {
                                    open(kit)
                                }
                            } onOpenKit: {
                                open(kit)
                            }
                            .cardRow()
                            .tag(kit.id)
                            .deletable { viewModel.prepareForDeletion(kit) }
                        }
                    }
                    if !otherKits.isEmpty {
                        section(title: continueKit != nil ? String(localized: "Otros Kits en curso") : String(localized: "En curso"), kits: otherKits)
                    }
                    if !confirmedKits.isEmpty {
                        section(title: String(localized: "Terminados"), kits: confirmedKits)
                    }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(22)
                .scrollContentBackground(.hidden)
                .background(alignment: .top) { BrandGlow() }
                .background(Color(.systemGroupedBackground))
                .transition(.opacity)
            }
        }
        // Al borrar el último Kit, la lista da paso al estado vacío con un fundido, sin saltos.
        .animation(.smooth(duration: 0.5), value: isEmpty)
        .navigationTitle("Mis Kits")
        .onChange(of: hasDetailColumn, initial: true) { _, hasColumn in
            // Con dos columnas, el detalle empieza mostrando el Kit que avanzaste por última vez.
            if hasColumn, viewModel.selectedKitEntity == nil, let kit = continueKit {
                viewModel.selectKit(kit)
                openedLastKitAutomatically = true
            } else if !hasColumn, openedLastKitAutomatically, !viewModel.isKitPlanCovered {
                // Al plegar se vuelve a Mis Kits: ese Kit no lo abriste tú, salvo que ya estés dentro de algo.
                viewModel.clearSelection()
                openedLastKitAutomatically = false
            }
        }
        .navigationDestination(item: $continuingStep) { step in
            StepDetailView(stepEntity: step, stepNumber: step.goal?.position(of: step) ?? 1)
        }
        .navigationDestination(item: $reviewingKit) { kit in
            ResultReviewView(kit: kit) {
                reviewingKit = nil
                open(kit)
            }
            .environment(\.returnToKits, { reviewingKit = nil })
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Crear a mano o con IA se elige dentro, en la barra de «Nuevo Kit».
                Button("Crear Kit", systemImage: "plus") { openCreator() }
                    .accessibilityIdentifier("kit.create")
                    .accessibilityHint("Abre el creador de kits")
            }
        }
    }

    private func section(title: String, kits: [GoalEntity]) -> some View {
        Section {
            ForEach(kits) { kit in
                Button { open(kit) } label: { KitHomeRow(kit: kit, lastProgress: lastProgress(of: kit)) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kit.row")
                    .accessibilityLabel("Kit: \(kit.title)")
                    .accessibilityValue(String(localized: "\(kit.completedStepCount) de \(kit.activeStepCount) pasos"))
                    .listRowInsets(EdgeInsets())
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 72 }
                    .tag(kit.id)
                    .deletable { viewModel.prepareForDeletion(kit) }
            }
        } header: {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color(.label))
                .textCase(nil)
        }
    }

    private func open(_ kit: GoalEntity) {
        // Un paso abierto antes de desplegar el Duo tapaba el Kit y «Ver Kit» no hacía nada.
        continuingStep = nil
        openedLastKitAutomatically = false
        viewModel.openKitPlan(kit)
    }

    /// En iPhone, la revisión se abre encima del plan del Kit para que «Volver al plan» sea un simple retroceso.
    private func startReview(of kit: GoalEntity) {
        guard isCompact else { reviewingKit = kit; return }
        viewModel.reviewOnOpenKitID = kit.id
        viewModel.selectKit(kit)
    }

    private func openCreator() {
        viewModel.showingKitCreator = true
    }
}

enum KitsHomeLayout {
    static let focusKey = "kitsHomeFocusLayout"
}

struct KitsEmptyView: View {
    let onCreate: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copyVisible = false
    @State private var size = CGSize(width: 400, height: 800)
    private var wide: Bool { size.width > size.height }

    var body: some View {
        Group {
            if wide {
                HStack(spacing: 20) {
                    OrbitMark(height: min(size.height * 0.62, 260), animated: true).frame(maxWidth: .infinity)
                    VStack(spacing: 12) { copy }.frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        OrbitMark(height: typeSize.isAccessibilitySize ? 160 : 230, animated: true)
                        copy
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, minHeight: size.height)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { EntryBackground() }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onAppear {
            if reduceMotion { copyVisible = true; return }
            // Siguiente ciclo: fuera del fundido con el que llega la vista (ver OrbitMark).
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.6).delay(0.9)) { copyVisible = true }
            }
        }
    }

    @ViewBuilder private var copy: some View {
        copyContent
            .opacity(copyVisible ? 1 : 0)
            .offset(y: copyVisible ? 0 : 12)
    }

    @ViewBuilder private var copyContent: some View {
        Text(String(localized: "Haz espacio a tu\npróximo objetivo"))
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        Text(String(localized: "Un plan claro. Un paso posible.\nY un lugar al que volver."))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        Button(action: onCreate) {
            Text("Crear mi primer Kit")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primaryAction)
        .controlSize(.large)
        .frame(maxWidth: 420)
        .padding(.horizontal, 30)
        .padding(.top, 8)
        .accessibilityIdentifier("emptyState.primaryAction")
    }
}

// MARK: - Datos derivados para la presentación

extension GoalEntity {
    /// Pasos visibles (sin borrar), en orden.
    /// Con el mismo `order` (puede pasar tras un sync o una inserción), decide la fecha de creación: así
    /// la numeración que se manda al asistente y la que resuelve su propuesta son siempre la misma.
    var orderedActiveSteps: [StepEntity] {
        // Sin repetidos: una relación con inversa puede traer el mismo paso dos veces en memoria.
        var seen = Set<UUID>()
        return steps.filter { $0.deletedAt == nil && seen.insert($0.id).inserted }
            .sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    var activeStepCount: Int { orderedActiveSteps.count }

    var completedStepCount: Int { orderedActiveSteps.filter(\.isCompleted).count }

    /// Primer paso sin completar.
    var nextStep: StepEntity? { orderedActiveSteps.first { !$0.isCompleted } }

    /// Posición del paso (1…n) entre los pasos visibles.
    func position(of step: StepEntity) -> Int {
        (orderedActiveSteps.firstIndex { $0.id == step.id } ?? 0) + 1
    }

    /// Último cambio en el Kit o en cualquiera de sus pasos.
    var lastActivity: Date {
        max(updatedAt, steps.map(\.updatedAt).max() ?? .distantPast)
    }
}

private extension View {
    /// Fila de List que muestra una tarjeta propia sin fondo ni separadores del sistema.
    func cardRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Deslizar para eliminar y menú contextual, como en la lista clásica.
    func deletable(_ action: @escaping () -> Void) -> some View {
        swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Eliminar", systemImage: "trash", action: action).tint(.red)
        }
        .contextMenu {
            Button("Eliminar Kit", systemImage: "trash", role: .destructive, action: action)
        }
    }
}
