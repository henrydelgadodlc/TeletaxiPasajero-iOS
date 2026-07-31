import Foundation
import CoreLocation
import SwiftUI

// Puerto de HomeState + HomeScreenContainer: máquina de estados del Home.
@MainActor
final class HomeViewModel: ObservableObject {

    // --- Estado (espejo de HomeState.kt) ---
    @Published var originAddress = ""
    @Published var destinationAddress = ""
    @Published var originLocation: CLLocationCoordinate2D?
    @Published var destinationLocation: CLLocationCoordinate2D?
    @Published var isStep2 = false
    @Published var estimatedPrice = "7.60"
    @Published var basePrice = ""
    @Published var paymentType = "efectivo"
    @Published var reference = ""
    @Published var isLoading = false
    @Published var promoCode = ""
    @Published var promoInfo: String?
    @Published var isPromoValid: Bool?
    @Published var routePoints: [CLLocationCoordinate2D] = []
    @Published var routeLegs: [[CLLocationCoordinate2D]] = []
    @Published var selectionMode = "destino"          // "origen" | "destino" | "waypoint_add" | "parada_N"
    // Multiruta (StopItem de HomeState.kt): el server anuncia por /isactive
    @Published var stops: [StopItem] = []
    @Published var multiStopEnabled = false
    @Published var maxStops = 3
    private var multiStopChecked = false
    @Published var selectingOnMap: String?            // nil | "origen" | "destino" (pin en mapa)
    @Published var selectedCategoriaId = 1
    @Published var categorias: [CategoriaItem] = []
    @Published var metodosPago: [MetodoPagoItem] = []
    @Published var toastMessage: String?
    @Published var createdRequestId: Int?             // dispara navegación a Temporal

    private var routeTask: Task<Void, Never>?

    // --- Carga inicial (LaunchedEffect Unit del Container) ---
    func onAppear() {
        getLocationFirstTime()
        Task {
            if let cats = try? await RequestAPI.categorias() {
                categorias = cats
                if !cats.isEmpty && !cats.contains(where: { $0.id_categoria == selectedCategoriaId }) {
                    selectedCategoriaId = cats[0].id_categoria
                }
            }
        }
        Task {
            if let metodos = try? await RequestAPI.metodosPago() {
                metodosPago = metodos
                if !metodos.isEmpty && !metodos.contains(where: { $0.clave == paymentType }) {
                    paymentType = metodos[0].clave
                }
            }
        }
    }

    func getLocationFirstTime() {
        isLoading = true
        LocationManager.shared.requestPermissionAndLocation { [weak self] coordinate in
            Task { @MainActor in
                guard let self else { return }
                guard let coordinate else {
                    self.isLoading = false
                    self.toastMessage = "Activa la ubicación para usar la app"
                    return
                }
                self.originLocation = coordinate
                self.originAddress = await LocationManager.shared.address(for: coordinate)
                self.isLoading = false
                self.checkMultiStop(coordinate)
                self.recalculateRoute()
            }
        }
    }

    // Multiruta: consulta única a /isactive (LaunchedEffect(originLocation))
    private func checkMultiStop(_ origin: CLLocationCoordinate2D) {
        guard !multiStopChecked, origin.latitude != 0 else { return }
        multiStopChecked = true
        Task {
            if let r = try? await RequestAPI.isActive(latitude: origin.latitude, longitude: origin.longitude),
               let ms = r.data?.multi_stop {
                multiStopEnabled = ms.enabled ?? false
                maxStops = ms.max_paradas ?? 3
            }
        }
    }

