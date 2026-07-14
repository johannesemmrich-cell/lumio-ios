import CoreLocation
import Foundation

struct WeatherData {
    let temperatureCurrent: Double
    let temperatureApparent: Double
    let temperatureMax: Double
    let temperatureMin: Double
    let weatherCode: Int
    let windSpeed: Double
    let precipitation: Double
    let fetchedAt: Date

    var conditionLabel: String {
        switch weatherCode {
        case 0:           return "Klarer Himmel"
        case 1:           return "Überwiegend klar"
        case 2:           return "Teils bewölkt"
        case 3:           return "Bewölkt"
        case 45, 48:      return "Nebel"
        case 51, 53, 55:  return "Nieselregen"
        case 61, 63, 65:  return "Regen"
        case 71, 73, 75:  return "Schneefall"
        case 77:          return "Schneegriesel"
        case 80, 81, 82:  return "Regenschauer"
        case 85, 86:      return "Schneeschauer"
        case 95:          return "Gewitter"
        case 96, 99:      return "Gewitter mit Hagel"
        default:          return "Unbekannt"
        }
    }

    var sfSymbol: String {
        switch weatherCode {
        case 0:           return "sun.max.fill"
        case 1, 2:        return "cloud.sun.fill"
        case 3:           return "cloud.fill"
        case 45, 48:      return "cloud.fog.fill"
        case 51, 53, 55:  return "cloud.drizzle.fill"
        case 61, 63, 65:  return "cloud.rain.fill"
        case 71, 73, 75:  return "snowflake"
        case 77:          return "cloud.snow.fill"
        case 80, 81, 82:  return "cloud.heavyrain.fill"
        case 85, 86:      return "cloud.snow.fill"
        case 95, 96, 99:  return "cloud.bolt.rain.fill"
        default:          return "cloud.fill"
        }
    }

    var briefingSnippet: String {
        let temp = Int(temperatureCurrent.rounded())
        let high = Int(temperatureMax.rounded())
        let low = Int(temperatureMin.rounded())
        return "\(conditionLabel), \(temp)°C (↑\(high)° ↓\(low)°)"
    }
}

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var weather: WeatherData?
    @Published private(set) var locationDenied: Bool = false

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    private var cachedLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func fetchWeather() async {
        if let cached = weather, Date().timeIntervalSince(cached.fetchedAt) < 1800 { return }

        let location = await resolveLocation()
        guard let loc = location else { return }

        let data = await fetchFromOpenMeteo(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        weather = data
    }

    // MARK: — Location

    private func resolveLocation() async -> CLLocation? {
        if let cached = cachedLocation { return cached }

        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            // Request auth; when granted, locationManagerDidChangeAuthorization triggers requestLocation()
            locationManager.requestWhenInUseAuthorization()
            return await withCheckedContinuation { continuation in
                locationContinuation = continuation
            }
        case .denied, .restricted:
            locationDenied = true
            return nil
        default:
            return await withCheckedContinuation { continuation in
                locationContinuation = continuation
                locationManager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.cachedLocation = location
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.locationContinuation != nil {
                    self.locationManager.requestLocation()
                }
            case .denied, .restricted:
                self.locationDenied = true
                self.locationContinuation?.resume(returning: nil)
                self.locationContinuation = nil
            default:
                break
            }
        }
    }

    // MARK: — Open-Meteo API

    private func fetchFromOpenMeteo(lat: Double, lon: Double) async -> WeatherData? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(lat)),
            .init(name: "longitude", value: String(lon)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "1"),
        ]

        guard let url = comps.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseResponse(data)
        } catch {
            return nil
        }
    }

    private func parseResponse(_ data: Data) -> WeatherData? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let current = json["current"] as? [String: Any],
            let daily = json["daily"] as? [String: Any]
        else { return nil }

        let temp     = (current["temperature_2m"] as? Double) ?? 0
        let apparent = (current["apparent_temperature"] as? Double) ?? 0
        let code     = (current["weather_code"] as? Int) ?? 0
        let wind     = (current["wind_speed_10m"] as? Double) ?? 0
        let precip   = (current["precipitation"] as? Double) ?? 0
        let maxTemps = (daily["temperature_2m_max"] as? [Double]) ?? []
        let minTemps = (daily["temperature_2m_min"] as? [Double]) ?? []

        return WeatherData(
            temperatureCurrent: temp,
            temperatureApparent: apparent,
            temperatureMax: maxTemps.first ?? temp,
            temperatureMin: minTemps.first ?? temp,
            weatherCode: code,
            windSpeed: wind,
            precipitation: precip,
            fetchedAt: Date()
        )
    }
}
