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
    // Day-2 forecast (nil if the API response only covered today) —
    // used by the premium "tomorrow briefing" preview.
    let tomorrowMax: Double?
    let tomorrowMin: Double?
    let tomorrowCode: Int?

    static func conditionLabel(for code: Int, language: String) -> String {
        let isDE = language == "de"
        switch code {
        case 0:           return isDE ? "Klarer Himmel" : "Clear sky"
        case 1:           return isDE ? "Überwiegend klar" : "Mostly clear"
        case 2:           return isDE ? "Teils bewölkt" : "Partly cloudy"
        case 3:           return isDE ? "Bewölkt" : "Overcast"
        case 45, 48:      return isDE ? "Nebel" : "Fog"
        case 51, 53, 55:  return isDE ? "Nieselregen" : "Drizzle"
        case 61, 63, 65:  return isDE ? "Regen" : "Rain"
        case 71, 73, 75:  return isDE ? "Schneefall" : "Snow"
        case 77:          return isDE ? "Schneegriesel" : "Snow grains"
        case 80, 81, 82:  return isDE ? "Regenschauer" : "Rain showers"
        case 85, 86:      return isDE ? "Schneeschauer" : "Snow showers"
        case 95:          return isDE ? "Gewitter" : "Thunderstorm"
        case 96, 99:      return isDE ? "Gewitter mit Hagel" : "Thunderstorm with hail"
        default:          return isDE ? "Unbekannt" : "Unknown"
        }
    }

    func conditionLabel(language: String) -> String {
        Self.conditionLabel(for: weatherCode, language: language)
    }

    static func sfSymbol(for code: Int) -> String {
        switch code {
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

    var sfSymbol: String { Self.sfSymbol(for: weatherCode) }

    func briefingSnippet(language: String) -> String {
        let temp = Int(temperatureCurrent.rounded())
        let high = Int(temperatureMax.rounded())
        let low = Int(temperatureMin.rounded())
        return "\(conditionLabel(language: language)), \(temp)°C (↑\(high)° ↓\(low)°)"
    }

    /// Forecast line for tomorrow, e.g. "Regen, 12° bis 18°" — nil if no day-2 data.
    func tomorrowSnippet(language: String) -> String? {
        guard let code = tomorrowCode, let max = tomorrowMax, let min = tomorrowMin else { return nil }
        let condition = Self.conditionLabel(for: code, language: language)
        let range = language == "de"
            ? "\(Int(min.rounded()))° bis \(Int(max.rounded()))°"
            : "\(Int(min.rounded()))° to \(Int(max.rounded()))°"
        return "\(condition), \(range)"
    }
}

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var weather: WeatherData?
    @Published private(set) var locationDenied: Bool = false

    private let locationManager = CLLocationManager()
    // Multiple concurrent fetches may wait on one location — every
    // continuation must be resumed exactly once, so keep them all.
    private var locationContinuations: [CheckedContinuation<CLLocation?, Never>] = []
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
                locationContinuations.append(continuation)
            }
        case .denied, .restricted:
            locationDenied = true
            return nil
        default:
            return await withCheckedContinuation { continuation in
                locationContinuations.append(continuation)
                locationManager.requestLocation()
            }
        }
    }

    private func resumeLocationWaiters(with location: CLLocation?) {
        let waiters = locationContinuations
        locationContinuations = []
        for continuation in waiters {
            continuation.resume(returning: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            self.cachedLocation = location
            self.resumeLocationWaiters(with: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.resumeLocationWaiters(with: nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if !self.locationContinuations.isEmpty {
                    self.locationManager.requestLocation()
                }
            case .denied, .restricted:
                self.locationDenied = true
                self.resumeLocationWaiters(with: nil)
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
            .init(name: "forecast_days", value: "2"),
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
        let dailyCodes = (daily["weather_code"] as? [Int]) ?? []

        return WeatherData(
            temperatureCurrent: temp,
            temperatureApparent: apparent,
            temperatureMax: maxTemps.first ?? temp,
            temperatureMin: minTemps.first ?? temp,
            weatherCode: code,
            windSpeed: wind,
            precipitation: precip,
            fetchedAt: Date(),
            tomorrowMax: maxTemps.count > 1 ? maxTemps[1] : nil,
            tomorrowMin: minTemps.count > 1 ? minTemps[1] : nil,
            tomorrowCode: dailyCodes.count > 1 ? dailyCodes[1] : nil
        )
    }
}
