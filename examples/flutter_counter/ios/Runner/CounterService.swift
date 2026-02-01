import Foundation
import NativeRPCKit

class CounterService: NativeRPCService {
    private var count = 0
    
    @ServiceDefinitionBuilder
    override func definition() -> ServiceDefinitionContainer {
        Name("counter")
        
        Function("getValue") { [weak self] () -> Int in
            return self?.count ?? 0
        }
        
        Function("increment") { [weak self] () -> Int in
            guard let self = self else { return 0 }
            self.count += 1
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        Function("decrement") { [weak self] () -> Int in
            guard let self = self else { return 0 }
            self.count -= 1
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        Function("reset") { [weak self] () -> Int in
            guard let self = self else { return 0 }
            self.count = 0
            self.emit("countChanged", data: ["count": self.count])
            return self.count
        }
        
        Events("countChanged")
    }
}
