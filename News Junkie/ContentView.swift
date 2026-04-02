//
//  ContentView.swift
//  News Junkie
//
//  Created by Chris Lane on 3/15/26.
//

import AVKit
import Combine
import MediaPlayer
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
                Text("Secret Shows")
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
                    .submitLabel(.done)
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
        ScrollViewReader { scrollProxy in
            GeometryReader { geometry in
                let columnCount = gridColumnCount(for: geometry.size.width)
                let columns = Array(
                    repeating: GridItem(.flexible(minimum: cardMinimumWidth, maximum: cardMaximumWidth), spacing: gridSpacing),
                    count: columnCount
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: 36) {
                        LibraryHeroHeader()
                            .padding(.horizontal, -60)
                            .padding(.top, -60)

                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hello, \(appModel.greetingName)!")
                                    .font(.system(size: 56, weight: .bold))
                                    .foregroundStyle(.white)
                                Text(appModel.librarySubtitle)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.74))
                            }

                            Spacer()

                            HStack(spacing: 18) {
                                if appModel.isLiveStreamButtonVisible {
                                    Button("LIVE STREAM!") {
                                        appModel.playLiveStream()
                                    }
                                    .buttonStyle(LiveStreamButtonStyle())
                                }

                                Button("Log Out", role: .destructive) {
                                    appModel.logout()
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                                .focused($focusedElement, equals: .logout)
                                .onMoveCommand(perform: handleLogoutMove)
                            }
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
                                    .id(show.id)
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
                    .padding(.horizontal, 60)
                    .padding(.bottom, 60)
                }
            }
            .onAppear {
                restoreGridFocusIfNeeded(using: scrollProxy)
            }
            .onChange(of: appModel.preferredLibraryFocusShowID) { _ in
                restoreGridFocusIfNeeded(using: scrollProxy)
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    guard !Task.isCancelled else { break }
                    await appModel.refreshLibraryMetadata()
                }
            }
        }
    }

    private func restoreGridFocusIfNeeded(using scrollProxy: ScrollViewProxy) {
        if let showID = appModel.preferredLibraryFocusShowID,
           appModel.videoShows.contains(where: { $0.id == showID }) {
            Task { @MainActor in
                scrollProxy.scrollTo(showID, anchor: .center)
                focusedElement = .grid(showID)
                try? await Task.sleep(for: .milliseconds(150))
                scrollProxy.scrollTo(showID, anchor: .center)
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
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32,
                topTrailingRadius: 0,
                style: .continuous
            )
                .fill(Color.white.opacity(0.08))
                .frame(height: 360)
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
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 32,
                        bottomTrailingRadius: 32,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )

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

private struct PlayerInfoTabView: View {
    let show: SecretShow

    var body: some View {
        HStack {
            HStack(alignment: .top, spacing: 32) {
                PlayerInfoArtworkView(show: show)
                    .frame(width: 280, height: 158)

                VStack(alignment: .leading, spacing: 20) {
                    Text(show.title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)

                    Text(show.descriptionText)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.leading)
                        .lineLimit(6)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 28)
            .frame(width: 1400, alignment: .leading)
            .background(Color.black)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .clipped()
    }
}

private struct PlayerMoreEpisodesTabView: View {
    let episodes: [SecretShow]
    let onSelectEpisode: (SecretShow) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(episodes) { episode in
                    Button {
                        onSelectEpisode(episode)
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            PlayerInfoArtworkView(show: episode)
                                .frame(width: 320, height: 180)

                            Text(episode.title)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                                .frame(width: 320, alignment: .leading)
                        }
                    }
                    .buttonStyle(MoreEpisodesCardButtonStyle())
                    .disableFocusEffectIfAvailable()
                }
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .clipped()
    }
}

private struct PlayerInfoArtworkView: View {
    let show: SecretShow

    var body: some View {
        Group {
            if let posterURL = show.posterURL {
                AsyncImage(url: posterURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))

            Image("SecretShowsPlaceholder")
                .resizable()
                .scaledToFit()
                .padding(28)
        }
    }
}

private final class PlayerInfoContentViewController: UIViewController {
    private let show: SecretShow
    private let posterView = PlayerPosterImageView(frame: .zero)

    init(show: SecretShow) {
        self.show = show
        super.init(nibName: nil, bundle: nil)
        title = "Info"
        preferredContentSize = CGSize(width: 1600, height: 300)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.alignment = .top
        contentStack.spacing = 32
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        posterView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            posterView.widthAnchor.constraint(equalToConstant: 280),
            posterView.heightAnchor.constraint(equalToConstant: 158)
        ])

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 20
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = show.title
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        let descriptionLabel = UILabel()
        descriptionLabel.text = show.descriptionText
        descriptionLabel.font = .systemFont(ofSize: 24, weight: .regular)
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.84)
        descriptionLabel.numberOfLines = 6

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(descriptionLabel)

        contentStack.addArrangedSubview(posterView)
        contentStack.addArrangedSubview(textStack)

        view.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])

        posterView.configure(with: show)
    }
}

