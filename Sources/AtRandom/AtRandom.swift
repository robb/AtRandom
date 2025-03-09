import SwiftUI

/// A property wrapper type that assigns a random value that is stable across
/// invocations of ``View.body``.
@propertyWrapper
public struct Random<Value>: DynamicProperty {
    /// A wrapper of the underlying random number generator that can override
    /// the seed value used.
    public struct Wrapper {
        /// A value used by the property wrapper to generate the value.
        ///
        /// Assign a value derived from your model object to this property to
        /// produce repetable random values across view instances.
        ///
        /// ```swift
        /// struct Cell: View {
        ///     @Random(in: "Hello", "Bonjour", "Willkommen") var greeting
        ///
        ///     var model: Model
        ///
        ///     init(model: Model) {
        ///         self.model = model
        ///         $greeting.seed = model.hashValue
        ///     }
        ///
        ///     var body: some View {
        ///       // The same `model` will get the same `greeting`, every time.
        ///       Text("\(greeting), \(model.name)!")
        ///     }
        /// }
        /// ```
        public var seed: Int
    }

    enum Source {
        case fixed(Int)
        case namespace
    }

    @Namespace var namespace

    var generator: (inout RandomNumberGenerator) -> Value

    var source: Source = .namespace

    /// Creates a property that generates a random value.
    ///
    /// - Parameter generator: A function that generates random value with a
    ///                        random number generator.
    public init(generator: @escaping (inout RandomNumberGenerator) -> Value) {
        self.generator = generator
    }

    /// A random value. When called from a `View`'s `body` or a `ViewModifier`'s `body(content:)` method, the same value is produced,
    /// consistently.
    public var wrappedValue: Value {
        var rng: any RandomNumberGenerator

        switch source {
        case .fixed(let seed): seed
            let seq = UInt64(bitPattern: Int64(seed))
            rng = PCGRandomNumberGenerator(seed: 0x2288, seq: seq)
        case .namespace: namespace.hashValue
            let seed = UInt64(bitPattern: Int64(namespace.hashValue))

            rng = PCGRandomNumberGenerator(seed)
        }

        return generator(&rng)
    }

    /// A value used by the property wrapper to generate the value.
    ///
    /// Assign a value derived from your model object to this property to
    /// produce repetable random values across view instances.
    ///
    /// ```swift
    /// struct Cell: View {
    ///     @Random(in: "Hello", "Bonjour", "Willkommen") var greeting
    ///
    ///     var model: Model
    ///
    ///     init(model: Model) {
    ///         self.model = model
    ///         $greeting.seed = model.hashValue
    ///     }
    ///
    ///     var body: some View {
    ///       // The same `model` will get the same `greeting`, every time.
    ///       Text("\(greeting), \(model.name)!")
    ///     }
    /// }
    /// ```
    public var projectedValue: Wrapper {
        get {
            switch source {
            case .fixed(let int):
                    .init(seed: int)
            case .namespace:
                    .init(seed: namespace.hashValue)
            }
        }
        set {
            source = .fixed(newValue.seed)
        }
    }
}

public extension Random where Value: VectorArithmetic {
    /// A property that generates a random value by interpolating between two
    /// values.
    ///
    /// The resulting value will be somewhere between `from` and `through`.
    ///
    /// - Parameters:
    ///   - from: The first value to interpolate between.
    ///   - through: The second value to interpolate between.
    public init(from: Value, through: Value) {
        self.init { rng in
            var copy = from
            copy.interpolate(
                towards: through,
                amount: .random(in: 0 ... 1, using: &rng)
            )

            return copy
        }
    }
}

public extension Random where Value: Animatable {
    /// A property that generates a random value by interpolating between two
    /// values.
    ///
    /// The resulting value will be somewhere between `from` and `through`, as
    /// if a SwiftUI animation between the two values had been stopped at a
    /// random point.
    ///
    /// - Parameters:
    ///   - from: The first value to interpolate between.
    ///   - through: The second value to interpolate between.
    public init(from: Value, through: Value) {
        self.init { rng in
            var copy = from
            copy.animatableData.interpolate(
                towards: through.animatableData,
                amount: .random(in: 0 ... 1, using: &rng)
            )

            return copy
        }
    }
}

public extension Random where Value: Comparable & Strideable, Value.Stride: SignedInteger {
    /// A property that generates a random value by choosing randomly from a
    /// range.
    ///
    /// - Parameter range: The range from which a value is selected.
    public init(in range: ClosedRange<Value>) {
        self.init { rng in
            range.randomElement(using: &rng) ?? range.lowerBound
        }
    }
}

public extension Random {
    /// A property that generates a random value by choosing randomly from a
    /// choice of options..
    ///
    /// - Parameters:
    ///   - first: The first possible values.
    ///   - remainder: All remaining possible values.
    public init(in first: Value, _ remainder: Value...) {
        var values = remainder
        values.append(first)

        self.init { rng in
            values.randomElement(using: &rng)!
        }
    }

    /// A property that generates a value by choosing it randomly from a
    /// collection of options.
    ///
    /// - Parameters:
    /// - Parameter values: The collection to chose from. The collection must
    ///                     not be empty.
    public init(in values: any Collection<Value>) {
        precondition(!values.isEmpty)

        self.init { rng in
            values.randomElement(using: &rng)!
        }
    }
}