    // --- Selección de direcciones (lógica de selectedPlace del Container) ---
    func setPlace(address: String, coordinate: CLLocationCoordinate2D) {
        switch true {
        case selectionMode == "origen":
            originAddress = address
            originLocation = coordinate
        // Dirección nueva agregada al final: el destino actual baja a ser
        // parada y esta se vuelve el nuevo destino (el último campo SIEMPRE
        // es el destino).
        case selectionMode == "waypoint_add":
            if !destinationAddress.isEmpty, let dest = destinationLocation, stops.count < maxStops {
                stops.append(StopItem(address: destinationAddress, lat: dest.latitude, lng: dest.longitude))
            }
            destinationAddress = address
            destinationLocation = coordinate
            selectionMode = "destino"
        case selectionMode.hasPrefix("parada_"):
            if let index = Int(selectionMode.dropFirst("parada_".count)), stops.indices.contains(index) {
                stops[index] = StopItem(address: address, lat: coordinate.latitude, lng: coordinate.longitude)
            }
            selectionMode = "destino"
        default:
            destinationAddress = address
            destinationLocation = coordinate
        }
        recalculateRoute()
    }

    func removeStop(at index: Int) {
        guard stops.indices.contains(index) else { return }
        stops.remove(at: index)
        recalculateRoute()
    }

    // Confirmación del pin en mapa (FlagScreen/selectingMode de Android)
    func confirmMapCenter(_ coordinate: CLLocationCoordinate2D) {
        isLoading = true
        Task {
            let address = await LocationManager.shared.address(for: coordinate)
            if selectionMode == "origen" {
                originAddress = address
                originLocation = coordinate
            } else {
                destinationAddress = address
                destinationLocation = coordinate
            }
            isLoading = false
            selectingOnMap = nil
            recalculateRoute()
        }
    }

    // --- Ruta + precio (LaunchedEffect(origin, destination) del Container) ---
    func recalculateRoute() {
        guard let origin = originLocation, let destination = destinationLocation,
              origin.latitude != 0, destination.latitude != 0 else { return }
        routeTask?.cancel()
        routeTask = Task {
            do {
                // Multiruta: origen → paradas → destino, en orden de recorrido
                var waypoints = ["\(origin.longitude),\(origin.latitude)"]
                waypoints.append(contentsOf: stops.map { "\($0.lng),\($0.lat)" })
                waypoints.append("\(destination.longitude),\(destination.latitude)")
                let result = try await RouteService.route(points: waypoints)
                guard !Task.isCancelled else { return }
                routePoints = result.points
                routeLegs = result.legs

                // Distancia/duración = SUMA real de los tramos (si no, el backend
                // estima con línea recta y el precio sale inflado)
                let estimate = try await RequestAPI.estimate(EstimateData(
                    latitud_origen: "\(origin.latitude)",
                    longitud_origen: "\(origin.longitude)",
                    latitud_destino: "\(destination.latitude)",
                    longitud_destino: "\(destination.longitude)",
                    route_distance_meters: "\(Int(result.distanceMeters))",
                    route_duration_seconds: "\(Int(result.durationSeconds))",
                    paradas: stops.isEmpty ? nil : stops.map { StopPayload(latitud: $0.lat, longitud: $0.lng, direccion: $0.address) }
                ))
                guard !Task.isCancelled, let detail = estimate.data else { return }
                basePrice = "\(detail.precio_referencial)"
                estimatedPrice = Self.formatPrice(Self.applyCategoryAdjustment(
                    base: detail.precio_referencial,
                    cat: categorias.first { $0.id_categoria == selectedCategoriaId }
                ))
            } catch {
                // Sin ruta no hay estimado; el usuario aún puede fijar precio manual
            }
        }
    }

    // --- Categorías (onCategoriaChange del Container) ---
    func selectCategoria(_ cat: CategoriaItem) {
        selectedCategoriaId = cat.id_categoria
        if let base = Double(basePrice), base > 0 {
            estimatedPrice = Self.formatPrice(Self.applyCategoryAdjustment(base: base, cat: cat))
        }
        if isPromoValid == true {
            validatePromo()
        }
    }

    func changePrice(_ newPrice: String) {
        estimatedPrice = newPrice
        if isPromoValid == true { validatePromo() }
    }

    // --- Promo (validatePromoWithPrice del Container) ---
    func promoCodeChanged(_ code: String) {
        promoCode = code
        isPromoValid = nil
        promoInfo = nil
    }

