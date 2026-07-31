import SwiftUI
import CoreLocation

// Puerto de PlacesScreen.kt + Container: favoritos con alta (título +
// búsqueda de dirección), borrado con confirmación y selección.
struct PlacesView: View {
    let onBack: () -> Void
    // Al tocar un favorito (se usa como selector desde el Home)
    var onPlaceSelected: ((FavoritePlace) -> Void)?

    @State private var places: [FavoritePlace] = []
    @State private var isLoading = false
    @State private var showAddDialog = false
    @State private var placeToDelete: FavoritePlace?
    @State private var toastMessage: String?

    // Alta de lugar
    @State private var newTitle = ""
    @State private var searchedAddress = ""
    @State private var searchedCoord: CLLocationCoordinate2D?
    @State private var showSearch = false

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MenuHeader(title: "Mis lugares favoritos", c: c, onBack: onBack)

                if isLoading && places.isEmpty {
                    Spacer()
                    ProgressView().tint(ChapaTheme.purplePrimary)
                    Spacer()
                } else if places.isEmpty {
                    EmptyMenuState(
                        icon: "star.fill",
                        title: "No tienes favoritos aún",
                        description: "Guarda tus destinos frecuentes para viajar con un solo toque.",
                        c: c
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(places) { place in
                                placeCard(place)
                            }
                        }
                        .padding(16)
                        .padding(.bottom, 80)
                    }
                }
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        newTitle = ""
                        searchedAddress = ""
                        searchedCoord = nil
                        showAddDialog = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(ChapaTheme.purplePrimary)
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                    }
                    .padding(20)
                }
            }

            if showAddDialog {
                addPlaceDialog
            }
        }
        .toast($toastMessage)
        .onAppear { load() }
        .alert("Eliminar favorito", isPresented: Binding(
            get: { placeToDelete != nil },
            set: { if !$0 { placeToDelete = nil } }
        )) {
            Button("Eliminar", role: .destructive) {
                if let place = placeToDelete {
                    delete(place)
                }
                placeToDelete = nil
            }
            Button("Cancelar", role: .cancel) { placeToDelete = nil }
        } message: {
            Text("¿Deseas quitar este lugar de tus favoritos?")
        }
        .background(
            EmptyView().fullScreenCover(isPresented: $showSearch) {
                PlaceSearchView(
                    title: "Buscar dirección",
                    initialQuery: newTitle,
                    isDark: isDark,
                    onSelected: { address, coordinate in
                        searchedAddress = address
                        searchedCoord = coordinate
                        showSearch = false
                    },
                    onClose: { showSearch = false }
                )
            }
        )
    }

    private func load() {
        isLoading = true
        Task {
            places = (try? await MenuAPI.favoritePlaces()) ?? []
            isLoading = false
        }
    }

    private func delete(_ place: FavoritePlace) {
        Task {
            try? await MenuAPI.deletePlace(id: place.id)
            toastMessage = "Lugar eliminado"
            load()
        }
    }

    private func placeCard(_ place: FavoritePlace) -> some View {
        Button {
            onPlaceSelected?(place)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 20))
                    .foregroundColor(ChapaTheme.purplePrimary)
                    .frame(width: 48, height: 48)
                    .background(ChapaTheme.purplePrimary.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.titulo)
                        .font(ChapaFont.bold(16))
                        .foregroundColor(c.textMain)
                        .lineLimit(1)
                    Text(place.direccion)
                        .font(ChapaFont.medium(13))
                        .foregroundColor(c.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { placeToDelete = place } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17))
                        .foregroundColor(.red.opacity(0.6))
                        .frame(width: 40, height: 40)
                }
            }
            .padding(16)
            .background(c.cardBg)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(c.borderPurple, lineWidth: 1))
        }
    }

    // Diálogo de alta (AddPlaceDialog)
    private var addPlaceDialog: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { showAddDialog = false }

            VStack(alignment: .leading, spacing: 14) {
                Text("Nuevo lugar favorito")
                    .font(ChapaFont.bold(18))
                    .foregroundColor(c.textMain)

                TextField("", text: $newTitle, prompt: Text("Título (Casa, Trabajo...)").foregroundColor(c.textDim))
                    .font(ChapaFont.medium(14))
                    .foregroundColor(c.textMain)
                    .padding(12)
                    .background(c.surfaceDark)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.borderPurple, lineWidth: 1))

                Button { showSearch = true } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ChapaTheme.purplePrimary)
                        Text(searchedAddress.isEmpty ? "Buscar dirección" : searchedAddress)
                            .font(ChapaFont.medium(13))
                            .foregroundColor(searchedAddress.isEmpty ? c.textDim : c.textMain)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(12)
                    .background(c.surfaceDark)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.borderPurple, lineWidth: 1))
                }

                HStack {
                    Spacer()
                    Button("Cancelar") { showAddDialog = false }
                        .font(ChapaFont.medium(14))
                        .foregroundColor(c.textMuted)
                    Button {
                        guard let coord = searchedCoord else { return }
                        showAddDialog = false
                        Task {
                            do {
                                try await MenuAPI.createPlace(
                                    titulo: newTitle,
                                    direccion: searchedAddress,
                                    lat: coord.latitude,
                                    lng: coord.longitude
                                )
                                toastMessage = "Lugar guardado con éxito"
                                load()
                            } catch {
                                toastMessage = "Error al guardar el lugar"
                            }
                        }
                    } label: {
                        Text("Guardar")
                            .font(ChapaFont.bold(14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(ChapaTheme.purplePrimary.opacity(newTitle.isEmpty || searchedCoord == nil ? 0.4 : 1))
                            .cornerRadius(12)
                    }
                    .disabled(newTitle.isEmpty || searchedCoord == nil)
                }
            }
            .padding(20)
            .background(c.cardBg)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(c.borderPurple, lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }
}
