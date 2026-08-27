//
//  ContentView.swift
//  Strides
//
//  Created by Hamza ST on 19/8/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LiveRunningHUDView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
