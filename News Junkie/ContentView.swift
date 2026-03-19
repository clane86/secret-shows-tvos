//
//  ContentView.swift
//  News Junkie
//
//  Created by Chris Lane on 3/15/26.
//

import AVKit
import Combine
import SwiftUI
import UIKit

enum SharedStorage {
    static let appGroupID = "group.com.thenewsjunkie.tv"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
}

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.08, blue: 0.11),
                    Color(red: 0.12, green: 0.13, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch appModel.screen {
            case .splash:
                SplashScreen {
                    appModel.splashFinished()
                }
            case .loading:
                LoadingScreen(message: appModel.loadingMessage)
            case .login:
                LoginScreen()
            case .accessDenied:
                AccessDeniedScreen(message: appModel.accessDeniedMessage)
            case .library:
                LibraryScreen()
            case .detail:
                if let show = appModel.selectedShow {
                    SecretShowDetailScreen(show: show)
                } else {
                    LoadingScreen(message: "Loading Secret Shows")
                }
            case .error:
                ErrorScreen(message: appModel.errorMessage)
            }
        }
        .fullScreenCover(item: $appModel.activePlaybackSession, onDismiss: appModel.playerDismissed) { session in
            PlayerView(session: session)
                .ignoresSafeArea()
        }
        .alert("Login Failed", isPresented: $appModel.isShowingLoginError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(appModel.loginErrorMessage)
        })
    }
}

private struct SplashScreen: View {
    let onFinished: () -> Void
    @State private var didFinish = false

    var body: some View {
        ZStack {
            if let splashURL = SplashVideoResource.url {
                SplashVideoPlayerView(url: splashURL) {
                    finishIfNeeded()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    finishIfNeeded()
                }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Text("News Junkie")
                        .font(.system(size: 72, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Secret Shows")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                    Spacer()
                }
                .padding(60)
                .task {
                    try? await Task.sleep(for: .seconds(1.5))
                    finishIfNeeded()
                }
            }
        }
        .ignoresSafeArea()
    }

    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

private struct SplashVideoPlayerView: UIViewRepresentable {
    let url: URL
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIView(context: Context) -> SplashPlayerContainerView {
        let view = SplashPlayerContainerView()
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause

        context.coordinator.configure(player: player)
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()

        return view
    }

    func updateUIView(_ uiView: SplashPlayerContainerView, context: Context) {
    }

    static func dismantleUIView(_ uiView: SplashPlayerContainerView, coordinator: Coordinator) {
        uiView.playerLayer.player?.pause()
        uiView.playerLayer.player = nil
        coordinator.teardown()
    }

    final class Coordinator {
        private var observer: NSObjectProtocol?
        private let onFinished: () -> Void

        init(onFinished: @escaping () -> Void) {
            self.onFinished = onFinished
        }

        func configure(player: AVPlayer) {
            teardown()
            if let item = player.currentItem {
                observer = NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: item,
                    queue: .main
                ) { [onFinished] _ in
                    onFinished()
                }
            }
        }

        func teardown() {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
        }
    }
}

private final class SplashPlayerContainerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

private struct LoadingScreen: View {
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            Text(message)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

private struct LoginScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        VStack(spacing: 42) {
            Spacer()

            Image("SecretPlayerLogin")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 420)

            VStack(spacing: 16) {
                Text("News Junkie Secret Shows")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(.white)
                Text("Sign in to browse and play Secret Shows videos.")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }

            VStack(spacing: 20) {
                TextField("Email", text: $appModel.email)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .modifier(TVTextFieldStyle())

                SecureField("Password", text: $appModel.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { appModel.loginTapped() }
                    .modifier(TVTextFieldStyle())
            }
            .frame(maxWidth: 760)

            Button(action: appModel.loginTapped) {
                Text(appModel.isLoggingIn ? "Signing In..." : "Sign In")
                    .font(.system(size: 28, weight: .semibold))
                    .frame(width: 420, height: 76)
            }
            .buttonStyle(PrimaryActionButtonStyle())
            .disabled(appModel.isLoggingIn)

            Spacer()
        }
        .padding(.horizontal, 80)
        .onAppear {
            focusedField = .email
        }
    }
}

private struct AccessDeniedScreen: View {
    @EnvironmentObject private var appModel: AppModel
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Secret Shows")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
            Button("Log Out", role: .destructive) {
                appModel.logout()
            }
            .buttonStyle(PrimaryActionButtonStyle())
            Spacer()
        }
        .padding(80)
    }
}

private struct ErrorScreen: View {
    @EnvironmentObject private var appModel: AppModel
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Unable to Load")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white.opacity(0.84))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 920)
            HStack(spacing: 24) {
                Button("Try Again") {
                    appModel.reloadSession()
                }
                .buttonStyle(PrimaryActionButtonStyle())

                Button("Log Out", role: .destructive) {
                    appModel.logout()
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            Spacer()
        }
        .padding(80)
    }
}

private struct LibraryScreen: View {
    @EnvironmentObject private var appModel: AppModel
    @FocusState private var focusedElement: FocusElement?
    @State private var logoutUpPressCount = 0
    @State private var lastLogoutUpPressDate: Date?

