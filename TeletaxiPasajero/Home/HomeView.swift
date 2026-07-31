import SwiftUI
import MapKit
import UIKit

// Paleta del Home (ChapaColors de HomeScreen.kt, variantes dark/light).
struct HomeColors {
    let isDark: Bool
    var darkBg: Color { isDark ? ChapaTheme.darkBg : Color(hex: 0xF0F2F5) }
    var cardBg: Color { isDark ? ChapaTheme.cardBg : .white }
    var surfaceDark: Color { isDark ? ChapaTheme.surfaceDark : Color(hex: 0xF8F9FA) }
    var purplePrimary: Color { isDark ? ChapaTheme.purplePrimary : ChapaTheme.purpleDeep }
    var purpleLight: Color { isDark ? ChapaTheme.purpleLight : ChapaTheme.purplePrimary }
    var textMain: Color { isDark ? ChapaTheme.textMain : Color(hex: 0x1C1E21) }
    var textMuted: Color { isDark ? ChapaTheme.textMuted : Color(hex: 0x65676B) }
    var textDim: Color { isDark ? ChapaTheme.textDim : Color(hex: 0xB0B3B8) }
    var borderPurple: Color { isDark ? ChapaTheme.borderPurple : Color(hex: 0xE4E6EB) }
}

// Etapas del viaje activo (rutas Temporal/Travel/Valoration de Android)
enum TripStage: Identifiable, Equatable {
    case temporal
    case travel
    case valoration(ValorationData)

    var id: String {
        switch self {
        case .temporal: return "temporal"
        case .travel: return "travel"
        case .valoration(let d): return "valoration-\(d.id)"
        }
    }
}

// Puerto 1:1 de HomeScreen.kt + HomeScreenContainer.kt
struct HomeView: View {
    var onLogout: () -> Void = {}

    @State private var tripStage: TripStage?
    @StateObject private var vm = HomeViewModel()
    @State private var showMenu = false
    @State private var drawerDestination: DrawerDestination?
    @State private var favoriteTarget: String?
    @State private var shareAppText: String?
    @State private var themeRefresh = false
    @State private var showPaymentMenu = false
    @State private var showPriceEdit = false
    @State private var tempPrice = ""
    @State private var searchTarget: String?   // "origen" | "destino" al abrir el buscador

    @State private var mapProxy = MapProxy()
    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                // --- MAPA ---
                ZStack {
                    HomeMapView(
                        proxy: mapProxy,
                        origin: vm.originLocation,
                        destination: vm.destinationLocation,
                        routePoints: vm.routePoints,
                        routeLegs: vm.routeLegs,
                        stops: vm.stops,
                        isDark: isDark
                    )
                    .clipShape(RoundedCorners(radius: 32, corners: [.topLeft, .topRight]))

                    mapSideButtons

                    if let mode = vm.selectingOnMap {
                        selectingOverlay(mode: mode)
                    }
                }
                .frame(maxHeight: .infinity)

