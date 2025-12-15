import SwiftUI

// MARK: - Models

enum Suit: CaseIterable, CustomStringConvertible {
    case clubs, diamonds, hearts, spades
    
    var symbol: String {
        switch self {
        case .clubs: return "♣"
        case .diamonds: return "♦"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }
    
    var isRed: Bool {
        self == .diamonds || self == .hearts
    }
    
    var description: String { symbol }
}

enum Rank: Int, CaseIterable, CustomStringConvertible {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace
    
    var display: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        }
    }
    
    // Base value; Aces are handled specially in Hand.value
    var baseValue: Int {
        switch self {
        case .jack, .queen, .king: return 10
        case .ace: return 11
        default: return self.rawValue
        }
    }
    
    var description: String { display }
}

struct Card: Identifiable, Equatable, CustomStringConvertible {
    let suit: Suit
    let rank: Rank
    let id = UUID()
    
    var description: String { "\(rank.display)\(suit.symbol)" }
}

struct Deck {
    private(set) var cards: [Card] = []
    
    init(shuffled: Bool = true) {
        var newCards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                newCards.append(Card(suit: suit, rank: rank))
            }
        }
        self.cards = shuffled ? newCards.shuffled() : newCards
    }
    
    mutating func deal() -> Card? {
        cards.popLast()
    }
    
    var isEmpty: Bool { cards.isEmpty }
}

struct Hand: CustomStringConvertible {
    var cards: [Card] = []
    
    var value: Int { Blackjack.handValue(cards) }
    
    var isBusted: Bool { Blackjack.isBusted(cards) }
    var isBlackjack: Bool { cards.count == 2 && value == 21 }
    
    mutating func add(_ card: Card) {
        cards.append(card)
    }
    
    var description: String { cards.map { $0.description }.joined(separator: " ") }
}

// MARK: - Modes

enum GameMode: String, CaseIterable, Identifiable {
    case blackjack = "Blackjack"
    case counting = "Card Counting Trainer"
    var id: String { rawValue }
}

// MARK: - Game State

enum Outcome: String {
    case none
    case playerBust = "Player busts"
    case dealerBust = "Dealer busts"
    case playerWins = "Player wins"
    case dealerWins = "Dealer wins"
    case push = "Push"
}

enum Blackjack {
    static func handValue(_ cards: [Card]) -> Int {
        var total = cards.reduce(0) { $0 + $1.rank.baseValue }
        var aces = cards.filter { $0.rank == .ace }.count
        while total > 21 && aces > 0 {
            total -= 10
            aces -= 1
        }
        return total
    }

    static func isBusted(_ cards: [Card]) -> Bool {
        handValue(cards) > 21
    }

    static func dealerShouldDraw(_ cards: [Card]) -> Bool {
        handValue(cards) < 17
    }

    static func resolveOutcome(player: [Card], dealer: [Card]) -> Outcome {
        let p = handValue(player)
        if p > 21 { return .playerBust }
        let d = handValue(dealer)
        if d > 21 { return .dealerBust }
        if p > d { return .playerWins }
        if d > p { return .dealerWins }
        return .push
    }
}

struct ContentView: View {
    // Deck and hands
    @State private var deck = Deck()
    @State private var player = Hand()
    @State private var dealer = Hand()
    
    // Control state
    @State private var outcome: Outcome = .none
    @State private var playerStood: Bool = false

    // App mode
    @State private var mode: GameMode = .blackjack

    // Counting trainer state
    @State private var countingDeck = Deck()
    @State private var shownCards: [Card] = []
    @State private var runningCount: Int = 0
    @State private var revealRunningCount: Bool = false
    @State private var guessText: String = ""
    @State private var guessFeedback: String? = nil