    private let gridSpacing: CGFloat = 36
    private let cardMinimumWidth: CGFloat = 420
    private let cardMaximumWidth: CGFloat = 520
    private let logoutUpPressWindow: TimeInterval = 1.8

    private enum FocusElement: Hashable {
        case logout
        case grid(String)
    }

    var body: some View {
        GeometryReader { geometry in
            let columnCount = gridColumnCount(for: geometry.size.width)
            let columns = Array(
                repeating: GridItem(.flexible(minimum: cardMinimumWidth, maximum: cardMaximumWidth), spacing: gridSpacing),
                count: columnCount
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    LibraryHeroHeader()

                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hello, \(appModel.greetingName)!")
                                .font(.system(size: 56, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Browse the Secret Shows video library...")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white.opacity(0.74))
                        }

                        Spacer()

                        Button("Log Out", role: .destructive) {
                            appModel.logout()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .focused($focusedElement, equals: .logout)
                        .onMoveCommand(perform: handleLogoutMove)
                    }

                    if appModel.videoShows.isEmpty {
                        Text("No Secret Shows videos are currently available.")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white.opacity(0.82))
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: gridSpacing) {
                            ForEach(appModel.videoShows) { show in
                                SecretShowCard(
                                    show: show,
                                    progress: appModel.playbackProgress(for: show),
                                    isFocused: focusedElement == .grid(show.id)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .focusable()
                                .focused($focusedElement, equals: .grid(show.id))
                                .onTapGesture {
                                    appModel.select(show: show)
                                }
                                .onMoveCommand { direction in
                                    handleGridMove(direction, from: show.id, columnCount: columnCount)
                                }
                            }
                        }
                        .onExitCommand {
                            focusedElement = .logout
                        }
                    }
                }
                .padding(60)
            }
        }
        .onAppear {
            restoreGridFocusIfNeeded()
        }
        .onChange(of: appModel.preferredLibraryFocusShowID) { _ in
            restoreGridFocusIfNeeded()
        }
    }

    private func restoreGridFocusIfNeeded() {
        if let showID = appModel.preferredLibraryFocusShowID,
           appModel.videoShows.contains(where: { $0.id == showID }) {
            Task { @MainActor in
                focusedElement = .grid(showID)
                appModel.preferredLibraryFocusShowID = nil
            }
        }
    }

    private func gridColumnCount(for totalWidth: CGFloat) -> Int {
        let availableWidth = max(totalWidth - 120, cardMinimumWidth)
        let count = Int((availableWidth + gridSpacing) / (cardMinimumWidth + gridSpacing))
        return max(count, 1)
    }

    private func handleGridMove(_ direction: MoveCommandDirection, from showID: String, columnCount: Int) {
        guard let currentIndex = appModel.videoShows.firstIndex(where: { $0.id == showID }) else { return }

        let rowStart = (currentIndex / columnCount) * columnCount
        let rowEnd = min(rowStart + columnCount - 1, appModel.videoShows.count - 1)

        switch direction {
        case .right:
            let nextRowStart = rowStart + columnCount
            guard currentIndex == rowEnd, nextRowStart < appModel.videoShows.count else { return }
            focusedElement = .grid(appModel.videoShows[nextRowStart].id)
        case .left:
            let previousRowEnd = rowStart - 1
            guard currentIndex == rowStart, previousRowEnd >= 0 else { return }
            focusedElement = .grid(appModel.videoShows[previousRowEnd].id)
        default:
            break
        }
    }

    private func handleLogoutMove(_ direction: MoveCommandDirection) {
        guard focusedElement == .logout else {
            resetLogoutEasterEgg()
            return
        }

        guard direction == .up else {
            resetLogoutEasterEgg()
            return
        }

        let now = Date()
        if let lastLogoutUpPressDate,
           now.timeIntervalSince(lastLogoutUpPressDate) <= logoutUpPressWindow {
            logoutUpPressCount += 1
        } else {
            logoutUpPressCount = 1
        }

        self.lastLogoutUpPressDate = now

        guard logoutUpPressCount >= 4 else { return }

        SplashPolicy.resetSplashCooldown()
        resetLogoutEasterEgg()
    }

    private func resetLogoutEasterEgg() {
        logoutUpPressCount = 0
        lastLogoutUpPressDate = nil
    }
}

private struct LibraryHeroHeader: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(height: 320)
                .overlay {
                    if let backgroundURL = appModel.userBackgroundURL {
                        AsyncImage(url: backgroundURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        Color.white.opacity(0.03)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    } else {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(0.16),
                            Color.black.opacity(0.40)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

            ZStack {
                Circle()
                    .fill(Color(red: 0.09, green: 0.10, blue: 0.13))
                    .frame(width: 265, height: 265)

                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 265, height: 265)

                if let avatarURL = appModel.userAvatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Image("SecretShowsPlaceholder")
                                .resizable()
                                .scaledToFit()
                                .padding(40)
                        }
                    }
                    .clipShape(Circle())
                    .frame(width: 245, height: 245)
                } else {
                    Image("SecretShowsPlaceholder")
                        .resizable()
                        .scaledToFit()
                        .padding(40)
                        .frame(width: 245, height: 245)
                }
            }
            .offset(y: 110)
        }
        .padding(.bottom, 110)
    }
}