private final class PlayerMoreEpisodesContentViewController: UIViewController {
    private let episodes: [SecretShow]
    private let progressByShowID: [String: ShowPlaybackProgress]
    private let onSelectEpisode: (SecretShow) -> Void
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(
        episodes: [SecretShow],
        progressByShowID: [String: ShowPlaybackProgress],
        onSelectEpisode: @escaping (SecretShow) -> Void
    ) {
        self.episodes = episodes
        self.progressByShowID = progressByShowID
        self.onSelectEpisode = onSelectEpisode
        super.init(nibName: nil, bundle: nil)
        title = "More Episodes"
        preferredContentSize = CGSize(width: 1600, height: 300)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false

        stackView.axis = .horizontal
        stackView.alignment = .top
        stackView.spacing = 28
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.backgroundColor = .clear

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 40),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -40),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -18),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -36)
        ])

        episodes.prefix(12).forEach { episode in
            let button = PlayerEpisodeCardControl(
                show: episode,
                progress: progressByShowID[episode.id] ?? .empty
            )
            button.addAction(UIAction { [weak self] _ in
                self?.onSelectEpisode(episode)
            }, for: .primaryActionTriggered)
            stackView.addArrangedSubview(button)
        }
    }
}

private final class PlayerEpisodeCardControl: UIControl {
    private let cardBackgroundView = UIView()
    private let posterView = PlayerPosterImageView(frame: .zero)
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)

    init(show: SecretShow, progress: ShowPlaybackProgress) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 336).isActive = true

        cardBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        cardBackgroundView.backgroundColor = UIColor(white: 0.1, alpha: 0.82)
        cardBackgroundView.layer.cornerRadius = 24
        cardBackgroundView.layer.borderWidth = 1
        cardBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        cardBackgroundView.layer.masksToBounds = true
        addSubview(cardBackgroundView)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.backgroundColor = .clear
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            cardBackgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardBackgroundView.topAnchor.constraint(equalTo: topAnchor),
            cardBackgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        posterView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            posterView.widthAnchor.constraint(equalToConstant: 320),
            posterView.heightAnchor.constraint(equalToConstant: 180)
        ])

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.18)
        progressView.progressTintColor = UIColor(red: 0.89, green: 0.11, blue: 0.16, alpha: 1.0)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        progressView.isHidden = !progress.showsProgressBar
        progressView.progress = Float(progress.fractionWatched)

        titleLabel.font = .systemFont(ofSize: 24, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.text = show.title
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        stackView.addArrangedSubview(posterView)
        stackView.addArrangedSubview(progressView)
        stackView.addArrangedSubview(titleLabel)

        NSLayoutConstraint.activate([
            progressView.widthAnchor.constraint(equalToConstant: 320)
        ])

        layer.cornerRadius = 24
        layer.masksToBounds = false
        posterView.configure(with: show)

        accessibilityLabel = show.title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFocused: Bool {
        true
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .select }) {
            sendActions(for: .primaryActionTriggered)
            return
        }

        super.pressesEnded(presses, with: event)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations {
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.025, y: 1.025)
                self.cardBackgroundView.layer.borderWidth = 3
                self.cardBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
                self.cardBackgroundView.backgroundColor = UIColor(white: 0.14, alpha: 0.92)
                self.layer.shadowColor = UIColor.white.withAlphaComponent(0.16).cgColor
                self.layer.shadowOpacity = 1
                self.layer.shadowRadius = 12
                self.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.cardBackgroundView.layer.borderWidth = 1
                self.cardBackgroundView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
                self.cardBackgroundView.backgroundColor = UIColor(white: 0.1, alpha: 0.82)
                self.layer.shadowOpacity = 0
            }
        }
    }
}

private final class PlayerPosterImageView: UIImageView {
    private var task: URLSessionDataTask?
    private var imageURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        task?.cancel()
    }

    func configure(with show: SecretShow) {
        task?.cancel()
        image = Self.placeholderImage()
        imageURL = show.posterURL

        layer.cornerRadius = 18
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor

        guard let url = show.posterURL else { return }
        if let cachedImage = PlayerPosterImageLoader.shared.cachedImage(for: url) {
            image = cachedImage
            return
        }

        task = PlayerPosterImageLoader.shared.loadImage(from: url) { [weak self] loadedImage in
            guard let self, self.imageURL == url, let loadedImage else { return }
            self.image = loadedImage
        }
    }

    private func commonInit() {
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = UIColor.white.withAlphaComponent(0.08)
    }

    private static func placeholderImage() -> UIImage? {
        UIImage(named: "SecretShowsPlaceholder")
    }
}

private final class PlayerPosterImageLoader {
    static let shared = PlayerPosterImageLoader()

