//
//  WeakFutureWrapper.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 25/12/23.
//

import Foundation
import Combine

struct WeakFutureWrapper<Output, Failure: Error> {
    weak var future: Future<Output, Failure>?
    
    init(future: Future<Output, Failure>? = nil) {
        self.future = future
    }
}
