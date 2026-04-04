//
//  ContentProvider.swift
//  NewsJunkieTopShelf
//
//  Created by Chris Lane on 3/18/26.
//

import Foundation
import TVServices
import UIKit

final class ContentProvider: TVTopShelfContentProvider {
    private let sharedStore = TopShelfSharedStore()
    private let apiClient = TopShelfAPIClient()

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        let shows = await loadShows()
        let liveState = await loadLiveStreamState()
        guard !shows.isEmpty || liveState.isVisible else { return nil }

        let records = sharedStore.playbackRecords
        let imageURLs = await TopShelfImageResolver.resolveImageURLs(for: shows)
        return TopShelfContentBuilder.makeContent(
            shows: shows,
            playbackRecords: records,
            liveState: liveState,
            imageURLs: imageURLs
        )
    }

    private func loadShows() async -> [TopShelfShow] {
        if let session = sharedStore.currentSession {
            do {
                let shows = try await apiClient.fetchSecretShows(session: session).filter(\.hasVideo)
                sharedStore.saveCachedShows(shows)
                return shows
            } catch {
                let cachedShows = sharedStore.cachedShows
                if !cachedShows.isEmpty {
                    return cachedShows
                }
            }
        }

        return sharedStore.cachedShows
    }

    private func loadLiveStreamState() async -> TopShelfLiveStreamState {
        do {
            let settings = try await apiClient.fetchTVSettings()
            return try await apiClient.resolveLiveStreamState(from: settings)
        } catch {
            return .hidden
        }
    }
}

private enum TopShelfSharedStorage {
    static let appGroupID = "group.com.thenewsjunkie.secretshows"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

private enum TopShelfStorageKeys {
    static let session = "tv.secretshows.session"
    static let playbackProgress = "tv.secretshows.playbackProgress"
    static let cachedShows = "tv.secretshows.cachedShows"
    static let deviceID = "tv.secretshows.deviceID"
}

private struct TopShelfUserSession: Codable {
    let userID: Int
    let authKey: String
    let email: String
}

private struct TopShelfShow: Codable, Hashable {
    let id: String
    let title: String
    let audioURL: String
    let videoURL: String
    let posterImage: String?
    let pubDate: String?
    let descriptionText: String
    let images: [TopShelfShowImage]

    var hasVideo: Bool {
        let normalized = playbackURLString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !normalized.isEmpty && normalized != "<null>" && normalized != "null"
    }

    var playbackURLString: String {
        let normalized = videoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let iframePrefix = "https://iframe.mediadelivery.net/"

        guard normalized.hasPrefix(iframePrefix) else {
            return normalized
        }

        guard let streamID = normalized.split(separator: "/").last, !streamID.isEmpty else {
            return normalized
        }

        return "https://vz-dcd66bc4-d38.b-cdn.net/\(streamID)/playlist.m3u8"
    }

    var publishedAt: Date {
        guard let pubDate,
              let date = TopShelfDateFormatter.inputFormatter.date(from: pubDate) else {
            return .distantPast
        }
        return date
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title = "Title"
        case audioURL = "Url"
        case videoURL = "videoUrl"
        case posterImage
        case pubDate
        case descriptionText = "description"
        case images = "SeeItNowNew"
    }
}

private struct TopShelfShowImage: Codable, Hashable {
    let image: String?
    let text: String?
}

private struct TopShelfPlaybackRecord: Codable {
    var lastWatchedTime: Double = 0
    var duration: Double = 0
    var isCompleted = false
    var lastUpdatedAt: Date?

    var isStarted: Bool {
        lastWatchedTime > TopShelfPlaybackRules.startedThreshold
    }

    var progressFraction: Double {
        guard duration > 0 else { return 0 }
        return min(max(lastWatchedTime / duration, 0), 1)
    }
}

private enum TopShelfPlaybackRules {
    static let startedThreshold: Double = 30
}

private enum TopShelfDateFormatter {
    static let inputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let liveWindowFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()
}

private enum TopShelfLiveStreamState {
    case hidden
    case visible(url: URL)

    var isVisible: Bool {
        if case .visible = self {
            return true
        }
        return false
    }
}

private final class TopShelfSharedStore {
    private let defaults = TopShelfSharedStorage.defaults

    var currentSession: TopShelfUserSession? {
        guard let data = defaults.data(forKey: TopShelfStorageKeys.session) else { return nil }
        return try? JSONDecoder().decode(TopShelfUserSession.self, from: data)
    }

    var cachedShows: [TopShelfShow] {
        guard let data = defaults.data(forKey: TopShelfStorageKeys.cachedShows),
              let shows = try? JSONDecoder().decode([TopShelfShow].self, from: data) else {
            return []
        }
        return shows
    }

