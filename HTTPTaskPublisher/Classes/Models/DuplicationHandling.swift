//
//  DuplicationHandling.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 25/12/23.
//

import Foundation

public enum DuplicationHandling {
    /// always create a new data task request no matter what
    case alwaysCreateNew
    /// subscribe to the current ongoing identical task if have any, otherwise, create a new data task
    case useCurrentIfPossible
    /// cancel the request if there is an ongoing identical task, otherwise, create a new data task
    case dropIfDuplicated
}