    private let cache = NSCache<NSURL, UIImage>()

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    @discardableResult
    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            if let image {
                self?.cache.setObject(image, forKey: url as NSURL)
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        task.resume()
        return task
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

private struct LiveStreamButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(
            configuration: configuration,
            fillColor: Color(red: 0.82, green: 0.08, blue: 0.08),
            pressedFillColor: Color(red: 0.66, green: 0.06, blue: 0.06),
            borderColor: Color(red: 1.0, green: 0.52, blue: 0.52),
            focusShadowColor: Color.red.opacity(0.6),
            idleShadowColor: Color.red.opacity(0.72)
        )
    }
}

private struct MoreEpisodesCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MoreEpisodesCardButtonBody(configuration: configuration)
    }
}

private struct MoreEpisodesCardButtonBody: View {
    let configuration: ButtonStyle.Configuration

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        configuration.label
            .padding(8)
            .background(Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(isFocused ? Color.white.opacity(0.9) : Color.clear, lineWidth: 3)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : (isFocused ? 1.025 : 1.0))
            .shadow(color: isFocused ? Color.white.opacity(0.16) : .clear, radius: 12)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

private struct ActionButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let fillColor: Color
    let pressedFillColor: Color
    let borderColor: Color
    var focusShadowColor: Color = .white.opacity(0.25)
    var idleShadowColor: Color = .clear

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
            .shadow(color: isFocused ? focusShadowColor : idleShadowColor, radius: isFocused ? 22 : 18)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let defaultLibrarySubtitle = "Browse the Secret Shows video library..."

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
    @Published var librarySubtitle = AppModel.defaultLibrarySubtitle
    @Published var isLiveStreamButtonVisible = false
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
    private var isRefreshingSplashAsset = false
    private var pendingDeepLinkShowID: String?
    private var pendingLiveStreamDeepLink = false
    private var liveStreamURL: URL?

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

        Task {
            await refreshSplashAsset()
        }

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
        if DeepLinkParser.isLiveStream(url) {
            pendingLiveStreamDeepLink = true

            if sessionStore.currentSession == nil {
                screen = .login
                return
            }

            Task {
                await loadAuthorizedContent(restoringPreviousLocation: true, showLoadingScreen: false)
            }
            return
        }

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
        librarySubtitle = Self.defaultLibrarySubtitle
        isLiveStreamButtonVisible = false
        liveStreamURL = nil
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
        showLibrary()
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

        let moreEpisodes = videoShows
            .filter { $0.id != show.id }
            .sorted { $0.publishedAt > $1.publishedAt }

        let moreEpisodesProgress = Dictionary(
            uniqueKeysWithValues: moreEpisodes.map { ($0.id, progressStore.progress(for: $0.id)) }
        )

