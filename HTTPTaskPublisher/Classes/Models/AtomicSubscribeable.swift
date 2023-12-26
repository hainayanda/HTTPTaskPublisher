//
//  AtomicSubscribeable.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 26/12/23.
//

import Foundation
import Combine

protocol AtomicSubscribeable: AnyObject {
    
    var atomicQueue: DispatchQueue { get }
    var subscribers: [CombineIdentifier: any CustomCombineIdentifierConvertible] { get set }
}

extension AtomicSubscribeable {
    
    func forEachSubscriber(_ action: (CustomCombineIdentifierConvertible) -> Void) {
        atomicQueue.sync(flags: .barrier) {
            self.subscribers.values.forEach(action)
        }
    }
    
    func forEachSubscriber<S>(tryCastTo type: S.Type, _ action: (S) -> Void) {
        forEachSubscriber { subscriber in
            guard let casted = subscriber as? S else { return }
            action(casted)
        }
    }
    
    func dequeueAllSubscriber(_ action: (CustomCombineIdentifierConvertible) -> Void) {
        atomicQueue.sync(flags: .barrier) {
            let subscribers = self.subscribers.values
            self.subscribers = [:]
            subscribers.forEach(action)
        }
    }
    
    func dequeueAllSubscriber<S>(tryCastTo type: S.Type, _ action: (S) -> Void) {
        dequeueAllSubscriber { subscriber in
            guard let casted = subscriber as? S else { return }
            action(casted)
        }
    }
}
