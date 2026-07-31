import SwiftUI
import PhotosUI

// Puerto de EditProfileScreen.kt: formulario + foto (base64 → updatefull).
struct EditProfileView: View {
    let onBack: () -> Void
    let onSaved: () -> Void

    @State private var names = Session.shared.nameUser
    @State private var email = Session.shared.emailUser
    @State private var phone = Session.shared.phoneUser
    @State private var isLoading = false
    @State private var toastMessage: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    private var isDark: Bool { Session.shared.themeMode == 2 }
    private var p: AuthPalette { AuthPalette(isDark: isDark) }
    private var scale: CGFloat { chapaScaleFactor }

    private var formReady: Bool {
        !names.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.count == 9
    }

    var body: some View {
        ZStack {
            p.bg.ignoresSafeArea()

            SkylineGraphic(color: ChapaTheme.purplePrimary)
                .opacity(isDark ? 0.15 : 0.08)
                .padding(.top, 110 * scale)
                .frame(maxHeight: .infinity, alignment: .top)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 18))
                                .foregroundColor(p.text)
                                .frame(width: 44, height: 44)
                                .background(p.panel.opacity(0.5))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.border, lineWidth: 1))
                        }
                        Spacer()
                        Text("Editar Perfil")
                            .font(ChapaFont.bold(20 * scale))
                            .foregroundColor(p.text)
                        Spacer()
                        Image("LogoChapa")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.top, 24 * scale)

                    // Foto de perfil
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            profileImage
                                .frame(width: 120 * scale, height: 120 * scale)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(ChapaTheme.purplePrimary, lineWidth: 2))
                            Image(systemName: "pencil")
                                .font(.system(size: 14 * scale))
                                .foregroundColor(.white)
                                .frame(width: 32 * scale, height: 32 * scale)
                                .background(ChapaTheme.purplePrimary)
                                .clipShape(Circle())
                                .padding(4)
                        }
                    }
                    .padding(.top, 40 * scale)

                    VStack(spacing: 16 * scale) {
                        ChapaTextField(value: $names, label: "Nombres completos", icon: "person.fill", palette: p)
                        ChapaTextField(value: $email, label: "Correo electrónico", icon: "envelope.fill", keyboard: .emailAddress, palette: p)
                        ChapaTextField(value: $phone, label: "Número de celular", icon: "phone.fill", keyboard: .phonePad, palette: p)
                    }
                    .padding(.top, 32 * scale)

                    Button(action: save) {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Guardar cambios").font(ChapaFont.bold(16 * scale)).foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54 * scale)
                        .background(ChapaTheme.purplePrimary.opacity(formReady && !isLoading ? 1 : 0.5))
                        .cornerRadius(14)
                    }
                    .disabled(!formReady || isLoading)
                    .padding(.top, 40 * scale)

                    Spacer().frame(height: 48)
                }
                .padding(.horizontal, 24)
            }

            if isLoading {
                (isDark ? Color.black : Color.white).opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.4).tint(ChapaTheme.purplePrimary)
                    Text("Actualizando perfil...").font(ChapaFont.medium(16)).foregroundColor(p.text)
                }
            }
        }
        .toast($toastMessage)
        .onChange(of: photoItem) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pickedImage = image
                }
            }
        }
    }

    private var profileImage: some View {
        Group {
            if let pickedImage {
                Image(uiImage: pickedImage).resizable().scaledToFill()
            } else {
                let foto = Session.shared.savePhoto
                let url = foto.hasPrefix("http") ? foto : Config.imageURL + foto
                if !foto.isEmpty, let u = URL(string: url) {
                    AsyncImage(url: u) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill").font(.system(size: 44)).foregroundColor(p.muted)
                    }
                } else {
                    Image(systemName: "person.fill").font(.system(size: 44)).foregroundColor(p.muted)
                }
            }
        }
        .background(p.panel)
    }

    // Igual que MainActivity: updateInfo con foto base64 (updatefull) o sin foto (update)
    private func save() {
        isLoading = true
        let base64: String? = pickedImage
            .flatMap { $0.jpegData(compressionQuality: 0.7)?.base64EncodedString() }
        Task {
            do {
                let response = try await MenuAPI.updateProfile(
                    nombres: names, correo: email, telefono: phone, fotoBase64: base64
                )
                isLoading = false
                if response.code == "200" {
                    let s = Session.shared
                    s.nameUser = names
                    s.emailUser = email
                    s.phoneUser = phone
                    if let foto = response.foto ?? response.user?.foto { s.savePhoto = foto }
                    toastMessage = "Perfil actualizado"
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    onSaved()
                } else {
                    toastMessage = "No se pudo actualizar el perfil"
                }
            } catch {
                isLoading = false
                toastMessage = error.localizedDescription
            }
        }
    }
}
