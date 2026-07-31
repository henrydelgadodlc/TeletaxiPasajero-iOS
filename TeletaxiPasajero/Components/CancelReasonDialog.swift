import SwiftUI

// Puerto de CancelReasonDialog.kt: diálogo único de cancelación con motivo.
let MOTIVOS_CANCELACION_VIAJE = [
    "Se reventó la llanta",
    "Se malogró el vehículo",
    "Hubo un choque o accidente",
    "El conductor no llega"
]

let MOTIVOS_CANCELACION_ESPERA = [
    "Los conductores tardan mucho",
    "Las ofertas son muy caras",
    "Ya no necesito el taxi",
    "Me equivoqué de dirección"
]

let MOTIVOS_CANCELACION_LLEGADA = [
    "No podré llegar al punto de recojo",
    "El conductor está mal ubicado",
    "Me demoraré más del tiempo de espera",
    "Ya no necesito el taxi"
]

struct CancelReasonDialog: View {
    let isDark: Bool
    var motivos: [String] = MOTIVOS_CANCELACION_VIAJE
    let onConfirm: (String) -> Void
    let onDismiss: () -> Void

    @State private var seleccion: String?
    @State private var otroTexto = ""

    private let otroLabel = "Otro motivo"
    private var c: HomeColors { HomeColors(isDark: isDark) }
    private var opciones: [String] { motivos + [otroLabel] }
    private var esOtro: Bool { seleccion == otroLabel }
    private var motivoFinal: String {
        esOtro ? otroTexto.trimmingCharacters(in: .whitespaces) : (seleccion ?? "")
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 8) {
                Text("Cancelar servicio")
                    .font(ChapaFont.bold(18))
                    .foregroundColor(c.textMain)

                Text("Cuéntanos por qué se cancela el viaje:")
                    .font(ChapaFont.medium(13))
                    .foregroundColor(c.textMuted)

                ForEach(opciones, id: \.self) { opcion in
                    Button { seleccion = opcion } label: {
                        HStack(spacing: 10) {
                            Image(systemName: seleccion == opcion ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(seleccion == opcion ? c.purplePrimary : c.textMuted)
                            Text(opcion)
                                .font(ChapaFont.medium(13))
                                .foregroundColor(c.textMain)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                if esOtro {
                    TextField("", text: Binding(
                        get: { otroTexto },
                        set: { otroTexto = String($0.prefix(200)) }
                    ), prompt: Text("Escribe el motivo...").font(ChapaFont.medium(13)).foregroundColor(c.textDim))
                    .font(ChapaFont.medium(13))
                    .foregroundColor(c.textMain)
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(c.borderPurple, lineWidth: 1))
                }

                HStack {
                    Spacer()
                    Button("Volver", action: onDismiss)
                        .font(ChapaFont.medium(14))
                        .foregroundColor(c.textMuted)

                    Button {
                        onConfirm(motivoFinal)
                    } label: {
                        Text("Cancelar servicio")
                            .font(ChapaFont.bold(14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(ChapaTheme.red.opacity(motivoFinal.isEmpty ? 0.3 : 1))
                            .cornerRadius(12)
                    }
                    .disabled(motivoFinal.isEmpty)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(c.cardBg)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(c.borderPurple, lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }
}
