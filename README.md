# @Random

A property wrapper that assigns a stable random value to a member variable, persisting across multiple `body` invocations.

Use this to introduce variation in animations without relying on `@State`.

For example

```swift
struct RandomOffsetTransition: Transition {
    @Random(distance: 20) var offset: CGSize

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.offset(offset)
    }
}
```

will create a transition that animates the view from a random offset.

## Fixed Seeds

By default, different instances of the same `View` or `ViewModifier` generate unique `@Random` values. To ensure consistency, you can provide a custom seed via the property wrapper’s `projectedValue`.

For example, assigning a model’s `hashValue` to `$greeting` ensures stability when the view gets recreated, say in a `LazyVStack`.

```swift
struct Cell: View {
    @Random(in: "Hello", "Bonjour", "Willkommen") var greeting

    var model: Model

    init(model: Model) {
        self.model = model
        $greeting = model.hashValue
    }

    var body: some View {
      // The same `model` will get the same `greeting`, every time.
      Text("\(greeting), \(model.name)!")
    }
}
```

This way, each `Cell` instance with the same model will always produce the same greeting.

> [!IMPORTANT]  
> Some Swift types, like `String`, generate different `hashValues` across app launches. For values that persist _across_ launches, use a stable identifier, such as a user ID.