        let session = PlayerSession(
            show: show,
            startTime: startTime,
            progressStore: progressStore,
            moreEpisodes: moreEpisodes,
            moreEpisodesProgress: moreEpisodesProgress,
            onSelectEpisode: { [weak self] selectedShow in
                self?.playFromPlayer(show: selectedShow)
            }
        )
        activePlaybackSession = session
    }

    private func playFromPlayer(show: SecretShow) {
        guard URL(string: show.playbackURLString) != nil else { return }

        preferredLibraryFocusShowID = show.id
        selectedShowID = show.id
        navigationStore.save(.detail(showID: show.id))

        let moreEpisodes = videoShows
            .filter { $0.id != show.id }
            .sorted { $0.publishedAt > $1.publishedAt }

        let moreEpisodesProgress = Dictionary(
            uniqueKeysWithValues: moreEpisodes.map { ($0.id, progressStore.progress(for: $0.id)) }
        )
        let startTime = progressStore.resumeTime(for: show.id)

        activePlaybackSession?.replacePlayback(
            show: show,
            startTime: startTime,
            moreEpisodes: moreEpisodes,
            moreEpisodesProgress: moreEpisodesProgress
        )
    }

    func playerDismissed() {
        activePlaybackSession?.saveProgress()
        activePlaybackSession = nil
    }

    func playLiveStream() {
        guard let liveStreamURL else { return }
        activePlaybackSession = PlayerSession(
            show: .liveStream(urlString: liveStreamURL.absoluteString),
            startTime: 0,
            progressStore: progressStore,
            tracksProgress: false
        )
    }

    func refreshLibraryMetadata() async {
        SettingsDebugLogger.log("Refreshing library metadata")
        do {
            let settings = try await apiClient.fetchTVSettings()
            await refreshSplashAsset(using: settings)
            let resolvedMessage = settings.currentMessage ?? Self.defaultLibrarySubtitle
            librarySubtitle = resolvedMessage
            let liveState = try await resolveLiveStreamState(from: settings)
            applyLiveStreamState(liveState)
            SettingsDebugLogger.log(
                """
                Library metadata refresh succeeded
                tvAppMsg: \(settings.tvAppMsg ?? "<nil>")
                tvAppMsgExpiry: \(settings.tvAppMsgExpiry ?? "<nil>")
                Resolved subtitle: \(resolvedMessage)
                LiveStreamURL: \(settings.liveStreamURL ?? "<nil>")
                SS_Live_Override: \(settings.ssLiveOverride?.description ?? "<nil>")
                Live stream visible: \(isLiveStreamButtonVisible)
                """
            )
        } catch {
            librarySubtitle = Self.defaultLibrarySubtitle
            applyLiveStreamState(.hidden)
            SettingsDebugLogger.log(
                """
                Library metadata refresh failed
                Error: \(error.localizedDescription)
                Falling back to default subtitle: \(Self.defaultLibrarySubtitle)
                """
            )
        }
    }

    func refreshSplashAsset(using settings: APIClient.TVSettingsResponse? = nil) async {
        guard !isRefreshingSplashAsset else { return }
        isRefreshingSplashAsset = true
        defer { isRefreshingSplashAsset = false }

        do {
            let resolvedSettings = try await {
                if let settings {
                    return settings
                }
                return try await apiClient.fetchTVSettings()
            }()

            try await SplashAssetStore.refresh(
                currentSplashName: resolvedSettings.sanitizedCurrentSplashName,
                currentSplashURL: resolvedSettings.sanitizedCurrentSplashURL
            )
        } catch {
            SettingsDebugLogger.log("Splash asset refresh failed: \(error.localizedDescription)")
        }
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
                pendingLiveStreamDeepLink = false
                accessDeniedMessage = "No video subscription detected.\nPlease visit https://www.thenewsjunkie.com/ to upgrade."
                screen = .accessDenied
                return
            }

            let shows = try await apiClient.fetchSecretShows(session: session)
            let filteredShows = shows.filter { $0.hasVideo }
            videoShows = filteredShows
            cacheStore.save(filteredShows)
            await refreshLibraryMetadata()

            guard !filteredShows.isEmpty else {
                errorMessage = "No Secret Shows videos are currently available for this account."
                screen = .error
                return
            }

            if openPendingLiveStreamIfNeeded() {
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
                showLibrary(refreshMetadata: false)
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
                showLibrary(refreshMetadata: false)
            }
        case .library, .none:
            selectedShowID = nil
            showLibrary(refreshMetadata: false)
        }
    }

    private func showLibrary(refreshMetadata: Bool = true) {
        screen = .library
        if refreshMetadata {
            Task {
                await refreshLibraryMetadata()
            }
        }
    }

    private func resolveLiveStreamState(from settings: APIClient.TVSettingsResponse) async throws -> LiveStreamState {
        guard let liveStreamURL = settings.sanitizedLiveStreamURL else {
            SettingsDebugLogger.log(
                """
                Live stream URL is blank or invalid; hiding live button
                Raw LiveStreamURL: \(settings.liveStreamURL ?? "<nil>")
                """
            )
            return .hidden
        }

        SettingsDebugLogger.log("Sanitized LiveStreamURL: \(liveStreamURL.absoluteString)")

        if settings.ssLiveOverride == true {
            SettingsDebugLogger.log("SS_Live_Override is true; showing live button without time check")
            return .visible(url: liveStreamURL)
        }

        guard let liveWindow = settings.weeklyShow else {
            SettingsDebugLogger.log("weeklyShow is missing; hiding live button")
            return .hidden
        }

        let isVisible = liveWindow.containsNow
        SettingsDebugLogger.log(
            """
            Live button time-window decision
            start: \(liveWindow.start)
            end: \(liveWindow.end)
            containsNow: \(isVisible)
            """
        )
        return isVisible ? .visible(url: liveStreamURL) : .hidden
    }

    private func applyLiveStreamState(_ state: LiveStreamState) {
        switch state {
        case .hidden:
            isLiveStreamButtonVisible = false
            liveStreamURL = nil
        case .visible(let url):
            isLiveStreamButtonVisible = true
            liveStreamURL = url
        }
    }

    @discardableResult
    private func openPendingLiveStreamIfNeeded() -> Bool {
        guard pendingLiveStreamDeepLink else { return false }
        pendingLiveStreamDeepLink = false

        guard isLiveStreamButtonVisible else {
            SettingsDebugLogger.log("Live deep link requested, but the live stream is not currently available")
            return false
        }

        playLiveStream()
        return true
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

    var posterURL: URL? {
        guard let posterImage else { return nil }
        let trimmed = posterImage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "null", trimmed.lowercased() != "<null>" else {
            return nil
        }
        return URL(string: trimmed)
    }

    var publishedAt: Date {
        SecretShowDateFormatter.date(from: pubDate) ?? .distantPast
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

    init(
        id: String,
        title: String,
        audioURL: String,
        videoURL: String,
        posterImage: String?,
        pubDate: String?,
        descriptionText: String,
        images: [SecretShowImage]
    ) {
        self.id = id
        self.title = title
        self.audioURL = audioURL
        self.videoURL = videoURL
        self.posterImage = posterImage
        self.pubDate = pubDate
        self.descriptionText = descriptionText
        self.images = images
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

    static func liveStream(urlString: String) -> SecretShow {
        SecretShow(
            id: "__live_stream__",
            title: "Secret Shows Live Stream",
            audioURL: "",
            videoURL: urlString,
            posterImage: nil,
            pubDate: nil,
            descriptionText: "Live Secret Shows stream",
            images: []
        )
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

    private static let playerSubtitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let playerSubtitleWithYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static func displayString(from apiValue: String) -> String? {
        guard let date = inputFormatter.date(from: apiValue) else {
            return nil
        }
        return outputFormatter.string(from: date)
    }

    static func date(from apiValue: String?) -> Date? {
        guard let apiValue else { return nil }
        return inputFormatter.date(from: apiValue)
    }

    static func playerSubtitleString(from apiValue: String?) -> String? {
        guard let apiValue,
              let date = inputFormatter.date(from: apiValue) else {
            return nil
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        let showYear = Calendar.current.component(.year, from: date)
        if showYear == currentYear {
            return playerSubtitleFormatter.string(from: date)
        }

        return playerSubtitleWithYearFormatter.string(from: date)
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
    static let currentSplashName = "tv.secretshows.currentSplashName"
    static let currentSplashFileExtension = "tv.secretshows.currentSplashFileExtension"
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

    struct TVSettingsResponse: Decodable {
        let tvAppMsg: String?
        let tvAppMsgExpiry: String?
        let liveStreamURL: String?
        let ssLiveOverride: Bool?
        let weeklyShow: WeeklyShowWindow?
        let currentSplashName: String?
        let currentSplashURL: String?

        enum CodingKeys: String, CodingKey {
            case tvAppMsg
            case tvAppMsgExpiry
            case liveStreamURL = "LiveStreamURL"
            case ssLiveOverride = "SS_Live_Override"
            case weeklyShow
            case currentSplashName
            case currentSplashURL
        }

        var currentMessage: String? {
            let trimmedMessage = tvAppMsg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedMessage.isEmpty else {
                SettingsDebugLogger.log("Settings message is blank or missing; using default subtitle")
                return nil
            }

            let trimmedExpiry = tvAppMsgExpiry?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedExpiry.isEmpty else {
                SettingsDebugLogger.log("Settings expiry is blank or missing; using default subtitle")
                return nil
            }

            guard let expiryDate = SettingsConfiguration.expiryFormatter.date(from: trimmedExpiry) else {
                SettingsDebugLogger.log(
                    "Settings expiry could not be parsed with format yyyy-MM-dd'T'HH:mm: \(trimmedExpiry)"
                )
                return nil
            }

            let now = Date()
            SettingsDebugLogger.log(
                """
                Evaluating settings message
                Trimmed message: \(trimmedMessage)
                Parsed expiry: \(expiryDate)
                Current time: \(now)
                """
            )

            guard expiryDate > now else {
                SettingsDebugLogger.log("Settings message is expired; using default subtitle")
                return nil
            }

            return trimmedMessage
        }

        var sanitizedLiveStreamURL: URL? {
            guard let liveStreamURL else { return nil }
            let trimmedURL = liveStreamURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedURL.isEmpty else { return nil }
            return URL(string: trimmedURL)
        }

        var sanitizedCurrentSplashName: String? {
            let trimmedName = currentSplashName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmedName.isEmpty ? nil : trimmedName
        }

        var sanitizedCurrentSplashURL: URL? {
            guard let currentSplashURL else { return nil }
            let trimmedURL = currentSplashURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedURL.isEmpty else { return nil }
            return URL(string: trimmedURL)
        }
    }

    struct WeeklyShowWindow: Decodable {
        let start: String
        let end: String

        var containsNow: Bool {
            guard let startDate = SettingsConfiguration.upcomingLiveFormatter.date(from: start),
                  let endDate = SettingsConfiguration.upcomingLiveFormatter.date(from: end) else {
                SettingsDebugLogger.log(
                    """
                    Weekly show window could not be parsed
                    start: \(start)
                    end: \(end)
                    """
                )
                return false
            }

            let now = Date()
            let easternFormatter = SettingsConfiguration.debugEasternFormatter
            SettingsDebugLogger.log(
                """
                Evaluating live window
                Start: \(startDate)
                End: \(endDate)
                Current time: \(now)
                Start (Eastern): \(easternFormatter.string(from: startDate))
                End (Eastern): \(easternFormatter.string(from: endDate))
                Current time (Eastern): \(easternFormatter.string(from: now))
                """
            )
            let containsNow = startDate <= now && now <= endDate
            SettingsDebugLogger.log("Live window contains current time: \(containsNow)")
            return containsNow
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

    func fetchTVSettings() async throws -> TVSettingsResponse {
        SettingsDebugLogger.log("Fetching TV settings from \(SettingsConfiguration.settingsURLString)")
        guard let url = URL(string: SettingsConfiguration.settingsURLString) else {
            SettingsDebugLogger.log("Settings URL is invalid")
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            if let httpResponse = response as? HTTPURLResponse {
                let payload = String(data: data, encoding: .utf8) ?? "<non-UTF8 payload>"
                SettingsDebugLogger.log(
                    """
                    Settings request failed
                    HTTP status: \(httpResponse.statusCode)
                    Response body: \(payload)
                    """
                )
            } else {
                SettingsDebugLogger.log("Settings request failed without an HTTP response")
            }
            throw APIError.invalidResponse
        }

        let payload = String(data: data, encoding: .utf8) ?? "<non-UTF8 payload>"
        SettingsDebugLogger.log(
            """
            Settings request succeeded
            HTTP status: \(httpResponse.statusCode)
            Response body: \(payload)
            """
        )

        return try decode(TVSettingsResponse.self, from: data)
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

enum SettingsConfiguration {
    static let settingsURLString = Bundle.main.object(forInfoDictionaryKey: "SettingsAPIURL") as? String ?? "https://gpmandlkcdompmdvethh.supabase.co/functions/v1/tv-settings/"
    static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
    static let upcomingLiveFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()
    static let debugEasternFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        return formatter
    }()
}

private enum LiveStreamState {
    case hidden
    case visible(url: URL)
}

enum SettingsDebugLogger {
    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        print("[TVSettings] \(message())")
#endif
    }
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

    static func isLiveStream(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == scheme else { return false }
        if url.host == "live" {
            return true
        }

        let components = url.pathComponents.filter { $0 != "/" }
        return components == ["live"]
    }
}

enum SplashVideoResource {
    static var url: URL? {
        SplashAssetStore.cachedSplashURL
            ?? Bundle.main.url(forResource: "NJ-TV-splash", withExtension: "mp4", subdirectory: "images")
            ?? Bundle.main.url(forResource: "NJ-TV-splash", withExtension: "mp4")
    }
}

enum SplashAssetStore {
    private static let fileManager = FileManager.default
    private static let maxSplashFileSizeBytes = 100 * 1024 * 1024
    private static let maxSplashDuration: Double = 30
    private static let allowedExtensions = Set(["mp4", "mov", "m4v"])
    private static let allowedContentTypes = [
        "video/mp4": "mp4",
        "video/quicktime": "mov",
        "video/x-m4v": "m4v",
        "video/m4v": "m4v"
    ]

    static var cachedSplashURL: URL? {
        let storedName = UserDefaults.standard.string(forKey: StorageKeys.currentSplashName)
        let storedExtension = UserDefaults.standard.string(forKey: StorageKeys.currentSplashFileExtension)
        guard let storedName, !storedName.isEmpty,
              let storedExtension, allowedExtensions.contains(storedExtension) else {
            return nil
        }

        let fileURL = cachedFileURL(for: storedName, fileExtension: storedExtension)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return fileURL
    }

    static func refresh(currentSplashName: String?, currentSplashURL: URL?) async throws {
        guard let currentSplashName, let currentSplashURL else {
            clearCachedSplash()
            return
        }

        SettingsDebugLogger.log(
            """
            Refreshing splash asset
            currentSplashName: \(currentSplashName)
            currentSplashURL: \(currentSplashURL.absoluteString)
            """
        )

        let cachedName = UserDefaults.standard.string(forKey: StorageKeys.currentSplashName)
        let cachedExtension = UserDefaults.standard.string(forKey: StorageKeys.currentSplashFileExtension)
        if let cachedName, cachedName == currentSplashName,
           let cachedExtension, allowedExtensions.contains(cachedExtension) {
            let targetURL = cachedFileURL(for: currentSplashName, fileExtension: cachedExtension)
            if fileManager.fileExists(atPath: targetURL.path) {
                SettingsDebugLogger.log("Splash asset already cached; skipping download")
                return
            }
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: currentSplashURL)
        let resolvedExtension = try await validateDownloadedFile(
            at: temporaryURL,
            response: response,
            sourceURL: currentSplashURL
        )
        let targetURL = cachedFileURL(for: currentSplashName, fileExtension: resolvedExtension)

        clearCachedSplash()
        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: targetURL)
        UserDefaults.standard.set(currentSplashName, forKey: StorageKeys.currentSplashName)
        UserDefaults.standard.set(resolvedExtension, forKey: StorageKeys.currentSplashFileExtension)
        SettingsDebugLogger.log("Cached splash asset: \(currentSplashName)")
    }

    private static func validateDownloadedFile(
        at fileURL: URL,
        response: URLResponse,
        sourceURL: URL
    ) async throws -> String {
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            SettingsDebugLogger.log("Splash download failed with HTTP status: \(httpResponse.statusCode)")
            throw SplashAssetError.downloadFailed
        }

        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = values.fileSize ?? 0
        SettingsDebugLogger.log(
            """
            Splash download response
            MIME type: \(response.mimeType ?? "<nil>")
            Suggested filename: \(response.suggestedFilename ?? "<nil>")
            Temporary file URL: \(fileURL.path)
            Temporary file size: \(fileSize)
            """
        )
        guard fileSize > 0, fileSize <= maxSplashFileSizeBytes else {
            throw SplashAssetError.invalidFileSize
        }

        guard let resolvedExtension = resolveFileExtension(response: response, sourceURL: sourceURL) else {
            throw SplashAssetError.unsupportedFileType
        }

        let validationURL = cacheDirectoryURL.appendingPathComponent("validation.\(resolvedExtension)")
        if fileManager.fileExists(atPath: validationURL.path) {
            try? fileManager.removeItem(at: validationURL)
        }
        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: fileURL, to: validationURL)
        defer {
            try? fileManager.removeItem(at: validationURL)
        }

        let asset = AVURLAsset(url: validationURL)
        let isPlayable = try await asset.load(.isPlayable)
        SettingsDebugLogger.log("Splash asset isPlayable: \(isPlayable)")
        guard isPlayable else {
            throw SplashAssetError.notPlayable
        }

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        SettingsDebugLogger.log("Splash asset durationSeconds: \(durationSeconds)")
        guard durationSeconds.isFinite, durationSeconds > 0, durationSeconds <= maxSplashDuration else {
            throw SplashAssetError.invalidDuration
        }

        return resolvedExtension
    }

    private static func resolveFileExtension(response: URLResponse, sourceURL: URL) -> String? {
        if let mimeType = response.mimeType?.lowercased(),
           let mappedExtension = allowedContentTypes[mimeType] {
            SettingsDebugLogger.log("Resolved splash file extension from MIME type: \(mappedExtension)")
            return mappedExtension
        }

        let urlExtension = sourceURL.pathExtension.lowercased()
        if allowedExtensions.contains(urlExtension) {
            SettingsDebugLogger.log("Resolved splash file extension from URL: \(urlExtension)")
            return urlExtension
        }

        SettingsDebugLogger.log(
            """
            Unable to resolve splash file extension
            MIME type: \(response.mimeType ?? "<nil>")
            Source URL extension: \(sourceURL.pathExtension)
            """
        )
        return nil
    }

    private static func clearCachedSplash() {
        if let cachedName = UserDefaults.standard.string(forKey: StorageKeys.currentSplashName) {
            if let cachedExtension = UserDefaults.standard.string(forKey: StorageKeys.currentSplashFileExtension) {
                let existingURL = cachedFileURL(for: cachedName, fileExtension: cachedExtension)
                try? fileManager.removeItem(at: existingURL)
            }
        }
        UserDefaults.standard.removeObject(forKey: StorageKeys.currentSplashName)
        UserDefaults.standard.removeObject(forKey: StorageKeys.currentSplashFileExtension)
    }

    private static var cacheDirectoryURL: URL {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SecretShowsSplash", isDirectory: true)
    }

    private static func cachedFileURL(for splashName: String, fileExtension: String) -> URL {
        let safeName = splashName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cacheDirectoryURL.appendingPathComponent("\(safeName).\(fileExtension)")
    }

    private enum SplashAssetError: LocalizedError {
        case unsupportedFileType
        case invalidFileSize
        case invalidDuration
        case notPlayable
        case downloadFailed

        var errorDescription: String? {
            switch self {
            case .unsupportedFileType:
                return "The splash asset format is not supported."
            case .invalidFileSize:
                return "The splash asset size is invalid."
            case .invalidDuration:
                return "The splash asset duration is invalid."
            case .notPlayable:
                return "The splash asset is not playable."
            case .downloadFailed:
                return "The splash asset download failed."
            }
        }
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
    @Published private(set) var show: SecretShow
    @Published private(set) var moreEpisodes: [SecretShow]
    @Published private(set) var moreEpisodesProgress: [String: ShowPlaybackProgress]

    private let progressStore: PlaybackProgressStore
    private let tracksProgress: Bool
    private let onSelectEpisode: ((SecretShow) -> Void)?
    private var timeObserver: Any?
    private var completionObserver: NSObjectProtocol?
    private var artworkLoadTask: URLSessionDataTask?

    init(
        show: SecretShow,
        startTime: Double,
        progressStore: PlaybackProgressStore,
        tracksProgress: Bool = true,
        moreEpisodes: [SecretShow] = [],
        moreEpisodesProgress: [String: ShowPlaybackProgress] = [:],
        onSelectEpisode: ((SecretShow) -> Void)? = nil
    ) {
        self.show = show
        self.progressStore = progressStore
        self.tracksProgress = tracksProgress
        self.moreEpisodes = moreEpisodes
        self.moreEpisodesProgress = moreEpisodesProgress
        self.onSelectEpisode = onSelectEpisode
        let playerItem = AVPlayerItem(url: URL(string: show.playbackURLString) ?? URL(fileURLWithPath: "/dev/null"))
        playerItem.externalMetadata = Self.metadataItems(for: show)
        self.player = AVPlayer(playerItem: playerItem)
        super.init()

        if startTime > 0 {
            let seekTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        if tracksProgress {
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
        }

        if tracksProgress, let item = player.currentItem {
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

        publishNowPlayingInfo()
    }

    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
        }
        artworkLoadTask?.cancel()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func saveProgress() {
        guard tracksProgress else { return }
        progressStore.save(
            time: player.currentTime().seconds,
            duration: player.currentItem?.duration.seconds ?? 0,
            for: show.id
        )
    }

    func replacePlayback(
        show: SecretShow,
        startTime: Double,
        moreEpisodes: [SecretShow],
        moreEpisodesProgress: [String: ShowPlaybackProgress]
    ) {
        self.show = show
        self.moreEpisodes = moreEpisodes
        self.moreEpisodesProgress = moreEpisodesProgress

        let playerItem = AVPlayerItem(url: URL(string: show.playbackURLString) ?? URL(fileURLWithPath: "/dev/null"))
        playerItem.externalMetadata = Self.metadataItems(for: show)
        player.replaceCurrentItem(with: playerItem)

        if let completionObserver {
            NotificationCenter.default.removeObserver(completionObserver)
            self.completionObserver = nil
        }

        if startTime > 0 {
            let seekTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        if tracksProgress, let item = player.currentItem {
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

        publishNowPlayingInfo()
        player.play()
    }

    func makeInfoViewControllers() -> [UIViewController] {
        guard !moreEpisodes.isEmpty else { return [] }

        let moreEpisodesController = PlayerMoreEpisodesContentViewController(
            episodes: Array(moreEpisodes.prefix(12)),
            progressByShowID: moreEpisodesProgress,
            onSelectEpisode: { [weak self] episode in
                guard let self else { return }
                self.saveProgress()
                self.onSelectEpisode?(episode)
            }
        )

        return [moreEpisodesController]
    }

    private static func metadataItems(for show: SecretShow, artworkData: Data? = nil) -> [AVMetadataItem] {
        var items = [AVMetadataItem]()
        items.append(metadataItem(identifier: .commonIdentifierTitle, value: show.title))
        items.append(metadataItem(identifier: .iTunesMetadataTrackSubTitle, value: "Secret Shows"))

        if !show.descriptionText.isEmpty {
            items.append(metadataItem(identifier: .commonIdentifierDescription, value: show.descriptionText))
        }

        if let artworkData {
            items.append(metadataItem(identifier: .commonIdentifierArtwork, dataValue: artworkData))
        } else if let placeholderData = UIImage(named: "SecretShowsPlaceholder")?.pngData() {
            items.append(metadataItem(identifier: .commonIdentifierArtwork, dataValue: placeholderData))
        }

        return items
    }

    private static func metadataItem(identifier: AVMetadataIdentifier, value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    private static func metadataItem(identifier: AVMetadataIdentifier, dataValue: Data) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = dataValue as NSData
        item.dataType = kCMMetadataBaseDataType_PNG as String
        item.extendedLanguageTag = "und"
        return item.copy() as! AVMetadataItem
    }

    private func publishNowPlayingInfo() {
        artworkLoadTask?.cancel()

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = show.title
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "Secret Shows"

        if let assetURL = URL(string: show.playbackURLString) {
            nowPlayingInfo[MPNowPlayingInfoPropertyAssetURL] = assetURL
        }

        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.video.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = show.id == "__live_stream__"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(player.currentTime().seconds, 0)
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate == 0 ? 1.0 : player.rate

        let duration = player.currentItem?.duration.seconds ?? 0
        if duration.isFinite && duration > 0 {
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let placeholderImage = UIImage(named: "SecretShowsPlaceholder") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork(for: placeholderImage)
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        player.currentItem?.externalMetadata = Self.metadataItems(for: show)

        guard let posterURL = show.posterURL else { return }
        if let cachedImage = PlayerPosterImageLoader.shared.cachedImage(for: posterURL) {
            updateNowPlayingArtwork(cachedImage)
            return
        }

        artworkLoadTask = PlayerPosterImageLoader.shared.loadImage(from: posterURL) { [weak self] image in
            guard let self, let image else { return }
            self.updateNowPlayingArtwork(image)
        }
    }

    private func updateNowPlayingArtwork(_ image: UIImage) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPMediaItemPropertyArtwork] = mediaArtwork(for: image)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        guard let data = image.pngData() ?? image.jpegData(compressionQuality: 0.9) else { return }
        player.currentItem?.externalMetadata = Self.metadataItems(for: show, artworkData: data)
    }

    private func mediaArtwork(for image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}

struct VideoPlayerControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var session: PlayerSession

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        configure(controller, context: context)
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        configure(uiViewController, context: context)
    }

    private func configure(_ controller: AVPlayerViewController, context: Context) {
        controller.player = session.player

        let infoViewState = InfoViewState(
            showID: session.show.id,
            moreEpisodeIDs: session.moreEpisodes.map(\.id)
        )
        if context.coordinator.infoViewState != infoViewState {
            controller.customInfoViewControllers = session.makeInfoViewControllers()
            context.coordinator.infoViewState = infoViewState
        }

        session.player.play()
    }

    final class Coordinator {
        var infoViewState: InfoViewState?
    }

    struct InfoViewState: Equatable {
        let showID: String
        let moreEpisodeIDs: [String]
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
