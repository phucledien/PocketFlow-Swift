import Testing

@testable import PocketFlow

struct FlowTests {
    @Test func testLinearFlow() async throws {
        final class A: BaseNode<String, String> {
            override func prep(shared: inout BaseNode<String, String>.Shared) async throws -> String
            {
                return "A_PREP_RESULT"
            }
            
            override func exec(prep: String) async throws -> String {
                return "A_EXEC_RESULT"
            }
            
            override func post(shared: inout Shared, prep: String, exec: String) async throws
            -> Action?
            {
                shared["a_exec_result"] = exec
                return "default"
            }
        }
        
        final class B: BaseNode<String, String> {
            override func prep(shared: inout BaseNode<String, String>.Shared) async throws -> String
            {
                return "B_PREP_RESULT"
            }
            
            override func exec(prep: String) async throws -> String {
                return "B_EXEC_RESULT"
            }
            
            override func post(shared: inout Shared, prep: String, exec: String) async throws
            -> Action?
            {
                shared["b_exec_result"] = exec
                return "default"
            }
        }
        
        let a = A()
        let b = B()
        a >>> b
        
        let flow = Flow(start: a)
        var shared = [String: Sendable]()
        _ = try await flow.run(shared: &shared)
        
        guard let aExecResult = shared["a_exec_result"] as? String else {
            Issue.record("shared[\"a_exec_result\"] not found")
            return
        }
        #expect(aExecResult == "A_EXEC_RESULT")
        
        guard let bExecResult = shared["b_exec_result"] as? String else {
            Issue.record("shared[\"b_exec_result\"] not found")
            return
        }
        #expect(bExecResult == "B_EXEC_RESULT")
    }
    
    @Test func testBranching() async throws {
        final class Review: BaseNode<String, String> {
            override func prep(shared: inout BaseNode<String, String>.Shared) async throws -> String
            {
                return "REVIEW_PREP_RESULT"
            }
            
            override func exec(prep: String) async throws -> String {
                return "REVIEW_EXEC_RESULT"
            }
            
            override func post(shared: inout Shared, prep: String, exec: String) async throws
            -> Action?
            {
                shared["review_exec_result"] = exec
                return "approve"
            }
        }
        
        final class Publish: BaseNode<String, String> {
            override func prep(shared: inout BaseNode<String, String>.Shared) async throws -> String
            {
                return "PUBLISH_PREP_RESULT"
            }
            
            override func exec(prep: String) async throws -> String {
                return "PUBLISH_EXEC_RESULT"
            }
            
            override func post(
                shared: inout BaseNode<String, String>.Shared, prep: String, exec: String
            ) async throws -> Action? {
                shared["publish_exec_result"] = exec
                return nil
            }
        }
        
        final class Draft: BaseNode<String, String> {
            override func prep(shared: inout BaseNode<String, String>.Shared) async throws -> String
            {
                return "DRAFT_PREP_RESULT"
            }
            
            override func exec(prep: String) async throws -> String {
                return "drafted"
            }
            
            override func post(
                shared: inout BaseNode<String, String>.Shared, prep: String, exec: String
            ) async throws -> Action? {
                shared["DRAFT_EXEC_RESULT"] = exec
                return nil
            }
        }
        
        let review = Review()
        let publish = Publish()
        let draft = Draft()
        
        review <> "approve" >>> publish
        review <> "revise" >>> draft
        
        let flow = Flow(start: review)
        var shared = [String: Sendable]()
        _ = try await flow.run(shared: &shared)
        
        guard let reviewExecResult = shared["review_exec_result"] as? String else {
            Issue.record("shared[\"a_exec_result\"] not found")
            return
        }
        #expect(reviewExecResult == "REVIEW_EXEC_RESULT")
        
        guard let publishExecResult = shared["publish_exec_result"] as? String else {
            Issue.record("shared[\"publish_exec_result\"] not found")
            return
        }
        #expect(publishExecResult == "PUBLISH_EXEC_RESULT")
        
        #expect(shared["draft_exec_result"] == nil)
    }
    
    @Test func testLooping() async throws {
        final class Loop: BaseNode<Int, Int> {
            override func prep(shared: inout Shared) async throws -> Int {
                guard let count = shared["count"] as? Int else {return 0}
                return count
            }
            
            override func exec(prep: Int) async throws -> Int {
                return prep + 1
            }
            
            override func post(shared: inout Shared, prep: Int, exec: Int) async throws -> Action? {
                let count = exec
                shared["count"] = count
                return count >= 3 ? "done" : "loop"
            }
        }
        
        final class Done: BaseNode<String, String> {
            override func prep(shared: inout BaseNode<String, String>.Shared) async throws -> String {
                return "DONE_PREP_RESULT"
            }
            
            override func exec(prep: String) async throws -> String {
                return "DONE"
            }
            
            override func post(shared: inout BaseNode<String, String>.Shared, prep: String, exec: String) async throws -> Action? {
                shared["done_exec_result"] = exec
                return nil
            }
        }
        
        let loop = Loop()
        let done = Done()
        
        loop <> "loop" >>> loop
        loop <> "done" >>> done
        
        let flow = Flow(start: loop)
        var shared = [String: Sendable]()
        _ = try await flow.run(shared: &shared)
        
        guard let countResult = shared["count"] as? Int else {
            Issue.record("shared[\"count\"] not found")
            return
        }
        #expect(countResult == 3)
        
        guard let doneExecResult = shared["done_exec_result"] as? String else {
            Issue.record("shared[\"done_exec_result\"] not found")
            return
        }
        #expect(doneExecResult == "DONE")
    }
}