private struct SecretShowCard: View {
    let show: SecretShow
    let progress: ShowPlaybackProgress
    let isFocused: Bool

    private var posterURL: URL? {
        guard let posterImage = show.posterImage?.trimmingCharacters(in: .whitespacesAndNewlines),
              !posterImage.isEmpty,
              posterImage.lowercased() != "null" else {
            return nil
        }
        return URL(string: posterImage)
    }

    private var formattedDate: String? {
        guard let pubDate = show.pubDate else { return nil }
        return SecretShowDateFormatter.displayString(from: pubDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .aspectRatio(381.0 / 200.0, contentMode: .fit)
                .overlay {
                    if let posterURL {
                        AsyncImage(url: posterURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                            default:
                                placeholderPoster
                            }
                        }
                    } else {
                        placeholderPoster
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if progress.isCompleted {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.13, green: 0.76, blue: 0.32))
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 40, height: 40)
                        .padding(16)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if progress.showsProgressBar {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.black.opacity(0.18))
                                Rectangle()
                                    .fill(Color(red: 0.13, green: 0.76, blue: 0.32))
                                    .frame(width: max(2, geometry.size.width * progress.fractionWatched))
                            }
                        }
                        .frame(height: 8)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 20,
                                bottomTrailingRadius: 20,
                                topTrailingRadius: 0
                            )
                        )
                    }
                }

            Text(show.title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)

            if let formattedDate {
                HStack {
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isFocused ? Color.white.opacity(0.78) : Color.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
        .background(isFocused ? Color.white.opacity(0.40) : Color.white.opacity(0.08))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isFocused ? Color.white.opacity(0.75) : Color.clear, lineWidth: 1.0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scaleEffect(isFocused ? 1.012 : 1.0)
        .shadow(color: isFocused ? Color.white.opacity(0.08) : .clear, radius: 8)
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }

    private var placeholderPoster: some View {
        Image("SecretShowsPlaceholder")
            .resizable()
            .scaledToFit()
            .frame(width: 176, height: 176)
    }
}

private struct SecretShowDetailScreen: View {
    @EnvironmentObject private var appModel: AppModel
    let show: SecretShow

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image("SecretShowsPlaceholder")
                .resizable()
                .scaledToFit()
                .frame(width: 520, height: 520)
                .opacity(0.10)
                .offset(x: 80, y: 80)

            VStack(alignment: .leading, spacing: 36) {
                Text(show.title)
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)

                ScrollView {
                    Text(show.descriptionText)
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 24) {
                    if appModel.hasResumeProgress(for: show) {
                        Button("Resume") {
                            appModel.play(show: show, resume: true)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        Button("Restart") {
                            appModel.play(show: show, resume: false)
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    } else {
                        Button("Play") {
                            appModel.play(show: show, resume: false)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }

                    Button("Back") {
                        appModel.backToLibrary()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
        .padding(60)
        .onExitCommand {
            appModel.backToLibrary()
        }
    }
}

private struct PlayerView: View {
    @ObservedObject var session: PlayerSession

    var body: some View {
        VideoPlayerControllerRepresentable(session: session)
            .background(Color.black)
    }
}

private struct TVTextFieldStyle: ViewModifier {
    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .font(.system(size: 28, weight: .medium))
            .padding(.horizontal, 8)
            .frame(height: 74)
            .foregroundStyle(isFocused ? Color.black.opacity(0.82) : Color.white.opacity(0.88))
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(
            configuration: configuration,
            fillColor: .red,
            pressedFillColor: Color.red.opacity(0.74),
            borderColor: Color.white.opacity(0.9)
        )
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(
            configuration: configuration,
            fillColor: Color.white.opacity(0.12),
            pressedFillColor: Color.white.opacity(0.22),
            borderColor: Color.white.opacity(0.55)
        )
    }
}

private struct ActionButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let fillColor: Color
    let pressedFillColor: Color
    let borderColor: Color

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: 280, minHeight: 84)
            .padding(.horizontal, 30)
            .background(configuration.isPressed ? pressedFillColor : fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isFocused ? borderColor : Color.clear, lineWidth: 5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : (isFocused ? 1.08 : 1.0))
            .shadow(color: isFocused ? .white.opacity(0.25) : .clear, radius: 18)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

@MainActor
final class AppModel: ObservableObject {
    enum Screen {
        case splash
        case loading
        case login
        case accessDenied
        case library
        case detail
        case error
    }

    @Published var screen: Screen = .loading
    @Published var email = UserDefaults.standard.string(forKey: StorageKeys.lastEmail) ?? ""
    @Published var password = ""
    @Published var loadingMessage = "Checking Session"
    @Published var accessDeniedMessage = ""
    @Published var errorMessage = ""
    @Published var loginErrorMessage = ""
    @Published var isShowingLoginError = false
    @Published var isLoggingIn = false
    @Published var videoShows: [SecretShow] = []
    @Published var userFirstName = ""
    @Published var userBackgroundURL: URL?
    @Published var userAvatarURL: URL?
    @Published var selectedShowID: String?
    @Published var preferredLibraryFocusShowID: String?
    @Published var activePlaybackSession: PlayerSession?

    private let apiClient = APIClient()
    private let sessionStore = SessionStore()
    private let navigationStore = NavigationStore()
    private let progressStore = PlaybackProgressStore()
    private let cacheStore = SecretShowsCacheStore()
    private var hasBootstrapped = false
    private var isRefreshingAuthorizedContent = false
    private var pendingDeepLinkShowID: String?

    var selectedShow: SecretShow? {
        guard let selectedShowID else { return nil }
        return videoShows.first(where: { $0.id == selectedShowID })
    }

    var greetingName: String {
        let trimmed = userFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        if SplashPolicy.shouldShowSplash {
            screen = .splash
        } else {
            SplashPolicy.markForegroundedNow()
            Task {
                await restoreSession()
            }
        }
    }

    func splashFinished() {
        guard screen == .splash else { return }
        SplashPolicy.markForegroundedNow()
        Task {
            await restoreSession()
        }
    }

    func handleScenePhase(_ scenePhase: ScenePhase) {
        if scenePhase == .active {
            guard sessionStore.currentSession != nil,
                  activePlaybackSession == nil,
                  screen != .splash,
                  screen != .loading else {
                return
            }

            if SplashPolicy.shouldShowSplash {
                screen = .splash
                return
            }

            SplashPolicy.markForegroundedNow()

            Task {
                await loadAuthorizedContent(restoringPreviousLocation: true, showLoadingScreen: false)
            }
        }
    }

    func handleOpenURL(_ url: URL) {
        guard let showID = DeepLinkParser.showID(from: url) else { return }
        pendingDeepLinkShowID = showID

        if sessionStore.currentSession == nil {
            screen = .login
            return
        }

        if let show = videoShows.first(where: { $0.id == showID }) {
            select(show: show)
            pendingDeepLinkShowID = nil
            return
        }

        Task {
            await loadAuthorizedContent(restoringPreviousLocation: false, showLoadingScreen: false)
        }
    }

    func loginTapped() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            loginErrorMessage = "Enter both your email and password."
            isShowingLoginError = true
            return
        }

        email = trimmedEmail
        password = trimmedPassword
        isLoggingIn = true

        Task {
            do {
                let session = try await apiClient.login(email: trimmedEmail, password: trimmedPassword)
                sessionStore.save(session)
                UserDefaults.standard.set(trimmedEmail, forKey: StorageKeys.lastEmail)
                await loadAuthorizedContent(restoringPreviousLocation: false)
            } catch {
                loginErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to sign in."
                isShowingLoginError = true
                screen = .login
            }

            isLoggingIn = false
        }
    }

