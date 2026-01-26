//
//  ContentView.swift
//  Card
//
//  Created by Ankur Yadav on 12/05/25.
//

import SwiftUI
import AVKit
import SDWebImageSwiftUI

enum CardMediaType {
    case image(name: String)
    case gif(name: String)
    case video(name: String)
}

struct CardModel: Identifiable {
    let id = UUID()
    let color: Color
    let media: CardMediaType
    let title: String
    let subtitle: String
}

enum SwipeDirection {
    case left
    case right
}

struct ContentView: View {
    @State private var cards: [CardModel] = [
        CardModel(color: .white, media: .image(name: "IMG_0478"), title: "First Drug", subtitle: "The first cup of coffee is magic, a quiet chat with myself before the world begins. I illustrated this on Procreate: just me and my coffee, sitting, sipping, and greeting the morning like old friends!"),
        CardModel(color: .black, media: .image(name: "IMG_0479"), title: "Fell for Her Again", subtitle: "One evening, I saw my girlfriend reading, completely lost in her world. Her focus, her quiet quirks, her calm. It made me fall for her all over again. I illustrated that moment on Procreate, lovingly"),
        CardModel(color: .black, media: .image(name: "IMG_0482"), title: "Our Little Pause", subtitle: "There's magic in the smallest pauses. That evening, she joined me on the balcony, coffee in hand, clouds drifting by. No words, just us. I drew this on Procreate to hold that quiet magic forever"),
        CardModel(color: .black, media: .video(name: "Instagram Video Animation Loader"), title: "A button", subtitle: "One of the early design days motion experiments. Conceptualised and rendered in After Effects and then using lottie to make the animation smaller in size"),
        CardModel(color: .white, media: .video(name: "Morph"), title: "Morph", subtitle: "Conceptualized a concept for About Me page on my portfolio. Made using After Effects"),
        CardModel(color: .black, media: .image(name: "IMG_0265"), title: "Inner Orbit", subtitle: "Created in my early Procreate days, when silence was loud and the void, endless. It captures the feeling of chasing dreams, trusting the faint glow within, and moving forward with quiet, guarded hope. Just me, my armor, and a whisper: keep going."),
        CardModel(color: .black, media: .image(name: "warrior"), title: "Red Stands for Her", subtitle: "A tribute to every woman who bleeds, endures, and rises. The red isn't just battle, it's her body, her strength, her story. Drawn on Adobe Illustrator, born from quiet fire"),
        CardModel(color: .black, media: .image(name: "manny-1"), title: "Human, Not Holy", subtitle: "I'm a firm atheist, but a Shiva poster in a friend's room caught my eye. Not for the divinity, but the expression. I reimagined him not as a god, but as a human, raw, grounded, real. Drawn on Illustrator, from my lens, not faith."),
        CardModel(color: .black, media: .image(name: "Star Lord"), title: "Star-Lord Energy", subtitle: "Not the strongest. Not the smartest. Definitely not the most loved. But stil he showed up, messed up, and somehow mattered. I sketched this on Illustrator as a salute to the chaos he wore like a badge.."),
        
    ]
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var selectedCard: CardModel? = nil
    @State private var isFullScreen: Bool = false
    @State private var showFullScreen: Bool = false
    @State private var zoomAmount: CGFloat = 1.0
    @State private var selectedIndex: Int? = nil

    // Card properties for each position
    let cardConfigs: [(CGSize, CGSize, Double)] = [
        (CGSize(width: 342, height: 372), CGSize(width: 0, height: 0), 0), // front
        (CGSize(width: 324, height: 364), CGSize(width: 0, height: -40), 2), // middle
        (CGSize(width: 296, height: 356), CGSize(width: 4, height: -70), -3),// back
        (CGSize(width: 272, height: 324), CGSize(width: 5, height: -105), 4), // fourth
        (CGSize(width: 272, height: 324), CGSize(width: 5, height: -105), 4), //fifth
        (CGSize(width: 272, height: 324), CGSize(width: 5, height: -105), 4), //sixth
        (CGSize(width: 272, height: 324), CGSize(width: 5, height: -105), 4),// seventh//
        (CGSize(width: 272, height: 324), CGSize(width: 5, height: -105), 4), //eigth
        (CGSize(width: 272, height: 324), CGSize(width: 5, height: -105), 4) //ninth
    ]
    

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(hex: "ECECEC"), location: 0.49),
                    .init(color: Color(hex: "FFFFFF"), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Cross button
                HStack {
                    Button(action: {
                        // Action for cross button
                    }) {
                        Image(systemName: "xmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 8, height: 8)
                            .foregroundColor(.black)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "FAF8F8"))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.leading, 16)
                // Title
                if let currentCard = cards.first {
                    Text(currentCard.title)
                        .font(.system(size: 36, design: .serif))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "222222"))
                        .padding(.top, 32)
                        .padding(.leading, 16)

                    Text(currentCard.subtitle)
                        .font(.custom("Inter", size: 16).weight(.regular))
                        .foregroundColor(Color(hex: "717171"))
                        .padding(.top, 8)
                        .padding(.leading, 16)
                        .padding(.trailing, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                // Centered card stack
                HStack {
                    Spacer()
                    ZStack {
                        ForEach(Array(cards.enumerated()), id: \.1.id) { idx, card in
                            let config = cardConfigs[idx]
                            CardView(card: card)
                                .frame(width: config.0.width, height: config.0.height)
                                .offset(x: config.1.width, y: config.1.height)
                                .rotationEffect(.degrees(config.2))
                                .zIndex(Double(2 - idx))
                                .offset(idx == 0 ? dragOffset : .zero)
                                .gesture(
                                    idx == 0 ?
                                    DragGesture()
                                        .onChanged { value in
                                            dragOffset = value.translation
                                            isDragging = true
                                        }
                                        .onEnded { value in
                                            if abs(value.translation.height) > 80 {
                                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                    let first = cards.removeFirst()
                                                    cards.append(first)
                                                    dragOffset = .zero
                                                    isDragging = false
                                                }
                                            } else {
                                                withAnimation(.spring()) {
                                                    dragOffset = .zero
                                                    isDragging = false
                                                }
                                            }
                                        }
                                    : nil
                                )
                                .onTapGesture {
                                    selectedCard = card
                                    selectedIndex = idx
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        showFullScreen = true
                                    }
                                }
                                .id(card.id) // Add an ID to help track cards
                        }
                    }
                    Spacer()
                }
            }
            .overlay(
                ZStack {
                    if let selectedIndex = selectedIndex, showFullScreen {
                        FullScreenMediaView(
                            card: cards[selectedIndex],
                            onDismiss: {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                                    showFullScreen = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    self.selectedCard = nil
                                    self.selectedIndex = nil
                                    FullScreenMediaView.resetState()
                                }
                            },
                            onSwipe: { direction in
                                if direction == .right, selectedIndex < cards.count - 1 {
                                    self.selectedIndex! += 1
                                } else if direction == .left, selectedIndex > 0 {
                                    self.selectedIndex! -= 1
                                }
                            }
                        )
                        .zIndex(100)
                    }
                }
            )
        }
    }
}