    // Instructions sheet
    @State private var showInstructions: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(GameMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .blackjack {
                    // Existing Blackjack UI
                    VStack(spacing: 24) {
                        // Dealer section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dealer")
                                .font(.headline)
                            HStack(spacing: 8) {
                                if dealer.cards.indices.contains(0) {
                                    CardView(card: dealer.cards[0])
                                }
                                if shouldHideDealerHoleCard {
                                    HiddenCardView()
                                } else if dealer.cards.indices.contains(1) {
                                    CardView(card: dealer.cards[1])
                                }
                                // Any additional dealer cards beyond the first two
                                if dealer.cards.count > 2 {
                                    ForEach(dealer.cards.dropFirst(2)) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            .accessibilityLabel(dealerAccessibilityLabel)

                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text(shouldHideDealerHoleCard ? "?" : "\(dealer.value)")
                                    .font(.title3).bold()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // Player section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Player")
                                .font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(player.cards) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text("\(player.value)")
                                    .font(.title3).bold()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Status
                        Text(statusText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(statusColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                        
                        // Controls
                        HStack(spacing: 16) {
                            Button("Hit", action: hit)
                                .buttonStyle(.borderedProminent)
                                .disabled(!canAct)
                            Button("Stand", action: stand)
                                .buttonStyle(.bordered)
                                .disabled(!canAct)
                            Button("New Round", action: newRound)
                                .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)
                        
                        Spacer()
                    }
                } else {
                    // Card Counting Trainer UI
                    VStack(spacing: 16) {
                        Text("Card Counting Trainer (Hi-Lo)")
                            .font(.title2).bold()

                        // Shown cards
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(shownCards) { card in
                                    CardView(card: card)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Controls for trainer
                        HStack(spacing: 12) {
                            Button(action: nextCountingCard) {
                                Label("Next Card", systemImage: "forward.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(countingDeck.isEmpty)

                            Button(action: resetCounting) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Guessing UI
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Guess for Running Count")
                                .font(.headline)
                            HStack {
                                TextField("e.g. 0", text: $guessText)
                                #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
                                    .keyboardType(.numbersAndPunctuation)
                                #endif
                                .textFieldStyle(.roundedBorder)
                                Button("Check", action: checkGuess)
                            }
                            if let feedback = guessFeedback {
                                Text(feedback)
                                    .font(.subheadline)
                                    .foregroundStyle(feedback.hasPrefix("Correct") ? .green : .red)
                            }
                        }

                        Toggle(isOn: $revealRunningCount) {
                            Text("Reveal Running Count")
                        }
                        if revealRunningCount {
                            Text("Running Count: \(runningCount)")
                                .font(.title3).bold()
                        }

                        Spacer()
                    }
                }
            }
            .padding()
            .navigationTitle("Blackjack")
            .onAppear(perform: newRound)
            .toolbar {
                #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Instructions") { showInstructions = true }
                }

                #elseif os(macOS)
                ToolbarItem(placement: .automatic) {
                    Button("Instructions") { showInstructions = true }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Instructions") { showInstructions = true }
                }
                #endif
            }
            .sheet(isPresented: $showInstructions) {
                InstructionsView()
            }
        }
    }
    
    // MARK: - Derived UI State
    
    private var shouldHideDealerHoleCard: Bool {
        outcome == .none && !playerStood
    }
    
    private var canAct: Bool {
        outcome == .none
    }
    
    private var statusText: String {
        switch outcome {
        case .none:
            return player.isBlackjack && !playerStood ? "Blackjack! Stand or Hit?" : "Your move"
        case .playerBust: return Outcome.playerBust.rawValue
        case .dealerBust: return Outcome.dealerBust.rawValue
        case .playerWins: return Outcome.playerWins.rawValue
        case .dealerWins: return Outcome.dealerWins.rawValue
        case .push: return Outcome.push.rawValue
        }
    }
    
    private var statusColor: Color {
        switch outcome {
        case .none: return .primary
        case .playerWins, .dealerBust: return .green
        case .dealerWins, .playerBust: return .red
        case .push: return .orange
        }
    }
    
    private var dealerAccessibilityLabel: String {
        if shouldHideDealerHoleCard {
            let first = dealer.cards.first.map { $0.description } ?? ""
            return "Dealer showing \(first). Hidden hole card."
        } else {
            return "Dealer hand: \(dealer.description). Total \(dealer.value)."
        }
    }
    
    // MARK: - Actions
    
    private func newRound() {
        deck = Deck()
        player = Hand()
        dealer = Hand()
        outcome = .none
        playerStood = false
        
        // Initial deal: player, dealer, player, dealer
        if let c1 = deck.deal() { player.add(c1) }
        if let d1 = deck.deal() { dealer.add(d1) }
        if let c2 = deck.deal() { player.add(c2) }
        if let d2 = deck.deal() { dealer.add(d2) }
        
        // If the player immediately busts (shouldn't happen) or blackjack logic
        checkForImmediateOutcome()
    }
    
    private func hit() {
        guard outcome == .none, let card = deck.deal() else { return }
        player.add(card)
        if player.isBusted {
            outcome = .playerBust
            playerStood = true // Reveal dealer
        }
    }
    
    private func stand() {
        guard outcome == .none else { return }
        playerStood = true
        dealerPlay()
        settle()
    }
    
    private func dealerPlay() {
        // Dealer draws until total >= 17
        while Blackjack.dealerShouldDraw(dealer.cards), let card = deck.deal() {
            dealer.add(card)
        }
    }
    
    private func settle() {
        outcome = Blackjack.resolveOutcome(player: player.cards, dealer: dealer.cards)
    }
    
    private func checkForImmediateOutcome() {
        // Optional: if both have blackjack, it's a push; if player has blackjack and dealer doesn't, player wins when standing
        // Keep round open so player can choose to Stand or Hit; no automatic resolution here.
    }

    // MARK: - Counting Trainer Actions

    private func resetCounting() {
        countingDeck = Deck()
        shownCards = []
        runningCount = 0
        revealRunningCount = false
        guessText = ""
        guessFeedback = nil
    }

    private func nextCountingCard() {
        guard let card = countingDeck.deal() else { return }
        shownCards.append(card)
        runningCount += hiLoValue(for: card)
    }

    private func checkGuess() {
        let trimmed = guessText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let guess = Int(trimmed) {
            if guess == runningCount {
                guessFeedback = "Correct! Running count is \(runningCount)."
            } else {
                let hint = runningCount > guess ? "higher" : "lower"
                guessFeedback = "Not quite. Try \(hint)."
            }
        } else {
            guessFeedback = "Please enter a valid integer."
        }
    }

    private func hiLoValue(for card: Card) -> Int {
        switch card.rank {
        case .two, .three, .four, .five, .six:
            return 1
        case .seven, .eight, .nine:
            return 0
        default: // 10, J, Q, K, A
            return -1
        }
    }
}

// MARK: - UI Components

private struct CardView: View {
    let card: Card
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary, lineWidth: 1)
                )
            VStack(alignment: .leading) {
                Text(card.rank.display)
                    .font(.headline)
                Text(card.suit.symbol)
                    .font(.title2)
                    .padding(.top, -6)
            }
            .foregroundStyle(card.suit.isRed ? .red : .primary)
            .padding(8)
        }
        .frame(width: 56, height: 80)
        .accessibilityLabel("\(card.rank.display) of \(card.suit.symbol)")
    }
}