    func reloadSession() {
        Task {
            await loadAuthorizedContent(restoringPreviousLocation: true)
        }
    }

    func logout() {
        activePlaybackSession?.saveProgress()
        activePlaybackSession = nil
        selectedShowID = nil
        preferredLibraryFocusShowID = nil
        videoShows = []
        userFirstName = ""
        userBackgroundURL = nil
        userAvatarURL = nil
        password = ""
        sessionStore.clear()
        navigationStore.clear()
        screen = .login
    }

    func select(show: SecretShow) {
        preferredLibraryFocusShowID = show.id
        selectedShowID = show.id
        navigationStore.save(.detail(showID: show.id))
        screen = .detail
    }

    func backToLibrary() {
        preferredLibraryFocusShowID = selectedShowID
        selectedShowID = nil
        navigationStore.save(.library)
        screen = .library
    }

    func hasResumeProgress(for show: SecretShow) -> Bool {
        progressStore.resumeTime(for: show.id) > 0
    }

    func playbackProgress(for show: SecretShow) -> ShowPlaybackProgress {
        progressStore.progress(for: show.id)
    }

    func play(show: SecretShow, resume: Bool) {
        guard URL(string: show.playbackURLString) != nil else {
            errorMessage = "This Secret Show does not have a valid video URL."
            screen = .error
            return
        }

        let startTime = resume ? progressStore.resumeTime(for: show.id) : 0
        if !resume {
            progressStore.clearProgress(for: show.id)
        }

        let session = PlayerSession(show: show, startTime: startTime, progressStore: progressStore)
        activePlaybackSession = session
    }

    func playerDismissed() {
        activePlaybackSession?.saveProgress()
        activePlaybackSession = nil
    }

    private func restoreSession() async {
        guard sessionStore.currentSession != nil else {
            screen = .login
            return
        }

        await loadAuthorizedContent(restoringPreviousLocation: true, showLoadingScreen: true)
    }

