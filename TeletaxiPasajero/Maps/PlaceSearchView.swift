import SwiftUI
import MapKit

// Reemplazo del Autocomplete de Google Places (Android) usando MapKit:
// pantalla completa de búsqueda con resultados en vivo, sesgada a la
// ubicación actual del pasajero.
final class PlaceSearchModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet { completer.queryFragment = query }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        if let origin = LocationManager.shared.location {
            completer.region = MKCoordinateRegion(center: origin, latitudinalMeters: 50000, longitudinalMeters: 50000)
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }

    func resolve(_ completion: MKLocalSearchCompletion, done: @escaping ((String, CLLocationCoordinate2D)?) -> Void) {
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        search.start { response, _ in
            guard let item = response?.mapItems.first else {
                done(nil)
                return
            }
            let name = [completion.title, completion.subtitle]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            done((name, item.placemark.coordinate))
        }
    }
}

struct PlaceSearchView: View {
    let title: String
    let initialQuery: String
    let isDark: Bool
    let onSelected: (String, CLLocationCoordinate2D) -> Void
    let onClose: () -> Void

    @StateObject private var model = PlaceSearchModel()
    @FocusState private var focused: Bool

    private var p: AuthPalette { AuthPalette(isDark: isDark) }

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20))
                            .foregroundColor(p.text)
                            .frame(width: 44, height: 44)
                    }
                    Text(title)
                        .font(ChapaFont.bold(17))
                        .foregroundColor(p.text)
                    Spacer()
                }
                .padding(.horizontal, 8)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ChapaTheme.purplePrimary)
                    TextField("", text: $model.query, prompt: Text("Buscar dirección o lugar").foregroundColor(p.muted))
                        .font(ChapaFont.medium(15))
                        .foregroundColor(p.text)
                        .focused($focused)
                        .autocorrectionDisabled()
                    if !model.query.isEmpty {
                        Button { model.query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(p.muted)
                        }
                    }
                }
                .padding(14)
                .background(p.panel)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.border, lineWidth: 1))
                .padding(.horizontal, 16)

                List(model.results, id: \.self) { result in
                    Button {
                        model.resolve(result) { resolved in
                            if let (address, coordinate) = resolved {
                                onSelected(address, coordinate)
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(ChapaTheme.purplePrimary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(ChapaFont.medium(14))
                                    .foregroundColor(p.text)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(ChapaFont.medium(12))
                                        .foregroundColor(p.muted)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(p.bg)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .onAppear {
            model.query = initialQuery
            focused = true
        }
    }
}
