//
//  String+Extensions.swift
//  HTTPTaskPublisher
//
//  Created by Nayanda Haberty on 27/5/23.
//

import Foundation

extension String {
    func extractFrom(regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self,
                                        range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