    private func loadAuthorizedContent(restoringPreviousLocation: Bool, showLoadingScreen: Bool = true) async {
        guard !isRefreshingAuthorizedContent else { return }
        guard let session = sessionStore.currentSession else {
            screen = .login
            return
        }

        isRefreshingAuthorizedContent = true
        defer { isRefreshingAuthorizedContent = false }

        if showLoadingScreen {
            loadingMessage = "Loading Secret Shows"
            screen = .loading
        }

        do {
            let userScore = try await apiClient.fetchUserScore(session: session)
            userFirstName = userScore.userFirstName
            userBackgroundURL = URL(string: userScore.userBackgroundImage)
            userAvatarURL = URL(string: userScore.userAvatarImage)

            guard userScore.subscriber, userScore.isVideo, userScore.isSecretShowEnabled else {
                accessDeniedMessage = "No video subscription detected. Please visit http://www.thenewsjunkie.com/ to upgrade."
                screen = .accessDenied
                return
            }

            let shows = try await apiClient.fetchSecretShows(session: session)
            let filteredShows = shows.filter { $0.hasVideo }
            videoShows = filteredShows
            cacheStore.save(filteredShows)

            guard !filteredShows.isEmpty else {
                errorMessage = "No Secret Shows videos are currently available for this account."
                screen = .error
                return
            }

            if openPendingDeepLinkIfNeeded(using: filteredShows) {
                return
            }

            if restoringPreviousLocation {
                restoreNavigation(using: filteredShows)
            } else {
                navigationStore.save(.library)
                selectedShowID = nil
                screen = .library
            }
        } catch APIClient.APIError.invalidSession {
            logout()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Unable to load Secret Shows."
            screen = .error
        }
    }

    private func restoreNavigation(using shows: [SecretShow]) {
        switch navigationStore.lastRoute {
        case .detail(let showID):
            if shows.contains(where: { $0.id == showID }) {
                selectedShowID = showID
                screen = .detail
            } else {
                navigationStore.save(.library)
                selectedShowID = nil
                screen = .library
            }
        case .library, .none:
            selectedShowID = nil
            screen = .library
        }
    }

    @discardableResult
    private func openPendingDeepLinkIfNeeded(using shows: [SecretShow]) -> Bool {
        guard let pendingDeepLinkShowID,
              let show = shows.first(where: { $0.id == pendingDeepLinkShowID }) else {
            return false
        }

        preferredLibraryFocusShowID = show.id
        selectedShowID = show.id
        navigationStore.save(.detail(showID: show.id))
        screen = .detail
        self.pendingDeepLinkShowID = nil
        return true
    }
}

struct SecretShow: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let audioURL: String
    let videoURL: String
    let posterImage: String?
    let pubDate: String?
    let descriptionText: String
    let images: [SecretShowImage]

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleString(forKey: .id) ?? ""
        title = try container.decodeFlexibleString(forKey: .title) ?? "Untitled Show"
        audioURL = try container.decodeFlexibleString(forKey: .audioURL) ?? ""
        videoURL = try container.decodeFlexibleString(forKey: .videoURL) ?? ""
        posterImage = try container.decodeFlexibleString(forKey: .posterImage)
        pubDate = try container.decodeFlexibleString(forKey: .pubDate)
        descriptionText = try container.decodeFlexibleString(forKey: .descriptionText) ?? "No description available."
        images = try container.decodeIfPresent([SecretShowImage].self, forKey: .images) ?? []
    }
}

struct SecretShowImage: Codable, Hashable {
    let image: String?
    let text: String?
}

enum SecretShowDateFormatter {
    private static let inputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let outputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func displayString(from apiValue: String) -> String? {
        guard let date = inputFormatter.date(from: apiValue) else {
            return nil
        }
        return outputFormatter.string(from: date)
    }
}

struct UserSession: Codable {
    let userID: Int
    let authKey: String
    let email: String
}

struct UserScorePayload: Decodable {
    let subscriber: Bool
    let isVideo: Bool
    let isAudio: Bool
    let isSecretShowEnabled: Bool
    let userFirstName: String
    let userBackgroundImage: String
    let userAvatarImage: String

    private enum CodingKeys: String, CodingKey {
        case subscriber
        case isVideo
        case isAudio
        case isSecretShowEnabled = "IsSecretShowEnabled"
        case userFirstName = "user_first_name"
        case userBackgroundImage = "user_bg_image"
        case userAvatarImage = "user_avatar_image"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscriber = try container.decodeFlexibleBool(forKey: .subscriber) ?? false
        isVideo = try container.decodeFlexibleBool(forKey: .isVideo) ?? false
        isAudio = try container.decodeFlexibleBool(forKey: .isAudio) ?? false
        isSecretShowEnabled = try container.decodeFlexibleBool(forKey: .isSecretShowEnabled) ?? false
        userFirstName = try container.decodeFlexibleString(forKey: .userFirstName) ?? ""
        userBackgroundImage = try container.decodeFlexibleString(forKey: .userBackgroundImage) ?? ""
        userAvatarImage = try container.decodeFlexibleString(forKey: .userAvatarImage) ?? ""
    }
}

enum SavedRoute: Codable {
    case library
    case detail(showID: String)
}

final class SessionStore {
    private let defaults = SharedStorage.defaults

    var currentSession: UserSession? {
        guard let data = defaults.data(forKey: StorageKeys.session) else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    func save(_ session: UserSession) {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: StorageKeys.session)
        }
    }

    func clear() {
        defaults.removeObject(forKey: StorageKeys.session)
    }
}

final class NavigationStore {
    private let defaults = UserDefaults.standard

    var lastRoute: SavedRoute? {
        guard let data = defaults.data(forKey: StorageKeys.lastRoute) else { return nil }
        return try? JSONDecoder().decode(SavedRoute.self, from: data)
    }