private struct HiddenCardView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(LinearGradient(colors: [.blue.opacity(0.6), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.secondary, lineWidth: 1)
            )
            .overlay(Text("🂠").font(.title))
            .frame(width: 56, height: 80)
            .accessibilityLabel("Hidden card")
    }
}

private struct InstructionsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("Welcome to Blackjack")
                            .font(.title2).bold()
                        Text("Goal: Get as close to 21 as possible without going over. Face cards are 10, Aces are 11 or 1. Dealer hits until 17.")
                        Text("Your Turn:")
                            .font(.headline)
                        Text("- Hit: Take another card.\n- Stand: Stop taking cards.\n- Blackjack: An Ace + a 10-value card on the initial deal (21).\n- Bust: If your total exceeds 21, you lose.")
                    }

                    Divider()

                    Group {
                        Text("Card Counting (Hi-Lo)")
                            .font(.title2).bold()
                        Text("Hi-Lo assigns values to track whether the remaining deck is rich in high or low cards:")
                        Text("- 2–6: +1\n- 7–9: 0\n- 10, J, Q, K, A: −1")
                        Text("Running Count: Start at 0. Add the value of each revealed card as it appears. A higher running count means more high cards remain in the deck, which generally favors the player.")
                        Text("Trainer Tips:")
                            .font(.headline)
                        Text("- Tap ‘Next Card’ to reveal cards one by one.\n- Enter your current running count guess and tap ‘Check’.\n- Toggle ‘Reveal Running Count’ to verify at any time.\n- Tap ‘Reset’ to reshuffle and start over.")
                    }
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .toolbar {
                #if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
                ToolbarItem(placement: .topBarTrailing) {
                    CloseSheetButton()
                }
                #elseif os(macOS)
                ToolbarItem(placement: .automatic) {
                    CloseSheetButton()
                }
                #else
                ToolbarItem(placement: .automatic) {
                    CloseSheetButton()
                }
                #endif
            }
        }
    }
}

private struct CloseSheetButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Done") { dismiss() }
    }
}

#Preview {
    ContentView()
}
