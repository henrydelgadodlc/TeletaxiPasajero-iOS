import Foundation

// Equivalente de BuildConfig (build.gradle.kts de ChapaPasajero Android).
// Mantener valores idénticos a la app Android.
enum Config {
    static let baseURL = "https://api.teletaxi.city/api/"
    static let socketURL = "https://api.teletaxi.city/location_driver"
    static let policyURL = "https://teletaxi.city/admin/passengers/policity/"
    static let uploadImgURL = "https://teletaxi.city/admin/img-upload-db"
    static let trackingTokenURL = "https://teletaxi.city/admin/trk-token?viaje_id="
    static let trackingViewURL = "https://teletaxi.city/admin/trk-view/"
    static let imageURL = "https://api.teletaxi.city/images/"
}