    func save(_ route: SavedRoute) {
        if let data = try? JSONEncoder().encode(route) {
            defaults.set(data, forKey: StorageKeys.lastRoute)
        }
    }

    func clear() {
        defaults.removeObject(forKey: StorageKeys.lastRoute)
    }
}

final class PlaybackProgressStore {
    private let defaults = SharedStorage.defaults

    func resumeTime(for showID: String) -> Double {
        record(for: showID)?.resumeTime ?? 0
    }

    func progress(for showID: String) -> ShowPlaybackProgress {
        record(for: showID)?.displayProgress ?? .empty
    }

    func save(time: Double, duration: Double, for showID: String) {
        let clampedTime = max(0, time)
        let normalizedDuration = duration.isFinite ? max(0, duration) : 0
        let isCompleted = ShowPlaybackRules.isCompleted(time: clampedTime, duration: normalizedDuration)

        var record = record(for: showID) ?? PlaybackRecord()
        record.lastWatchedTime = clampedTime
        record.duration = max(record.duration, normalizedDuration)
        record.isCompleted = isCompleted
        record.lastUpdatedAt = Date()
        save(record, for: showID)
    }

    func markCompleted(duration: Double, for showID: String) {
        var record = record(for: showID) ?? PlaybackRecord()
        let normalizedDuration = duration.isFinite ? max(duration, 0) : record.duration
        record.lastWatchedTime = normalizedDuration
        record.duration = max(record.duration, normalizedDuration)
        record.isCompleted = true
        record.lastUpdatedAt = Date()
        save(record, for: showID)
    }

    func clearProgress(for showID: String) {
        var progress = records()
        progress.removeValue(forKey: showID)
        save(progress)
    }

    private func record(for showID: String) -> PlaybackRecord? {
        records()[showID]
    }

    private func records() -> [String: PlaybackRecord] {
        guard let storedValue = defaults.object(forKey: StorageKeys.playbackProgress) else {
            return [:]
        }

        if let data = storedValue as? Data,
           let records = try? JSONDecoder().decode([String: PlaybackRecord].self, from: data) {
            return records
        }

        if let legacyRecords = storedValue as? [String: Double] {
            return legacyRecords.reduce(into: [:]) { result, item in
                result[item.key] = PlaybackRecord(lastWatchedTime: item.value, duration: 0, isCompleted: false)
            }
        }

        return [:]
    }

    private func save(_ record: PlaybackRecord, for showID: String) {
        var progress = records()
        progress[showID] = record
        save(progress)
    }

    private func save(_ records: [String: PlaybackRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: StorageKeys.playbackProgress)
        }
    }
}

final class SecretShowsCacheStore {
    private let defaults = SharedStorage.defaults

    var cachedShows: [SecretShow] {
        guard let data = defaults.data(forKey: StorageKeys.cachedShows),
              let shows = try? JSONDecoder().decode([SecretShow].self, from: data) else {
            return []
        }
        return shows
    }

    func save(_ shows: [SecretShow]) {
        guard let data = try? JSONEncoder().encode(shows) else { return }
        defaults.set(data, forKey: StorageKeys.cachedShows)
        defaults.set(Date(), forKey: StorageKeys.cachedShowsUpdatedAt)
    }
}

enum SplashPolicy {
    private static let splashInterval: TimeInterval = 6 * 60 * 60

    static var shouldShowSplash: Bool {
        guard let lastForegroundDate = UserDefaults.standard.object(forKey: StorageKeys.lastForegroundDate) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastForegroundDate) >= splashInterval
    }

    static func markForegroundedNow() {
        UserDefaults.standard.set(Date(), forKey: StorageKeys.lastForegroundDate)
    }

    static func resetSplashCooldown() {
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastForegroundDate)
    }
}

enum StorageKeys {
    static let session = "tv.secretshows.session"
    static let playbackProgress = "tv.secretshows.playbackProgress"
    static let lastRoute = "tv.secretshows.lastRoute"
    static let lastForegroundDate = "tv.secretshows.lastForegroundDate"
    static let lastEmail = "tv.secretshows.lastEmail"
    static let deviceID = "tv.secretshows.deviceID"
    static let cachedShows = "tv.secretshows.cachedShows"
    static let cachedShowsUpdatedAt = "tv.secretshows.cachedShowsUpdatedAt"
}

enum ShowPlaybackRules {
    static let startedThreshold: Double = 30
    static let completedThreshold: Double = 0.98

    static func isCompleted(time: Double, duration: Double) -> Bool {
        guard duration > 0 else { return false }
        return time / duration >= completedThreshold
    }

    static func isStarted(time: Double) -> Bool {
        time > startedThreshold
    }
}

struct ShowPlaybackProgress: Equatable {
    let fractionWatched: Double
    let isStarted: Bool
    let isCompleted: Bool

    static let empty = ShowPlaybackProgress(fractionWatched: 0, isStarted: false, isCompleted: false)

    var showsProgressBar: Bool {
        isStarted || isCompleted
    }
}

private struct PlaybackRecord: Codable {
    var lastWatchedTime: Double = 0
    var duration: Double = 0
    var isCompleted = false
    var lastUpdatedAt: Date?