struct CardView: View {
    let card: CardModel
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card background and shadow
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(card.color)
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
            // Card media, clipped to the same shape
            mediaView
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        // Clip the entire ZStack to the rounded rectangle
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    var mediaView: some View {
        switch card.media {
        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFill()
        case .gif(let name):
            AnimatedImage(name: name)
                .resizable()
                .scaledToFill()
        case .video(let name):
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                VideoPlayerContainer(url: url)
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray
            }
        }
    }
}

struct VideoPlayerContainer: View {
    let url: URL
    @State private var player: AVPlayer = AVPlayer()
    @State private var playerLooper: Any?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                let avPlayer = AVPlayer(url: url)
                player = avPlayer
                avPlayer.seek(to: .zero)
                avPlayer.play()
                // Add observer for looping
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: avPlayer.currentItem,
                    queue: .main
                ) { _ in
                    avPlayer.seek(to: .zero)
                    avPlayer.play()
                }
            }
            .onDisappear {
                player.pause()
                player.seek(to: .zero)
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
            }
    }
}

// Helper extension for hex color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (1, 1, 1)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

struct FullScreenMediaView: View {
    let card: CardModel
    var onDismiss: () -> Void
    var onSwipe: (SwipeDirection) -> Void

    @State private var appear = false
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var minScale: CGFloat = 1.0
    @State private var floatAmount: CGFloat = 0
    @State private var zoomAmount: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                mediaView(geo: geo)
                    .scaleEffect(appear ? 1.0 : 0.85)
                    .opacity(appear ? 1.0 : 0.5)
                    .onAppear {
                        withAnimation(
                            Animation.easeInOut(duration: 3.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            zoomAmount = 1.05 // A subtle zoom (e.g., 1.02–1.05)
                        }
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                            appear = true
                        }
                    }
                
                // Back button overlay matching main page style
                VStack {
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 8, height: 8)
                                .foregroundColor(.black)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: "FAF8F8"))
                                .clipShape(Circle())
                        }
                        .padding(.top, 88)
                        .padding(.leading, 16)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .ignoresSafeArea()
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -50 {
                            onSwipe(.right)
                        } else if value.translation.width > 50 {
                            onSwipe(.left)
                        }
                    }
            )
        }
    }
    
    func clampedOffset(for size: CGSize) -> CGSize {
        let width = size.width
        let height = size.height
        let scaledWidth = width * scale
        let scaledHeight = height * scale
        let maxX = max(0, (scaledWidth - width) / 2)
        let maxY = max(0, (scaledHeight - height) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    @ViewBuilder
    func mediaView(geo: GeometryProxy) -> some View {
        let screen = UIScreen.main.bounds
        switch card.media {
        case .image(let name):
            ZStack {
                // Original image
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: screen.width, height: screen.height)
                    .clipped()
                    .scaleEffect(zoomAmount)

                // Blurred image with radial mask
                Image(name)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: screen.width, height: screen.height)
                    .blur(radius: 2)
                    .mask(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: .white, location: 0.0),
                                .init(color: .white, location: 0.0),
                                .init(color: .clear, location: 1.0)
                            ]),
                            center: .bottom,
                            startRadius: 0,
                            endRadius: max(screen.width, screen.height) / 2
                        )
                    )
                    .scaleEffect(zoomAmount)
            }
        case .gif(let name):
            AnimatedImage(name: name)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: screen.width, height: screen.height)
                .clipped()
        case .video(let name):
            if let url = Bundle.main.url(forResource: name, withExtension: "mp4") {
                VideoPlayer(player: AVPlayer(url: url))
                    .aspectRatio(contentMode: .fill)
                    .frame(width: screen.width, height: screen.height)
                    .clipped()
            } else {
                Color.gray
            }
        }
    }

    private func dismiss() {
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            appear = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDismiss()
        }
    }

    static func resetState() {
        // This is a placeholder. You may need to use a Binding or pass a reset closure to actually reset the state in the parent.
    }
}

#Preview {
    ContentView()
}
