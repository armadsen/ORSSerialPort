//
//  ContentView.swift
//  SwiftUIDemo
//
//  Created by Jan Anstipp on 02.10.20.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewM: ViewModel = ViewModel()
    var body: some View {
        DemoView(viewM: viewM)
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
