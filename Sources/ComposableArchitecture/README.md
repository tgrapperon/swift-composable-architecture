# Reducer Modifiers

Here are a few notes about the experiment with reducer modifiers. The objective was to define modifiers as "recipes", independent from the base reducer they modify.

TL;DR: I think it goes nowhere given the way things are currently arranged in TCA. I'll elaborate below on this. The proposed solution is probably slower (at least implemented like I did, as there is a sneaky erasure in `_ReducerModifierContent<Modifier>.init`).

As an aside, I've improved (I think) `ReducerBuilder`: Accumulating `EmptyReducers` should be noop, and I've expanded a few `buildBlock`s to support `ReducerModifier` body's construction. I've initially tried to move the `<State, Action>` generics from the Builder to each function. If TCA itself builds, SwiftUI case studies aren't, so I put it back in `ReducerBuilder<State, Action>`. Please note that case studies are not building with the current state of the repo but I'm unable to track the issue for now. TCA builds and gives an idea of the API.

I've also removed the `= Self` in `ReducerProtocol`'s `Body` declaration, as I'm not understanding it. It doesn't seem to make a difference.

A `ReducerModifier` protocol is introduced. You build its `body` using a `content: Content` reducer provided as an argument. It doesn't use some `reduce(state: inout State, action: Action, content: Content)` because it would turn modifiers almost equivalent to simple wrappers (like it's the case in `proto-2`) with erased `Upstream`.

The body is built using a `ReducerBuilder`. I've added a few helpers `Reducer`s: an `_Either` reducer used in the builder for conditional branching (not used yet), and some `IfLet` reducer that evaluates a closure `(State, Action) -> T?` and execute one reducer if the result is non-nil, or another if it is nil. This reducer is used in `BindingModifier` which is right now the only reducer I've refactored. I'm proposing two usages of `IfLet` for `BindingModifier`: one with an `else` branch, similar to the "classical" "guard" implementation, and one that leverages `ReducerBuilder` to execute the perform the binding iff the action matches, and then runs the original reducer unconditionally. I find this last implementation to be the nicest outcome of this experiment.

I've also added a NeverReducer<State, Action> that plays the role of `Never` for SwiftUI `body`'s, but with generics that `Never` can't host. It's not used like in SwiftUI though, and I'm only using it in `_ReducerModifierContent<Modifier>` because this reducer is never installed itself.

Fun "discovery" about `ModifiedContent` in SwiftUI: The first generic is not always a `View` and conformance of this type to `View` is conditional to this first generic being a `View`. This value can also be a `ViewModifier`, for which case the `ModifiedContent` becomes a `ViewModifier` itself. The entry point for `View` is the `View`'s extension `.modifier()`, whereas the entry point for `ViewModifier` is their `.concat()` extension. `View` and `ViewModifier` which are different types are playing symmetrical roles in `ModifiedContent`. I've missed this, as we rarely concatenate manually modifiers (because we generally install them as extensions of `View`), but I guess this is used internally.


There are issues though:
- SwiftUI Case Studies doesn't build;
- the `concat` variant of `ReducerModifier` doesn't compile.;
- there is some level of erasure when forming the modifier's content we send to `Body`.

The following is not backed by a reference, only my guesses based on experience, official statements, and what we can grasp of the implementation:
SwiftUI is a declarative framework. The `View` we write is a description of what we want, but they don't realize any work (or at least not UI work). SwiftUI parses their bodies, and when it encounters a `Never`, it delegates work to an internal and effective implementation of the "view". In other words, you describe the view tree with a value-based API (the `View`s), and a "graph builder" generates a tree of reference types (UI/NSView/Controller or CALayers, or else), along with a graph of dependencies between them (at least, that's how I understand it). When some value is invalidated in the `View` tree, SwiftUI computes the orbit in the graph of dependencies and updates the corresponding reference types.

This is a huge difference with TCA (or `swift-parsing`), where the value-type tree (the reducers/parsers) is directly (thus injectively) performing the work. There is no processing, no simplification. For this reason, I suspect that we will not be able to extract some performance gains from `ReducerModifier`s (to the contrary).

I wonder if some setup similar to SwiftUI is possible. It seems very far, but it would be interesting: Having a description of Reducers that is dynamically evolving with the active `Store`s and their `State`. But for now, it is science fiction.

So if I find the API quite appealing, I'm not sure how and if this experiment should go further. If some way to bypass the erasure to `Content` is possible when calling `ReducerModifier`'s body, and if `CaseStudies` failure to build is resolved, there are maybe providing a nice separation of concerns between reducers.