    func validatePromo() {
        let codigo = promoCode.trimmingCharacters(in: .whitespaces)
        guard !codigo.isEmpty else { return }
        let tarifa = Double(estimatedPrice) ?? 0
        Task {
            do {
                let resp = try await RequestAPI.validatePromo(
                    codigo: codigo,
                    telefono: Session.shared.phoneUser,
                    tarifa: tarifa
                )
                if resp.valid {
                    let monto = resp.monto_descuento ?? 0
                    let final = resp.tarifa_final ?? 0
                    isPromoValid = true
                    promoInfo = "Código válido: descuento S/ \(String(format: "%.2f", monto)). Pagarás S/ \(String(format: "%.2f", final))."
                } else {
                    isPromoValid = false
                    promoInfo = resp.message ?? "Código no válido."
                }
            } catch {
                isPromoValid = false
                promoInfo = (error as? APIError).map { $0.errorDescription ?? "" } ?? "Código no válido."
            }
        }
    }

    // --- Crear solicitud (onRequestTaxi del Container) ---
    func requestTaxi() {
        guard !isLoading else { return }
        let currentPrice = Float(estimatedPrice) ?? 0
        if currentPrice < 6.0 {
            toastMessage = "El precio mínimo es de 6 soles"
            return
        }
        guard let origin = originLocation, let destination = destinationLocation else {
            toastMessage = "Por favor, selecciona origen y destino"
            return
        }
        isLoading = true
        let data = RequestData(
            id_pasajero: Session.shared.idPassenger,
            latitud_origen: origin.latitude,
            longitud_origen: origin.longitude,
            latitud_destino: destination.latitude,
            longitud_destino: destination.longitude,
            direccion_actual: originAddress,
            direccion_destino: destinationAddress,
            referencia: reference,
            precio: currentPrice,
            tipo_pago: paymentType,
            codigo_descuento: {
                let c = promoCode.trimmingCharacters(in: .whitespaces)
                return (!c.isEmpty && isPromoValid == true) ? c : nil
            }(),
            telefono: Session.shared.phoneUser,
            tarifa_pasajero: currentPrice,
            id_categoria: selectedCategoriaId,
            paradas: stops.isEmpty ? nil : stops.map { StopPayload(latitud: $0.lat, longitud: $0.lng, direccion: $0.address) }
        )
        Task {
            do {
                let response = try await RequestAPI.createRequest(data)
                if response.code == 200, let info = response.data {
                    let s = Session.shared
                    s.stateTemporal = true
                    s.currentRequest = info.id_solicitud
                    s.requestStartTime = Int64(Date().timeIntervalSince1970 * 1000)
                    s.promoDiscount = info.monto_descuento_codigo ?? 0
                    if !promoCode.isEmpty && info.codigo_aplicado != true {
                        toastMessage = "El viaje se creó, pero el código de descuento no pudo aplicarse."
                    }
                    isLoading = false
                    isStep2 = false
                    promoCode = ""
                    promoInfo = nil
                    isPromoValid = nil
                    createdRequestId = info.id_solicitud
                } else {
                    isLoading = false
                    toastMessage = response.message ?? "No se pudo crear la solicitud"
                }
            } catch {
                isLoading = false
                toastMessage = error.localizedDescription
            }
        }
    }

    // Al volver de Temporal/Travel (LaunchedEffect(currentBackStackEntry))
    func resetAfterTrip() {
        destinationAddress = ""
        destinationLocation = nil
        routePoints = []
        routeLegs = []
        stops = []
        isStep2 = false
        getLocationFirstTime()
    }

    // --- Helpers (aplicarAjusteCategoria / formatearPrecio) ---
    static func applyCategoryAdjustment(base: Double, cat: CategoriaItem?) -> Double {
        guard let cat, cat.ajuste_valor > 0 else { return base }
        let adjusted = cat.ajuste_tipo == "porcentaje"
            ? base * (1 + cat.ajuste_valor / 100.0)
            : base + cat.ajuste_valor
        return (adjusted * 10).rounded() / 10
    }

    static func formatPrice(_ value: Double) -> String {
        var s = String(format: "%.2f", value)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
