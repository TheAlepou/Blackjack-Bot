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
    case pvp = "2 Players Mode"
    case headToHead = "Player vs Dealer (Local)"
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
    case dealerMustPush = "Dealer must push"
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

    // PvP state
    private enum PlayerTurn { case player1, player2 }
    @State private var pvpDeck = Deck()
    @State private var pvpDealer = Hand()
    @State private var p1 = Hand()
    @State private var p2 = Hand()
    @State private var p1Outcome: Outcome = .none
    @State private var p2Outcome: Outcome = .none
    @State private var p1Stood: Bool = false
    @State private var p2Stood: Bool = false
    @State private var currentTurn: PlayerTurn = .player1

    // Head-to-head (Player vs Dealer) state
    private enum H2HTurn { case player, dealer }
    @State private var h2hDeck = Deck()
    @State private var h2hPlayer = Hand()
    @State private var h2hDealer = Hand()
    @State private var h2hOutcome: Outcome = .none
    @State private var h2hPlayerStood: Bool = false
    @State private var h2hDealerStood: Bool = false
    @State private var h2hTurn: H2HTurn = .player

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
                } else if mode == .pvp {
                    // Local PvP UI
                    VStack(spacing: 24) {
                        // Dealer section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dealer")
                                .font(.headline)
                            HStack(spacing: 8) {
                                if pvpDealer.cards.indices.contains(0) {
                                    CardView(card: pvpDealer.cards[0])
                                }
                                if pvpShouldHideDealerHoleCard {
                                    HiddenCardView()
                                } else if pvpDealer.cards.indices.contains(1) {
                                    CardView(card: pvpDealer.cards[1])
                                }
                                if pvpDealer.cards.count > 2 {
                                    ForEach(pvpDealer.cards.dropFirst(2)) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            .accessibilityLabel(pvpDealerAccessibilityLabel)

                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text(pvpShouldHideDealerHoleCard ? "?" : "\(pvpDealer.value)")
                                    .font(.title3).bold()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Divider()

                        // Player 1
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Player 1")
                                    .font(.headline)
                                if currentTurn == .player1 && p1Outcome == .none && !p1Stood {
                                    Text("(Your turn)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(p1.cards) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text("\(p1.value)")
                                    .font(.title3).bold()
                            }
                            if p1Outcome != .none {
                                Text(p1Outcome.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(color(for: p1Outcome))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Player 2
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Player 2")
                                    .font(.headline)
                                if currentTurn == .player2 && p2Outcome == .none && !p2Stood {
                                    Text("(Your turn)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(p2.cards) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text("\(p2.value)")
                                    .font(.title3).bold()
                            }
                            if p2Outcome != .none {
                                Text(p2Outcome.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(color(for: p2Outcome))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Status
                        Text(pvpStatusText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)

                        // Controls
                        HStack(spacing: 16) {
                            Button("Hit", action: pvpHit)
                                .buttonStyle(.borderedProminent)
                                .disabled(!pvpCanAct)
                            Button("Stand", action: pvpStand)
                                .buttonStyle(.bordered)
                                .disabled(!pvpCanAct)
                            Button("New Round", action: pvpNewRound)
                                .buttonStyle(.bordered)
                        }
                        .padding(.top, 4)

                        Spacer()
                    }
                } else if mode == .headToHead {
                    // Head-to-Head Local mode
                    VStack(spacing: 24) {
                        // Dealer section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Dealer")
                                    .font(.headline)
                                if h2hTurn == .dealer && h2hOutcome == .none && !h2hDealerStood {
                                    Text("(Your turn)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            HStack(spacing: 8) {
                                if h2hDealer.cards.indices.contains(0) {
                                    CardView(card: h2hDealer.cards[0])
                                }
                                if h2hShouldHideDealerHoleCard {
                                    HiddenCardView()
                                } else if h2hDealer.cards.indices.contains(1) {
                                    CardView(card: h2hDealer.cards[1])
                                }
                                if h2hDealer.cards.count > 2 {
                                    ForEach(h2hDealer.cards.dropFirst(2)) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            .accessibilityLabel(h2hDealerAccessibilityLabel)

                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text(h2hShouldHideDealerHoleCard ? "?" : "\(h2hDealer.value)")
                                    .font(.title3).bold()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Player section
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Player")
                                    .font(.headline)
                                if h2hTurn == .player && h2hOutcome == .none && !h2hPlayerStood {
                                    Text("(Your turn)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(h2hPlayer.cards) { card in
                                        CardView(card: card)
                                    }
                                }
                            }
                            HStack {
                                Text("Total:")
                                    .foregroundStyle(.secondary)
                                Text("\(h2hPlayer.value)")
                                    .font(.title3).bold()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Status
                        Text(h2hStatusText)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(color(for: h2hOutcome))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)

                        // Controls
                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                Button("Player Hit", action: h2hPlayerHit)
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!h2hPlayerCanAct)
                                Button("Player Stand", action: h2hPlayerStand)
                                    .buttonStyle(.bordered)
                                    .disabled(!h2hPlayerCanAct)
                            }
                            HStack(spacing: 16) {
                                Button("Dealer Hit", action: h2hDealerHit)
                                    .buttonStyle(.borderedProminent)
                                    .disabled(!h2hDealerCanAct)
                                Button("Dealer Stand", action: h2hDealerStand)
                                    .buttonStyle(.bordered)
                                    .disabled(!h2hDealerCanAct)
                            }
                            Button("New Round", action: h2hNewRound)
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                        }

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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Blackjack").font(.headline)
                    // OR your segmented control if you keep it there
                }
            }            .onAppear(perform: newRound)
            .onChange(of: mode) { newMode in
                switch newMode {
                case .blackjack:
                    newRound()
                case .pvp:
                    pvpNewRound()
                case .headToHead:
                    h2hNewRound()
                case .counting:
                    resetCounting()
                }
            }
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
    
    private var dealerMustPush: Bool {
        // Dealer must push means dealer total < 17
        Blackjack.dealerShouldDraw(dealer.cards)
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
        case .dealerMustPush: return Outcome.dealerMustPush.rawValue
        }
    }
    
    private var statusColor: Color {
        switch outcome {
        case .none: return .primary
        case .playerWins, .dealerBust: return .green
        case .dealerWins, .playerBust: return .red
        case .push: return .orange
        case .dealerMustPush:
            return .gray
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
    
    private func color(for outcome: Outcome) -> Color {
        switch outcome {
        case .none: return .primary
        case .playerWins, .dealerBust: return .green
        case .dealerWins, .playerBust: return .red
        case .push: return .orange
        case .dealerMustPush:
            return .gray
        }
    }

    private var pvpShouldHideDealerHoleCard: Bool {
        !( (p1Stood || p1Outcome != .none) && (p2Stood || p2Outcome != .none) )
    }

    private var pvpCanAct: Bool {
        switch currentTurn {
        case .player1:
            return p1Outcome == .none && !p1Stood
        case .player2:
            return p2Outcome == .none && !p2Stood
        }
    }

    private var pvpDealerMustPush: Bool {
        Blackjack.dealerShouldDraw(pvpDealer.cards)
    }

    private var pvpStatusText: String {
        let bothFinished = (p1Stood || p1Outcome != .none) && (p2Stood || p2Outcome != .none)
        if bothFinished {
            return "Round complete"
        }
        switch currentTurn {
        case .player1:
            return p1.isBlackjack && !p1Stood ? "Player 1: Blackjack! Stand or Hit?" : "Player 1's move"
        case .player2:
            return p2.isBlackjack && !p2Stood ? "Player 2: Blackjack! Stand or Hit?" : "Player 2's move"
        }
    }

    private var pvpDealerAccessibilityLabel: String {
        if pvpShouldHideDealerHoleCard {
            let first = pvpDealer.cards.first.map { $0.description } ?? ""
            return "Dealer showing \(first). Hidden hole card."
        } else {
            return "Dealer hand: \(pvpDealer.description). Total \(pvpDealer.value)."
        }
    }
    
    // Head-to-head derived UI
    private var h2hShouldHideDealerHoleCard: Bool {
        h2hOutcome == .none && h2hTurn == .player && !h2hDealerStood
    }

    private var h2hPlayerCanAct: Bool {
        h2hOutcome == .none && h2hTurn == .player && !h2hPlayerStood
    }

    private var h2hDealerCanAct: Bool {
        h2hOutcome == .none && h2hTurn == .dealer && !h2hDealerStood
    }
    
    private var h2hDealerMustPush: Bool {
        Blackjack.dealerShouldDraw(h2hDealer.cards)
    }

    private var h2hStatusText: String {
        switch h2hOutcome {
        case .none:
            if h2hTurn == .player {
                return h2hPlayer.isBlackjack && !h2hPlayerStood ? "Player: Blackjack! Stand or Hit?" : "Player's move"
            } else {
                return h2hDealer.isBlackjack && !h2hDealerStood ? "Dealer: Blackjack! Stand or Hit?" : "Dealer's move"
            }
        default:
            return h2hOutcome.rawValue
        }
    }

    private var h2hDealerAccessibilityLabel: String {
        if h2hShouldHideDealerHoleCard {
            let first = h2hDealer.cards.first.map { $0.description } ?? ""
            return "Dealer showing \(first). Hidden hole card."
        } else {
            return "Dealer hand: \(h2hDealer.description). Total \(h2hDealer.value)."
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
        // Do not resolve while dealer must push (dealer total < 17)
        if dealerMustPush {
            dealerPlay()
            settle()
            return
        }
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

    // MARK: - PvP Actions

    private func pvpNewRound() {
        pvpDeck = Deck()
        p1 = Hand()
        p2 = Hand()
        pvpDealer = Hand()
        p1Outcome = .none
        p2Outcome = .none
        p1Stood = false
        p2Stood = false
        currentTurn = .player1

        // Initial deal: P1, P2, Dealer, P1, P2, Dealer
        if let c1 = pvpDeck.deal() { p1.add(c1) }
        if let c2 = pvpDeck.deal() { p2.add(c2) }
        if let d1 = pvpDeck.deal() { pvpDealer.add(d1) }
        if let c3 = pvpDeck.deal() { p1.add(c3) }
        if let c4 = pvpDeck.deal() { p2.add(c4) }
        if let d2 = pvpDeck.deal() { pvpDealer.add(d2) }
    }

    private func pvpHit() {
        guard pvpCanAct, let card = pvpDeck.deal() else { return }
        switch currentTurn {
        case .player1:
            p1.add(card)
            if p1.isBusted {
                p1Outcome = .playerBust
                p1Stood = true
                pvpAdvanceTurnOrFinish()
            }
        case .player2:
            p2.add(card)
            if p2.isBusted {
                p2Outcome = .playerBust
                p2Stood = true
                pvpAdvanceTurnOrFinish()
            }
        }
    }

    private func pvpStand() {
        guard pvpCanAct else { return }
        switch currentTurn {
        case .player1:
            p1Stood = true
        case .player2:
            p2Stood = true
        }
        pvpAdvanceTurnOrFinish()
    }

    private func pvpAdvanceTurnOrFinish() {
        switch currentTurn {
        case .player1:
            currentTurn = .player2
            if p2Stood || p2Outcome != .none {
                pvpFinishRoundIfNeeded()
            }
        case .player2:
            pvpFinishRoundIfNeeded()
        }
    }

    private func pvpFinishRoundIfNeeded() {
        // Do not finish while dealer must push (dealer total < 17)
        if dealerMustPush {
            dealerPlay()
            settle()
            return
        }
        let p1Done = p1Stood || p1Outcome != .none
        let p2Done = p2Stood || p2Outcome != .none
        guard p1Done && p2Done else { return }
        if !(p1Outcome == .playerBust && p2Outcome == .playerBust) {
            pvpDealerPlay()
        }
        pvpSettle()
    }

    private func pvpDealerPlay() {
        while Blackjack.dealerShouldDraw(pvpDealer.cards), let card = pvpDeck.deal() {
            pvpDealer.add(card)
        }
    }

    private func pvpSettle() {
        if p1Outcome == .none {
            p1Outcome = Blackjack.resolveOutcome(player: p1.cards, dealer: pvpDealer.cards)
        }
        if p2Outcome == .none {
            p2Outcome = Blackjack.resolveOutcome(player: p2.cards, dealer: pvpDealer.cards)
        }
    }

    // MARK: - Head-to-Head Actions

    private func h2hNewRound() {
        h2hDeck = Deck()
        h2hPlayer = Hand()
        h2hDealer = Hand()
        h2hOutcome = .none
        h2hPlayerStood = false
        h2hDealerStood = false
        h2hTurn = .player

        // Initial deal: Player, Dealer, Player, Dealer
        if let p1 = h2hDeck.deal() { h2hPlayer.add(p1) }
        if let d1 = h2hDeck.deal() { h2hDealer.add(d1) }
        if let p2 = h2hDeck.deal() { h2hPlayer.add(p2) }
        if let d2 = h2hDeck.deal() { h2hDealer.add(d2) }
    }

    private func h2hPlayerHit() {
        guard h2hPlayerCanAct, let card = h2hDeck.deal() else { return }
        h2hPlayer.add(card)
        if h2hPlayer.isBusted {
            h2hOutcome = .playerBust
        }
    }

    private func h2hPlayerStand() {
        guard h2hOutcome == .none && !h2hPlayerStood else { return }
        h2hPlayerStood = true
        h2hTurn = .dealer
    }

    private func h2hDealerHit() {
        guard h2hDealerCanAct, let card = h2hDeck.deal() else { return }
        h2hDealer.add(card)
        if h2hDealer.isBusted {
            h2hOutcome = .dealerBust
        }
    }

    private func h2hDealerStand() {
        guard h2hOutcome == .none && !h2hDealerStood else { return }
        h2hDealerStood = true
        h2hSettleIfNeeded()
    }

    private func h2hSettleIfNeeded() {
        guard h2hOutcome == .none else { return }
        // Do not settle while dealer must push (dealer total < 17)
        if dealerMustPush {
            dealerPlay()
            settle()
            return
        }
        if h2hPlayerStood && h2hDealerStood {
            h2hOutcome = Blackjack.resolveOutcome(player: h2hPlayer.cards, dealer: h2hDealer.cards)
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

