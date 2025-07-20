# PocketFlow-Swift

[![Swift](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2013%2B%20%7C%20macOS%2010.15%2B-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Lines of Code](https://img.shields.io/badge/Lines%20of%20Code-~165-brightgreen.svg)](Sources/PocketFlow/PocketFlow.swift)
[![SPM Compatible](https://img.shields.io/badge/SPM-Compatible-success.svg)](Package.swift)

A Swift port of the minimalist LLM workflow framework [PocketFlow](https://github.com/The-Pocket/PocketFlow).

> **Lightweight**: Just ~165 lines. Zero bloat, zero dependencies, zero vendor lock-in.  
> **Expressive**: Everything you love—Agents, Workflows, branching, and looping.  
> **Agentic Coding**: Let AI Agents build Agents—10x productivity boost!

## About

PocketFlow-Swift is a Swift implementation inspired by the original [PocketFlow](https://github.com/The-Pocket/PocketFlow) Python framework. While the original focuses on LLM applications, this Swift port provides a general-purpose workflow orchestration framework that can be used for any asynchronous task coordination.

## Installation

### Swift Package Manager

Add PocketFlow-Swift to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/phucledien/PocketFlow-Swift.git", from: "1.0.0")
]
```

### Manual Installation

Simply copy the `Sources/PocketFlow/PocketFlow.swift` file into your project. It's only ~165 lines!

## Quick Start

### 1. Define Your Nodes

Create custom nodes by inheriting from `BaseNode`:

```swift
import PocketFlow

final class ProcessData: BaseNode<String, [String]> {
    override func prep(shared: inout Shared) async throws -> String {
        // Preparation phase - setup input data
        return "input_data"
    }
    
    override func exec(prep: String) async throws -> [String] {
        // Execution phase - main logic
        return prep.components(separatedBy: "_")
    }
    
    override func post(shared: inout Shared, prep: String, exec: [String]) async throws -> Action? {
        // Post-processing phase - store results and determine next action
        shared["processed_data"] = exec
        return "success"
    }
}
```

### 2. Build Your Workflow

Connect nodes using operators:

```swift
let processData = ProcessData()
let saveResults = SaveResults()
let handleError = HandleError()

// Linear flow: processData -> saveResults
processData >>> saveResults

// Conditional flow: processData -> saveResults (on "success") or handleError (on "error")
processData <> "success" >>> saveResults
processData <> "error" >>> handleError
```

### 3. Execute Your Flow

```swift
let flow = Flow(start: processData)
var shared = [String: Sendable]()
let result = try await flow.run(shared: &shared)
```

## Core Concepts

### BaseNode

The building block of workflows. Every node has three phases:

- **`prep`**: Prepare input data from shared state
- **`exec`**: Execute the main logic (with automatic retry support)
- **`post`**: Process results and determine the next action

### Flow

Orchestrates the execution of connected nodes, maintaining shared state throughout the workflow.

### Operators

- **`>>>`**: Sequential connection (default path)
- **`<>`**: Conditional connection (specific action path)

## Workflow Patterns

### Linear Workflow

```swift
final class StepA: BaseNode<String, String> {
    override func prep(shared: inout Shared) async throws -> String {
        return "input"
    }
    
    override func exec(prep: String) async throws -> String {
        return "processed_\(prep)"
    }
    
    override func post(shared: inout Shared, prep: String, exec: String) async throws -> Action? {
        shared["step_a_result"] = exec
        return "default"
    }
}

final class StepB: BaseNode<String, String> {
    override func prep(shared: inout Shared) async throws -> String {
        return shared["step_a_result"] as? String ?? ""
    }
    
    override func exec(prep: String) async throws -> String {
        return "final_\(prep)"
    }
    
    override func post(shared: inout Shared, prep: String, exec: String) async throws -> Action? {
        shared["final_result"] = exec
        return nil // End of workflow
    }
}

let stepA = StepA()
let stepB = StepB()
stepA >>> stepB

let flow = Flow(start: stepA)
var shared = [String: Sendable]()
_ = try await flow.run(shared: &shared)
```

### Branching Workflow

```swift
final class DecisionNode: BaseNode<String, String> {
    override func exec(prep: String) async throws -> String {
        return prep
    }
    
    override func post(shared: inout Shared, prep: String, exec: String) async throws -> Action? {
        // Return different actions based on logic
        return exec.contains("success") ? "approve" : "reject"
    }
}

let decision = DecisionNode()
let approveNode = ApproveNode()
let rejectNode = RejectNode()

decision <> "approve" >>> approveNode
decision <> "reject" >>> rejectNode
```

### Looping Workflow

```swift
final class LoopNode: BaseNode<Int, Int> {
    override func prep(shared: inout Shared) async throws -> Int {
        return shared["counter"] as? Int ?? 0
    }
    
    override func exec(prep: Int) async throws -> Int {
        return prep + 1
    }
    
    override func post(shared: inout Shared, prep: Int, exec: Int) async throws -> Action? {
        shared["counter"] = exec
        return exec >= 5 ? "done" : "continue"
    }
}

let loop = LoopNode()
let done = DoneNode()

loop <> "continue" >>> loop  // Self-loop
loop <> "done" >>> done
```

## Advanced Features

### Retry Logic

Configure automatic retries and wait periods:

```swift
let unreliableNode = UnreliableNode()
unreliableNode.maxRetries = 3
unreliableNode.waitInSeconds = 1

// Override execFallback for custom error handling
class UnreliableNode: BaseNode<String, String> {
    override func execFallback(prep: String, error: any Error) async throws -> String {
        return "fallback_result"
    }
}
```

### Shared State

Pass data between nodes using the shared dictionary:

```swift
override func post(shared: inout Shared, prep: PrepType, exec: ExecType) async throws -> Action? {
    shared["key"] = "value"
    shared["results"] = computedResults
    return "next_action"
}
```

## Examples

Check out the test files for complete examples:

- **Linear Flow**: Sequential processing with state sharing
- **Branching Flow**: Conditional routing based on node results
- **Looping Flow**: Iterative processing with termination conditions

## Comparison with Original PocketFlow

| Feature | Original PocketFlow (Python) | PocketFlow-Swift |
|---------|-------------------------------|------------------|
| **Purpose** | LLM workflow orchestration | General async workflow orchestration |
| **Lines of Code** | ~100 | ~165 |
| **Dependencies** | Zero | Zero |
| **Type Safety** | Runtime | Compile-time |
| **Concurrency** | asyncio | Swift async/await |
| **Operators** | `>>`, `~>` | `>>>`, `<>` |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Original [PocketFlow](https://github.com/The-Pocket/PocketFlow) by [The Pocket](https://github.com/The-Pocket)
- Inspired by the minimalist philosophy of the original framework
- Built for the Swift ecosystem with modern async/await support

## Related Projects

- [PocketFlow](https://github.com/The-Pocket/PocketFlow) - Original Python implementation
- [PocketFlow TypeScript](https://github.com/The-Pocket/PocketFlow) - TypeScript port
- [PocketFlow Java](https://github.com/The-Pocket/PocketFlow) - Java port
- [PocketFlow C++](https://github.com/The-Pocket/PocketFlow) - C++ port
- [PocketFlow Go](https://github.com/The-Pocket/PocketFlow) - Go port

---

**Happy Flowing! 🚀** 