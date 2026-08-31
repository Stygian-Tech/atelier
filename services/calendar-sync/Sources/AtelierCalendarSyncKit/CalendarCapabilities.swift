import AtelierProviders
import Foundation

public enum CalendarSourceKind: String, CaseIterable, Codable, Sendable {
    case ics
    case community
    case googleCalendar
    case microsoftCalendar
    case caldav
}

public enum CalendarSourceRole: String, Codable, Sendable {
    case icsSubscription
    case communitySubscription
    case googleProvider
    case microsoftProvider
    case caldavProvider
}

public enum CalendarSourceTransport: String, Codable, Sendable {
    case iCalendarFeed
    case communityFeed
    case googleCalendarAPI
    case microsoftGraph
    case calDAV
}

public enum CalendarAdapterAvailability: String, Codable, Sendable {
    case contractOnly
}

public struct CalendarSourceCapabilityDescriptor: Equatable, Sendable {
    public let source: CalendarSourceKind
    public let role: CalendarSourceRole
    public let transport: CalendarSourceTransport
    public let sourceAuthority: CalendarSourceAuthority
    public let incrementalSync: Bool
    public let pushNotifications: Bool
    public let recurrence: Bool
    public let attendees: Bool
    public let writeback: Bool
    public let preservesCompleteICalendar: Bool
    public let availability: CalendarAdapterAvailability

    public init(
        source: CalendarSourceKind,
        role: CalendarSourceRole,
        transport: CalendarSourceTransport,
        sourceAuthority: CalendarSourceAuthority,
        incrementalSync: Bool,
        pushNotifications: Bool,
        recurrence: Bool,
        attendees: Bool,
        writeback: Bool,
        preservesCompleteICalendar: Bool = true,
        availability: CalendarAdapterAvailability = .contractOnly
    ) {
        self.source = source
        self.role = role
        self.transport = transport
        self.sourceAuthority = sourceAuthority
        self.incrementalSync = incrementalSync
        self.pushNotifications = pushNotifications
        self.recurrence = recurrence
        self.attendees = attendees
        self.writeback = writeback
        self.preservesCompleteICalendar = preservesCompleteICalendar
        self.availability = availability
    }
}

public enum CalendarSyncCapabilities {
    public static let orderedSources: [CalendarSourceCapabilityDescriptor] = [
        .init(
            source: .ics,
            role: .icsSubscription,
            transport: .iCalendarFeed,
            sourceAuthority: .subscribedFeed,
            incrementalSync: true,
            pushNotifications: false,
            recurrence: true,
            attendees: true,
            writeback: false
        ),
        .init(
            source: .community,
            role: .communitySubscription,
            transport: .communityFeed,
            sourceAuthority: .subscribedFeed,
            incrementalSync: true,
            pushNotifications: false,
            recurrence: true,
            attendees: true,
            writeback: false
        ),
        providerDescriptor(
            source: .googleCalendar,
            role: .googleProvider,
            transport: .googleCalendarAPI,
            provider: .googleCalendar
        ),
        providerDescriptor(
            source: .microsoftCalendar,
            role: .microsoftProvider,
            transport: .microsoftGraph,
            provider: .microsoftCalendar
        ),
        providerDescriptor(
            source: .caldav,
            role: .caldavProvider,
            transport: .calDAV,
            provider: .caldav
        ),
    ]

    private static func providerDescriptor(
        source: CalendarSourceKind,
        role: CalendarSourceRole,
        transport: CalendarSourceTransport,
        provider: CalendarProviderKind
    ) -> CalendarSourceCapabilityDescriptor {
        let capabilities = provider.capabilities
        return CalendarSourceCapabilityDescriptor(
            source: source,
            role: role,
            transport: transport,
            sourceAuthority: .provider,
            incrementalSync: capabilities.incrementalSync,
            pushNotifications: capabilities.pushNotifications,
            recurrence: capabilities.recurrence,
            attendees: capabilities.attendees,
            writeback: capabilities.writeback
        )
    }
}
