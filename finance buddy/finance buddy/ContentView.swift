//
//  ContentView.swift
//  finance buddy
//
//  Created by Hannah Holden on 10/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "dollarsign.circle.fill")
                    .imageScale(.large)
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                
                Text("Welcome to Finance Buddy!")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let email = authManager.user?.email {
                    Text("Logged in as:")
                        .foregroundColor(.secondary)
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                // Sign Out Button
                Button(action: {
                    authManager.signOut()
                }) {
                    Text("Sign Out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Finance Buddy")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
