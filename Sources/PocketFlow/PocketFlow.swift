import Foundation

// MARK: - Action Alias

public typealias Action = String

// MARK: - Protocol

public protocol FlowNode: AnyObject {
    associatedtype Shared
    associatedtype Prep: Sendable
    associatedtype Exec: Sendable
    associatedtype Act: Hashable & Sendable = Action

    func prep(shared: inout Shared) async throws -> Prep
    func exec(prep: Prep) async throws -> Exec
    func post(shared: inout Shared, prep: Prep, exec: Exec) async throws -> Act?
}

extension FlowNode {
    public func _run(shared: inout Shared) async throws -> Act? {
        let p = try await prep(shared: &shared)
        let e = try await exec(prep: p)
        return try await post(shared: &shared, prep: p, exec: e)
    }
}

// MARK: - Base Node

open class BaseNode<PrepRes: Sendable, ExecRes: Sendable>: FlowNode {
    public typealias Shared = [String: Sendable]
    public typealias Prep = PrepRes
    public typealias Exec = ExecRes
    public typealias Act = Action

    public var maxRetries: Int = 1
    public var waitInSeconds: UInt64 = 0
    public var successors: [Action: any AnyNode] = [:]
    public var params: [String: Sendable] = [:]

    public init() {}

    open func prep(shared: inout Shared) async throws -> PrepRes {
        fatalError("Must override prep")
    }

    open func exec(prep: PrepRes) async throws -> ExecRes {
        fatalError("Must override exec")
    }

    open func post(shared: inout Shared, prep: PrepRes, exec: ExecRes) async throws -> Action? {
        fatalError("Must override post")
    }

    open func execFallback(prep: PrepRes, error: any Error) async throws -> ExecRes {
        throw error
    }

    public func _exec(prep: PrepRes) async throws -> ExecRes {
        for i in 0..<maxRetries {
            do {
                return try await exec(prep: prep)
            } catch {
                if i == (maxRetries - 1) {
                    return try await execFallback(prep: prep, error: error)
                }
                if waitInSeconds > 0 {
                    try await Task.sleep(nanoseconds: UInt64(waitInSeconds) * 1_000_000_000)
                }
            }
        }
        throw NSError(domain: "RetryFailed", code: -1)
    }

    public func setNext(_ action: Action = "default", _ node: some AnyNode) {
        successors[action] = node
    }
}

// MARK: - Type Erasure

public protocol AnyNode: AnyObject {
    var params: [String: Sendable] { get set }
    var successors: [Action: any AnyNode] { get set }
    func _run(shared: inout [String: Sendable]) async throws -> Action?
}

extension BaseNode: AnyNode {
    public func _run(shared: inout [String: Sendable]) async throws -> Action? {
        let prep = try await prep(shared: &shared)
        let exec = try await _exec(prep: prep)
        return try await post(shared: &shared, prep: prep, exec: exec)
    }
}

// MARK: - Conditional Transition

public struct _ConditionalTransition<P: Sendable, E: Sendable> {
    let node: BaseNode<P, E>
    let action: Action

    public init(node: BaseNode<P, E>, action: Action) {
        self.node = node
        self.action = action
    }
}

// MARK: - Flow

public final class Flow {
    public var startNode: any AnyNode

    public init(start: any AnyNode) {
        self.startNode = start
    }

    public func run(shared: inout [String: Sendable]) async throws -> Action? {
        var current: AnyNode? = startNode
        var lastAction: Action? = nil

        while let node = current {
            lastAction = try await node._run(shared: &shared)
            current = node.successors[lastAction ?? "default"]
        }

        return lastAction
    }
}

// MARK: - Operators

precedencegroup FlowConnectPrecedence {
    associativity: left
}

precedencegroup FlowTransitionPrecedence {
    associativity: left
    higherThan: FlowConnectPrecedence
}

infix operator >>> : FlowConnectPrecedence
infix operator <> : FlowTransitionPrecedence

@discardableResult
public func >>> <P: Sendable, E: Sendable, N: AnyNode>(
    lhs: BaseNode<P, E>,
    rhs: N
) -> N {
    lhs.setNext("default", rhs)
    return rhs
}

@discardableResult
public func >>> <P: Sendable, E: Sendable, N: AnyNode>(
    lhs: _ConditionalTransition<P, E>,
    rhs: N
) -> N {
    lhs.node.setNext(lhs.action, rhs)
    return rhs
}

public func <> <P: Sendable, E: Sendable>(lhs: BaseNode<P, E>, action: Action)
    -> _ConditionalTransition<P, E>
{
    _ConditionalTransition(node: lhs, action: action)
}