                bottomPanel
                    .offset(y: -32)
                    .padding(.bottom, -32)
            }

            if vm.isLoading {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.3).tint(c.purplePrimary)
                    Text("Actualizando...").font(ChapaFont.medium(15)).foregroundColor(.white)
                }
            }

            // --- DRAWER (ModalDrawer + MainDrawerContent) ---
            if showMenu {
                Color.black.opacity(0.5).ignoresSafeArea()
                    .onTapGesture { withAnimation { showMenu = false } }
                    .zIndex(5)
                DrawerView(
                    isDarkMode: isDark,
                    onNavigate: { dest in
                        withAnimation { showMenu = false }
                        drawerDestination = dest
                    },
                    onShare: {
                        withAnimation { showMenu = false }
                        shareAppText = "🚕 ¡Viaja seguro con Teletaxi! Descarga la app: https://teletaxi.city"
                    },
                    onLogout: {
                        withAnimation { showMenu = false }
                        onLogout()
                    },
                    onThemeToggle: { dark in
                        Session.shared.themeMode = dark ? 2 : 1
                        themeRefresh.toggle()
                    },
                    onClose: { withAnimation { showMenu = false } }
                )
                .transition(.move(edge: .leading))
                .zIndex(6)
            }
        }
        .id(themeRefresh)
        .toast($vm.toastMessage)
        .onAppear {
            vm.onAppear()
            resumeTripIfNeeded()
        }
        .fullScreenCover(item: $tripStage, onDismiss: {
            vm.resetAfterTrip()
        }) { stage in
            switch stage {
            case .temporal:
                TemporalView(
                    onCancelled: { tripStage = nil },
                    onAccepted: { tripStage = .travel }
                )
            case .travel:
                TravelView(
                    onExitToHome: { tripStage = nil },
                    onFinished: { data in tripStage = .valoration(data) }
                )
            case .valoration(let data):
                ValorationView(data: data) {
                    tripStage = nil
                }
            }
        }
        .onChange(of: vm.originLocation?.latitude) { _ in
            if let origin = vm.originLocation, vm.destinationLocation == nil {
                mapProxy.animate(to: origin)
            }
        }
        .onChange(of: vm.routePoints.count) { _ in
            if !vm.routePoints.isEmpty { mapProxy.fit(points: vm.routePoints) }
        }
        .onChange(of: vm.createdRequestId) { id in
            if id != nil {
                vm.createdRequestId = nil
                tripStage = .temporal
            }
        }
        .background(
            // En un View solo funciona un fullScreenCover por cadena de
            // modificadores; el buscador va en un background aparte.
            EmptyView().fullScreenCover(item: $searchTarget) { target in
                PlaceSearchView(
                    title: {
                        if target == "origen" { return "¿Cuál es tu ubicación?" }
                        if target == "waypoint_add" { return vm.stops.isEmpty ? "¿Agregas una parada?" : "¿Otra parada?" }
                        if target.hasPrefix("parada_") { return "Editar parada" }
                        return "¿A dónde vas?"
                    }(),
                    initialQuery: "",
                    isDark: isDark,
                    onSelected: { address, coordinate in
                        vm.selectionMode = target
                        vm.setPlace(address: address, coordinate: coordinate)
                        searchTarget = nil
                    },
                    onClose: { searchTarget = nil }
                )
            }
        )
        .background(
            EmptyView().fullScreenCover(item: $drawerDestination) { dest in
                switch dest {
                case .places:
                    PlacesView(
                        onBack: { drawerDestination = nil },
                        onPlaceSelected: { place in
                            if let target = favoriteTarget { vm.selectionMode = target }
                            let coord = CLLocationCoordinate2D(
                                latitude: Double(place.latitud) ?? 0,
                                longitude: Double(place.longitud) ?? 0
                            )
                            vm.setPlace(address: place.direccion, coordinate: coord)
                            favoriteTarget = nil
                            drawerDestination = nil
                        }
                    )
                case .recommended:
                    RecommendedView(
                        onBack: { drawerDestination = nil },
                        onPlaceSelected: { name, coord in
                            vm.selectionMode = "destino"
                            vm.setPlace(address: name, coordinate: coord)
                            drawerDestination = nil
                        }
                    )
                case .history:
                    HistoryView(onBack: { drawerDestination = nil })
                case .support:
                    SupportView(onBack: { drawerDestination = nil })
                case .editProfile:
                    EditProfileView(
                        onBack: { drawerDestination = nil },
                        onSaved: { drawerDestination = nil }
                    )
                }
            }
        )
        .background(
            EmptyView().sheet(item: Binding(
                get: { shareAppText.map { ShareText(text: $0) } },
                set: { shareAppText = $0?.text }
            )) { share in
                ActivityView(text: share.text)
            }
        )
    }

    // Reanudación al abrir la app (lógica de la ruta splash de AppNavigation):
    // confirma contra el servidor antes de retomar el viaje guardado.
    private func resumeTripIfNeeded() {
        let s = Session.shared
        let hasTripFlags = s.stateTravel || (s.stateTemporal && s.currentRequest != 0)
        guard hasTripFlags, s.idPassenger != 0 else { return }

        Task {
            guard let resp = try? await TemporalAPI.resumePassenger() else {
                // Error de red: retomar según el estado local guardado
                tripStage = s.stateTravel ? .travel : .temporal
                return
            }
            let estado = (resp.info?.estado ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            let requestId = resp.info?.id ?? 0
            if resp.code == 200 && requestId != 0 && (estado == "aceptado" || estado == "abordo") {
                s.currentRequest = requestId
                s.stateTemporal = false
                s.stateTravel = true
                tripStage = .travel
            } else if resp.code == 200 && requestId != 0 && estado == "pendiente" {
                s.currentRequest = requestId
                s.stateTemporal = true
                s.stateTravel = false
                tripStage = .temporal
            } else {
                s.clearTripStates()
            }
        }
    }

    // --- HEADER (HomeHeader) ---
    private var header: some View {
        HStack {
            Button { withAnimation { showMenu = true } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22))
                    .foregroundColor(c.textMain)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text("Teletaxi")
                .font(ChapaFont.bold(18))
                .foregroundColor(c.purpleLight)
            Spacer()
            Spacer().frame(width: 40)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // --- BOTONES LATERALES DEL MAPA (MapActionButton) ---
    private var mapSideButtons: some View {
        VStack(spacing: 12) {
            mapButton(icon: "smallcircle.filled.circle", active: vm.selectingOnMap == "origen") {
                vm.selectingOnMap = vm.selectingOnMap == "origen" ? nil : "origen"
                vm.selectionMode = "origen"
            }
            mapButton(icon: "flag.fill", active: vm.selectingOnMap == "destino") {
                vm.selectingOnMap = vm.selectingOnMap == "destino" ? nil : "destino"
                vm.selectionMode = "destino"
            }
            mapButton(icon: "location.fill", active: false) {
                if !vm.routePoints.isEmpty {
                    mapProxy.fit(points: vm.routePoints)
                } else if let origin = vm.originLocation {
                    mapProxy.animate(to: origin)
                } else {
                    vm.getLocationFirstTime()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.trailing, 12)
        .padding(.bottom, 48)
    }

    private func mapButton(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(active ? c.purpleLight : c.textMuted)
                .frame(width: 40, height: 40)
                .background(c.cardBg)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.borderPurple, lineWidth: 1))
        }
    }

    // --- PIN CENTRAL + CONFIRMAR (selectingMode) ---
    private func selectingOverlay(mode: String) -> some View {
        ZStack {
            Image(systemName: mode == "origen" ? "person.crop.circle.badge.checkmark" : "mappin.and.ellipse")
                .font(.system(size: 44))
                .foregroundColor(mode == "origen" ? c.purpleLight : .red)
                .padding(.bottom, 44)

            VStack {
                Spacer()
                Button {
                    if let center = mapProxy.centerCoordinate {
                        vm.confirmMapCenter(center)
                    }
                } label: {
                    Text(mode == "origen" ? "Confirmar Origen" : "Confirmar Destino")
                        .font(ChapaFont.bold(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 45)
                        .background(c.purplePrimary)
                        .cornerRadius(22)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // --- PANEL INFERIOR (HomeBottomPanel) ---
    private var bottomPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !vm.isStep2 {
                step1
            } else {
                step2
            }
            HStack {
                Spacer()
                Capsule()
                    .fill(c.textDim.opacity(0.2))
                    .frame(width: 120, height: 4)
                Spacer()
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 12)
        .background(c.cardBg)
        .clipShape(RoundedCorners(radius: 32, corners: [.topLeft, .topRight]))
        .shadow(color: .black.opacity(0.25), radius: 8, y: -2)
    }

    // Paso 1: origen/destino
    private var step1: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("¿A dónde quieres ir?")
                    .font(ChapaFont.bold(19))
                    .foregroundColor(c.textMain)
                LinearGradient(colors: [c.purplePrimary, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 48, height: 2)
                    .cornerRadius(2)
            }
            .padding(.bottom, 16)

            addressCard(
                value: vm.isLoading && vm.originAddress.isEmpty ? "Obteniendo ubicación..." : vm.originAddress,
                placeholder: "¿Cuál es tu ubicación?",
                isFavorite: !vm.originAddress.isEmpty,
                onFavorite: {
                    favoriteTarget = "origen"
                    drawerDestination = .places
                }
            ) {
                searchTarget = "origen"
            }

            let isCompact = vm.multiStopEnabled && !vm.stops.isEmpty

            if !isCompact {
                Text("Busca con la lupa o marca en el mapa.")
                    .font(.system(size: 11))
                    .foregroundColor(c.textMuted)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            } else {
                Spacer().frame(height: 6)
            }

            // Multiruta: paradas en el orden del recorrido (el último campo
            // SIEMPRE es el destino)
            if vm.multiStopEnabled {
                ForEach(Array(vm.stops.enumerated()), id: \.element.id) { index, stop in
                    stopCard(index: index, stop: stop)
                        .padding(.bottom, 6)
                }
            }

            addressCard(
                value: vm.destinationAddress,
                placeholder: "¿A dónde vas?",
                isFavorite: !vm.destinationAddress.isEmpty,
                onFavorite: {
                    favoriteTarget = "destino"
                    drawerDestination = .places
                }
            ) {
                searchTarget = "destino"
            }

            // Agregar otra dirección: el destino actual baja a ser parada
            if vm.multiStopEnabled && !vm.destinationAddress.isEmpty && vm.stops.count < vm.maxStops {
                addressCard(
                    value: "",
                    placeholder: vm.stops.isEmpty ? "¿Agregas una parada?" : "¿Otra parada?",
                    isFavorite: false
                ) {
                    searchTarget = "waypoint_add"
                }
                .padding(.top, 6)
            }

            if !isCompact {
                Text("Toca la estrella para tus favoritos.")
                    .font(.system(size: 11))
                    .foregroundColor(c.textMuted)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
            } else {
                Spacer().frame(height: 12)
            }

            ctaButton("Continuar", enabled: !vm.originAddress.isEmpty && !vm.destinationAddress.isEmpty) {
                vm.isStep2 = true
            }

            if !isCompact {
                featuresRow
                    .padding(.top, 18)
            }
        }
    }

    // Tarjeta de parada (AddressInputCard con badge numerado y X)
    private func stopCard(index: Int, stop: StopItem) -> some View {
        HStack(spacing: 0) {
            Text("\(index + 1)")
                .font(ChapaFont.bold(10))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(c.purplePrimary)
                .clipShape(Circle())

            Button { searchTarget = "parada_\(index)" } label: {
                Text(stop.address)
                    .font(ChapaFont.bold(14))
                    .foregroundColor(c.textMain)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
            }

            Button { searchTarget = "parada_\(index)" } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(c.textMuted)
                    .frame(width: 32, height: 32)
            }
            Button { vm.removeStop(at: index) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                    .foregroundColor(c.textMuted)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(c.surfaceDark)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple, lineWidth: 1))
    }

    // Tarjeta de dirección (AddressInputCard)
    private func addressCard(value: String, placeholder: String, isFavorite: Bool, onFavorite: (() -> Void)? = nil, onSearch: @escaping () -> Void) -> some View {
        Button(action: onSearch) {
            HStack(spacing: 0) {
                Button { onFavorite?() } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 15))
                        .foregroundColor(isFavorite ? c.purplePrimary : c.textDim)
                        .frame(width: 36, height: 36)
                        .background(isFavorite ? c.purplePrimary.opacity(0.1) : .clear)
                        .clipShape(Circle())
                }

                Text(value.isEmpty ? placeholder : value)
                    .font(value.isEmpty ? ChapaFont.medium(14) : ChapaFont.bold(14))
                    .foregroundColor(value.isEmpty ? c.textDim : c.textMain)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(c.textMuted)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(c.surfaceDark)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple, lineWidth: 1))
        }
    }

    // Paso 2: detalles del viaje
    private var step2: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button { vm.isStep2 = false } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17))
                        .foregroundColor(c.textMain)
                        .frame(width: 40, height: 40)
                        .background(c.surfaceDark)
                        .cornerRadius(12)
                }
                Text("Detalles del viaje")
                    .font(ChapaFont.bold(18))
                    .foregroundColor(c.textMain)
                    .frame(maxWidth: .infinity)
                Spacer().frame(width: 40)
            }

            HStack(spacing: 12) {
                detailSelector(title: "Precio Est.", value: "S/ \(vm.estimatedPrice)", icon: "banknote") {
                    tempPrice = vm.estimatedPrice
                    showPriceEdit = true
                }
                let nombrePago = vm.metodosPago.first { $0.clave == vm.paymentType }?.nombre
                    ?? vm.paymentType.capitalized
                detailSelector(title: "Pago", value: nombrePago, icon: "wallet.pass", hasDropdown: true) {
                    showPaymentMenu = true
                }
            }
            .padding(.top, 20)

            if !vm.stops.isEmpty {
                Text("🔀 Viaje con \(vm.stops.count) parada\(vm.stops.count == 1 ? "" : "s") intermedia\(vm.stops.count == 1 ? "" : "s") (recargo incluido)")
                    .font(ChapaFont.bold(11.5))
                    .foregroundColor(c.purpleLight)
                    .padding(.top, 10)
            }

            if vm.categorias.count > 1 {
                categoriaSelector
                    .padding(.top, 14)
            }

            referenceField
                .padding(.top, 16)

            promoField
                .padding(.top, 12)

            ctaButton("Solicitar taxi", enabled: (Float(vm.estimatedPrice) ?? 0) >= 6.0 && !vm.isLoading) {
                vm.requestTaxi()
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showPaymentMenu) { paymentSheet }
        .alert("Ajustar Precio", isPresented: $showPriceEdit) {
            TextField("Precio", text: $tempPrice)
                .keyboardType(.decimalPad)
            Button("Aceptar") { vm.changePrice(tempPrice) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Propón una tarifa justa")
        }
    }

    private func detailSelector(title: String, value: String, icon: String, hasDropdown: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(c.purplePrimary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(ChapaFont.medium(10)).foregroundColor(c.textMuted)
                    Text(value).font(ChapaFont.bold(14)).foregroundColor(c.textMain).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if hasDropdown {
                    Image(systemName: "chevron.down").font(.system(size: 13)).foregroundColor(c.textMuted)
                }
            }
            .padding(12)
            .frame(height: 64)
            .background(c.surfaceDark)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple, lineWidth: 1))
        }
    }

    // Chips de categoría (CategoriaSelectorRow)
    private var categoriaSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Tipo de vehículo").font(ChapaFont.medium(11)).foregroundColor(c.textMuted)
                if let desc = vm.categorias.first(where: { $0.id_categoria == vm.selectedCategoriaId })?.descripcion, !desc.isEmpty {
                    Text("• \(desc)")
                        .font(ChapaFont.medium(10.5))
                        .foregroundColor(c.purpleLight)
                        .lineLimit(1)
                }
            }
            HStack(spacing: 8) {
                ForEach(categoriasOrdenadas) { cat in
                    categoriaChip(cat)
                }
            }
        }
    }

    // Orden fijo del selector: autos por nivel (Eco, Plus, XL), luego mototaxi, luego moto.
    private var categoriasOrdenadas: [CategoriaItem] {
        let orden = ["auto": 0, "mototaxi": 1, "moto": 2, "desarrollo": 3]
        return vm.categorias.sorted {
            let a = orden[$0.grupo.lowercased()] ?? 9
            let b = orden[$1.grupo.lowercased()] ?? 9
            if a != b { return a < b }
            if $0.nivel != $1.nivel { return $0.nivel < $1.nivel }
            return $0.id_categoria < $1.id_categoria
        }
    }

    // Ícono del tipo de vehículo (SF Symbols iOS 16). "mototaxi" antes que "moto".
    private func categoriaIcon(_ cat: CategoriaItem) -> String {
        let n = cat.nombre.lowercased(); let g = cat.grupo.lowercased()
        if g == "mototaxi" || n.contains("mototaxi") { return "bus.fill" }
        if g == "moto" || n.contains("moto") { return "bicycle" }
        if n.contains("xl") || n.contains("van") { return "car.2.fill" }
        return "car.fill"
    }

    private func categoriaChip(_ cat: CategoriaItem) -> some View {
        let selected = cat.id_categoria == vm.selectedCategoriaId
        let extra: String? = {
            if cat.ajuste_valor <= 0 { return nil }
            let v = HomeViewModel.formatPrice(cat.ajuste_valor)
            return cat.ajuste_tipo == "porcentaje" ? "+\(v)%" : "+S/ \(v)"
        }()
        return Button { vm.selectCategoria(cat) } label: {
            VStack(spacing: 1) {
                HStack(spacing: 6) {
                    Image(systemName: categoriaIcon(cat))
                        .font(.system(size: 13))
                        .foregroundColor(selected ? c.purplePrimary : c.textMuted)
                    Text(cat.nombre)
                        .font(selected ? ChapaFont.bold(12.5) : ChapaFont.medium(12.5))
                        .foregroundColor(selected ? c.purplePrimary : c.textMain)
                        .lineLimit(1)
                }
                Text(extra ?? " ")
                    .font(ChapaFont.medium(9.5))
                    .foregroundColor(selected ? c.purplePrimary : c.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(selected ? c.purplePrimary.opacity(0.12) : c.surfaceDark)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? c.purplePrimary : c.borderPurple, lineWidth: 1))
        }
    }

    // Referencia (ReferenceInputField)
    private var referenceField: some View {
        TextField("", text: $vm.reference, prompt: Text("Referencia (opcional): puerta verde, frente al parque...").font(.system(size: 13)).foregroundColor(c.textDim))
            .font(ChapaFont.medium(14))
            .foregroundColor(c.textMain)
            .padding(14)
            .background(c.surfaceDark)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple, lineWidth: 1))
    }

    // Código promocional (PromoCodeInputField)
    private var promoField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 15))
                    .foregroundColor(c.purplePrimary)
                TextField("", text: Binding(
                    get: { vm.promoCode },
                    set: { vm.promoCodeChanged(String($0.uppercased().trimmingCharacters(in: .whitespaces).prefix(20))) }
                ), prompt: Text("Código de descuento (opcional)").font(ChapaFont.medium(13)).foregroundColor(c.textDim))
                .font(ChapaFont.bold(14))
                .foregroundColor(c.textMain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)

                Button(action: { vm.validatePromo() }) {
                    Text(vm.isPromoValid == true ? "Aplicado" : "Aplicar")
                        .font(ChapaFont.bold(13))
                        .foregroundColor(vm.promoCode.isEmpty ? c.textDim : c.purplePrimary)
                }
                .disabled(vm.promoCode.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(c.surfaceDark)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                vm.isPromoValid == true ? c.purplePrimary : (vm.isPromoValid == false ? ChapaTheme.redAlt : c.borderPurple),
                lineWidth: 1
            ))

            if let info = vm.promoInfo {
                Text(info)
                    .font(ChapaFont.medium(11))
                    .foregroundColor(vm.isPromoValid == true ? c.purplePrimary : ChapaTheme.redAlt)
                    .padding(.leading, 4)
            }
        }
    }

    // Botón principal con degradado (MainCTAButton)
    private func ctaButton(_ text: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(text).font(ChapaFont.bold(16)).foregroundColor(enabled ? .white : c.textDim)
                Image(systemName: "arrow.right").font(.system(size: 16)).foregroundColor(enabled ? .white : c.textDim)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Group {
                    if enabled {
                        LinearGradient(colors: [c.purplePrimary, c.purpleLight], startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        c.textDim.opacity(0.3)
                    }
                }
            )
            .cornerRadius(18)
        }
        .disabled(!enabled)
    }

    // FeaturesRow
    private var featuresRow: some View {
        HStack {
            featureItem(icon: "shield.fill", label: "Viajes seguros", sub: "Conductores verificados")
            Spacer()
            featureItem(icon: "bolt.fill", label: "Llegada rápida", sub: "En minutos")
            Spacer()
            featureItem(icon: "headphones", label: "Soporte 24/7", sub: "Siempre contigo")
        }
    }

    private func featureItem(icon: String, label: String, sub: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(c.purplePrimary)
                .frame(width: 32, height: 32)
                .background(c.purplePrimary.opacity(0.05))
                .clipShape(Circle())
                .overlay(Circle().stroke(c.purplePrimary.opacity(0.2), lineWidth: 1))
            Text(label).font(ChapaFont.bold(10)).foregroundColor(c.textMain).multilineTextAlignment(.center)
            Text(sub).font(ChapaFont.medium(9)).foregroundColor(c.textMuted).multilineTextAlignment(.center)
        }
        .frame(width: 100)
    }

    // Diálogo de método de pago (AlertDialog de Android → sheet)
    private var paymentSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Método de Pago")
                .font(ChapaFont.bold(18))
                .foregroundColor(c.textMain)
                .padding(.bottom, 6)
            let metodos = vm.metodosPago.isEmpty
                ? [MetodoPagoItem(id_metodo: 1, clave: "efectivo", nombre: "Efectivo", color: nil),
                   MetodoPagoItem(id_metodo: 2, clave: "yape", nombre: "Yape", color: nil),
                   MetodoPagoItem(id_metodo: 3, clave: "plin", nombre: "Plin", color: nil)]
                : vm.metodosPago
            ForEach(metodos) { metodo in
                let selected = vm.paymentType == metodo.clave
                Button {
                    vm.paymentType = metodo.clave
                    showPaymentMenu = false
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: paymentIcon(metodo.clave))
                            .font(.system(size: 20))
                            .foregroundColor(paymentColor(metodo.clave))
                        Text(metodo.nombre)
                            .font(ChapaFont.medium(15))
                            .foregroundColor(c.textMain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if selected {
                            Image(systemName: "checkmark").foregroundColor(c.purplePrimary)
                        }
                    }
                    .padding(16)
                    .background(selected ? c.purplePrimary.opacity(0.1) : .clear)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? c.purplePrimary : c.borderPurple, lineWidth: 1))
                }
            }
            Spacer()
        }
        .padding(20)
        .presentationDetents([.medium])
        .background(c.cardBg)
    }

    private func paymentIcon(_ clave: String) -> String {
        switch clave {
        case "efectivo": return "banknote.fill"
        case "yape", "plin": return "iphone.gen3"
        default: return "wallet.pass.fill"
        }
    }

    private func paymentColor(_ clave: String) -> Color {
        switch clave {
        case "yape": return ChapaTheme.yape
        case "plin": return ChapaTheme.plin
        case "efectivo": return ChapaTheme.green
        default: return c.purplePrimary
        }
    }
}

// Esquinas superiores redondeadas (RoundedCornerShape(topStart, topEnd))
struct RoundedCorners: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension String: Identifiable {
    public var id: String { self }
}
