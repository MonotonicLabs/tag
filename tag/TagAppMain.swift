//
//  TagAppMain.swift
//  tag
//
//  Created by Oliy on 1/27/26.
//

import Darwin
import Foundation
import SwiftUI

@main
struct TagAppMain {
    static func main() async {
        if CommandLine.arguments.contains("--run-once") {
            let code = await HeadlessRunner.runOnce()
            exit(code)
        }

        tagApp.main()
    }
}
