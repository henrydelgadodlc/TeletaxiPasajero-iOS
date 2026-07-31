import SwiftUI

// Puerto de HistoryScreen.kt: historial con filtro por rango de fechas
// (por defecto: hoy) y tarjetas origen/destino/conductor.
struct HistoryView: View {
    let onBack: () -> Void

    @State private var history: [HistoryEntity] = []
    @State private var isLoading = false
    @State private var startDate: Date? = Calendar.current.startOfDay(for: Date())
    @State private var endDate: Date?
    @State private var showDatePicker = false
    @State private var pickerDate = Date()

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    private var filtered: [HistoryEntity] {
        guard startDate != nil || endDate != nil else { return history }
        return history.filter { item in
            guard let date = Self.parseDate(item.fechayhora ?? "") else { return false }
            if let startDate, date < startDate { return false }
            if let endDate, date > endDate.addingTimeInterval(86399) { return false }
            return true
        }
    }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MenuHeader(title: "Historial de viajes", c: c, onBack: onBack) {
                    Button { showDatePicker = true } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 18))
                            .foregroundColor(startDate != nil ? ChapaTheme.purplePrimary : c.textMain)
                            .frame(width: 40, height: 40)
                    }
                }

                if let startDate {
                    HStack {
                        let f = Self.shortFormatter
                        Text("Filtro: \(f.string(from: startDate)) - \(endDate.map { f.string(from: $0) } ?? "...")")
                            .font(ChapaFont.medium(12))
                            .foregroundColor(c.textMuted)
                        Spacer()
                        Button("Limpiar") {
                            self.startDate = nil
                            self.endDate = nil
                        }
                        .font(ChapaFont.bold(12))
                        .foregroundColor(ChapaTheme.purplePrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }

                if filtered.isEmpty && !isLoading {
                    let isToday = startDate == Calendar.current.startOfDay(for: Date()) && endDate == nil
                    EmptyMenuState(
                        icon: "clock.arrow.circlepath",
                        title: isToday ? "Sin viajes hoy" : "No se encontraron viajes",
                        description: isToday
                            ? "No tienes viajes registrados para hoy. Puedes buscar por fecha en el filtro de la parte superior."
                            : "No hay viajes que coincidan con el rango seleccionado.",
                        c: c
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(filtered) { item in
                                historyCard(item)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }

            if isLoading {
                c.darkBg.opacity(0.7).ignoresSafeArea()
                ProgressView().tint(ChapaTheme.purplePrimary)
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showDatePicker) {
            VStack(spacing: 16) {
                Text(startDate == nil || endDate != nil ? "Fecha inicial" : "Fecha final")
                    .font(ChapaFont.bold(16))
                    .foregroundColor(c.textMain)
                DatePicker("", selection: $pickerDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(ChapaTheme.purplePrimary)
                Button("Aplicar") {
                    let selected = Calendar.current.startOfDay(for: pickerDate)
                    if startDate == nil || endDate != nil {
                        startDate = selected
                        endDate = nil
                    } else if let s = startDate, selected < s {
                        endDate = s
                        startDate = selected
                    } else {
                        endDate = selected
                    }
                    showDatePicker = false
                }
                .font(ChapaFont.bold(15))
                .foregroundColor(ChapaTheme.purplePrimary)
            }
            .padding(20)
            .presentationDetents([.medium])
        }
    }

    private func load() {
        isLoading = true
        Task {
            history = (try? await MenuAPI.history()) ?? []
            isLoading = false
        }
    }

    private func historyCard(_ item: HistoryEntity) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(ChapaTheme.purplePrimary)
                    Text(Self.formatDate(item.fechayhora ?? ""))
                        .font(ChapaFont.medium(11))
                        .foregroundColor(c.textMuted)
                }
                Spacer()
                Text("S/ \(String(format: "%.2f", item.precio))")
                    .font(ChapaFont.bold(15))
                    .foregroundColor(ChapaTheme.purplePrimary)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Circle().fill(ChapaTheme.purplePrimary).frame(width: 6, height: 6)
                    Rectangle().fill(c.textMuted.opacity(0.2)).frame(width: 1, height: 20)
                    Circle().stroke(ChapaTheme.purplePrimary, lineWidth: 1).frame(width: 6, height: 6)
                }
                .padding(.top, 4)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.origen ?? "—")
                        .font(ChapaFont.medium(12)).foregroundColor(c.textMain).lineLimit(1)
                    Text(item.destino ?? "—")
                        .font(ChapaFont.medium(12)).foregroundColor(c.textMain).lineLimit(1)
                }
                Spacer()
            }
            .padding(.top, 10)

            Rectangle().fill(c.borderPurple).frame(height: 0.5).padding(.vertical, 10)

            HStack(spacing: 10) {
                let fotoRaw = item.foto ?? ""
                let url = fotoRaw.hasPrefix("http") ? fotoRaw : Config.imageURL + fotoRaw
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill").resizable().foregroundColor(c.textMuted)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.conductor ?? "—")
                        .font(ChapaFont.bold(13)).foregroundColor(c.textMain)
                    Text((item.referencia ?? "").isEmpty ? "Sin referencia" : "Ref: \(item.referencia ?? "")")
                        .font(ChapaFont.medium(10)).foregroundColor(c.textMuted).lineLimit(1)
                }
                Spacer()
                Text(item.tipo_pago ?? "—")
                    .font(ChapaFont.bold(10))
                    .foregroundColor(ChapaTheme.purplePrimary)
            }
        }
        .padding(12)
        .background(c.cardBg)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(c.borderPurple, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // fechayhora: "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" (UTC) → "dd MMM yyyy, hh:mm a" (Lima)
    static func parseDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: s)
    }

    static var shortFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yy"
        return f
    }

    static func formatDate(_ s: String) -> String {
        guard let date = parseDate(s) else { return s }
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_PE")
        out.timeZone = TimeZone(identifier: "America/Lima")
        out.dateFormat = "dd MMM yyyy, hh:mm a"
        return out.string(from: date)
    }
}

// Header compartido de las pantallas del menú
struct MenuHeader<Trailing: View>: View {
    let title: String
    let c: HomeColors
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20))
                    .foregroundColor(c.textMain)
                    .frame(width: 44, height: 44)
            }
            Text(title)
                .font(ChapaFont.bold(18))
                .foregroundColor(c.textMain)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 8)
    }
}

extension MenuHeader where Trailing == EmptyView {
    init(title: String, c: HomeColors, onBack: @escaping () -> Void) {
        self.init(title: title, c: c, onBack: onBack) { EmptyView() }
    }
}

// Estado vacío compartido (EmptyHistoryState/EmptyPlacesState)
struct EmptyMenuState: View {
    let icon: String
    let title: String
    let description: String
    let c: HomeColors

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(ChapaTheme.purplePrimary.opacity(0.25))
                .frame(width: 100, height: 100)
                .background(ChapaTheme.purplePrimary.opacity(0.05))
                .clipShape(Circle())
            Text(title)
                .font(ChapaFont.bold(20))
                .foregroundColor(c.textMain)
                .multilineTextAlignment(.center)
                .padding(.top, 24)
            Text(description)
                .font(ChapaFont.medium(14))
                .foregroundColor(c.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
