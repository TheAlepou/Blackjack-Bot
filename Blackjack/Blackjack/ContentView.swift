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
    
    var body: some View {
        NavigationStack {
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
            .padding()
            .navigationTitle("Blackjack")
            .onAppear(perform: newRound)
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

#Preview {
    ContentView()
}