    var resumeTime: Double {
        guard !isCompleted, ShowPlaybackRules.isStarted(time: lastWatchedTime) else { return 0 }
        return lastWatchedTime
    }

    var displayProgress: ShowPlaybackProgress {
        let fraction = duration > 0 ? min(max(lastWatchedTime / duration, 0), 1) : 0
        return ShowPlaybackProgress(
            fractionWatched: isCompleted ? 1 : fraction,
            isStarted: ShowPlaybackRules.isStarted(time: lastWatchedTime),
            isCompleted: isCompleted
        )
    }
}

final class APIClient {
    enum APIError: LocalizedError {
        case invalidResponse
        case invalidSession
        case serverMessage(String)
        case decodingFailed(String?)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The server response was invalid."
            case .invalidSession:
                return "Your session is no longer valid. Please sign in again."
            case .serverMessage(let message):
                return message
            case .decodingFailed(let payloadPreview):
                if let payloadPreview, !payloadPreview.isEmpty {
                    return "The server returned data in an unexpected format. Response: \(payloadPreview)"
                }
                return "The server returned data in an unexpected format."
            }
        }
    }

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    func login(email: String, password: String) async throws -> UserSession {
        let body = try await request(
            action: "user/login",
            method: "POST",
            body: [
                "user_email": email,
                "user_password": password
            ],
            requiresAuth: false,
            extraHeaders: ["Content-Type": "text/plain"]
        )

        let response = try decode(LoginEnvelope.self, from: body)
        if let message = response.error?.message, !message.isEmpty {
            throw APIError.serverMessage(message)
        }
        if let message = response.nonFieldErrors.first, !message.isEmpty {
            throw APIError.serverMessage(message)
        }

        guard let user = response.userDetail else {
            throw APIError.decodingFailed(nil)
        }

        return UserSession(userID: user.userID, authKey: user.authKey, email: email)
    }

    func fetchUserScore(session: UserSession) async throws -> UserScorePayload {
        let body = try await request(
            action: "user/score",
            method: "GET",
            query: [URLQueryItem(name: "user_id", value: String(session.userID))],
            requiresAuth: true,
            session: session
        )

        let response = try decode(UserScoreEnvelope.self, from: body)
        if let message = response.error?.message, !message.isEmpty {
            throw message.lowercased().contains("auth") ? APIError.invalidSession : APIError.serverMessage(message)
        }

        guard let userScore = response.userScore else {
            throw APIError.decodingFailed(nil)
        }

        return userScore
    }

    func fetchSecretShows(session: UserSession) async throws -> [SecretShow] {
        let body = try await request(
            action: "secretshows",
            method: "GET",
            requiresAuth: true,
            session: session
        )

        let response = try decode(SecretShowsEnvelope.self, from: body)
        if let message = response.error?.message, !message.isEmpty {
            throw message.lowercased().contains("auth") ? APIError.invalidSession : APIError.serverMessage(message)
        }

        return response.secretShows ?? []
    }

    private func request(
        action: String,
        method: String,
        query: [URLQueryItem] = [],
        body: [String: String]? = nil,
        requiresAuth: Bool,
        session: UserSession? = nil,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        var components = URLComponents(string: APIConfiguration.baseURL + APIConfiguration.apiPath)
        var queryItems = [URLQueryItem(name: "action", value: action)]
        queryItems.append(contentsOf: query)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        baseHeaders(requiresAuth: requiresAuth, session: session).merging(extraHeaders) { _, new in new }
            .forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.invalidSession
        }

        if !(200...299).contains(httpResponse.statusCode) && data.isEmpty {
            throw APIError.invalidResponse
        }

        debugLogResponse(data: data, action: action, statusCode: httpResponse.statusCode)

        return data
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let rawPayload = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = rawPayload.map { String($0.prefix(240)) }
            throw APIError.decodingFailed(preview)
        }
    }

    private func baseHeaders(requiresAuth: Bool, session: UserSession?) -> [String: String] {
        var headers = [
            "X-DEVICETYPE": APIConfiguration.deviceType,
            "X-DEVICEID": APIConfiguration.deviceID,
            "X-APPVERSION": APIConfiguration.appVersion,
            "X-APPKEY": APIConfiguration.appKey
        ]

        if requiresAuth, let session {
            headers["X-AUTHKEY"] = session.authKey
            headers["Content-Type"] = "application/json"
        } else {
            headers["Content-Type"] = "text/plain"
        }

        return headers
    }

    private func debugLogResponse(data: Data, action: String, statusCode: Int) {
#if DEBUG
        guard action == "user/login" || action == "user/score" || action == "secretshows" else {
            return
        }

        let payload = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
        print("=== API RESPONSE START [\(action)] status=\(statusCode) ===")
        print(payload)
        print("=== API RESPONSE END [\(action)] ===")
#endif
    }
}

enum APIConfiguration {
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
    static let appKey = "f1b23fc72bd79ce53ab96e48b24b78a2"
    static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    static let deviceType = "iPhone"
    static let deviceID: String = {
        let defaults = SharedStorage.defaults
        if let existing = defaults.string(forKey: StorageKeys.deviceID) {
            return existing
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: StorageKeys.deviceID)
        return generated
    }()
}