    var playbackRecords: [String: TopShelfPlaybackRecord] {
        guard let storedValue = defaults.object(forKey: TopShelfStorageKeys.playbackProgress) else {
            return [:]
        }

        if let data = storedValue as? Data,
           let records = try? JSONDecoder().decode([String: TopShelfPlaybackRecord].self, from: data) {
            return records
        }

        if let legacyRecords = storedValue as? [String: Double] {
            return legacyRecords.reduce(into: [:]) { result, item in
                result[item.key] = TopShelfPlaybackRecord(lastWatchedTime: item.value, duration: 0, isCompleted: false)
            }
        }

        return [:]
    }

    func saveCachedShows(_ shows: [TopShelfShow]) {
        guard let data = try? JSONEncoder().encode(shows) else { return }
        defaults.set(data, forKey: TopShelfStorageKeys.cachedShows)
    }
}

private enum TopShelfContentBuilder {
    static func makeContent(
        shows: [TopShelfShow],
        playbackRecords: [String: TopShelfPlaybackRecord],
        liveState: TopShelfLiveStreamState,
        imageURLs: [String: URL]
    ) -> TVTopShelfSectionedContent? {
        let showsByID = Dictionary(uniqueKeysWithValues: shows.map { ($0.id, $0) })
        let newestShows = shows.sorted { $0.publishedAt > $1.publishedAt }

        let startedShowIDs = Set(
            playbackRecords.compactMap { key, record in
                record.isStarted ? key : nil
            }
        )

        let latestShow = newestShows.first
        let latestID = latestShow?.id

        let continueWatchingShows = playbackRecords
            .filter { _, record in
                record.isStarted && !record.isCompleted
            }
            .sorted {
                ($0.value.lastUpdatedAt ?? .distantPast) > ($1.value.lastUpdatedAt ?? .distantPast)
            }
            .compactMap { showsByID[$0.key] }
            .filter { $0.id != latestID }
            .prefix(4)
            .map { $0 }

        let continueWatchingIDs = Set(continueWatchingShows.map(\.id))

        let fallbackShows = newestShows.filter { show in
            guard show.id != latestID else { return false }
            guard !continueWatchingIDs.contains(show.id) else { return false }
            return !startedShowIDs.contains(show.id)
        }

        var sections = [TVTopShelfItemCollection<TVTopShelfSectionedItem>]()

        if case .visible(let liveURL) = liveState {
            var liveSectionItems = [TVTopShelfSectionedItem]()

            if let liveItem = makeLiveItem(streamURL: liveURL) {
                liveSectionItems.append(liveItem)
            }

            if let latestShow,
               let latestItem = makeSectionedItem(
                for: latestShow,
                playbackRecord: playbackRecords[latestShow.id],
                imageURL: imageURLs[latestShow.id]
               ) {
                liveSectionItems.append(latestItem)
            }

            if !liveSectionItems.isEmpty {
                let collection = TVTopShelfItemCollection(items: liveSectionItems)
                collection.title = "LIVE NOW!"
                sections.append(collection)
            }
        } else if let latestShow,
                  let latestItem = makeSectionedItem(
                    for: latestShow,
                    playbackRecord: playbackRecords[latestShow.id],
                    imageURL: imageURLs[latestShow.id]
                  ) {
            let collection = TVTopShelfItemCollection(items: [latestItem])
            collection.title = "Latest Episode"
            sections.append(collection)
        }

        let remainingCount = max(0, 4 - continueWatchingShows.count)
        let additionalShows = Array(fallbackShows.prefix(remainingCount))
        let continueItems = (continueWatchingShows + additionalShows).compactMap { show in
            makeSectionedItem(
                for: show,
                playbackRecord: playbackRecords[show.id],
                imageURL: imageURLs[show.id]
            )
        }

        if !continueItems.isEmpty {
            let collection = TVTopShelfItemCollection(items: continueItems)
            collection.title = continueWatchingShows.isEmpty ? "More Episodes" : "Continue Watching"
            sections.append(collection)
        }

        guard !sections.isEmpty else { return nil }
        return TVTopShelfSectionedContent(sections: sections)
    }

    private static func makeSectionedItem(
        for show: TopShelfShow,
        playbackRecord: TopShelfPlaybackRecord?,
        imageURL: URL?
    ) -> TVTopShelfSectionedItem? {
        let item = TVTopShelfSectionedItem(identifier: show.id)
        item.title = show.title
        item.imageShape = .hdtv

        if let imageURL {
            item.setImageURL(imageURL, for: .screenScale1x)
            item.setImageURL(imageURL, for: .screenScale2x)
        } else if let fallbackURL = bundledFallbackImageURL() {
            item.setImageURL(fallbackURL, for: .screenScale1x)
            item.setImageURL(fallbackURL, for: .screenScale2x)
        }

        let deepLinkURL = URL(string: "njtv://show/\(show.id)")!
        item.displayAction = TVTopShelfAction(url: deepLinkURL)

        if let playbackRecord,
           playbackRecord.isStarted,
           !playbackRecord.isCompleted {
            item.playbackProgress = playbackRecord.progressFraction
        }

        return item
    }

