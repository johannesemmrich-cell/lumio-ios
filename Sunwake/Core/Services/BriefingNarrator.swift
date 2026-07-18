import Foundation

/// Builds the spoken narrative briefing from the day's data.
/// Extracted from PlayBarView so playback UI and the AI prompt share one source of truth.
enum BriefingNarrator {
    /// Single source of truth for the time-of-day greeting and daypart label —
    /// used by the Today header, the AI prompt (pinned greeting) and this
    /// narrative fallback, so they can never disagree.
    static func timeOfDay(language: String, date: Date = Date()) -> (greeting: String, daypart: String) {
        let isDE = language.hasPrefix("de")
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12:  return (isDE ? "Guten Morgen" : "Good morning", isDE ? "Morgen" : "morning")
        case 12..<17: return (isDE ? "Guten Tag" : "Good afternoon", isDE ? "Nachmittag" : "afternoon")
        case 17..<22: return (isDE ? "Guten Abend" : "Good evening", isDE ? "Abend" : "evening")
        default:      return (isDE ? "Hallo" : "Hello", isDE ? "Nacht" : "night")
        }
    }

    static func narrative(events: [CalendarEvent], reminders: [ReminderItem], weather: WeatherData?, language: String) -> String {
        let isDE = language == "de"
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"

        let greeting = timeOfDay(language: language).greeting + "!"

        var parts: [String] = [greeting]

        // Weather
        if let w = weather {
            let temp = Int(w.temperatureCurrent.rounded())
            if isDE {
                parts.append("Das Wetter heute: \(w.conditionLabel(language: language)), \(temp) Grad.")
            } else {
                parts.append("Today's weather: \(w.conditionLabel(language: language)), \(temp) degrees.")
            }
        }

        // Events
        if events.isEmpty && reminders.isEmpty {
            parts.append(isDE
                ? "Du hast heute keine Termine oder Erinnerungen. Genieße den freien Tag!"
                : "You have no events or reminders today. Enjoy your free day!")
        } else {
            if !events.isEmpty {
                if isDE {
                    parts.append("Du hast \(events.count == 1 ? "einen Termin" : "\(events.count) Termine") heute.")
                } else {
                    parts.append("You have \(events.count == 1 ? "one event" : "\(events.count) events") today.")
                }

                for (index, event) in events.enumerated() {
                    let timeStr = event.isAllDay
                        ? (isDE ? "den ganzen Tag" : "all day")
                        : (isDE ? "um \(fmt.string(from: event.startDate)) Uhr" : "at \(fmt.string(from: event.startDate))")
                    let locationPart: String
                    if let loc = event.location, !loc.isEmpty {
                        locationPart = isDE ? ", in \(loc)," : ", at \(loc),"
                    } else {
                        locationPart = ""
                    }
                    let sentence: String
                    if index == 0 {
                        sentence = isDE
                            ? "Dein Tag startet \(timeStr) mit \(event.title)\(locationPart)."
                            : "Your day starts \(timeStr) with \(event.title)\(locationPart)."
                    } else if index == events.count - 1 {
                        sentence = isDE
                            ? "Und zum Abschluss hast du \(timeStr) \(event.title)\(locationPart)."
                            : "And to wrap up, you have \(event.title) \(timeStr)\(locationPart)."
                    } else {
                        let transitions = isDE
                            ? ["Danach", "Anschließend", "Im Anschluss"]
                            : ["Then", "After that,", "Next up:"]
                        let transition = transitions[index % transitions.count]
                        sentence = isDE
                            ? "\(transition) geht es \(timeStr) weiter mit \(event.title)\(locationPart)."
                            : "\(transition) \(event.title) \(timeStr)\(locationPart)."
                    }
                    parts.append(sentence)
                }
            }

            if !reminders.isEmpty {
                if isDE {
                    parts.append("Deine Erinnerungen für heute: \(reminders.prefix(3).map(\.title).joined(separator: ", ")).")
                } else {
                    parts.append("Your reminders today: \(reminders.prefix(3).map(\.title).joined(separator: ", ")).")
                }
            }
        }

        parts.append(isDE ? "Das war dein Briefing — einen schönen Tag!" : "That's your briefing — have a great day!")
        return parts.joined(separator: " ")
    }
}
