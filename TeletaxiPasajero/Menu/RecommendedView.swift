import SwiftUI
import CoreLocation

// Puerto de RecommendedScreen.kt: banners destacados, categorías y lugares;
// al elegir uno se fija como destino en el Home.
struct RecommendedView: View {
    let onBack: () -> Void
    let onPlaceSelected: (String, CLLocationCoordinate2D) -> Void

    @State private var featured: [RecommendedPlace] = []
    @State private var categories: [RecommendedCategory] = []
    @State private var places: [RecommendedPlace] = []
    @State private var selectedCategoryId: Int?
    @State private var isLoading = false
    @State private var bannerIndex = 0

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var c: HomeColors { HomeColors(isDark: isDark) }

    var body: some View {
        ZStack {
            c.darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                MenuHeader(title: "Explorar lugares", c: c, onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !featured.isEmpty {
                            bannersCarousel
                                .padding(.bottom, 24)
                        }

                        Text("Categorías")
                            .font(ChapaFont.bold(18))
                            .foregroundColor(c.textMain)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                categoryChip(nil, name: "Todos")
                                ForEach(categories) { cat in
                                    categoryChip(cat.id_categoria, name: cat.nombre)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 28)

                        Text(selectedCategoryId == nil ? "Recomendados para ti" : "Resultados")
                            .font(ChapaFont.bold(18))
                            .foregroundColor(c.textMain)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        if places.isEmpty && !isLoading {
                            Text("No hay lugares en esta categoría.")
                                .font(ChapaFont.medium(13))
                                .foregroundColor(c.textMuted)
                                .padding(.horizontal, 20)
                        }

                        VStack(spacing: 12) {
                            ForEach(places) { place in
                                placeCard(place)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 80)
                    }
                }
            }

            if isLoading {
                c.darkBg.opacity(0.6).ignoresSafeArea()
                ProgressView().tint(ChapaTheme.purplePrimary)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        isLoading = true
        Task {
            async let f = MenuAPI.featuredPlaces()
            async let cats = MenuAPI.categories()
            async let recs = MenuAPI.recommendedPlaces(categoryId: nil)
            featured = (try? await f) ?? []
            categories = (try? await cats) ?? []
            places = (try? await recs) ?? []
            isLoading = false
        }
    }

    private func selectCategory(_ id: Int?) {
        selectedCategoryId = id
        isLoading = true
        Task {
            places = (try? await MenuAPI.recommendedPlaces(categoryId: id)) ?? []
            isLoading = false
        }
    }

    // Banners destacados (FeaturedBanners/BannersCarousel)
    private var bannersCarousel: some View {
        TabView(selection: $bannerIndex) {
            ForEach(Array(featured.enumerated()), id: \.offset) { index, place in
                Button {
                    onPlaceSelected(place.nombre, CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng))
                } label: {
                    AsyncImage(url: URL(string: (place.banner_url?.isEmpty == false ? place.banner_url : place.logo_url) ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        c.surfaceDark
                    }
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: featured.count > 1 ? .always : .never))
        .frame(height: 175)
        .onReceive(Timer.publish(every: 6, on: .main, in: .common).autoconnect()) { _ in
            guard featured.count > 1 else { return }
            withAnimation { bannerIndex = (bannerIndex + 1) % featured.count }
        }
    }

    private func categoryChip(_ id: Int?, name: String) -> some View {
        let selected = selectedCategoryId == id
        return Button { selectCategory(id) } label: {
            Text(name)
                .font(selected ? ChapaFont.bold(13) : ChapaFont.medium(13))
                .foregroundColor(selected ? .white : c.textMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(selected ? ChapaTheme.purplePrimary : c.cardBg)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? ChapaTheme.purplePrimary : c.borderPurple, lineWidth: 1))
        }
    }

    private func placeCard(_ place: RecommendedPlace) -> some View {
        Button {
            onPlaceSelected(place.nombre, CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng))
        } label: {
            HStack(spacing: 14) {
                AsyncImage(url: URL(string: place.logo_url ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(ChapaTheme.purplePrimary.opacity(0.4))
                }
                .frame(width: 56, height: 56)
                .background(ChapaTheme.purplePrimary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 3) {
                    Text(place.nombre)
                        .font(ChapaFont.bold(15))
                        .foregroundColor(c.textMain)
                        .lineLimit(1)
                    Text(place.direccion ?? "")
                        .font(ChapaFont.medium(12))
                        .foregroundColor(c.textMuted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let cat = place.categoria_nombre, !cat.isEmpty {
                        Text(cat)
                            .font(ChapaFont.bold(10))
                            .foregroundColor(ChapaTheme.purpleLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(ChapaTheme.purplePrimary.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(c.textMuted)
            }
            .padding(12)
            .background(c.cardBg)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(c.borderPurple, lineWidth: 1))
        }
    }
}