    private static func makeLiveItem(streamURL: URL) -> TVTopShelfSectionedItem? {
        let item = TVTopShelfSectionedItem(identifier: "live-stream")
        item.title = "LIVE STREAM!"
        item.imageShape = .hdtv

        if let liveImageURL = liveCardImageURL() {
            item.setImageURL(liveImageURL, for: .screenScale1x)
            item.setImageURL(liveImageURL, for: .screenScale2x)
        }

        item.displayAction = TVTopShelfAction(url: URL(string: "njtv://live")!)
        return item
    }

    static func bundledFallbackImageURL() -> URL? {
        backupCardImageURL() ?? bundleFallbackImageURL()
    }

    private static func liveCardImageURL() -> URL? {
        Bundle.main.url(forResource: "ssLiveTopShelf", withExtension: "png")
            ?? bundledFallbackImageURL()
    }

    private static func backupCardImageURL() -> URL? {
        Bundle.main.url(forResource: "ssTopShelfBackup", withExtension: "png")
    }

    private static func bundleFallbackImageURL() -> URL? {
        Bundle.main.url(forResource: "img_secret-shows", withExtension: "png")
    }

    private static func paddedFallbackImageURL() -> URL? {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("topshelf-fallback-hdtv.png")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            return outputURL
        }

        guard let image = UIImage(named: "img_secret-shows", in: Bundle.main, compatibleWith: nil) else {
            return nil
        }

        let canvasSize = CGSize(width: 1920, height: 1080)
        let horizontalInset: CGFloat = 84
        let availableRect = CGRect(
            x: horizontalInset,
            y: 0,
            width: canvasSize.width - (horizontalInset * 2),
            height: canvasSize.height
        )

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        let renderedImage = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))

            let widthScale = availableRect.width / image.size.width
            let heightScale = availableRect.height / image.size.height
            let scale = min(widthScale, heightScale)
            let fittedSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let fittedRect = CGRect(
                x: availableRect.midX - (fittedSize.width / 2),
                y: availableRect.midY - (fittedSize.height / 2),
                width: fittedSize.width,
                height: fittedSize.height
            )
            image.draw(in: fittedRect)
        }

        guard let pngData = renderedImage.pngData() else {
            return nil
        }

        do {
            try pngData.write(to: outputURL, options: Data.WritingOptions.atomic)
            return outputURL
        } catch {
            return nil
        }
    }

    static func sanitizedURL(from string: String?) -> URL? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null", trimmed.lowercased() != "<null>" else {
            return nil
        }
        return URL(string: trimmed)
    }
}

private enum TopShelfImageResolver {
    static func resolveImageURLs(for shows: [TopShelfShow]) async -> [String: URL] {
        let fallbackURL = TopShelfContentBuilder.bundledFallbackImageURL()
        return await withTaskGroup(of: (String, URL?).self, returning: [String: URL].self) { group in
            for show in shows {
                group.addTask {
                    let resolvedURL = await resolveImageURL(for: show, fallbackURL: fallbackURL)
                    return (show.id, resolvedURL)
                }
            }

            var result = [String: URL]()
            for await (showID, imageURL) in group {
                if let imageURL {
                    result[showID] = imageURL
                }
            }
            return result
        }
    }

    private static func resolveImageURL(for show: TopShelfShow, fallbackURL: URL?) async -> URL? {
        guard let posterURL = TopShelfContentBuilder.sanitizedURL(from: show.posterImage) else {
            return fallbackURL
        }

        guard await canLoadImage(from: posterURL) else {
            return fallbackURL
        }

        return posterURL
    }

    private static func canLoadImage(from remoteURL: URL) async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  UIImage(data: data) != nil else {
                return false
            }
            return true
        } catch {
            return false
        }
    }
}

private final class TopShelfAPIClient {
    private let decoder = JSONDecoder()

    struct TVSettingsResponse: Decodable {
        let liveStreamURL: String?
        let ssLiveOverride: Bool?
        let weeklyShow: WeeklyShowWindow?

        enum CodingKeys: String, CodingKey {
            case liveStreamURL = "LiveStreamURL"
            case ssLiveOverride = "SS_Live_Override"
            case weeklyShow
        }

        var sanitizedLiveStreamURL: URL? {
            guard let liveStreamURL else { return nil }
            let trimmedURL = liveStreamURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedURL.isEmpty else { return nil }
            return URL(string: trimmedURL)
        }
    }

    struct WeeklyShowWindow: Decodable {
        let start: String
        let end: String

