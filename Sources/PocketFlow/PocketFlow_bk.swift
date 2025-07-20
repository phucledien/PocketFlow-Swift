//public class BaseNode {
//    var params: [String : Sendable] = [:]
//    var successors: [Action: BaseNode] = [:]
//    
//    func _exec(prepRes: Sendable) async throws -> Sendable {
//        return try await self.exec(prepRes: prepRes)
//    }
//    
//    public func prep(shared: [String:Sendable]) async -> Sendable { return "" }
//    public func exec(prepRes: Sendable) async throws -> Sendable { return "" }
//    public func post(shared: [String:Sendable], prepRes: Sendable, excecRes: Sendable) async -> Action? { return nil }
//    
//    private func _run(shared: [String:Sendable]) async throws -> Action? {
//        let p = await self.prep(shared: shared)
//        let e = try await self._exec(prepRes: p)
//        return await self.post(shared: shared, prepRes: p, excecRes: e)
//    }
//    
//    public func run(shared: [String:Sendable]) async throws -> Action? {
//        guard !self.successors.isEmpty else { return nil }
//        return try await self._run(shared: shared)
//    }
//    
//    public func set(params: [String: Sendable]) -> Self {
//        self.params = params
//        return self
//    }
//    
//    public func next<T: BaseNode>(node: T) -> T {
//        _ = self.on(action: "default", node: node)
//        return node
//    }
//    
//    public func on(action: Action, node: BaseNode) -> Self {
//        self.successors[action] = node
//        return self
//    }
//    
//    public func getNextNode(action: Action = "default") -> BaseNode? {
//        return self.successors[action]
//    }
//}
//
//public class Node: BaseNode {
//    public let maxRetries: UInt
//    public let wait: TimeInterval
//    
//    public init(maxRetries: UInt = 1, wait: TimeInterval = 0) {
//        self.maxRetries = maxRetries
//        self.wait = wait
//    }
//    
//    public func execFallback(prepRes: Sendable, error: Error) async throws -> Sendable { throw error }
//   
//    public override func _exec(prepRes: Sendable) async throws -> Sendable {
//        for retry in 0..<maxRetries {
//            do {
//                return try await self.exec(prepRes: prepRes)
//            } catch {
//                if retry == self.maxRetries - 1 {
//                   return try await self.execFallback(prepRes: prepRes, error: error)
//                }
//                if self.wait > 0 {
//                    try await Task.sleep(nanoseconds: UInt64(wait) * 1_000_000_000)
//                }
//            }
//        }
//        fatalError(#function + " should never be reached")
//    }
//}
//
//public class BatchNode: Node, @unchecked Sendable {
//    public func _exec(items: [Sendable]) async throws -> [Sendable] {
//        if items.isEmpty { return [] }
//        var results: [Sendable] = []
//        for item in items {
//            let result = try await self._exec(prepRes: item)
//            results.append(result)
//        }
//        return results
//    }
//}
//
//public class ParallelBatchNode: Node, @unchecked Sendable {
//    public func _exec(items: [Sendable]) async throws -> [Sendable] {
//        if items.isEmpty { return [] }
//        return try await withThrowingTaskGroup { group in
//            for item in items {
//                group.addTask {
//                    try await self._exec(prepRes: item)
//                }
//            }
//            
//            var results = [Sendable]()
//            for try await result in group {
//                results.append(result)
//            }
//            return results
//        }
//    }
//}



//class Flow<S = unknown, P extends NonIterableObject = NonIterableObject> extends BaseNode<S, P> {
//  start: BaseNode;
//  constructor(start: BaseNode) { super(); this.start = start; }
//  protected async _orchestrate(shared: S, params?: P): Promise<void> {
//    let current: BaseNode | undefined = this.start.clone();
//    const p = params || this._params;
//    while (current) {
//      current.setParams(p); const action = await current._run(shared);
//      current = current.getNextNode(action); current = current?.clone();
//    }
//  }
//  async _run(shared: S): Promise<Action | undefined> {
//    const pr = await this.prep(shared); await this._orchestrate(shared);
//    return await this.post(shared, pr, undefined);
//  }
//  async exec(prepRes: unknown): Promise<unknown> { throw new Error("Flow can't exec."); }
//}
//class BatchFlow<S = unknown, P extends NonIterableObject = NonIterableObject, NP extends NonIterableObject[] = NonIterableObject[]> extends Flow<S, P> {
//  async _run(shared: S): Promise<Action | undefined> {
//    const batchParams = await this.prep(shared);
//    for (const bp of batchParams) {
//      const mergedParams = { ...this._params, ...bp };
//      await this._orchestrate(shared, mergedParams);
//    }
//    return await this.post(shared, batchParams, undefined);
//  }
//  async prep(shared: S): Promise<NP> { const empty: readonly NonIterableObject[] = []; return empty as NP; }
//}
//class ParallelBatchFlow<S = unknown, P extends NonIterableObject = NonIterableObject, NP extends NonIterableObject[] = NonIterableObject[]> extends BatchFlow<S, P, NP> {
//  async _run(shared: S): Promise<Action | undefined> {
//    const batchParams = await this.prep(shared);
//    await Promise.all(batchParams.map(bp => {
//      const mergedParams = { ...this._params, ...bp };
//      return this._orchestrate(shared, mergedParams);
//    }));
//    return await this.post(shared, batchParams, undefined);
//  }
//}


// Init nodes
//let review = Review()
//let revise = Revise()
//let payment = Payment()
//let finish = Finish()
//
// Define flow
//review - "approved" >> payment
//review - "need_revision" >> revise
//review - "rejected" >> finish
//
//revise >> review
//payment >> finish
//
// Init flow
//flow = Flow(start: review)