enum DeepLinkParser {
    static let scheme = "njtv"

    static func showID(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        if url.host == "show" {
            return url.pathComponents.dropFirst().first
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard components.first == "show", components.count > 1 else { return nil }
        return components[1]
    }
}

enum SplashVideoResource {
    static var url: URL? {
        Bundle.main.url(forResource: "NJ-TV-splash", withExtension: "mp4", subdirectory: "images")
            ?? Bundle.main.url(forResource: "NJ-TV-splash", withExtension: "mp4")
    }
}

private struct LoginEnvelope: Decodable {
    let error: APIErrorPayload?
    let userDetail: LoginUserDetail?
    let nonFieldErrors: [String]

    private enum CodingKeys: String, CodingKey {
        case error
        case userDetail = "UserDetail"
        case userDetailLowercase = "userDetail"
        case userDetailSnakeCase = "user_detail"
        case nonFieldErrors = "non_field_errors"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(APIErrorPayload.self, forKey: .error)
        userDetail =
            try container.decodeIfPresent(LoginUserDetail.self, forKey: .userDetail) ??
            container.decodeIfPresent(LoginUserDetail.self, forKey: .userDetailLowercase) ??
            container.decodeIfPresent(LoginUserDetail.self, forKey: .userDetailSnakeCase)
        nonFieldErrors = try container.decodeIfPresent([String].self, forKey: .nonFieldErrors) ?? []
    }
}

private struct LoginUserDetail: Decodable {
    let userID: Int
    let authKey: String

    private enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case authKey = "auth_key"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decodeFlexibleInt(forKey: .userID) ?? 0
        authKey = try container.decodeFlexibleString(forKey: .authKey) ?? ""
    }
}

private struct UserScoreEnvelope: Decodable {
    let error: APIErrorPayload?
    let userScore: UserScorePayload?

    private enum CodingKeys: String, CodingKey {
        case error
        case userScore = "UserScore"
        case userScoreLowercase = "userScore"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(APIErrorPayload.self, forKey: .error)
        userScore =
            try container.decodeIfPresent(UserScorePayload.self, forKey: .userScore) ??
            container.decodeIfPresent(UserScorePayload.self, forKey: .userScoreLowercase)
    }
}

private struct SecretShowsEnvelope: Decodable {
    let error: APIErrorPayload?
    let secretShows: [SecretShow]?

    private enum CodingKeys: String, CodingKey {
        case error
        case secretShows = "SecretShows"
        case secretShowsLowercase = "secretShows"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(APIErrorPayload.self, forKey: .error)
        secretShows =
            try container.decodeIfPresent([SecretShow].self, forKey: .secretShows) ??
            container.decodeIfPresent([SecretShow].self, forKey: .secretShowsLowercase)
    }
}

private struct APIErrorPayload: Decodable {
    let code: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
    }

    init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer() {
            if singleValue.decodeNil() {
                code = nil
                message = nil
                return
            }

            if let messageString = try? singleValue.decode(String.self) {
                let trimmed = messageString.trimmingCharacters(in: .whitespacesAndNewlines)
                code = nil
                message = trimmed.isEmpty ? nil : trimmed
                return
            }
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeFlexibleString(forKey: .code)
        message = try container.decodeFlexibleString(forKey: .message)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }

        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }

        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue ? "true" : "false"
        }

        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }

        return nil
    }

    func decodeFlexibleBool(forKey key: Key) throws -> Bool? {
        if let boolValue = try? decodeIfPresent(Bool.self, forKey: key) {
            return boolValue
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue != 0
        }

        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            switch stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes":
                return true
            case "0", "false", "no":
                return false
            default:
                return nil
            }
        }

        return nil
    }
}

final class PlayerSession: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    let player: AVPlayer
    let show: SecretShow

    private let progressStore: PlaybackProgressStore
    private var timeObserver: Any?
    private var completionObserver: NSObjectProtocol?

    init(show: SecretShow, startTime: Double, progressStore: PlaybackProgressStore) {
        self.show = show
        self.progressStore = progressStore
        self.player = AVPlayer(url: URL(string: show.playbackURLString) ?? URL(fileURLWithPath: "/dev/null"))
        super.init()

        if startTime > 0 {
            let seekTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            self.progressStore.save(
                time: time.seconds,
                duration: self.player.currentItem?.duration.seconds ?? 0,
                for: self.show.id
            )
        }

        if let item = player.currentItem {
            completionObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                let duration = self.player.currentItem?.duration.seconds ?? 0
                self.progressStore.markCompleted(duration: duration, for: self.show.id)
            }
        }
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
        }
    }

    func saveProgress() {
        progressStore.save(
            time: player.currentTime().seconds,
            duration: player.currentItem?.duration.seconds ?? 0,
            for: show.id
        )
    }
}

struct VideoPlayerControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var session: PlayerSession

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = session.player
        session.player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = session.player
    }
}

private extension View {
    @ViewBuilder
    func disableFocusEffectIfAvailable() -> some View {
        if #available(tvOS 17.0, *) {
            focusEffectDisabled()
        } else {
            self
        }
    }
}