        var containsNow: Bool {
            guard let startDate = TopShelfDateFormatter.liveWindowFormatter.date(from: start),
                  let endDate = TopShelfDateFormatter.liveWindowFormatter.date(from: end) else {
                return false
            }

            let now = Date()
            return startDate <= now && now <= endDate
        }
    }

    func fetchSecretShows(session: TopShelfUserSession) async throws -> [TopShelfShow] {
        let body = try await request(action: "secretshows", method: "GET", requiresAuth: true, session: session)
        let response = try decoder.decode(TopShelfSecretShowsEnvelope.self, from: body)

        if let message = response.error?.message, !message.isEmpty {
            throw TopShelfAPIError.serverMessage(message)
        }

        return response.secretShows ?? []
    }

    func fetchTVSettings() async throws -> TVSettingsResponse {
        guard let url = URL(string: TopShelfAPIConfiguration.settingsURLString) else {
            throw TopShelfAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TopShelfAPIError.invalidResponse
        }

        return try decoder.decode(TVSettingsResponse.self, from: data)
    }

    func resolveLiveStreamState(from settings: TVSettingsResponse) async throws -> TopShelfLiveStreamState {
        guard let liveStreamURL = settings.sanitizedLiveStreamURL else {
            return .hidden
        }

        if settings.ssLiveOverride == true {
            return .visible(url: liveStreamURL)
        }

        guard let liveWindow = settings.weeklyShow else {
            return .hidden
        }
        return liveWindow.containsNow ? .visible(url: liveStreamURL) : .hidden
    }

    private func request(
        action: String,
        method: String,
        requiresAuth: Bool,
        session: TopShelfUserSession? = nil
    ) async throws -> Data {
        var components = URLComponents(string: TopShelfAPIConfiguration.baseURL + TopShelfAPIConfiguration.apiPath)
        components?.queryItems = [URLQueryItem(name: "action", value: action)]

        guard let url = components?.url else {
            throw TopShelfAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        baseHeaders(requiresAuth: requiresAuth, session: session)
            .forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) || !data.isEmpty else {
            throw TopShelfAPIError.invalidResponse
        }

        return data
    }

    private func baseHeaders(requiresAuth: Bool, session: TopShelfUserSession?) -> [String: String] {
        var headers = [
            "X-DEVICETYPE": TopShelfAPIConfiguration.deviceType,
            "X-DEVICEID": TopShelfAPIConfiguration.deviceID,
            "X-APPVERSION": TopShelfAPIConfiguration.appVersion,
            "X-APPKEY": TopShelfAPIConfiguration.appKey,
            "Content-Type": requiresAuth ? "application/json" : "text/plain"
        ]

        if requiresAuth, let session {
            headers["X-AUTHKEY"] = session.authKey
        }

        return headers
    }
}

private enum TopShelfAPIConfiguration {
    static let baseURL: String = {
        if let override = ProcessInfo.processInfo.environment["API_BASE_URL"], !override.isEmpty {
            return override
        }
        #if DEV_SERVER
        return "https://dev.thenewsjunkie.com"
        #else
        return "https://thenewsjunkie.com"
        #endif
    }()
    static let apiPath = "/api/v6/ApiControllerV7.php"
    static let settingsURLString = Bundle.main.object(forInfoDictionaryKey: "SettingsAPIURL") as? String ?? "https://gpmandlkcdompmdvethh.supabase.co/functions/v1/tv-settings/"
    static let appKey = "f1b23fc72bd79ce53ab96e48b24b78a2"
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    static let deviceType = "AppleTV"
    static let deviceID: String = {
        let defaults = TopShelfSharedStorage.defaults
        if let existing = defaults.string(forKey: TopShelfStorageKeys.deviceID) {
            return existing
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: TopShelfStorageKeys.deviceID)
        return generated
    }()
}

private enum TopShelfAPIError: Error {
    case invalidResponse
    case serverMessage(String)
}

private struct TopShelfSecretShowsEnvelope: Decodable {
    let error: TopShelfAPIErrorPayload?
    let secretShows: [TopShelfShow]?

    private enum CodingKeys: String, CodingKey {
        case error
        case secretShows = "SecretShows"
        case secretShowsLowercase = "secretShows"
        case secretShowsSnakeCase = "secret_shows"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(TopShelfAPIErrorPayload.self, forKey: .error)
        secretShows =
            try container.decodeIfPresent([TopShelfShow].self, forKey: .secretShows) ??
            container.decodeIfPresent([TopShelfShow].self, forKey: .secretShowsLowercase) ??
            container.decodeIfPresent([TopShelfShow].self, forKey: .secretShowsSnakeCase)
    }
}

private struct TopShelfAPIErrorPayload: Decodable {
    let message: String?
}