public extension Random where Value == CGPoint {
    /// A property that generates a random point, a fixed distance away from
    /// another point.
    ///
    /// - Parameters:
    ///   - r: The distance between the generated point and the center.
    ///   - center: The center point around which a new point is generated.
    public init(distance r: CGFloat, from center: CGPoint) {
        self.init(distance: r ... r, from: center)
    }


    /// A property that generates a random point, a variable distance away from
    /// another point.
    ///
    /// - Parameters:
    ///   - d: The range of distances from which the generated point is
    ///        chosen, relative to the center..
    ///   - center: The center point around which a new point is generated.
    public init(distance d: ClosedRange<CGFloat>, from center: CGPoint) {
        self.init { rng in
            let theta = CGFloat.random(in: 0 ... 2 * .pi, using: &rng)
            let r = d.lowerBound + (d.upperBound - d.lowerBound) * sqrt(.random(in: 0.0 ... 1.0, using: &rng))

            var point = center
            point.x += r * cos(theta)
            point.y += r * sin(theta)

            return point
        }
    }

    /// A property that generates a point selected randomly from within a
    /// rectangle.
    ///
    /// - Parameter rect: The rectangle from which the generated point is
    ///                   chosen.
    public init(in rect: CGRect) {
        self.init { rng in
            CGPoint(
                x: .random(in: rect.minX ... rect.maxX, using: &rng),
                y: .random(in: rect.minY ... rect.maxY, using: &rng)
            )
        }
    }
}

public extension Random where Value == CGSize {
    /// A property that generates a random offset with a fixed length.
    ///
    /// This can be used with SwiftUI's ``View/offset(_:).`` modifier.
    ///
    /// ```swift
    /// struct RandomOffset: ViewModifier {
    ///     @Random(distance: 10) var offset: CGSize
    ///
    ///     func body(content: Content) -> some View {
    ///         content.offset(offset)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - r: The distance between of the generated offset.
    public init(distance r: CGFloat) {
        self.init(distance: r ... r)
    }

    /// A property that generates a random offset with a variable length.
    /// 
    /// This can be used with SwiftUI's ``View/offset(_:).`` modifier.
    /// 
    /// ```swift
    /// struct RandomOffset: ViewModifier {
    ///     @Random(distance: 5 ..< 10) var offset: CGSize
    /// 
    ///     func body(content: Content) -> some View {
    ///         content.offset(offset)
    ///     }
    /// }
    /// ```
    /// 
    /// - Parameters:
    /// - Parameter d: The range from the distance is chosen.
    public init(distance d: ClosedRange<CGFloat>) {
        self.init { rng in
            let theta = CGFloat.random(in: 0 ... 2 * .pi, using: &rng)
            let r = d.lowerBound + (d.upperBound - d.lowerBound) * sqrt(.random(in: 0.0 ... 1.0, using: &rng))

            var size = CGSize()
            size.width += r * cos(theta)
            size.height += r * sin(theta)

            return size
        }
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public extension Random where Value == Color {
    /// A property that generates a random colors by interpolating between two
    /// colors.
    ///
    /// - Parameters:
    ///   - a: The first color.
    ///   - b: The second color.
    ///   - colorSpace: The color space in which to interpolate, default is
    ///                 `.perceptual`.
    public init(from a: Color, through b: Color, in colorSpace: Gradient.ColorSpace = .perceptual) {
        self.generator = { rng in
            a.mix(with: b, by: .random(in: 0 ... 1, using: &rng), in: colorSpace)
        }
    }
}

struct PCGRandomNumberGenerator: RandomNumberGenerator {
    var low: PCGXSHRS32Generator
    var high: PCGXSHRS32Generator

    init(_ seed: UInt64) {
        self.init(seed: seed, seq: 0xda3e39cb94b95bdb)
    }

    init(seed: UInt64, seq: UInt64) {
        self.init(lowSeed: seed, highSeed: seed, seq1: seq, seq2: seq)
    }

    init(lowSeed: UInt64, highSeed: UInt64, seq1: UInt64, seq2: UInt64) {
        let mask: UInt64 = ~0 >> 1;

        var (stream1, stream2) = (seq1, seq2)

        if stream1 & mask == stream2 & mask {
            stream2 = ~stream2
        }

        low = PCGXSHRS32Generator(state: lowSeed, stream: stream1)
        high = PCGXSHRS32Generator(state: highSeed, stream: stream2)
    }

    mutating func next() -> UInt64 {
        UInt64(low.next()) << 32 | UInt64(high.next())
    }
}

struct PCGXSHRS32Generator {
    var state: UInt64

    var stream: UInt64

    init(state: UInt64, stream: UInt64) {
        self.state = 0
        self.stream = (stream << 1) | 1
        step()
        self.state &+= state
        step()
    }

    mutating func next() -> UInt32 {
        let current = state

        step()

        let base = (current ^ (current >> 22))
        let shift = Int(22 + (current >> 61))
        return UInt32(truncatingIfNeeded: base >> shift)
    }

    private mutating func step() {
        state = state &* 6_364_136_223_846_793_005 &+ stream
    }
}
