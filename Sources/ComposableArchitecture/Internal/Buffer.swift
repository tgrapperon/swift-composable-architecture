struct Buffer<Element> {
  final private class Node {
    let element: Element
    var next: Node?

    init(_ element: Element) {
      self.element = element
      self.next = nil
    }
  }

  private var head: Node?
  private var tail: Node?

  init() {}

  var isEmpty: Bool { head == nil }

  mutating func append(_ element: Element) {
    if isEmpty {
      head = Node(element)
      tail = head
    } else {
      tail!.next = Node(element)
      tail = tail!.next
    }
  }
  
  mutating func popFirst() -> Element? {
    isEmpty ? nil : removeFirst()
  }

  mutating func removeFirst() -> Element {
    assert(!isEmpty, "Can't remove first element from an empty buffer")
    let element = head!.element
    head = head!.next
    if isEmpty { tail = nil }
    return element
  }
}
